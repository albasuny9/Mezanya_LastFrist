import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../utils/budget_setup_display_helpers.dart';
import '../widgets/budget_details_blocks.dart';
import '../widgets/budget_info_sheet_shell.dart';

Future<void> showDebtInfoSheet(
  BuildContext context, {
  required DebtEntity debt,
  required BudgetSetupEntity budget,
  required List<RecurringTransactionEntity> recurringTransactions,
  required List<WalletEntity> wallets,
  required AppCubit cubit,
  required Future<void> Function(BudgetSetupEntity budget) onSaveBudget,
  required VoidCallback onEdit,
}) {
  final recurring = budgetLinkedRecurringDebt(recurringTransactions, debt);
  final walletName = () {
    final id = recurring?.walletId ?? '';
    if (id.isEmpty) return 'غير محدد';
    for (final w in wallets) {
      if (w.id == id) return w.name;
    }
    return id;
  }();
  final fundingName = () {
    final id = debt.fundingSource;
    for (final income in budget.incomeSources) {
      if (income.id == id) return income.name;
    }
    return id.isEmpty ? 'غير محدد' : id;
  }();
  final recurrenceLabel = budgetRecurrenceLabel(
    recurring?.recurrencePattern ?? RecurrencePattern.monthly.value,
  );
  final monthlyDay =
      (recurring?.dayOfMonth ?? debt.executionDay).clamp(1, 28).toString();
  final timeLabel = (recurring?.scheduledTime?.isNotEmpty == true)
      ? budgetFormatClockTime(recurring!.scheduledTime!)
      : 'غير محدد';
  final reminderLabel = budgetReminderLabel(
    recurrencePattern:
        recurring?.recurrencePattern ?? RecurrencePattern.monthly.value,
    executionType: recurring?.executionType ?? debt.type,
    reminderLeadDays: recurring?.reminderLeadDays ?? 0,
  );

  final isSubscription = debt.isSubscription;
  final sheetTitle = isSubscription ? 'تفاصيل الاشتراك' : 'تفاصيل الدين';
  final nameLabel = isSubscription ? 'اسم الاشتراك' : 'اسم الدين';
  final amountLabel = isSubscription ? 'قيمة الاشتراك' : 'قيمة القسط';
  final editLabel = isSubscription ? 'تعديل الاشتراك' : 'تعديل الدين';
  final deleteTitle = isSubscription ? 'حذف الاشتراك' : 'حذف الدين';
  final deleteMessage = isSubscription
      ? 'سيتم حذف "${debt.name}" من قائمة الاشتراكات. هل تريد المتابعة؟'
      : 'سيتم حذف "${debt.name}" من خطة الميزانية. هل تريد المتابعة؟';

  return showBudgetInfoSheet(
    context: context,
    title: sheetTitle,
    editLabel: editLabel,
    onEdit: onEdit,
    heightFactor: 0.6,
    minHeight: 420,
    maxHeight: 580,
    blocks: [
      BudgetDetailsBlock.wide(nameLabel, debt.name),
      BudgetDetailsBlock.narrow(
        amountLabel,
        debt.amount.toStringAsFixed(2),
      ),
      if (recurring?.debtPrincipalTotal != null)
        BudgetDetailsBlock.narrow(
          'إجمالي الدين',
          recurring!.debtPrincipalTotal!.toStringAsFixed(2),
        ),
      BudgetDetailsBlock.narrow(
        'يوم الاستحقاق',
        '${debt.executionDay}',
      ),
      BudgetDetailsBlock.narrow('مصدر التمويل', fundingName),
      BudgetDetailsBlock.narrow('محفظة السداد', walletName),
      BudgetDetailsBlock.narrow(
        'طريقة التنفيذ',
        budgetIncomeTypeLabel(recurring?.executionType ?? debt.type),
      ),
      BudgetDetailsBlock.narrow('نوع التكرار', recurrenceLabel),
      BudgetDetailsBlock.narrow('اليوم الشهري', monthlyDay),
      BudgetDetailsBlock.narrow('الوقت', timeLabel),
      BudgetDetailsBlock.narrow('وقت الإشعار', reminderLabel),
      BudgetDetailsBlock.wide(
        'الملاحظات',
        recurring?.notes?.isNotEmpty == true ? recurring!.notes! : '—',
      ),
    ],
    extraActions: [
      const SizedBox(height: 8),
      Builder(
        builder: (sheetCtx) {
          return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.of(sheetCtx).pop();
                final approved = await confirmBudgetDeletion(
                  context,
                  title: deleteTitle,
                  message: deleteMessage,
                );
                if (!approved) return;
                final rec = budgetLinkedRecurringDebt(
                  recurringTransactions,
                  debt,
                );
                if (rec != null) {
                  await cubit.deleteRecurringTransaction(rec.id);
                }
                await onSaveBudget(
                  budget.copyWith(
                    debts: budget.debts.where((e) => e.id != debt.id).toList(),
                  ),
                );
              },
              icon: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(sheetCtx).colorScheme.error,
              ),
              label: Text(
                deleteTitle,
                style: TextStyle(color: Theme.of(sheetCtx).colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(
                  color: Theme.of(sheetCtx)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.4),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}
