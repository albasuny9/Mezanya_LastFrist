import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/presentation/screens/recurring_transaction_composer_screen.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../utils/budget_setup_display_helpers.dart';

Future<void> showDebtDialog(
  BuildContext context, {
  required AppCubit cubit,
  required BudgetSetupEntity budget,
  required DebtEntity? current,
  required String Function(String prefix) idFactory,
  required Future<void> Function(BudgetSetupEntity budget) onSaveBudget,
}) async {
  final linkedRecurring = current == null
      ? null
      : budgetLinkedRecurringDebt(
          cubit.state.recurringTransactions,
          current,
        );
  final draftRecurring = (linkedRecurring ??
          RecurringTransactionEntity(
            id: current?.recurringTransactionId ?? '',
            name: current?.name ?? '',
            type: TransactionType.expense.value,
            amount: current?.amount ?? 0,
            dayOfMonth: (current?.executionDay ?? 1).clamp(1, 28),
            executionType: current?.type ?? AutomationType.confirm.value,
            walletId: cubit.state.wallets.isNotEmpty
                ? cubit.state.wallets.first.id
                : '',
            budgetScope: BudgetScope.withinBudget.value,
            recurrencePattern:
                current?.recurrencePattern ?? RecurrencePattern.monthly.value,
            icon: 'receipt',
            iconColor: '#c65d2e',
            monthOfYear: current?.monthOfYear,
            incomeSourceId: null,
            isDebtOrSubscription: true,
            expensePlanKind: current?.isSubscription == true
                ? ExpensePlanKind.subscription.value
                : ExpensePlanKind.installment.value,
            debtPrincipalTotal: current?.principalTotal ??
                (current?.isInstallment == true ? current!.amount : null),
          ))
      .copyWith(
    recurrencePattern: current?.recurrencePattern != null &&
            current!.recurrencePattern != RecurrencePattern.monthly.value
        ? current.recurrencePattern
        : (linkedRecurring?.recurrencePattern ??
            RecurrencePattern.monthly.value),
    monthOfYear: current?.monthOfYear ?? linkedRecurring?.monthOfYear,
    expensePlanKind: linkedRecurring?.expensePlanKind ??
        (current?.isSubscription == true
            ? ExpensePlanKind.subscription.value
            : ExpensePlanKind.installment.value),
    debtPrincipalTotal: linkedRecurring?.debtPrincipalTotal ??
        current?.principalTotal ??
        (current?.isInstallment == true ? current!.amount : null),
  );

  final result =
      await Navigator.of(context).push<RecurringTransactionComposerResult>(
    MaterialPageRoute(
      builder: (_) => RecurringTransactionComposerScreen(
        cubit: cubit,
        initialType: TransactionType.expense.value,
        initialWithinBudget: true,
        initialRecurring: draftRecurring,
        initialExpensePlanKind: draftRecurring.expensePlanKind ??
            ExpensePlanKind.installment.value,
        debtOnlyMode: true,
        returnOnSave: true,
      ),
      fullscreenDialog: true,
    ),
  );
  final recurring = result?.recurring;
  if (recurring == null) {
    return;
  }

  final recurringId =
      linkedRecurring?.id ?? current?.recurringTransactionId ?? idFactory('rec');
  final isSubscription =
      recurring.expensePlanKind == ExpensePlanKind.subscription.value;
  final principal = recurring.debtPrincipalTotal;
  final debt = DebtEntity(
    id: current?.id ?? idFactory('debt'),
    name: recurring.name,
    amount: recurring.amount,
    executionDay: recurring.dayOfMonth.clamp(1, 31),
    type: recurring.executionType,
    fundingSource: current?.fundingSource ??
        (budget.incomeSources.isNotEmpty ? budget.incomeSources.first.id : ''),
    recurringTransactionId: recurringId,
    kind: isSubscription
        ? ExpensePlanKind.subscription.value
        : ExpensePlanKind.installment.value,
    principalTotal: isSubscription
        ? null
        : (principal != null && principal > 0 ? principal : null),
    installmentCount: isSubscription ? null : recurring.installmentCount,
    downPayment: isSubscription ? null : recurring.installmentDownPayment,
    recurrencePattern: recurring.recurrencePattern,
    monthOfYear: recurring.monthOfYear,
  );

  final nextDebts = current == null
      ? [...budget.debts, debt]
      : budget.debts
          .map((item) => item.id == current.id ? debt : item)
          .toList();
  await onSaveBudget(budget.copyWith(debts: nextDebts));

  final recurringToSave = recurring.copyWith(
    id: recurringId,
    type: TransactionType.expense.value,
    budgetScope: BudgetScope.withinBudget.value,
    isDebtOrSubscription: true,
    allocationId: null,
    targetJarId: null,
  );

  if (linkedRecurring == null) {
    await cubit.addRecurringTransaction(
      id: recurringId,
      name: recurringToSave.name,
      type: recurringToSave.type,
      amount: recurringToSave.amount,
      dayOfMonth: recurringToSave.dayOfMonth,
      executionType: recurringToSave.executionType,
      walletId: recurringToSave.walletId,
      budgetScope: recurringToSave.budgetScope,
      recurrencePattern: recurringToSave.recurrencePattern,
      icon: recurringToSave.icon,
      iconColor: recurringToSave.iconColor,
      weekday: recurringToSave.weekday,
      weekdays: recurringToSave.weekdays,
      monthOfYear: recurringToSave.monthOfYear,
      anchorDate: recurringToSave.anchorDate,
      scheduledTime: recurringToSave.scheduledTime,
      reminderLeadDays: recurringToSave.reminderLeadDays,
      isDebtOrSubscription: true,
      expensePlanKind: recurringToSave.expensePlanKind,
      debtPrincipalTotal: recurringToSave.debtPrincipalTotal,
      installmentCount: recurringToSave.installmentCount,
      installmentDownPayment: recurringToSave.installmentDownPayment,
      notes: recurringToSave.notes,
    );
  } else {
    await cubit.updateRecurringTransaction(recurringToSave);
  }
}
