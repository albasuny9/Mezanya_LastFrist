import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/services/budget_recurring_plan_service.dart';

String budgetFundingBreakdownText(
  List<(String, double)> funding,
  List<IncomeSourceEntity> incomeSources,
) {
  final cleaned = funding.where((f) => f.$1.isNotEmpty && f.$2 > 0).toList();
  if (cleaned.isEmpty) {
    return 'لا يوجد';
  }
  final nameById = <String, String>{
    for (final inc in incomeSources) inc.id: inc.name,
  };
  return cleaned.map((f) {
    final name = nameById[f.$1] ?? f.$1;
    final amount = f.$2.toStringAsFixed(0);
    return '$name $amount';
  }).join('\n');
}

String budgetRecurrenceLabel(String pattern) {
  if (pattern == RecurrencePattern.daily.value) return 'يومي';
  if (pattern == RecurrencePattern.weekly.value) return 'أسبوعي';
  if (pattern == RecurrencePattern.biweekly.value) return 'كل أسبوعين';
  if (pattern == RecurrencePattern.every3Weeks.value) return 'كل 3 أسابيع';
  if (pattern == RecurrencePattern.monthly.value) return 'شهري';
  if (pattern == RecurrencePattern.every2Months.value) return 'كل شهرين';
  if (pattern == RecurrencePattern.every3Months.value) return 'كل 3 شهور';
  if (pattern == RecurrencePattern.every6Months.value) return 'كل 6 شهور';
  if (pattern == RecurrencePattern.yearly.value) return 'سنوي';
  if (pattern == RecurrencePattern.manualVariable.value) return 'يدوي';
  return pattern;
}

String budgetFormatClockTime(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return value;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;
  final h = hour.clamp(0, 23);
  final m = minute.clamp(0, 59);
  final suffix = h >= 12 ? 'مساء' : 'صباحًا';
  final displayH = (h % 12 == 0) ? 12 : (h % 12);
  final mm = m.toString().padLeft(2, '0');
  return '$displayH:$mm $suffix';
}

String budgetReminderLabel({
  required String recurrencePattern,
  required String executionType,
  required int reminderLeadDays,
}) {
  if (executionType != AutomationType.confirm.value) {
    return 'لا يوجد';
  }
  final value = reminderLeadDays.clamp(0, 3);
  final isHourly = recurrencePattern == RecurrencePattern.daily.value ||
      recurrencePattern == RecurrencePattern.weekly.value ||
      recurrencePattern == RecurrencePattern.biweekly.value ||
      recurrencePattern == RecurrencePattern.every3Weeks.value;
  if (isHourly) {
    return value == 0 ? 'في الوقت المحدد' : 'قبلها بـ $value ساعة';
  }
  return value == 0 ? 'في نفس اليوم' : 'مبكر بـ $value يوم';
}

String budgetIncomeTypeLabel(String type) {
  if (type == AutomationType.auto.value) return 'تلقائي';
  if (type == AutomationType.confirm.value) return 'تأكيد';
  if (type == 'manual') return 'يدوي';
  return type;
}

RecurringTransactionEntity? budgetLinkedRecurringIncome(
  List<RecurringTransactionEntity> recurringTransactions,
  IncomeSourceEntity source,
) {
  final linked = recurringTransactions.where(
    (item) =>
        item.type == TransactionType.income.value &&
        item.budgetScope == BudgetScope.withinBudget.value &&
        (item.incomeSourceId == source.id ||
            ((item.incomeSourceId ?? '').isEmpty &&
                item.name == source.name &&
                item.walletId == source.targetWalletId)),
  );
  if (linked.isEmpty) {
    return null;
  }
  return linked.first;
}

RecurringTransactionEntity? budgetLinkedRecurringDebt(
  List<RecurringTransactionEntity> recurringTransactions,
  DebtEntity debt,
) {
  return BudgetRecurringPlanService.linkedRecurring(
    recurringTransactions,
    debt,
  );
}

Future<bool> confirmBudgetDeletion(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'حذف',
}) async {
  final approved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return approved == true;
}
