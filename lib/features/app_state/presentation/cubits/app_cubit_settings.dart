part of 'app_cubit.dart';

mixin AppCubitSettingsMixin on AppCubitBase {
  Future<void> updateSettings({
    String? userName,
    String? currencyCode,
    bool? notificationsEnabled,
    String? googleEmail,
    String? backupDirectoryPath,
    String? autoBackupMode,
    String? profileImageUrl,
  }) async {
    final next = state.copyWith(
      userName: userName,
      currencyCode: currencyCode,
      notificationsEnabled: notificationsEnabled,
      googleEmail: googleEmail,
      backupDirectoryPath: backupDirectoryPath,
      autoBackupMode: autoBackupMode,
      profileImageUrl: profileImageUrl,
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'settings',
      entityId: 'app-settings',
      details: 'تم تعديل إعدادات التطبيق',
      apply: () async => next,
    );
  }

  Future<void> updateAutoBackupTimestamp(DateTime at) async {
    final next = state.copyWith(lastAutoBackupAt: at.toIso8601String());
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }
}
