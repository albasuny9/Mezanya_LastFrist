import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';
import '../diagnostics/persistence_diagnostics.dart';
import '../serializers/app_state_serializer.dart';
import '../store/core_state_store.dart';
import '../store/logs_store.dart';
import '../store/shared_prefs_store.dart';
import '../validation/app_state_validator.dart';

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
// CoreStateStore -> AppStateSerializer -> AppStateValidator -> migration ->
// diagnostics -> return AppState, and the mirror sequence for save. (The
// "AppStateSerializer" and "validation" split described here was further
// refined in the final cleanup pass below — see that note for the current,
// accurate picture.)
//
// Phase 6.4: the size/breakdown diagnostics report moved to
// PersistenceDiagnostics (../diagnostics/persistence_diagnostics.dart) —
// self-gated by kDebugMode internally, called unconditionally from
// _writeCore.
//
// Final cleanup pass:
//   - The Sprint #2 timing instrumentation (Stopwatch/TxnTimingCollector)
//     that used to wrap every step here was investigation-only scaffolding,
//     never part of the permanent architecture — removed entirely rather
//     than extracted, along with the two files that defined it
//     (core/perf/txn_timing.dart, core/perf/screen_open_timing.dart).
//   - Validation (the try/catch parse-attempt logic) moved to
//     AppStateValidator (../validation/app_state_validator.dart). This
//     repository no longer contains any try/catch itself — it checks
//     AppStateValidator's null-on-failure return value instead, and still
//     owns the *decision* of what to do on failure (never overwrite a
//     corrupted payload on disk), since that decision is tied to
//     persistence, not to whether the JSON parsed.
//   - Migration ordering (logs written before core, for crash-safety) was
//     reviewed and left unchanged — it was already correct.
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

    // AppStateValidator.tryDeserializeCore reads `logs` from the map if
    // present (old format) and defaults to an empty list if absent (new
    // format) — this line's behavior is correct for both formats without
    // any special-casing.
    final deserialized = AppStateValidator.tryDeserializeCore(payload);
    if (deserialized == null) {
      // لا نكتب فوق الـ payload المعطوب على الديسك — القراءة الفاشلة قد
      // تكون عارضة (race, عطل مؤقت في الـ plugin...)، والكتابة هنا كانت
      // بتحوّلها لمسح دائم لبيانات المستخدم. نرجّع حالة ابتدائية للجلسة
      // الحالية فقط، ونترك البيانات الأصلية كما هي على الديسك.
      return AppStateEntity.initial();
    }
    var state = deserialized;

    final logsPayload = _logsStore.loadLogs();
    if (logsPayload == null || logsPayload.isEmpty) {
      // ── One-time migration ──────────────────────────────────────────
      // The separate logs key doesn't exist yet. `state.logs` at this
      // point holds whatever `tryDeserializeCore` found embedded in the
      // legacy blob (the full historical log list if this install
      // predates this change, or an empty list for a fresh install —
      // either way correct). Persist it to the new key, then rewrite the
      // core blob without embedded logs.
      //
      // Crash-safety: logs are written FIRST. If the app is killed
      // between the two writes, the next launch sees a non-null
      // logsPayload and takes the normal (non-migration) path below,
      // re-reading the still-legacy core blob (which still has the logs
      // embedded, since its rewrite didn't complete) and then
      // overwriting `state.logs` with the (identical) content from the
      // new key — a harmless no-op, not data loss. The core blob only
      // finally drops its embedded logs on the next successful save.
      await _writeLogs(state.logs);
      await _writeCore(state);
    } else {
      final logs = AppStateValidator.tryDeserializeLogs(logsPayload);
      if (logs != null) {
        state = state.copyWith(logs: logs);
      }
      // else: separate logs payload corrupted — do not overwrite it (same
      // "never destroy on read failure" principle as above). state.logs
      // stays as whatever tryDeserializeCore produced from the core blob
      // (normally empty, post-migration).
    }
    return state;
  }

  @override
  Future<void> saveState(AppStateEntity state) async {
    await _writeLogs(state.logs);
    await _writeCore(state);
  }

  Future<void> _writeLogs(List<LogEntryEntity> logs) async {
    final payload = AppStateSerializer.serializeLogs(logs);
    await _logsStore.saveLogs(payload);
  }

  Future<void> _writeCore(AppStateEntity state) async {
    final payload = AppStateSerializer.serializeCore(state);
    PersistenceDiagnostics.reportSizeBreakdown(state, payload);
    await _coreStore.saveCore(payload);
  }
}
