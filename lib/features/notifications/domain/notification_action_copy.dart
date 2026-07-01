import 'package:intl/intl.dart' hide TextDirection;

String formatNotificationMoney(double amount) {
  final value = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$value جنيه';
}

String relativePostponeLabel(DateTime until) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(until.year, until.month, until.day);
  final days = target.difference(today).inDays;
  if (days <= 0) return 'اليوم';
  if (days == 1) return 'غد';
  if (days <= 7) return '$days أيام';
  return DateFormat('d MMMM yyyy', 'ar').format(until);
}

String allocationConfirmTitle({required String name}) => 'تخصيص لمخصص $name';

String allocationConfirmMessage({
  required double amount,
  required String name,
}) =>
    'تخصيص ${formatNotificationMoney(amount)} لمخصص $name';

String allocationSkipTitle({required String name}) => 'تخطي تخصيص لمخصص $name';

String allocationSkipMessage({
  required double amount,
  required String name,
}) =>
    'تخطي تخصيص ${formatNotificationMoney(amount)} لمخصص $name';

String jarAllocationConfirmTitle({required String jarName}) =>
    'تخصيص لحصالة $jarName';

String jarAllocationConfirmMessage({
  required double amount,
  required String jarName,
}) =>
    'تخصيص ${formatNotificationMoney(amount)} لحصالة $jarName';

String jarPhysicalConfirmTitle({required String jarName}) =>
    'خصم لحصالة $jarName';

String jarPhysicalConfirmMessage({
  required double amount,
  required String jarName,
}) =>
    'خصم ${formatNotificationMoney(amount)} لحصالة $jarName';

String jarAllocationSkipTitle({required String jarName}) =>
    'تخطي تخصيص لحصالة $jarName';

String jarAllocationSkipMessage({
  required double amount,
  required String jarName,
}) =>
    'تخطي تخصيص ${formatNotificationMoney(amount)} لحصالة $jarName';

String incomeConfirmTitle({
  required String name,
  bool early = false,
}) =>
    early ? 'تسجيل مبكر لراتب $name' : 'نزل راتب $name';

String incomeConfirmMessage({
  required String name,
  required double amount,
  bool early = false,
}) =>
    early
        ? 'تسجيل مبكر لراتب $name — ${formatNotificationMoney(amount)}'
        : 'نزل راتب $name — ${formatNotificationMoney(amount)}';

String incomePostponeTitle({required String name}) => 'تأجيل راتب $name';

String incomePostponeMessage({
  required String name,
  required double amount,
  required DateTime until,
}) =>
    'تأجيل راتب $name (${formatNotificationMoney(amount)}) حتى ${relativePostponeLabel(until)}';

String debtPayTitle({required String name}) => 'سداد $name';

String debtPayMessage({
  required String name,
  required double amount,
}) =>
    'سداد $name — ${formatNotificationMoney(amount)}';

String debtPostponeTitle({required String name}) => 'تأجيل $name';

String debtPostponeMessage({
  required String name,
  required double amount,
  required DateTime until,
}) =>
    'تأجيل $name (${formatNotificationMoney(amount)}) حتى ${relativePostponeLabel(until)}';

String debtSkipTitle({required String name}) => 'تخطي $name';

String debtSkipMessage({
  required String name,
  required double amount,
}) =>
    'تخطي $name — ${formatNotificationMoney(amount)}';

/// عنوان مختصر للكارت — يدعم الإشعارات القديمة اللي العنوان فيها فيه المبلغ.
String notificationHistoryTitle({
  required String title,
  required String message,
}) {
  final trimmed = title.trim();
  if (trimmed.isNotEmpty && !_titleLooksLikeFullSentence(trimmed)) {
    return trimmed;
  }
  return _shortenNotificationTitle(message.trim().isNotEmpty ? message : trimmed);
}

String notificationHistoryAmount({
  required String message,
  String? logDetails,
}) {
  final source = '${message.trim()} ${logDetails?.trim() ?? ''}';
  final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(source);
  if (match == null) return '';
  final raw = match.group(1)!.replaceAll(',', '.');
  final value = double.tryParse(raw);
  if (value == null) return match.group(1)!;
  return formatNotificationMoney(value);
}

bool _titleLooksLikeFullSentence(String title) {
  return title.contains('جنيه') ||
      title.contains('—') ||
      RegExp(r'\d').hasMatch(title);
}

String _shortenNotificationTitle(String text) {
  final s = text.trim();
  if (s.isEmpty) return 'إشعار';

  RegExpMatch? match;

  match = RegExp(r'^خصم\s+[\d.,]+\s+جنيه\s+لحصالة\s+(.+)$').firstMatch(s);
  if (match != null) return 'خصم لحصالة ${match.group(1)}';

  match = RegExp(r'^تخصيص\s+[\d.,]+\s+جنيه\s+لحصالة\s+(.+)$').firstMatch(s);
  if (match != null) return 'تخصيص لحصالة ${match.group(1)}';

  match = RegExp(r'^تخصيص\s+[\d.,]+\s+جنيه\s+لمخصص\s+(.+)$').firstMatch(s);
  if (match != null) return 'تخصيص لمخصص ${match.group(1)}';

  match =
      RegExp(r'^تخطي تخصيص\s+[\d.,]+\s+جنيه\s+لحصالة\s+(.+)$').firstMatch(s);
  if (match != null) return 'تخطي تخصيص لحصالة ${match.group(1)}';

  match =
      RegExp(r'^تخطي تخصيص\s+[\d.,]+\s+جنيه\s+لمخصص\s+(.+)$').firstMatch(s);
  if (match != null) return 'تخطي تخصيص لمخصص ${match.group(1)}';

  match = RegExp(r'^نزل راتب\s+(.+?)\s+—').firstMatch(s);
  if (match != null) return 'نزل راتب ${match.group(1)}';

  match = RegExp(r'^تسجيل مبكر لراتب\s+(.+?)\s+—').firstMatch(s);
  if (match != null) return 'تسجيل مبكر لراتب ${match.group(1)}';

  match = RegExp(r'^تأجيل راتب\s+(.+?)\s+\(').firstMatch(s);
  if (match != null) return 'تأجيل راتب ${match.group(1)}';

  match = RegExp(r'^سداد\s+(.+?)\s+—').firstMatch(s);
  if (match != null) return 'سداد ${match.group(1)}';

  match = RegExp(r'^تأجيل\s+(.+?)\s+\(').firstMatch(s);
  if (match != null) return 'تأجيل ${match.group(1)}';

  match = RegExp(r'^تخطي\s+(.+?)\s+—').firstMatch(s);
  if (match != null) return 'تخطي ${match.group(1)}';

  match = RegExp(r'^تأكيد النزول لـ:\s*(.+)$').firstMatch(s);
  if (match != null) return 'تخصيص لمخصص ${match.group(1)}';

  match = RegExp(r'^تخطي النزول لـ:\s*(.+)$').firstMatch(s);
  if (match != null) return 'تخطي تخصيص لمخصص ${match.group(1)}';

  return s;
}
