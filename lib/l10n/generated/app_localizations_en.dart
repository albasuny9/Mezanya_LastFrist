// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Mezanya';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupLocalSection => 'Local Backup';

  @override
  String get backupCloudSection => 'Cloud Backup';

  @override
  String get backupAutomatic => 'Automatic Backup';

  @override
  String get backupManual => 'Manual Backup';

  @override
  String get backupNow => 'Backup Now';

  @override
  String get backupNever => 'Never backed up';

  @override
  String get backupTimeToday => 'Today';

  @override
  String get backupTimeYesterday => 'Yesterday';

  @override
  String get backupConnected => 'Connected';

  @override
  String get backupSignInGoogle => 'Sign in with Google';

  @override
  String get backupSignOut => 'Sign out';

  @override
  String get backupCheckingAccount => 'Checking...';

  @override
  String get backupNotSignedIn => 'Not signed in';

  @override
  String get backupMenuRestore => 'Restore';

  @override
  String get backupMenuChangeFolder => 'Change Folder';

  @override
  String get backupConfirmTitle => 'Restore Backup';

  @override
  String get backupConfirmBody =>
      'Your current data will be replaced with the saved backup. Continue?';

  @override
  String get backupConfirmProceed => 'Proceed';

  @override
  String get backupConfirmCancel => 'Cancel';

  @override
  String get backupNoBackupFound => 'No backup found';

  @override
  String get backupMsgRestored => 'Restored ✓';

  @override
  String get backupMsgSaved => 'Backup saved ✓';

  @override
  String get backupMsgSignInFirst => 'Please sign in with Google first';

  @override
  String get backupMsgReAuth => 'Please sign in with Google again';

  @override
  String get backupMsgFolderChanged => 'Folder updated ✓';

  @override
  String get backupMsgSignInFailed => 'Sign-in failed';

  @override
  String get backupMsgUploadFailed => 'Backup failed';

  @override
  String get backupLastBackup => 'Last backup';

  @override
  String get backupError => 'Error';

  @override
  String get backupReplaceTitle => 'Replace Manual Backup';

  @override
  String get backupReplaceBody =>
      'A manual backup already exists. It will be fully replaced with the current app data.';

  @override
  String backupReplaceDate(String date) {
    return 'Current backup date: $date';
  }

  @override
  String backupReplaceTxCount(int count) {
    return 'Transactions: $count';
  }

  @override
  String backupReplaceWalletCount(int count) {
    return 'Wallets: $count';
  }

  @override
  String get backupReplaceConfirm => 'Replace Backup';
}
