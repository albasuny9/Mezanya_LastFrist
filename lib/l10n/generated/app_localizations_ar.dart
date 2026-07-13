// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'ميزانية';

  @override
  String get backupTitle => 'النسخ الاحتياطي';

  @override
  String get backupLocalSection => 'النسخ المحلي';

  @override
  String get backupCloudSection => 'النسخ على السحابة';

  @override
  String get backupAutomatic => 'النسخ التلقائي';

  @override
  String get backupManual => 'النسخ اليدوي';

  @override
  String get backupNow => 'نسخ الآن';

  @override
  String get backupNever => 'لم يتم بعد';

  @override
  String get backupTimeToday => 'اليوم';

  @override
  String get backupTimeYesterday => 'أمس';

  @override
  String get backupConnected => 'متصل';

  @override
  String get backupSignInGoogle => 'تسجيل الدخول بجوجل';

  @override
  String get backupSignOut => 'خروج';

  @override
  String get backupCheckingAccount => 'جاري التحقق...';

  @override
  String get backupNotSignedIn => 'غير مسجّل الدخول';

  @override
  String get backupMenuRestore => 'استرجاع';

  @override
  String get backupMenuChangeFolder => 'تغيير المجلد';

  @override
  String get backupConfirmTitle => 'استرجاع النسخة';

  @override
  String get backupConfirmBody =>
      'سيتم استبدال بياناتك الحالية بالنسخة المحفوظة. هل تريد المتابعة؟';

  @override
  String get backupConfirmProceed => 'متابعة';

  @override
  String get backupConfirmCancel => 'إلغاء';

  @override
  String get backupNoBackupFound => 'لا توجد نسخة محفوظة';

  @override
  String get backupMsgRestored => 'تم الاسترجاع ✓';

  @override
  String get backupMsgSaved => 'تم حفظ النسخة ✓';

  @override
  String get backupMsgSignInFirst => 'سجّل دخول بجوجل أولاً';

  @override
  String get backupMsgReAuth => 'أعد تسجيل الدخول بجوجل';

  @override
  String get backupMsgFolderChanged => 'تم تغيير المجلد ✓';

  @override
  String get backupMsgSignInFailed => 'فشل تسجيل الدخول';

  @override
  String get backupMsgUploadFailed => 'تعذّر إنشاء النسخة';

  @override
  String get backupLastBackup => 'آخر نسخة';

  @override
  String get backupError => 'خطأ';

  @override
  String get backupReplaceTitle => 'استبدال النسخة اليدوية';

  @override
  String get backupReplaceBody =>
      'توجد نسخة يدوية محفوظة بالفعل. سيتم استبدالها بالكامل ببيانات التطبيق الحالية.';

  @override
  String backupReplaceDate(String date) {
    return 'تاريخ النسخة الحالية: $date';
  }

  @override
  String backupReplaceTxCount(int count) {
    return 'عدد المعاملات: $count';
  }

  @override
  String backupReplaceWalletCount(int count) {
    return 'عدد المحافظ: $count';
  }

  @override
  String get backupReplaceConfirm => 'استبدال النسخة';
}
