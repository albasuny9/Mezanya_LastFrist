import 'package:intl/intl.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';
import '../../domain/entities/budget_setup_entity.dart';

class BudgetRecurringPlanService {
  const BudgetRecurringPlanService._();

  static RecurringTransactionEntity? linkedRecurring(
    Iterable<RecurringTransactionEntity> recurringTransactions,
    DebtEntity debt,
  ) {
    if ((debt.recurringTransactionId ?? '').isNotEmpty) {
      final exact = recurringTransactions.where(
        (item) =>
            item.type == TransactionType.expense.value &&
            item.budgetScope == BudgetScope.withinBudget.value &&
            item.isDebtOrSubscription &&
            item.id == debt.recurringTransactionId,
      );
      if (exact.isNotEmpty) return exact.first;
    }
    final fallback = recurringTransactions.where(
      (item) =>
          item.type == TransactionType.expense.value &&
          item.budgetScope == BudgetScope.withinBudget.value &&
          item.isDebtOrSubscription &&
          item.name == debt.name,
    );
    return fallback.isEmpty ? null : fallback.first;
  }

  // ── Core: كل الحسابات تمر هنا ─────────────────────────────────────────────

  /// عدد مرات الاستحقاق في الدورة
  /// الأقساط دايمًا = 1 مرة بغض النظر عن التكرار.
  /// الاشتراكات: نعتمد على RecurringScheduleEngine أولاً، ثم DebtEntity كـ fallback.
  static int occurrencesInCycle({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    if (debt.isInstallment) return 1;

    // ── اشتراك مع recurring entity ──────────────────────────────────────────
    if (recurring != null) {
      return RecurringScheduleEngine.occurrencesInRange(
        recurring,
        cycleStart,
        cycleEnd,
      );
    }

    // ── fallback: DebtEntity فقط (بيانات مبسطة) ────────────────────────────
    return _fallbackOccurrences(debt, cycleStart, cycleEnd);
  }

  static List<DateTime> occurrenceDatesInCycle({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    if (debt.isInstallment) {
      // الأقساط بنديها تاريخ واحد في بداية الدورة لعدم وجود تواريخ تفصيلية،
      // أو ممكن نرجعلها قائمة فاضية لو مش مهمة في السياق ده
      return [cycleStart];
    }

    if (recurring != null) {
      return RecurringScheduleEngine.occurrenceDatesInRange(
        recurring,
        cycleStart,
        cycleEnd,
      );
    }

    return _fallbackOccurrenceDates(debt, cycleStart, cycleEnd);
  }

  static bool isDueInCycle({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    if (debt.isInstallment) return true;
    return occurrencesInCycle(
          debt: debt,
          recurring: recurring,
          cycleStart: cycleStart,
          cycleEnd: cycleEnd,
        ) >
        0;
  }

  /// قيمة كل دفعة واحدة (مش إجمالي الدورة)
  static double amountPerOccurrence({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
  }) {
    final amount = recurring?.amount ?? debt.amount;
    return amount < 0 ? 0 : amount;
  }

  /// إجمالي المبلغ المستحق في الدورة كلها
  static double amountDueInCycle({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required DateTime cycleStart,
    required DateTime cycleEnd,
  }) {
    final perOccurrence = amountPerOccurrence(debt: debt, recurring: recurring);
    if (debt.isInstallment) return perOccurrence;
    final count = occurrencesInCycle(
      debt: debt,
      recurring: recurring,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
    );
    return perOccurrence * count;
  }

  // ── Debt payment queries ──────────────────────────────────────────────────

  /// Returns `true` if [t] is an expense whose notes contain [debt.name],
  /// meaning it counts as a payment toward that debt.
  ///
  /// Extracted from `_transactionCountsTowardDebt` in
  /// `budget_tracking_screen.dart`.
  static bool transactionCountsTowardDebt(
    TransactionEntity t,
    DebtEntity debt,
  ) {
    if (t.type != TransactionType.expense.value) return false;
    final n = t.notes ?? '';
    return n.contains(debt.name);
  }

  /// Returns all historical expense transactions that count as payments toward
  /// [debt], sorted newest-first.
  ///
  /// Extracted from `_allDebtPayments` in `budget_tracking_screen.dart`.
  static List<TransactionEntity> allDebtPayments(
    AppStateEntity state,
    DebtEntity debt,
  ) {
    final list = state.transactions
        .where((t) => transactionCountsTowardDebt(t, debt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Returns a metadata map describing the pending/due/snoozed status of a
  /// recurring debt or subscription, or `null` when no prompt applies.
  ///
  /// Keys: `status` (String), `occurrence` (DateTime?), `pending` (bool),
  /// `snoozed` (bool).
  ///
  /// Extracted from `_expensePendingMeta` in `budget_tracking_screen.dart`.
  static Map<String, dynamic>? expensePendingMeta(
    RecurringTransactionEntity? recurring,
  ) {
    if (recurring == null) {
      return null;
    }
    final now = DateTime.now();
    final fallbackOccurrence =
        RecurringScheduleEngine.dueOccurrenceNow(recurring, now) ??
            RecurringScheduleEngine.nextOccurrence(recurring, now);
    final snoozedUntil = recurring.snoozedUntil == null
        ? null
        : DateTime.tryParse(recurring.snoozedUntil!);
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
      return <String, dynamic>{
        'status':
            'مؤجل حتى ${DateFormat('d MMMM - h:mm a', 'ar').format(snoozedUntil)}',
        'occurrence': fallbackOccurrence,
        'pending': false,
        'snoozed': true,
      };
    }
    final prompt = RecurringScheduleEngine.expensePrompt(recurring, now);
    if (prompt != null) {
      return <String, dynamic>{
        'status': switch (prompt.state) {
          RecurringExpensePromptState.upcoming =>
            'مستحق قريبًا ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
          RecurringExpensePromptState.due =>
            'مستحق الآن ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
          RecurringExpensePromptState.overdue => prompt.catchUpFromAuto
              ? 'دورة فائتة تحتاج قرارًا ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}'
              : 'استحقاق متأخر ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
        },
        'occurrence': prompt.occurrence,
        'pending': true,
        'snoozed': false,
      };
    }

    final occurrence = fallbackOccurrence;
    if (occurrence == null) return null;
    return <String, dynamic>{
      'status':
          'الاستحقاق القادم ${DateFormat('d/M - h:mm a', 'ar').format(occurrence)}',
      'occurrence': occurrence,
      'pending': false,
      'snoozed': false,
    };
  }

  static double pendingDecisionAmount({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required double cyclePaid,
  }) {
    final perOccurrence = amountPerOccurrence(debt: debt, recurring: recurring);
    if (debt.isSubscription) return perOccurrence;
    final remaining = perOccurrence - cyclePaid;
    return remaining > 0 ? remaining : 0;
  }

  // ── Fallback بدون recurring entity ────────────────────────────────────────
  // يُستخدم فقط لو DebtEntity مش مربوطة بـ RecurringTransactionEntity
  static int _fallbackOccurrences(
    DebtEntity debt,
    DateTime cycleStart,
    DateTime cycleEnd,
  ) {
    final pattern = debt.recurrencePattern;
    if (pattern == RecurrencePattern.monthly.value) {
      return _dayInRange(debt.executionDay, cycleStart, cycleEnd) ? 1 : 0;
    }
    if (pattern == RecurrencePattern.yearly.value) {
      final month = debt.monthOfYear ?? cycleStart.month;
      return _yearlyDayInRange(debt.executionDay, month, cycleStart, cycleEnd)
          ? 1
          : 0;
    }
    if (pattern == RecurrencePattern.every2Months.value ||
        pattern == RecurrencePattern.every3Months.value ||
        pattern == RecurrencePattern.every6Months.value) {
      final interval = pattern == RecurrencePattern.every2Months.value
          ? 2
          : pattern == RecurrencePattern.every3Months.value
              ? 3
              : 6;
      return _multiMonthOccurrences(
          debt.executionDay, interval, cycleStart, cycleEnd);
    }
    return 0;
  }

  static List<DateTime> _fallbackOccurrenceDates(
    DebtEntity debt,
    DateTime cycleStart,
    DateTime cycleEnd,
  ) {
    final pattern = debt.recurrencePattern;
    final dates = <DateTime>[];
    if (pattern == RecurrencePattern.monthly.value) {
      final d = _getDateInRange(debt.executionDay, cycleStart, cycleEnd);
      if (d != null) dates.add(d);
    } else if (pattern == RecurrencePattern.yearly.value) {
      final month = debt.monthOfYear ?? cycleStart.month;
      final d = _getYearlyDateInRange(
          debt.executionDay, month, cycleStart, cycleEnd);
      if (d != null) dates.add(d);
    } else if (pattern == RecurrencePattern.every2Months.value ||
        pattern == RecurrencePattern.every3Months.value ||
        pattern == RecurrencePattern.every6Months.value) {
      final interval = pattern == RecurrencePattern.every2Months.value
          ? 2
          : pattern == RecurrencePattern.every3Months.value
              ? 3
              : 6;
      dates.addAll(_getMultiMonthOccurrenceDates(
          debt.executionDay, interval, cycleStart, cycleEnd));
    }
    return dates;
  }

  static bool _dayInRange(int day, DateTime start, DateTime end) {
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (cursor.day == day.clamp(1, 28)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  static bool _yearlyDayInRange(
      int day, int month, DateTime start, DateTime end) {
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (cursor.day == day.clamp(1, 28) && cursor.month == month) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  static int _multiMonthOccurrences(
      int day, int interval, DateTime start, DateTime end) {
    var count = 0;
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (cursor.day == day.clamp(1, 28) && cursor.month % interval == 0) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  static DateTime? _getDateInRange(int day, DateTime start, DateTime end) {
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (cursor.day == day.clamp(1, 28)) return cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  static DateTime? _getYearlyDateInRange(
      int day, int month, DateTime start, DateTime end) {
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (cursor.day == day.clamp(1, 28) && cursor.month == month) {
        return cursor;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return null;
  }

  static List<DateTime> _getMultiMonthOccurrenceDates(
      int day, int interval, DateTime start, DateTime end) {
    final dates = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (cursor.day == day.clamp(1, 28) && cursor.month % interval == 0) {
        dates.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }
}
