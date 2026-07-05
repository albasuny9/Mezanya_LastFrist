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

String currencyLabelAr(String code) {
  switch (code.toUpperCase()) {
    case 'EGP':
      return 'جنيه';
    case 'SAR':
      return 'ريال';
    case 'AED':
      return 'درهم';
    case 'USD':
      return 'دولار';
    case 'EUR':
      return 'يورو';
    case 'KWD':
      return 'دينار كويتي';
    case 'QAR':
      return 'ريال قطري';
    case 'BHD':
      return 'دينار بحريني';
    case 'OMR':
      return 'ريال عماني';
    case 'JOD':
      return 'دينار أردني';
    case 'LBP':
      return 'ليرة لبنانية';
    case 'IQD':
      return 'دينار عراقي';
    case 'MAD':
      return 'درهم مغربي';
    case 'TND':
      return 'دينار تونسي';
    case 'DZD':
      return 'دينار جزائري';
    case 'LYD':
      return 'دينار ليبي';
    case 'SDG':
      return 'جنيه سوداني';
    case 'YER':
      return 'ريال يمني';
    case 'SYP':
      return 'ليرة سورية';
    default:
      return code;
  }
}

String currencyFromCode(String currencyCode) {
  return currencyLabelAr(currencyCode);
}
