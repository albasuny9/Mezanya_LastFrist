import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../utils/budget_setup_display_helpers.dart';
import '../widgets/budget_details_blocks.dart';
import '../widgets/budget_info_sheet_shell.dart';

Future<void> showIncomeInfoSheet(
  BuildContext context, {
  required IncomeSourceEntity income,
  required List<RecurringTransactionEntity> recurringTransactions,
  required List<WalletEntity> wallets,
  required VoidCallback onEdit,
}) {
  final recurring = budgetLinkedRecurringIncome(recurringTransactions, income);

  String resolveWalletName() {
    for (final w in wallets) {
      if (w.id == income.targetWalletId) return w.name;
    }
    return income.targetWalletId.isEmpty ? 'غير محدد' : income.targetWalletId;
  }

  final incomeTypeLabel = income.isVariable ? 'متغير' : 'ثابت';
  final executionLabel = recurring == null
      ? budgetIncomeTypeLabel(income.type)
      : budgetIncomeTypeLabel(recurring.executionType);
  final recurrenceLabel = budgetRecurrenceLabel(
    recurring?.recurrencePattern ?? RecurrencePattern.monthly.value,
  );
  final monthlyDay = (recurring?.dayOfMonth ?? income.date).clamp(1, 28);
  final timeLabel = (recurring?.scheduledTime?.isNotEmpty == true)
      ? budgetFormatClockTime(recurring!.scheduledTime!)
      : null;
  final executionDayLine = income.isVariable
      ? 'يدوي'
      : timeLabel != null
          ? 'يوم $monthlyDay • $timeLabel'
          : 'يوم $monthlyDay';

  return showBudgetInfoSheet(
    context: context,
    title: 'تفاصيل الدخل',
    editLabel: 'تعديل الدخل',
    onEdit: onEdit,
    heightFactor: 0.48,
    minHeight: 340,
    maxHeight: 460,
    blocks: [
      BudgetDetailsBlock.wide('اسم الدخل', income.name),
      BudgetDetailsBlock.narrow('نوع الدخل', incomeTypeLabel),
      BudgetDetailsBlock.narrow(
        'قيمة الدخل',
        income.isVariable ? 'متغير' : income.amount.toStringAsFixed(2),
      ),
      BudgetDetailsBlock.narrow('محفظة الإيداع', resolveWalletName()),
      BudgetDetailsBlock.narrow('نوع التكرار', recurrenceLabel),
      BudgetDetailsBlock.wide('يوم التنفيذ', executionDayLine),
      BudgetDetailsBlock.narrow('طريقة التنفيذ', executionLabel),
    ],
  );
}
