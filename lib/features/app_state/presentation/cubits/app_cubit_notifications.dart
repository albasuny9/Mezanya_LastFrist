part of 'app_cubit.dart';

mixin AppCubitNotificationsMixin on AppCubitBase {
  Future<void> toggleLogRevert(String logId) async {
    final target = state.logs.where((log) => log.id == logId).toList();
    if (target.isEmpty) return;
    final log = target.first;

    final updatedLogs = state.logs
        .map((item) => item.id == logId
            ? item.copyWith(
                isReverted: !item.isReverted,
                revertedAt: item.isReverted ? null : DateTime.now())
            : item)
        .toList();

    final restored = _restoreFromCore(
        log.isReverted ? log.afterState : log.beforeState, updatedLogs);
    final revertLog = LogEntryEntity(
      id: _id('log'),
      action: 'revert',
      entityType: log.entityType,
      entityId: log.entityId,
      details: log.isReverted
          ? 'تم التراجع عن التراجع'
          : 'تم التراجع عن العملية الأصلية',
      timestamp: DateTime.now(),
      beforeState: jsonEncode(_coreMap(state.copyWith(logs: updatedLogs))),
      afterState: jsonEncode(_coreMap(restored)),
      isReverted: false,
    );
    final revertNotification = NotificationEntity(
      id: _id('notif'),
      title: 'إشعار تراجع',
      message: revertLog.details,
      createdAt: DateTime.now(),
      type: 'revert-system', // Changed to hide from history UI
      relatedLogId: revertLog.id,
    );
    final next = restored.copyWith(
      logs: [revertLog, ...updatedLogs].take(600).toList(),
      notifications:
          [revertNotification, ...state.notifications].take(800).toList(),
    );
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final updated = state.notifications
        .map((n) => n.id == notificationId && !n.isRead
            ? n.copyWith(readAt: DateTime.now())
            : n)
        .toList();
    final next = state.copyWith(notifications: updated);
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }
}
