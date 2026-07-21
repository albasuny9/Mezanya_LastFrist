part of 'app_cubit.dart';

mixin AppCubitBudgetMixin on AppCubitBase {
  @override
  Future<void> updateBudgetSetup(
    BudgetSetupEntity setup, {
    String? detailsOverride,
    String? titleOverride,
    bool recordInNotificationHistory = false,
  }) async {
    final details = detailsOverride ?? 'تم تعديل إعدادات الميزانية';
    await _applyAndLog(
      action: 'edit',
      entityType: 'budget',
      entityId: 'budget-setup',
      details: details,
      titleOverride:
          recordInNotificationHistory ? (titleOverride ?? details) : null,
      recordInNotificationHistory: recordInNotificationHistory,
      apply: () async {
        final raw = state.copyWith(budgetSetup: setup);
        return _withMonthlySnapshot(raw, setup);
      },
    );
  }
}
