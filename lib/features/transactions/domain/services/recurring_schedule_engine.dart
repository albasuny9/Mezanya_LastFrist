import '../entities/recurring_transaction_entity.dart';

enum RecurringExpensePromptState {
  upcoming,
  due,
  overdue,
}

class RecurringExpensePrompt {
  const RecurringExpensePrompt({
    required this.occurrence,
    required this.reminderAt,
    required this.state,
    required this.catchUpFromAuto,
  });

  final DateTime occurrence;
  final DateTime reminderAt;
  final RecurringExpensePromptState state;
  final bool catchUpFromAuto;

  bool get isPending => true;
  bool get isDueNow => state == RecurringExpensePromptState.due;
  bool get isOverdue => state == RecurringExpensePromptState.overdue;
}

class RecurringScheduleEngine {
  const RecurringScheduleEngine._();

  static DateTime? parseScheduledTime(String? value, DateTime reference) {
    if (value == null || value.isEmpty || !value.contains(':')) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(
      reference.year,
      reference.month,
      reference.day,
      hour.clamp(0, 23),
      minute.clamp(0, 59),
    );
  }

  static Duration reminderDuration(RecurringTransactionEntity recurring) {
    final lead = recurring.reminderLeadDays ?? 0;
    if (recurring.recurrencePattern == 'daily' ||
        recurring.recurrencePattern == 'weekly' ||
        recurring.recurrencePattern == 'biweekly' ||
        recurring.recurrencePattern == 'every_3_weeks') {
      return Duration(hours: lead);
    }
    return Duration(days: lead);
  }

  static DateTime defaultAnchorDate(
    RecurringTransactionEntity recurring, {
    DateTime? from,
  }) {
    final reference = from ?? DateTime.now();

    // للأنماط الأسبوعية: الـ anchor هو آخر يوم مطابق في الأسبوع الحالي أو السابق
    if (recurring.recurrencePattern == 'weekly' ||
        recurring.recurrencePattern == 'biweekly' ||
        recurring.recurrencePattern == 'every_3_weeks') {
      final weekdays = _resolvedWeekdays(recurring, reference);
      if (weekdays.isNotEmpty) {
        // ابحث عن أقرب يوم مطابق في الماضي (حتى 21 يوم للخلف)
        for (var offset = 0; offset <= 21; offset++) {
          final day = reference.subtract(Duration(days: offset));
          if (weekdays.contains(day.weekday)) {
            final time =
                parseScheduledTime(recurring.scheduledTime, day) ?? day;
            return DateTime(
                day.year, day.month, day.day, time.hour, time.minute);
          }
        }
      }
    }

    // للأنماط الشهرية: الـ anchor هو يوم الاستحقاق في الشهر الحالي أو السابق
    if (recurring.recurrencePattern == 'monthly' ||
        recurring.recurrencePattern == 'every_2_months' ||
        recurring.recurrencePattern == 'every_3_months' ||
        recurring.recurrencePattern == 'every_6_months') {
      final time =
          parseScheduledTime(recurring.scheduledTime, reference) ?? reference;
      final thisMonthDay =
          _dayInMonth(reference.year, reference.month, recurring.dayOfMonth);
      final thisMonth = DateTime(reference.year, reference.month, thisMonthDay,
          time.hour, time.minute);
      if (!thisMonth.isAfter(reference)) return thisMonth;
      // لو يوم الاستحقاق لسه ما جاش، رجع للشهر اللي فات
      final prevMonth = DateTime(reference.year, reference.month - 1, 1);
      final prevDay =
          _dayInMonth(prevMonth.year, prevMonth.month, recurring.dayOfMonth);
      return DateTime(
          prevMonth.year, prevMonth.month, prevDay, time.hour, time.minute);
    }

    // للسنوي: الـ anchor هو تاريخ اليوم لضمان عدم استرجاع استحقاقات من السنة الماضية للمشتريات الجديدة
    if (recurring.recurrencePattern == 'yearly') {
      return reference;
    }

    // fallback: استخدم nextOccurrence
    final exact = nextOccurrence(
          recurring,
          reference.subtract(const Duration(minutes: 1)),
        ) ??
        reference;
    return exact;
  }

  static DateTime? nextOccurrence(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) {
    final time = parseScheduledTime(recurring.scheduledTime, now) ?? now;
    final hour = time.hour;
    final minute = time.minute;
    final explicitAnchor = _explicitAnchor(recurring, hour, minute);

    DateTime atDate(DateTime day) => DateTime(
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        );

    switch (recurring.recurrencePattern) {
      case 'daily':
        final today = atDate(now);
        final candidate =
            today.isAfter(now) ? today : today.add(const Duration(days: 1));
        return _applyAnchor(candidate, explicitAnchor);
      case 'weekly':
      case 'biweekly':
      case 'every_3_weeks':
        final weekdays = _resolvedWeekdays(recurring, now);
        if (weekdays.isEmpty) return null;
        final intervalWeeks = _weekInterval(recurring.recurrencePattern);
        final anchor = _resolvedAnchor(recurring, now, hour, minute);
        for (var offset = 0; offset <= 366 * 3; offset++) {
          final day = now.add(Duration(days: offset));
          if (!weekdays.contains(day.weekday)) continue;
          if (!_weekCycleMatches(anchor, day, intervalWeeks)) continue;
          final candidate = atDate(day);
          if (!_isOnOrAfterAnchor(candidate, explicitAnchor)) continue;
          if (candidate.isAfter(now)) return candidate;
        }
        return null;
      case 'yearly':
        final month = (recurring.monthOfYear ?? now.month).clamp(1, 12);
        final day = _dayInMonth(now.year, month, recurring.dayOfMonth);
        var candidate = DateTime(now.year, month, day, hour, minute);
        if (_isOnOrAfterAnchor(candidate, explicitAnchor) &&
            candidate.isAfter(now)) {
          return candidate;
        }
        final nextYearDay =
            _dayInMonth(now.year + 1, month, recurring.dayOfMonth);
        candidate = DateTime(now.year + 1, month, nextYearDay, hour, minute);
        return _applyAnchor(candidate, explicitAnchor);
      default:
        final intervalMonths = _monthInterval(recurring.recurrencePattern);
        final anchor = _resolvedAnchor(recurring, now, hour, minute);
        for (var offset = 0; offset <= 120; offset++) {
          final monthDate = DateTime(now.year, now.month + offset, 1);
          final day = _dayInMonth(
            monthDate.year,
            monthDate.month,
            recurring.dayOfMonth,
          );
          final candidate = DateTime(
            monthDate.year,
            monthDate.month,
            day,
            hour,
            minute,
          );
          if (!_monthCycleMatches(anchor, candidate, intervalMonths)) continue;
          if (!_isOnOrAfterAnchor(candidate, explicitAnchor)) continue;
          if (candidate.isAfter(now)) return candidate;
        }
        return null;
    }
  }

  static DateTime? dueOccurrenceNow(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) {
    final time = parseScheduledTime(recurring.scheduledTime, now) ?? now;
    final hour = time.hour;
    final minute = time.minute;
    final explicitAnchor = _explicitAnchor(recurring, hour, minute);
    final handledAt = _handledOccurrence(recurring);
    final hasScheduleHistory = explicitAnchor != null || handledAt != null;

    DateTime atDate(DateTime day) => DateTime(
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        );

    switch (recurring.recurrencePattern) {
      case 'daily':
        final today = atDate(now);
        if (today.isAfter(now)) return null;
        return _isOnOrAfterAnchor(today, explicitAnchor) ? today : null;
      case 'weekly':
      case 'biweekly':
      case 'every_3_weeks':
        final weekdays = _resolvedWeekdays(recurring, now);
        if (weekdays.isEmpty) return null;
        final intervalWeeks = _weekInterval(recurring.recurrencePattern);
        final anchor = _resolvedAnchor(recurring, now, hour, minute);
        final maxLookBack = hasScheduleHistory ? 366 * 3 : 6;
        for (var offset = 0; offset <= maxLookBack; offset++) {
          final day = now.subtract(Duration(days: offset));
          if (!weekdays.contains(day.weekday)) continue;
          if (!_weekCycleMatches(anchor, day, intervalWeeks)) continue;
          final candidate = atDate(day);
          if (!_isOnOrAfterAnchor(candidate, explicitAnchor)) return null;
          if (!candidate.isAfter(now)) return candidate;
        }
        return null;
      case 'yearly':
        final month = (recurring.monthOfYear ?? now.month).clamp(1, 12);
        final thisYearDay = _dayInMonth(now.year, month, recurring.dayOfMonth);
        final candidate = DateTime(now.year, month, thisYearDay, hour, minute);
        if (!candidate.isAfter(now) &&
            _isOnOrAfterAnchor(candidate, explicitAnchor)) {
          return candidate;
        }
        if (!hasScheduleHistory) return null;
        final previousYearDay =
            _dayInMonth(now.year - 1, month, recurring.dayOfMonth);
        final previous =
            DateTime(now.year - 1, month, previousYearDay, hour, minute);
        return _isOnOrAfterAnchor(previous, explicitAnchor) ? previous : null;
      default:
        final intervalMonths = _monthInterval(recurring.recurrencePattern);
        final anchor = _resolvedAnchor(recurring, now, hour, minute);
        final currentMonthDay = _dayInMonth(
          now.year,
          now.month,
          recurring.dayOfMonth,
        );
        final currentCandidate = DateTime(
          now.year,
          now.month,
          currentMonthDay,
          hour,
          minute,
        );
        if (!hasScheduleHistory) {
          if (currentCandidate.isAfter(now)) return null;
          return _isOnOrAfterAnchor(currentCandidate, explicitAnchor)
              ? currentCandidate
              : null;
        }
        for (var offset = 0; offset <= 120; offset++) {
          final monthDate = DateTime(now.year, now.month - offset, 1);
          final day = _dayInMonth(
            monthDate.year,
            monthDate.month,
            recurring.dayOfMonth,
          );
          final candidate = DateTime(
            monthDate.year,
            monthDate.month,
            day,
            hour,
            minute,
          );
          if (!_isOnOrAfterAnchor(candidate, explicitAnchor)) return null;
          if (!_monthCycleMatches(anchor, candidate, intervalMonths)) continue;
          if (!candidate.isAfter(now)) return candidate;
        }
        return null;
    }
  }

  static bool wasOccurrenceHandled(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) {
    final handled = recurring.lastHandledOccurrenceAt == null
        ? null
        : DateTime.tryParse(recurring.lastHandledOccurrenceAt!);
    if (handled == null) return false;
    final normalized = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
      occurrence.hour,
      occurrence.minute,
    );
    return !handled.isBefore(normalized);
  }

  static DateTime? _handledOccurrence(RecurringTransactionEntity recurring) {
    if (recurring.lastHandledOccurrenceAt == null ||
        recurring.lastHandledOccurrenceAt!.isEmpty) {
      return null;
    }
    return DateTime.tryParse(recurring.lastHandledOccurrenceAt!);
  }

  static RecurringExpensePrompt? expensePrompt(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) {
    final dueOccurrence = dueOccurrenceNow(recurring, now);
    final next = nextOccurrence(recurring, now);
    final snoozedUntil =
        recurring.snoozedUntil == null || recurring.snoozedUntil!.isEmpty
            ? null
            : DateTime.tryParse(recurring.snoozedUntil!);
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
      return null;
    }

    if (recurring.executionType == 'auto') {
      if (dueOccurrence == null ||
          wasOccurrenceHandled(recurring, dueOccurrence)) {
        return null;
      }
      if (isSameCalendarDay(dueOccurrence, now)) {
        return null;
      }
      return RecurringExpensePrompt(
        occurrence: dueOccurrence,
        reminderAt: dueOccurrence,
        state: RecurringExpensePromptState.overdue,
        catchUpFromAuto: true,
      );
    }

    if (recurring.executionType != 'confirm') {
      return null;
    }

    if (dueOccurrence != null &&
        !wasOccurrenceHandled(recurring, dueOccurrence)) {
      
      // If it has never been handled (newly created), and the most recent past occurrence is too old,
      // the user probably doesn't want to be nagged about it. We should just wait for the next one.
      bool ignoreDue = false;
      if (recurring.lastHandledOccurrenceAt == null || recurring.lastHandledOccurrenceAt!.isEmpty) {
        final ageDays = now.difference(dueOccurrence).inDays;
        if (recurring.recurrencePattern == 'yearly' && ageDays > 30) {
          ignoreDue = true;
        } else if (recurring.recurrencePattern.contains('month') && ageDays > 15) {
          ignoreDue = true;
        } else if (recurring.recurrencePattern.contains('week') && ageDays > 7) {
          ignoreDue = true;
        } else if (recurring.recurrencePattern == 'daily' && ageDays > 2) {
          ignoreDue = true;
        }
      }

      if (!ignoreDue) {
        return RecurringExpensePrompt(
          occurrence: dueOccurrence,
          reminderAt: dueOccurrence.subtract(reminderDuration(recurring)),
          state: isSameCalendarDay(dueOccurrence, now)
              ? RecurringExpensePromptState.due
              : RecurringExpensePromptState.overdue,
          catchUpFromAuto: false,
        );
      }
    }

    if (next == null) return null;
    final reminderAt = next.subtract(reminderDuration(recurring));
    if (now.isBefore(reminderAt)) return null;
    return RecurringExpensePrompt(
      occurrence: next,
      reminderAt: reminderAt,
      state: RecurringExpensePromptState.upcoming,
      catchUpFromAuto: false,
    );
  }

  static bool hasOccurrenceInRange(
    RecurringTransactionEntity recurring,
    DateTime start,
    DateTime end,
  ) {
    return occurrencesInRange(recurring, start, end) > 0;
  }

  /// عدد مرات الاستحقاق في النطاق.
  /// [planningMode] = true → نتجاهل الـ anchorDate ونحسب بناءً على الـ weekdays/pattern فقط.
  /// ده بيُستخدم في حسابات الميزانية عشان نعرف المبلغ المتوقع في الدورة.
  static int occurrencesInRange(
    RecurringTransactionEntity recurring,
    DateTime start,
    DateTime end, {
    bool planningMode = true,
  }) {
    if (end.isBefore(start)) return 0;

    // في planning mode: نحسب الأيام المطابقة للجدول مباشرة بدون anchor restriction
    if (planningMode) {
      return _occurrencesInRangeDirect(recurring, start, end);
    }

    var count = 0;
    var cursor = start.subtract(const Duration(minutes: 1));
    for (var index = 0; index < 500; index++) {
      final next = nextOccurrence(recurring, cursor);
      if (next == null || next.isAfter(end)) break;
      count++;
      cursor = next;
    }
    return count;
  }

  /// حساب مباشر بدون anchor restriction — للاستخدام في تخطيط الميزانية
  static int _occurrencesInRangeDirect(
    RecurringTransactionEntity recurring,
    DateTime start,
    DateTime end,
  ) {
    final time = parseScheduledTime(recurring.scheduledTime, start) ?? start;
    final hour = time.hour;
    final minute = time.minute;


    switch (recurring.recurrencePattern) {
      case 'daily':
        var count = 0;
        var cursor = start;
        while (!cursor.isAfter(end)) {
          count++;
          cursor = cursor.add(const Duration(days: 1));
        }
        return count;

      case 'weekly':
        final weekdays = _resolvedWeekdays(recurring, start);
        if (weekdays.isEmpty) return 0;
        var count = 0;
        var cursor = start;
        while (!cursor.isAfter(end)) {
          if (weekdays.contains(cursor.weekday)) count++;
          cursor = cursor.add(const Duration(days: 1));
        }
        return count;

      case 'biweekly':
      case 'every_3_weeks':
        final weekdays = _resolvedWeekdays(recurring, start);
        if (weekdays.isEmpty) return 0;
        final intervalWeeks = _weekInterval(recurring.recurrencePattern);
        final anchor = _resolvedAnchor(recurring, start, hour, minute);
        var count = 0;
        var cursor = start;
        while (!cursor.isAfter(end)) {
          if (weekdays.contains(cursor.weekday) &&
              _weekCycleMatches(anchor, cursor, intervalWeeks)) {
            count++;
          }
          cursor = cursor.add(const Duration(days: 1));
        }
        return count;

      case 'yearly':
        final month = (recurring.monthOfYear ?? start.month).clamp(1, 12);
        var count = 0;
        for (var y = start.year; y <= end.year; y++) {
          final d = _dayInMonth(y, month, recurring.dayOfMonth);
          final candidate = DateTime(y, month, d, hour, minute);
          if (!candidate.isBefore(start) && !candidate.isAfter(end)) count++;
        }
        return count;

      default:
        final intervalMonths = _monthInterval(recurring.recurrencePattern);
        final anchor = _resolvedAnchor(recurring, start, hour, minute);
        var count = 0;
        var cursor = DateTime(start.year, start.month, 1);
        while (!cursor.isAfter(end)) {
          final d =
              _dayInMonth(cursor.year, cursor.month, recurring.dayOfMonth);
          final candidate =
              DateTime(cursor.year, cursor.month, d, hour, minute);
          if (!candidate.isBefore(start) &&
              !candidate.isAfter(end) &&
              _monthCycleMatches(anchor, candidate, intervalMonths)) {
            count++;
          }
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }
        return count;
    }
  }

  static List<DateTime> occurrenceDatesInRange(
    RecurringTransactionEntity recurring,
    DateTime start,
    DateTime end, {
    bool planningMode = true,
  }) {
    if (end.isBefore(start)) return [];

    if (planningMode) {
      return _occurrenceDatesInRangeDirect(recurring, start, end);
    }

    final dates = <DateTime>[];
    var cursor = start.subtract(const Duration(minutes: 1));
    for (var index = 0; index < 500; index++) {
      final next = nextOccurrence(recurring, cursor);
      if (next == null || next.isAfter(end)) break;
      dates.add(next);
      cursor = next;
    }
    return dates;
  }

  static List<DateTime> _occurrenceDatesInRangeDirect(
    RecurringTransactionEntity recurring,
    DateTime start,
    DateTime end,
  ) {
    final time = parseScheduledTime(recurring.scheduledTime, start) ?? start;
    final hour = time.hour;
    final minute = time.minute;

    DateTime atDate(DateTime d) =>
        DateTime(d.year, d.month, d.day, hour, minute);

    final dates = <DateTime>[];

    switch (recurring.recurrencePattern) {
      case 'daily':
        var cursor = start;
        while (!cursor.isAfter(end)) {
          dates.add(atDate(cursor));
          cursor = cursor.add(const Duration(days: 1));
        }
        return dates;

      case 'weekly':
        final weekdays = _resolvedWeekdays(recurring, start);
        if (weekdays.isEmpty) return dates;
        var cursor = start;
        while (!cursor.isAfter(end)) {
          if (weekdays.contains(cursor.weekday)) {
            dates.add(atDate(cursor));
          }
          cursor = cursor.add(const Duration(days: 1));
        }
        return dates;

      case 'biweekly':
      case 'every_3_weeks':
        final weekdays = _resolvedWeekdays(recurring, start);
        if (weekdays.isEmpty) return dates;
        final intervalWeeks = _weekInterval(recurring.recurrencePattern);
        final anchor = _resolvedAnchor(recurring, start, hour, minute);
        var cursor = start;
        while (!cursor.isAfter(end)) {
          if (weekdays.contains(cursor.weekday) &&
              _weekCycleMatches(anchor, cursor, intervalWeeks)) {
            dates.add(atDate(cursor));
          }
          cursor = cursor.add(const Duration(days: 1));
        }
        return dates;

      case 'yearly':
        final month = (recurring.monthOfYear ?? start.month).clamp(1, 12);
        for (var y = start.year; y <= end.year; y++) {
          final d = _dayInMonth(y, month, recurring.dayOfMonth);
          final candidate = DateTime(y, month, d, hour, minute);
          if (!candidate.isBefore(start) && !candidate.isAfter(end)) {
            dates.add(candidate);
          }
        }
        return dates;

      default:
        final intervalMonths = _monthInterval(recurring.recurrencePattern);
        final anchor = _resolvedAnchor(recurring, start, hour, minute);
        var cursor = DateTime(start.year, start.month, 1);
        while (!cursor.isAfter(end)) {
          final d =
              _dayInMonth(cursor.year, cursor.month, recurring.dayOfMonth);
          final candidate =
              DateTime(cursor.year, cursor.month, d, hour, minute);
          if (!candidate.isBefore(start) &&
              !candidate.isAfter(end) &&
              _monthCycleMatches(anchor, candidate, intervalMonths)) {
            dates.add(candidate);
          }
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }
        return dates;
    }
  }

  static bool isSameCalendarDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  static int _weekInterval(String pattern) {
    switch (pattern) {
      case 'biweekly':
        return 2;
      case 'every_3_weeks':
        return 3;
      default:
        return 1;
    }
  }

  static int _monthInterval(String pattern) {
    switch (pattern) {
      case 'every_2_months':
        return 2;
      case 'every_3_months':
        return 3;
      case 'every_6_months':
        return 6;
      default:
        return 1;
    }
  }

  static List<int> _resolvedWeekdays(
    RecurringTransactionEntity recurring,
    DateTime reference,
  ) {
    if (recurring.weekdays.isNotEmpty) {
      return recurring.weekdays.toList()..sort();
    }
    if (recurring.weekday != null) {
      return <int>[(recurring.weekday!.clamp(1, 7))];
    }
    return <int>[reference.weekday];
  }

  static DateTime? _explicitAnchor(
    RecurringTransactionEntity recurring,
    int hour,
    int minute,
  ) {
    if (recurring.anchorDate == null || recurring.anchorDate!.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(recurring.anchorDate!);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day, hour, minute);
  }

  static DateTime _resolvedAnchor(
    RecurringTransactionEntity recurring,
    DateTime reference,
    int hour,
    int minute,
  ) {
    final stored = recurring.anchorDate == null || recurring.anchorDate!.isEmpty
        ? null
        : DateTime.tryParse(recurring.anchorDate!);
    if (stored != null) {
      return DateTime(stored.year, stored.month, stored.day, hour, minute);
    }

    final handled = recurring.lastHandledOccurrenceAt == null ||
            recurring.lastHandledOccurrenceAt!.isEmpty
        ? null
        : DateTime.tryParse(recurring.lastHandledOccurrenceAt!);
    if (handled != null) {
      return DateTime(handled.year, handled.month, handled.day, hour, minute);
    }

    switch (recurring.recurrencePattern) {
      case 'daily':
        final today = DateTime(
          reference.year,
          reference.month,
          reference.day,
          hour,
          minute,
        );
        return today.isAfter(reference)
            ? today.subtract(const Duration(days: 1))
            : today;
      case 'weekly':
      case 'biweekly':
      case 'every_3_weeks':
        final weekdays = _resolvedWeekdays(recurring, reference);
        for (var offset = 0; offset <= 21; offset++) {
          final day = reference.subtract(Duration(days: offset));
          if (weekdays.contains(day.weekday)) {
            final candidate = DateTime(
              day.year,
              day.month,
              day.day,
              hour,
              minute,
            );
            if (!candidate.isAfter(reference)) return candidate;
          }
        }
        final fallback = reference;
        return DateTime(
          fallback.year,
          fallback.month,
          fallback.day,
          hour,
          minute,
        );
      case 'yearly':
        final month = (recurring.monthOfYear ?? reference.month).clamp(1, 12);
        final day = _dayInMonth(reference.year, month, recurring.dayOfMonth);
        final candidate = DateTime(reference.year, month, day, hour, minute);
        if (!candidate.isAfter(reference)) return candidate;
        final previousYearDay =
            _dayInMonth(reference.year - 1, month, recurring.dayOfMonth);
        return DateTime(
            reference.year - 1, month, previousYearDay, hour, minute);
      default:
        final day = _dayInMonth(
          reference.year,
          reference.month,
          recurring.dayOfMonth,
        );
        final candidate = DateTime(
          reference.year,
          reference.month,
          day,
          hour,
          minute,
        );
        if (!candidate.isAfter(reference)) return candidate;
        final previousMonth = DateTime(reference.year, reference.month - 1, 1);
        final previousDay = _dayInMonth(
          previousMonth.year,
          previousMonth.month,
          recurring.dayOfMonth,
        );
        return DateTime(
          previousMonth.year,
          previousMonth.month,
          previousDay,
          hour,
          minute,
        );
    }
  }

  static bool _weekCycleMatches(
    DateTime anchor,
    DateTime candidate,
    int intervalWeeks,
  ) {
    // للأسبوعي العادي (interval=1): كل أسبوع مطابق — مش محتاجين cycle check
    if (intervalWeeks == 1) return true;

    final anchorWeek = _startOfWeek(anchor);
    final candidateWeek = _startOfWeek(candidate);
    final differenceInDays = candidateWeek.difference(anchorWeek).inDays.abs();
    return (differenceInDays ~/ 7) % intervalWeeks == 0;
  }

  static bool _monthCycleMatches(
    DateTime anchor,
    DateTime candidate,
    int intervalMonths,
  ) {
    final months =
        (candidate.year - anchor.year) * 12 + candidate.month - anchor.month;
    if (months < 0) return false;
    return months % intervalMonths == 0;
  }

  static DateTime _startOfWeek(DateTime value) {
    final date = DateTime(value.year, value.month, value.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  static int _dayInMonth(int year, int month, int preferredDay) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return preferredDay.clamp(1, lastDay);
  }

  static bool _isOnOrAfterAnchor(DateTime candidate, DateTime? anchor) {
    if (anchor == null) return true;
    return !candidate.isBefore(anchor);
  }

  static DateTime? _applyAnchor(DateTime candidate, DateTime? anchor) {
    if (anchor == null) return candidate;
    return candidate.isBefore(anchor) ? anchor : candidate;
  }
}
