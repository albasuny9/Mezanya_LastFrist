import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/shared_prefs_keys.dart';
import '../../../../core/perf/txn_timing.dart'; // Sprint #2 — remove when done
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';

class SharedPrefsAppRepository implements AppRepository {
  SharedPrefsAppRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<AppStateEntity> loadState() async {
    final payload = _prefs.getString(SharedPrefsKeys.appState);
    if (payload == null || payload.isEmpty) {
      final initial = AppStateEntity.initial();
      await saveState(initial);
      return initial;
    }
    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return AppStateEntity.fromMap(decoded);
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
    // ── Sprint #2: measure jsonEncode and setString separately ──────────────
    final _swEncode = Stopwatch()..start();
    final payload = jsonEncode(state.toMap());
    _swEncode.stop();
    TxnTimingCollector.current
        .record('06c | jsonEncode — saveState.toMap()', _swEncode.elapsedMilliseconds);

    // ── DIAG: AppState size + section breakdown — remove when done ───────────
    if (kDebugMode) _diagPrint(state, payload);
    // ─────────────────────────────────────────────────────────────────────────

    final _swSet = Stopwatch()..start();
    await _prefs.setString(SharedPrefsKeys.appState, payload);
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
