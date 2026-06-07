import '../../../../core/constants/transaction_types.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';

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
    switch (pattern) {
      case 'monthly':
        // مرة واحدة لو يوم الاستحقاق ضمن الدورة
        return _dayInRange(debt.executionDay, cycleStart, cycleEnd) ? 1 : 0;
      case 'yearly':
        final month = debt.monthOfYear ?? cycleStart.month;
        return _yearlyDayInRange(debt.executionDay, month, cycleStart, cycleEnd)
            ? 1
            : 0;
      case 'every_2_months':
      case 'every_3_months':
      case 'every_6_months':
        final interval = pattern == 'every_2_months'
            ? 2
            : pattern == 'every_3_months'
                ? 3
                : 6;
        return _multiMonthOccurrences(
            debt.executionDay, interval, cycleStart, cycleEnd);
      default:
        // weekly/biweekly بدون recurring = مش قادر نحسب صح → 0
        return 0;
    }
  }

  static List<DateTime> _fallbackOccurrenceDates(
    DebtEntity debt,
    DateTime cycleStart,
    DateTime cycleEnd,
  ) {
    final pattern = debt.recurrencePattern;
    final dates = <DateTime>[];
    switch (pattern) {
      case 'monthly':
        final d = _getDateInRange(debt.executionDay, cycleStart, cycleEnd);
        if (d != null) dates.add(d);
        break;
      case 'yearly':
        final month = debt.monthOfYear ?? cycleStart.month;
        final d = _getYearlyDateInRange(
            debt.executionDay, month, cycleStart, cycleEnd);
        if (d != null) dates.add(d);
        break;
      case 'every_2_months':
      case 'every_3_months':
      case 'every_6_months':
        final interval = pattern == 'every_2_months'
            ? 2
            : pattern == 'every_3_months'
                ? 3
                : 6;
        dates.addAll(_getMultiMonthOccurrenceDates(
            debt.executionDay, interval, cycleStart, cycleEnd));
        break;
      default:
        break;
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
