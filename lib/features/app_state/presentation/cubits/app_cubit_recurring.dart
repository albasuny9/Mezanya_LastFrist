part of 'app_cubit.dart';

mixin AppCubitRecurringMixin on AppCubitBase {
  Future<void> addRecurringTransaction({
    String? id,
    required String name,
    required String type,
    required double amount,
    required int dayOfMonth,
    required String executionType,
    required String walletId,
    required String budgetScope,
    required String recurrencePattern,
    required String icon,
    required String iconColor,
    int? weekday,
    List<int>? weekdays,
    int? monthOfYear,
    String? anchorDate,
    String? scheduledTime,
    int? reminderLeadDays,
    String? allocationId,
    String? targetJarId,
    String? incomeSourceId,
    List<String>? categoryIds,
    bool isVariableIncome = false,
    bool isDebtOrSubscription = false,
    String? expensePlanKind,
    double? debtPrincipalTotal,
    int? installmentCount,
    double? installmentDownPayment,
    String? notes,
  }) async {
    final recurring = RecurringTransactionEntity(
      id: id ?? _id('rec'),
      name: name,
      type: type,
      amount: amount,
      dayOfMonth: dayOfMonth,
      executionType: executionType,
      walletId: walletId,
      budgetScope: budgetScope,
      recurrencePattern: recurrencePattern,
      icon: icon,
      iconColor: iconColor,
      weekday: weekday,
      weekdays: weekdays ?? const [],
      monthOfYear: monthOfYear,
      anchorDate: anchorDate,
      scheduledTime: scheduledTime,
      reminderLeadDays: reminderLeadDays,
      allocationId: allocationId,
      targetJarId: targetJarId,
      incomeSourceId: incomeSourceId,
      categoryIds: categoryIds ?? const [],
      isVariableIncome: isVariableIncome,
      isDebtOrSubscription: isDebtOrSubscription,
      expensePlanKind: expensePlanKind,
      debtPrincipalTotal: debtPrincipalTotal,
      installmentCount: installmentCount,
      installmentDownPayment: installmentDownPayment,
      notes: notes,
    );

    // زامن DebtEntity في budget.debts عند إضافة اشتراك/دين من خارج شاشة الميزانية
    final alreadyLinked = state.budgetSetup.debts
        .any((d) => d.recurringTransactionId == recurring.id);
    final nextBudget = (isDebtOrSubscription && !alreadyLinked)
        ? state.budgetSetup.copyWith(debts: [
            ...state.budgetSetup.debts,
            DebtEntity(
              id: 'debt-${recurring.id}',
              name: recurring.name,
              amount: recurring.amount,
              executionDay: recurring.dayOfMonth.clamp(1, 28),
              type: recurring.executionType,
              fundingSource: state.budgetSetup.incomeSources.isNotEmpty
                  ? state.budgetSetup.incomeSources.first.id
                  : '',
              recurringTransactionId: recurring.id,
              kind:
                  recurring.expensePlanKind == ExpensePlanKind.installment.value
                      ? ExpensePlanKind.installment.value
                      : ExpensePlanKind.subscription.value,
              principalTotal: recurring.debtPrincipalTotal,
              installmentCount: recurring.installmentCount,
              downPayment: recurring.installmentDownPayment,
              recurrencePattern: recurring.recurrencePattern,
              monthOfYear: recurring.monthOfYear,
            ),
          ])
        : state.budgetSetup;

    final next = state.copyWith(
      recurringTransactions: [...state.recurringTransactions, recurring],
      budgetSetup: nextBudget,
    );
    await _applyAndLog(
      action: 'add',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: _recurringTransactionDetails('إضافة معاملة متكررة', recurring),
      apply: () async => next,
    );
  }

  Future<void> updateRecurringTransaction(
    RecurringTransactionEntity recurring, {
    String? detailsOverride,
  }) async {
    final next = _applyRecurringSync(state, recurring);
    await _applyAndLog(
      action: 'edit',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: detailsOverride ??
          _recurringTransactionDetails('تعديل معاملة متكررة', recurring),
      titleOverride: recurring.name,
      apply: () async => next,
    );
  }

  AppStateEntity _applyRecurringSync(
    AppStateEntity source,
    RecurringTransactionEntity recurring,
  ) {
    BudgetSetupEntity nextBudget = source.budgetSetup;
    if (recurring.isDebtOrSubscription) {
      final linkedIndex = source.budgetSetup.debts
          .indexWhere((d) => d.recurringTransactionId == recurring.id);
      if (linkedIndex >= 0) {
        final existing = source.budgetSetup.debts[linkedIndex];
        final updated = existing.copyWith(
          name: recurring.name,
          amount: recurring.amount,
          executionDay: recurring.dayOfMonth.clamp(1, 28),
          type: recurring.executionType,
          kind: recurring.expensePlanKind == ExpensePlanKind.installment.value
              ? ExpensePlanKind.installment.value
              : ExpensePlanKind.subscription.value,
          principalTotal: recurring.debtPrincipalTotal,
          installmentCount: recurring.installmentCount,
          downPayment: recurring.installmentDownPayment,
          recurrencePattern: recurring.recurrencePattern,
          monthOfYear: recurring.monthOfYear,
        );
        final updatedDebts = List<DebtEntity>.from(source.budgetSetup.debts)
          ..[linkedIndex] = updated;
        nextBudget = source.budgetSetup.copyWith(debts: updatedDebts);
      }
    }
    return source.copyWith(
      recurringTransactions: source.recurringTransactions
          .map((item) => item.id == recurring.id ? recurring : item)
          .toList(),
      budgetSetup: nextBudget,
    );
  }

  Future<void> recordRecurringIncomeOccurrence({
    required RecurringTransactionEntity recurring,
    required double amount,
    required DateTime occurrence,
    required String transactionNotes,
    required String logDetails,
    String? titleOverride,
  }) async {
    final jarId = recurring.targetJarId?.trim();
    final hasJarTarget = jarId != null && jarId.isNotEmpty;
    final incomeSourceId = recurring.incomeSourceId?.trim();
    final hasBudgetSource = incomeSourceId != null && incomeSourceId.isNotEmpty;

    final transaction = TransactionEntity(
      id: _id('txn'),
      walletId: recurring.walletId,
      toWalletId: hasJarTarget ? jarId : null,
      amount: amount,
      type: TransactionType.income.value,
      budgetScope: hasBudgetSource
          ? BudgetScope.withinBudget.value
          : BudgetScope.outsideBudget.value,
      incomeSourceId: hasBudgetSource ? incomeSourceId : null,
      transferType:
          hasJarTarget ? TransferType.depositWithJarLabel.value : null,
      categoryId:
          recurring.categoryIds.isNotEmpty ? recurring.categoryIds.first : null,
      notes:
          transactionNotes.trim().isEmpty ? recurring.name : transactionNotes,
      createdAt: DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
        occurrence.hour,
        occurrence.minute,
      ),
    );

    final updatedRecurring = recurring.copyWith(
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );

    await _applyAndLog(
      action: 'add',
      entityType: 'recurring-income-handled',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? logDetails,
      recordInNotificationHistory: true,
      apply: () async {
        final stateAfterTx = TransactionProcessor.apply(state, transaction);
        return _applyRecurringSync(stateAfterTx, updatedRecurring);
      },
    );
  }

  Future<void> recordRecurringExpenseOccurrence({
    required RecurringTransactionEntity recurring,
    required double amount,
    required DateTime occurrence,
    required String transactionNotes,
    required String logDetails,
    String? titleOverride,
  }) async {
    final transaction = TransactionEntity(
      id: _id('txn'),
      walletId: recurring.walletId,
      toWalletId: recurring.targetJarId,
      amount: amount,
      type: TransactionType.expense.value,
      budgetScope: recurring.budgetScope,
      allocationId: recurring.allocationId,
      categoryId:
          recurring.categoryIds.isNotEmpty ? recurring.categoryIds.first : null,
      notes: transactionNotes,
      createdAt: DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
        occurrence.hour,
        occurrence.minute,
      ),
    );

    final updatedRecurring = recurring.copyWith(
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );

    await _applyAndLog(
      action: 'add',
      entityType: 'recurring-expense-handled',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? logDetails,
      recordInNotificationHistory: true,
      apply: () async {
        // 1. Add physical transaction (updates balance/allocations)
        final stateAfterTx = TransactionProcessor.apply(state, transaction);
        // 2. Update recurring state & sync debt in one go
        return _applyRecurringSync(stateAfterTx, updatedRecurring);
      },
    );
  }

  Future<void> recordRecurringPostpone({
    required RecurringTransactionEntity recurring,
    required DateTime snoozedUntil,
    required String logDetails,
    String? titleOverride,
  }) async {
    final updatedRecurring = recurring.copyWith(
      snoozedUntil: snoozedUntil.toIso8601String(),
    );

    await _applyAndLog(
      action: 'edit',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? logDetails,
      recordInNotificationHistory: true,
      apply: () async => _applyRecurringSync(state, updatedRecurring),
    );
  }

  Future<void> recordRecurringSkip({
    required RecurringTransactionEntity recurring,
    required DateTime occurrence,
    required String logDetails,
    String? titleOverride,
  }) async {
    final updatedRecurring = recurring.copyWith(
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );

    await _applyAndLog(
      action: 'skip',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? logDetails,
      recordInNotificationHistory: true,
      apply: () async => _applyRecurringSync(state, updatedRecurring),
    );
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final target =
        state.recurringTransactions.where((item) => item.id == id).toList();
    final deleted = target.isEmpty ? null : target.first;

    // احذف DebtEntity المرتبط لو وُجد
    final nextBudget = state.budgetSetup.copyWith(
      debts: state.budgetSetup.debts
          .where((d) => d.recurringTransactionId != id)
          .toList(),
    );

    final next = state.copyWith(
      recurringTransactions:
          state.recurringTransactions.where((item) => item.id != id).toList(),
      budgetSetup: nextBudget,
    );
    await _applyAndLog(
      action: 'delete',
      entityType: 'recurring-transaction',
      entityId: id,
      details: deleted == null
          ? 'تم حذف معاملة متكررة'
          : _recurringTransactionDetails('حذف معاملة متكررة', deleted),
      apply: () async => next,
    );
  }

  String _executionTypeLabel(String type) {
    if (type == AutomationType.auto.value) return 'تلقائي';
    if (type == AutomationType.confirm.value) return 'يحتاج تأكيد';
    if (type == AutomationType.manual.value) return 'يدوي';
    return type;
  }

  String _budgetScopeLabel(String scope) {
    return scope == BudgetScope.withinBudget.value
        ? 'داخل الميزانية'
        : 'خارج الميزانية';
  }

  String _recurrenceLabel(String pattern) {
    if (pattern == RecurrencePattern.daily.value) return 'يومي';
    if (pattern == RecurrencePattern.weekly.value) return 'أسبوعي';
    if (pattern == RecurrencePattern.biweekly.value) return 'كل أسبوعين';
    if (pattern == RecurrencePattern.every3Weeks.value) return 'كل 3 أسابيع';
    if (pattern == RecurrencePattern.monthly.value) return 'شهري';
    if (pattern == RecurrencePattern.every2Months.value) return 'كل شهرين';
    if (pattern == RecurrencePattern.every3Months.value) return 'كل 3 شهور';
    if (pattern == RecurrencePattern.every6Months.value) return 'كل 6 شهور';
    if (pattern == RecurrencePattern.yearly.value) return 'سنوي';
    if (pattern == RecurrencePattern.manualVariable.value) return 'يدوي متغير';
    return pattern;
  }

  String _recurringTransactionDetails(
    String action,
    RecurringTransactionEntity recurring,
  ) {
    final type = AuditLogService.transactionTypeLabel(recurring.type);
    final amount = recurring.isVariableIncome
        ? 'دخل متغير'
        : recurring.amount.toStringAsFixed(2);
    final debtLabel = recurring.isDebtOrSubscription
        ? recurring.expensePlanKind == ExpensePlanKind.installment.value
            ? ' · تقسيط'
            : recurring.expensePlanKind == ExpensePlanKind.subscription.value
                ? ' · اشتراك'
                : ' · دين أو اشتراك'
        : '';
    return '$action: ${recurring.name} · النوع: $type · القيمة: $amount · التكرار: ${_recurrenceLabel(recurring.recurrencePattern)} · التنفيذ: ${_executionTypeLabel(recurring.executionType)} · ${_budgetScopeLabel(recurring.budgetScope)}$debtLabel';
  }
}
