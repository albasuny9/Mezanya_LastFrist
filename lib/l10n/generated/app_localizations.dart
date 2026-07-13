import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// اسم التطبيق كما يظهر في نظام التشغيل ومدير المهام.
  ///
  /// In ar, this message translates to:
  /// **'ميزانية'**
  String get appTitle;

  /// No description provided for @backupTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي'**
  String get backupTitle;

  /// No description provided for @backupLocalSection.
  ///
  /// In ar, this message translates to:
  /// **'النسخ المحلي'**
  String get backupLocalSection;

  /// No description provided for @backupCloudSection.
  ///
  /// In ar, this message translates to:
  /// **'النسخ على السحابة'**
  String get backupCloudSection;

  /// No description provided for @backupAutomatic.
  ///
  /// In ar, this message translates to:
  /// **'النسخ التلقائي'**
  String get backupAutomatic;

  /// No description provided for @backupManual.
  ///
  /// In ar, this message translates to:
  /// **'النسخ اليدوي'**
  String get backupManual;

  /// No description provided for @backupNow.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الآن'**
  String get backupNow;

  /// No description provided for @backupNever.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم بعد'**
  String get backupNever;

  /// No description provided for @backupTimeToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get backupTimeToday;

  /// No description provided for @backupTimeYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get backupTimeYesterday;

  /// No description provided for @backupConnected.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get backupConnected;

  /// No description provided for @backupSignInGoogle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول بجوجل'**
  String get backupSignInGoogle;

  /// No description provided for @backupSignOut.
  ///
  /// In ar, this message translates to:
  /// **'خروج'**
  String get backupSignOut;

  /// No description provided for @backupCheckingAccount.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحقق...'**
  String get backupCheckingAccount;

  /// No description provided for @backupNotSignedIn.
  ///
  /// In ar, this message translates to:
  /// **'غير مسجّل الدخول'**
  String get backupNotSignedIn;

  /// No description provided for @backupMenuRestore.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع'**
  String get backupMenuRestore;

  /// No description provided for @backupMenuChangeFolder.
  ///
  /// In ar, this message translates to:
  /// **'تغيير المجلد'**
  String get backupMenuChangeFolder;

  /// No description provided for @backupConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'استرجاع النسخة'**
  String get backupConfirmTitle;

  /// No description provided for @backupConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'سيتم استبدال بياناتك الحالية بالنسخة المحفوظة. هل تريد المتابعة؟'**
  String get backupConfirmBody;

  /// No description provided for @backupConfirmProceed.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get backupConfirmProceed;

  /// No description provided for @backupConfirmCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get backupConfirmCancel;

  /// No description provided for @backupNoBackupFound.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخة محفوظة'**
  String get backupNoBackupFound;

  /// No description provided for @backupMsgRestored.
  ///
  /// In ar, this message translates to:
  /// **'تم الاسترجاع ✓'**
  String get backupMsgRestored;

  /// No description provided for @backupMsgSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم حفظ النسخة ✓'**
  String get backupMsgSaved;

  /// No description provided for @backupMsgSignInFirst.
  ///
  /// In ar, this message translates to:
  /// **'سجّل دخول بجوجل أولاً'**
  String get backupMsgSignInFirst;

  /// No description provided for @backupMsgReAuth.
  ///
  /// In ar, this message translates to:
  /// **'أعد تسجيل الدخول بجوجل'**
  String get backupMsgReAuth;

  /// No description provided for @backupMsgFolderChanged.
  ///
  /// In ar, this message translates to:
  /// **'تم تغيير المجلد ✓'**
  String get backupMsgFolderChanged;

  /// No description provided for @backupMsgSignInFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل تسجيل الدخول'**
  String get backupMsgSignInFailed;

  /// No description provided for @backupMsgUploadFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء النسخة'**
  String get backupMsgUploadFailed;

  /// No description provided for @backupLastBackup.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة'**
  String get backupLastBackup;

  /// No description provided for @backupError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ'**
  String get backupError;

  /// No description provided for @backupReplaceTitle.
  ///
  /// In ar, this message translates to:
  /// **'استبدال النسخة اليدوية'**
  String get backupReplaceTitle;

  /// No description provided for @backupReplaceBody.
  ///
  /// In ar, this message translates to:
  /// **'توجد نسخة يدوية محفوظة بالفعل. سيتم استبدالها بالكامل ببيانات التطبيق الحالية.'**
  String get backupReplaceBody;

  /// No description provided for @backupReplaceDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ النسخة الحالية: {date}'**
  String backupReplaceDate(String date);

  /// No description provided for @backupReplaceTxCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد المعاملات: {count}'**
  String backupReplaceTxCount(int count);

  /// No description provided for @backupReplaceWalletCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد المحافظ: {count}'**
  String backupReplaceWalletCount(int count);

  /// No description provided for @backupReplaceConfirm.
  ///
  /// In ar, this message translates to:
  /// **'استبدال النسخة'**
  String get backupReplaceConfirm;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
