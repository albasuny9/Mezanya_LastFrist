import 'entities/notification_entity.dart';

enum NotificationHistoryCategory {
  all,
  income,
  allocation,
  jar,
  debt,
}

enum NotificationHistoryDuration {
  days30,
  months3,
  months6,
}

extension NotificationHistoryCategoryLabels on NotificationHistoryCategory {
  String get label => switch (this) {
        NotificationHistoryCategory.all => 'الكل',
        NotificationHistoryCategory.income => 'دخل',
        NotificationHistoryCategory.allocation => 'مخصصات',
        NotificationHistoryCategory.jar => 'حصالات',
        NotificationHistoryCategory.debt => 'ديون',
      };
}

extension NotificationHistoryDurationLabels on NotificationHistoryDuration {
  String get label => switch (this) {
        NotificationHistoryDuration.days30 => 'آخر 30 يوم',
        NotificationHistoryDuration.months3 => 'آخر 3 شهور',
        NotificationHistoryDuration.months6 => 'آخر 6 شهور',
      };

  DateTime get startDate {
    final now = DateTime.now();
    return switch (this) {
      NotificationHistoryDuration.days30 => now.subtract(const Duration(days: 30)),
      NotificationHistoryDuration.months3 =>
        DateTime(now.year, now.month - 3, now.day, now.hour, now.minute),
      NotificationHistoryDuration.months6 =>
        DateTime(now.year, now.month - 6, now.day, now.hour, now.minute),
    };
  }
}

NotificationHistoryCategory notificationHistoryCategoryOf(
  NotificationEntity item,
) {
  final text = '${item.title} ${item.message}';
  final type = item.type;

  if (type == 'allocation') {
    return NotificationHistoryCategory.allocation;
  }
  if (type == 'jar') {
    return NotificationHistoryCategory.jar;
  }
  if (text.contains('حصالة')) {
    return NotificationHistoryCategory.jar;
  }
  if (text.contains('مخصص')) {
    return NotificationHistoryCategory.allocation;
  }
  if (type == 'recurring-expense-handled' ||
      type == 'recurring-transaction' ||
      text.contains('سداد') ||
      text.contains('دين') ||
      text.contains('اشتراك')) {
    return NotificationHistoryCategory.debt;
  }
  if (text.contains('راتب') || text.contains('دخل')) {
    return NotificationHistoryCategory.income;
  }
  if (type == 'transaction' || type == 'income') {
    return NotificationHistoryCategory.income;
  }
  if (type == 'budget' && text.contains('راتب')) {
    return NotificationHistoryCategory.income;
  }
  return NotificationHistoryCategory.all;
}

bool notificationMatchesHistoryCategory(
  NotificationEntity item,
  NotificationHistoryCategory category,
) {
  if (category == NotificationHistoryCategory.all) return true;
  return notificationHistoryCategoryOf(item) == category;
}

String notificationHistoryDateGroupLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  if (target == today) return 'اليوم';
  final yesterday = today.subtract(const Duration(days: 1));
  if (target == yesterday) return 'أمس';
  return '${date.day} ${_arabicMonth(date.month)} ${date.year}';
}

String _arabicMonth(int month) {
  const months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  return months[month - 1];
}
