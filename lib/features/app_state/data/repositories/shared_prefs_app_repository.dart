import 'dart:convert';

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
      final fallback = AppStateEntity.initial();
      await saveState(fallback);
      return fallback;
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

    final _swSet = Stopwatch()..start();
    await _prefs.setString(SharedPrefsKeys.appState, payload);
    _swSet.stop();
    TxnTimingCollector.current
        .record('08  | SharedPreferences.setString()', _swSet.elapsedMilliseconds);
    // ────────────────────────────────────────────────────────────────────────
  }
}
