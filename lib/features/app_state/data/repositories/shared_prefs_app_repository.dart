import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../../core/storage/shared_prefs_keys.dart';
import '../../../../core/perf/txn_timing.dart'; // Sprint #2 — remove when done
import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';
import '../serializers/app_state_serializer.dart';
import '../store/shared_prefs_store.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Emergency stabilization (Phase 1 of the persistence-architecture plan).
//
// Problem measured in production: the audit-log history (LogEntryEntity,
// each holding full beforeState/afterState JSON snapshots) was embedded
// inside the same single SharedPreferences blob as the rest of AppState.
// With ~250 logs this blob reached 16+ MB, and every single transaction
// save re-serialized and re-wrote that entire blob — measured at ~5.2s per
// save and an eventual OutOfMemoryError crash reading it back.
//
// Fix (this file only — AppRepository's public API is unchanged):
//   - `logs` are now persisted under their own SharedPreferences key
//     (SharedPrefsKeys.appStateLogs), serialized independently.
//   - The main `appState` key no longer embeds `logs` at all
//     (AppStateEntity.toMap(includeLogs: false)).
//   - Both blobs are still written on every save in this phase (no
//     incremental/partial persistence yet — that's Phase 2/3 of the
//     long-term plan). The win here is that the *core* AppState blob no
//     longer carries the ever-growing, multi-megabyte logs history, so
//     jsonEncode/setString on the core blob become fast and bounded by
//     the actual financial data size, not by audit-history size.
//   - Each blob can now also be reasoned about/inspected/migrated
//     independently.
//   - The log cap (600) is unchanged. No audit history is discarded.
//
// Migration: see the `logsPayload == null` branch in loadState below.
//
// Phase 6.1 (persistence-architecture redesign, see conversation report):
// core/logs JSON serialization and deserialization moved to
// AppStateSerializer (../serializers/app_state_serializer.dart) — pure
// functions, no SharedPreferences/timing/diagnostics/migration/validation
// knowledge. This repository now only calls it; the try/catch structure,
// migration logic, timing instrumentation, and diagnostics below are
// unchanged and still live here (each is its own future extraction step).
//
// Phase 6.2: raw SharedPreferences I/O moved to SharedPrefsStore
// (../store/shared_prefs_store.dart) — readString/writeString only, no
// JSON/entity/domain knowledge. This repository is now the only caller of
// SharedPrefsStore for app-state persistence; it no longer touches
// SharedPreferences directly at all.
// ═══════════════════════════════════════════════════════════════════════════

class SharedPrefsAppRepository implements AppRepository {
  SharedPrefsAppRepository(this._store);

  final SharedPrefsStore _store;

  @override
  Future<AppStateEntity> loadState() async {
    final payload = _store.readString(SharedPrefsKeys.appState);
    if (payload == null || payload.isEmpty) {
      final initial = AppStateEntity.initial();
      await saveState(initial);
      return initial;
    }
    try {
      // AppStateSerializer.deserializeCore reads `logs` from the map if
      // present (old format) and defaults to an empty list if absent (new
      // format) — this line's behavior is correct for both formats
      // without any special-casing.
      var state = AppStateSerializer.deserializeCore(payload);

      final logsPayload = _store.readString(SharedPrefsKeys.appStateLogs);
      if (logsPayload == null || logsPayload.isEmpty) {
        // ── One-time migration ──────────────────────────────────────────
        // The separate logs key doesn't exist yet. `state.logs` at this
        // point holds whatever `fromMap` found embedded in the legacy
        // blob (the full historical log list if this install predates
        // this change, or an empty list for a fresh install — either way
        // correct). Persist it to the new key, then rewrite the core
        // blob without embedded logs.
        //
        // Crash-safety: logs are written FIRST. If the app is killed
        // between the two writes, the next launch sees a non-null
        // logsPayload and takes the normal (non-migration) path below,
        // re-reading the still-legacy core blob (which still has the
        // logs embedded, since its rewrite didn't complete) and then
        // overwriting `state.logs` with the (identical) content from the
        // new key — a harmless no-op, not data loss. The core blob only
        // finally drops its embedded logs on the next successful save.
        await _writeLogs(state.logs);
        await _writeCore(state);
      } else {
        try {
          final logs = AppStateSerializer.deserializeLogs(logsPayload);
          state = state.copyWith(logs: logs);
        } catch (_) {
          // Separate logs payload corrupted — do not overwrite it (same
          // "never destroy on read failure" principle as the outer
          // catch below). state.logs stays as whatever fromMap produced
          // from the core blob (normally empty, post-migration).
        }
      }
      return state;
    } catch (_) {
      // لا نكتب فوق الـ payload المعطوب على الديسك — القراءة الفاشلة قد
      // تكون عارضة (race, عطل مؤقت في الـ plugin...)، والكتابة هنا كانت
      // بتحوّلها لمسح دائم لبيانات المستخدم. نرجّع حالة ابتدائية للجلسة
      // الحالية فقط، ونترك البيانات الأصلية كما هي على الديسك.
      return AppStateEntity.initial();
    }
  }

  @override
  Future<void> saveState(AppStateEntity state) async {
    await _writeLogs(state.logs);
    await _writeCore(state);
  }

  Future<void> _writeLogs(List<LogEntryEntity> logs) async {
    final _swEncode = Stopwatch()..start();
    final payload = AppStateSerializer.serializeLogs(logs);
    _swEncode.stop();
    TxnTimingCollector.current.record(
        '06d | jsonEncode — logs blob', _swEncode.elapsedMilliseconds);

    final _swSet = Stopwatch()..start();
    await _store.writeString(SharedPrefsKeys.appStateLogs, payload);
    _swSet.stop();
    TxnTimingCollector.current.record(
        '08b | SharedPreferences.setString(logs)', _swSet.elapsedMilliseconds);
  }

  Future<void> _writeCore(AppStateEntity state) async {
    // ── Sprint #2: measure jsonEncode and setString separately ──────────────
    final _swEncode = Stopwatch()..start();
    final payload = AppStateSerializer.serializeCore(state);
    _swEncode.stop();
    TxnTimingCollector.current
        .record('06c | jsonEncode — saveState.toMap()', _swEncode.elapsedMilliseconds);

    // ── DIAG: AppState size + section breakdown — remove when done ───────────
    if (kDebugMode) _diagPrint(state, payload);
    // ─────────────────────────────────────────────────────────────────────────

    final _swSet = Stopwatch()..start();
    await _store.writeString(SharedPrefsKeys.appState, payload);
    _swSet.stop();
    TxnTimingCollector.current
        .record('08  | SharedPreferences.setString()', _swSet.elapsedMilliseconds);
    // ────────────────────────────────────────────────────────────────────────
  }

  // ── DIAG helper — remove together with the call above ─────────────────────
  void _diagPrint(AppStateEntity state, String payload) {
    // helpers
    int _b(Object obj) => utf8.encode(jsonEncode(obj)).length;
    String _fmt(int b) {
      if (b >= 1024 * 1024) return '${(b / 1048576).toStringAsFixed(2)} MB';
      if (b >= 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
      return '$b B';
    }

    // ── 1. Final payload size ─────────────────────────────────────────────
    final totalBytes = utf8.encode(payload).length;
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════════════════╗');
    debugPrint('║          APPSTATE SIZE DIAGNOSIS                      ║');
    debugPrint('╠═══════════════════════════════════════════════════════╣');
    debugPrint('  Payload');
    debugPrint('    Characters : ${payload.length}');
    debugPrint('    Bytes      : $totalBytes');
    debugPrint('    KB         : ${(totalBytes / 1024).toStringAsFixed(1)}');
    debugPrint('    MB         : ${(totalBytes / 1048576).toStringAsFixed(2)}');

    // ── 2. Collection counts ──────────────────────────────────────────────
    debugPrint('');
    debugPrint('  Collection counts');
    debugPrint('    transactions             : ${state.transactions.length}');
    debugPrint('    logs                     : ${state.logs.length}');
    debugPrint('    notifications            : ${state.notifications.length}');
    debugPrint('    wallets                  : ${state.wallets.length}');
    debugPrint('    categories               : ${state.categories.length}');
    debugPrint('    goals                    : ${state.goals.length}');
    debugPrint('    recurringTransactions    : ${state.recurringTransactions.length}');
    debugPrint('    moneyDistributions       : ${state.moneyDistributions.length}');
    debugPrint('    monthlyBudgetSnapshots   : ${state.monthlyBudgetSnapshots.length}');
    debugPrint('    budgetSetup.incomeSources: ${state.budgetSetup.incomeSources.length}');
    debugPrint('    budgetSetup.allocations  : ${state.budgetSetup.allocations.length}');
    debugPrint('    budgetSetup.linkedWallets: ${state.budgetSetup.linkedWallets.length}');
    debugPrint('    budgetSetup.debts        : ${state.budgetSetup.debts.length}');

    // ── 3. Per-section serialized sizes ───────────────────────────────────
    final txnB      = _b(state.transactions.map((t) => t.toMap()).toList());
    final logsB     = _b(state.logs.map((l) => l.toMap()).toList());
    final notifB    = _b(state.notifications.map((n) => n.toMap()).toList());
    final walletB   = _b(state.wallets.map((w) => w.toMap()).toList());
    final budgetB   = _b(state.budgetSetup.toMap());
    final catB      = _b(state.categories.map((c) => c.toMap()).toList());
    final goalB     = _b(state.goals.map((g) => g.toMap()).toList());
    final recurB    = _b(state.recurringTransactions.map((r) => r.toMap()).toList());
    final distB     = _b(state.moneyDistributions.map((d) => d.toMap()).toList());
    final snapB     = _b(state.monthlyBudgetSnapshots);

    debugPrint('');
    debugPrint('  Section serialized sizes');
    debugPrint('    transactions           : ${_fmt(txnB).padLeft(10)}  (${(txnB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    logs                   : ${_fmt(logsB).padLeft(10)}  (${(logsB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    notifications          : ${_fmt(notifB).padLeft(10)}  (${(notifB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    wallets                : ${_fmt(walletB).padLeft(10)}  (${(walletB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    budgetSetup            : ${_fmt(budgetB).padLeft(10)}  (${(budgetB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    categories             : ${_fmt(catB).padLeft(10)}  (${(catB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    goals                  : ${_fmt(goalB).padLeft(10)}  (${(goalB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    recurringTransactions  : ${_fmt(recurB).padLeft(10)}  (${(recurB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    moneyDistributions     : ${_fmt(distB).padLeft(10)}  (${(distB * 100 / totalBytes).toStringAsFixed(1)}%)');
    debugPrint('    monthlyBudgetSnapshots : ${_fmt(snapB).padLeft(10)}  (${(snapB * 100 / totalBytes).toStringAsFixed(1)}%)');

    // ── 4. Deep logs investigation ─────────────────────────────────────────
    debugPrint('');
    if (state.logs.isEmpty) {
      debugPrint('  Logs: empty');
    } else {
      final beforeLens = state.logs.map((l) => l.beforeState.length).toList();
      final afterLens  = state.logs.map((l) => l.afterState.length).toList();
      final maxBefore  = beforeLens.reduce((a, b) => a > b ? a : b);
      final maxAfter   = afterLens.reduce((a, b) => a > b ? a : b);
      final avgBefore  = beforeLens.fold<int>(0, (s, l) => s + l) ~/ beforeLens.length;
      final avgAfter   = afterLens.fold<int>(0, (s, l) => s + l) ~/ afterLens.length;
      final totBefore  = beforeLens.fold<int>(0, (s, l) => s + l);
      final totAfter   = afterLens.fold<int>(0, (s, l) => s + l);

      debugPrint('  Logs deep investigation');
      debugPrint('    count                       : ${state.logs.length}');
      debugPrint('    largest beforeState (chars) : $maxBefore  (${_fmt(maxBefore)})');
      debugPrint('    largest afterState  (chars) : $maxAfter  (${_fmt(maxAfter)})');
      debugPrint('    average beforeState (chars) : $avgBefore  (${_fmt(avgBefore)})');
      debugPrint('    average afterState  (chars) : $avgAfter  (${_fmt(avgAfter)})');
      debugPrint('    total beforeState bytes     : ${_fmt(totBefore)}');
      debugPrint('    total afterState  bytes     : ${_fmt(totAfter)}');
      debugPrint('    total state-string overhead : ${_fmt(totBefore + totAfter)}');
    }

    debugPrint('╚═══════════════════════════════════════════════════════╝');
    debugPrint('');
  }
  // ── end DIAG ──────────────────────────────────────────────────────────────
}
