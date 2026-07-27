import '../../../../core/perf/txn_timing.dart'; // Sprint #2 — remove when done
import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';
import '../diagnostics/persistence_diagnostics.dart';
import '../serializers/app_state_serializer.dart';
import '../store/core_state_store.dart';
import '../store/logs_store.dart';
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
//
// Phase 6.3: raw core/logs payload persistence moved to CoreStateStore and
// LogsStore (../store/core_state_store.dart, ../store/logs_store.dart) —
// each a thin, single-key wrapper over SharedPrefsStore
// (loadCore/saveCore, loadLogs/saveLogs). This repository no longer knows
// the SharedPrefsKeys.appState/appStateLogs key names at all — it just
// asks each store for "the core payload" / "the logs payload". The
// repository's own responsibility is now purely orchestration: call
// CoreStateStore -> AppStateSerializer -> migration -> (implicit)
// validation via try/catch -> diagnostics -> return AppState, and the
// mirror sequence for save.
//
// Phase 6.4: the size/breakdown diagnostics report moved to
// PersistenceDiagnostics (../diagnostics/persistence_diagnostics.dart) —
// self-gated by kDebugMode internally now, called unconditionally from
// _writeCore. Migration, validation (the try/catch structure), and timing
// instrumentation are unchanged and still live here — each remains its
// own future extraction step, deliberately not touched in this phase.
// ═══════════════════════════════════════════════════════════════════════════

class SharedPrefsAppRepository implements AppRepository {
  SharedPrefsAppRepository(SharedPrefsStore store)
      : _coreStore = CoreStateStore(store),
        _logsStore = LogsStore(store);

  final CoreStateStore _coreStore;
  final LogsStore _logsStore;

  @override
  Future<AppStateEntity> loadState() async {
    final payload = _coreStore.loadCore();
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

      final logsPayload = _logsStore.loadLogs();
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
    await _logsStore.saveLogs(payload);
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

    // ── DIAG: AppState size + section breakdown — self-gated by kDebugMode
    // internally, see PersistenceDiagnostics ────────────────────────────────
    PersistenceDiagnostics.reportSizeBreakdown(state, payload);
    // ─────────────────────────────────────────────────────────────────────────

    final _swSet = Stopwatch()..start();
    await _coreStore.saveCore(payload);
    _swSet.stop();
    TxnTimingCollector.current
        .record('08  | SharedPreferences.setString()', _swSet.elapsedMilliseconds);
    // ────────────────────────────────────────────────────────────────────────
  }
}
