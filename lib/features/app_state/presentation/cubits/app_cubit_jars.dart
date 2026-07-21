part of 'app_cubit.dart';

mixin AppCubitJarsMixin on AppCubitBase {
  Future<void> reorderJars(List<LinkedWalletEntity> ordered) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: ordered),
    );
  }

  Future<void> toggleJarHighlight(String jarId) async {
    final jars = state.budgetSetup.linkedWallets.map((j) {
      if (j.id != jarId) return j;
      return j.copyWith(isHighlighted: !j.isHighlighted);
    }).toList();
    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: jars),
    );
  }

  Future<void> addLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(state.budgetSetup.copyWith(
        linkedWallets: [...state.budgetSetup.linkedWallets, linkedWallet]));
  }

  Future<void> updateLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .map((item) => item.id == linkedWallet.id ? linkedWallet : item)
            .toList(),
      ),
    );
  }

  /// تحديث مصادر الحصالة (label فقط — بدون تغيير الرصيد أو إنشاء transaction)

  Future<void> deleteLinkedWallet(String id) async {
    if (id == 'linked-savings-default') {
      return;
    }
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .where((wallet) => wallet.id != id)
            .toList(),
      ),
    );
  }

  /// تأكيد توزيع الراتب على حصالة "يحتاج تأكيد"
  Future<void> confirmJarDistribution(String jarId) async {
    final jars = List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
    final idx = jars.indexWhere((j) => j.id == jarId);
    if (idx == -1) return;
    final jar = jars[idx];
    final amount = jar.pendingDistribution;
    if (amount <= 0) return;
    final isPhysical = _isJarPendingPhysical(jar);

    final clearedPending = jars
        .map((item) => item.id == jarId
            ? item.copyWith(
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
                pendingDistributionSnoozedUntil: '',
              )
            : item)
        .toList();
    final stagedState = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: clearedPending),
    );

    emit(stagedState);
    await _repository.saveState(stagedState);

    final historyTitle = isPhysical
        ? jarPhysicalConfirmTitle(jarName: jar.name)
        : jarAllocationConfirmTitle(jarName: jar.name);
    final historyMessage = isPhysical
        ? jarPhysicalConfirmMessage(amount: amount, jarName: jar.name)
        : jarAllocationConfirmMessage(amount: amount, jarName: jar.name);

    await addTransaction(
      walletId: jar.pendingDistributionWalletId.isNotEmpty
          ? jar.pendingDistributionWalletId
          : null,
      fromWalletId: !isPhysical && jar.pendingDistributionWalletId.isNotEmpty
          ? jar.pendingDistributionWalletId
          : null,
      toWalletId: jar.id,
      amount: amount,
      type: isPhysical
          ? TransactionType.expense.value
          : TransactionType.transfer.value,
      budgetScope: BudgetScope.withinBudget.value,
      incomeSourceId: jar.pendingDistributionSourceId.isNotEmpty
          ? jar.pendingDistributionSourceId
          : null,
      transferType: isPhysical
          ? TransferType.jarFundingPhysical.value
          : TransferType.jarFunding.value,
      notes: null,
      details: historyMessage,
      notificationTitleOverride: historyTitle,
      recordInNotificationHistory: true,
    );
  }

  /// تأجيل (إلغاء) توزيع معلّق على حصالة
  Future<void> postponeJarDistribution(String jarId) async {
    final jar = state.budgetSetup.linkedWallets.firstWhere(
      (j) => j.id == jarId,
      orElse: () => state.budgetSetup.linkedWallets.first,
    );
    final amount = jar.pendingDistribution;
    final jars = state.budgetSetup.linkedWallets
        .map((j) => j.id == jarId
            ? j.copyWith(
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
                pendingDistributionSnoozedUntil: '',
              )
            : j)
        .toList();
    final historyTitle = jarAllocationSkipTitle(jarName: jar.name);
    final historyMessage =
        jarAllocationSkipMessage(amount: amount, jarName: jar.name);
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: jars),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'jar',
      entityId: jarId,
      details: historyMessage,
      titleOverride: historyTitle,
      recordInNotificationHistory: true,
      apply: () async => next,
    );
  }

  Future<void> snoozeJarDistribution(String jarId, DateTime until) async {
    final jars = state.budgetSetup.linkedWallets
        .map(
          (j) => j.id == jarId
              ? j.copyWith(
                  pendingDistributionSnoozedUntil: until.toIso8601String(),
                )
              : j,
        )
        .toList();
    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: jars),
    );
  }

  bool _isJarPendingPhysical(LinkedWalletEntity jar) {
    final sourceId = jar.pendingDistributionSourceId;
    if (sourceId.isEmpty) return false;
    return jar.funding.any(
      (entry) => entry.incomeSourceId == sourceId && entry.isPhysical,
    );
  }

  Future<void> ensureDefaultSavingsJar() async {
    final next = MigrationService.ensureDefaultSavingsJarSync(state);
    if (identical(next, state)) return;
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }
}
