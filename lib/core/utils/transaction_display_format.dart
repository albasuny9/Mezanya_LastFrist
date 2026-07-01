import 'package:intl/intl.dart';

/// وقت 12 ساعة (ص/م) ثم التاريخ: `3:30 م | 5 يونيو`
String formatTransactionDateTime(DateTime dateTime) {
  final time = DateFormat('h:mm', 'ar').format(dateTime);
  final period = dateTime.hour < 12 ? 'ص' : 'م';
  final date = DateFormat('d MMM', 'ar').format(dateTime);
  return '$time $period | $date';
}

/// وقت 12 ساعة فقط: `9:11 ص`
String formatTransactionTime(DateTime dateTime) {
  final time = DateFormat('h:mm', 'ar').format(dateTime);
  final period = dateTime.hour < 12 ? 'ص' : 'م';
  return '$time $period';
}
