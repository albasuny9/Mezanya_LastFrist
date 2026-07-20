part of 'app_cubit.dart';

mixin AppCubitAllocationsMixin on AppCubitBase {
  /// تأكيد توزيع الراتب على مخصصة "يحتاج تأكيد"
  Future<void> confirmAllocationDistribution(String allocationId) async {
    final allocations =
        List<AllocationEntity>.from(state.budgetSetup.allocations);
    final idx = allocations.indexWhere((a) => a.id == allocationId);
    if (idx == -1) return;
    final alloc = allocations[idx];
    final amount = alloc.pendingDistribution;
    if (amount <= 0) return;

    final nextBalances = Map<String, double>.from(alloc.walletBalances);
    if (alloc.pendingDistributionWalletId.isNotEmpty) {
      nextBalances[alloc.pendingDistributionWalletId] =
          (nextBalances[alloc.pendingDistributionWalletId] ?? 0) + amount;
    }
    allocations[idx] = alloc.copyWith(
      balance: alloc.balance + amount,
      walletBalances: nextBalances,
      pendingDistribution: 0,
      pendingDistributionWalletId: '',
      pendingDistributionSourceId: '',
      pendingDistributionSnoozedUntil: '',
    );

    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(allocations: allocations),
    );
    final historyTitle = allocationConfirmTitle(name: alloc.name);
    final historyMessage =
        allocationConfirmMessage(amount: amount, name: alloc.name);
    await _applyAndLog(
      action: 'edit',
      entityType: 'allocation',
      entityId: allocationId,
      details: historyMessage,
      titleOverride: historyTitle,
      recordInNotificationHistory: true,
      apply: () async => next,
    );
  }

  /// تأجيل (إلغاء) توزيع معلّق على مخصصة
  Future<void> postponeAllocationDistribution(String allocationId) async {
    final alloc = state.budgetSetup.allocations.firstWhere(
      (a) => a.id == allocationId,
      orElse: () => state.budgetSetup.allocations.first,
    );
    final amount = alloc.pendingDistribution;
    final allocations = state.budgetSetup.allocations
        .map((a) => a.id == allocationId
            ? a.copyWith(
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
                pendingDistributionSnoozedUntil: '',
              )
            : a)
        .toList();
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(allocations: allocations),
    );
    final historyTitle = allocationSkipTitle(name: alloc.name);
    final historyMessage =
        allocationSkipMessage(amount: amount, name: alloc.name);
    await _applyAndLog(
      action: 'edit',
      entityType: 'allocation',
      entityId: allocationId,
      details: historyMessage,
      titleOverride: historyTitle,
      recordInNotificationHistory: true,
      apply: () async => next,
    );
  }

  Future<void> snoozeAllocationDistribution(
    String allocationId,
    DateTime until,
  ) async {
    final allocations = state.budgetSetup.allocations
        .map(
          (a) => a.id == allocationId
              ? a.copyWith(
                  pendingDistributionSnoozedUntil: until.toIso8601String(),
                )
              : a,
        )
        .toList();
    await updateBudgetSetup(
      state.budgetSetup.copyWith(allocations: allocations),
    );
  }

  Future<void> updateAllocationCategories({
    required String allocationId,
    required List<CategoryEntity> categories,
  }) async {
    final allocations = state.budgetSetup.allocations
        .map((item) => item.id == allocationId
            ? item.copyWith(categories: categories)
            : item)
        .toList();
    await updateBudgetSetup(
        state.budgetSetup.copyWith(allocations: allocations));
  }
}
