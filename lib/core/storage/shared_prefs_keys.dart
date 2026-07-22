class SharedPrefsKeys {
  static const appState = 'korassa_app_state';

  /// Emergency stabilization (Phase 1): logs are stored separately from
  /// the main app_state blob so a normal transaction save no longer has
  /// to re-serialize/re-write the entire audit-log history on every
  /// write. See shared_prefs_app_repository.dart for the migration.
  static const appStateLogs = 'korassa_app_state_logs';
}
