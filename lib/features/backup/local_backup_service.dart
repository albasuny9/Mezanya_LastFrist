import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// ملخص محتوى نسخة احتياطية محلية موجودة — يُستخدَم لعرض مقارنة للمستخدم
/// قبل استبدال نسخة يدوية موجودة (تاريخ الإنشاء، عدد المعاملات، عدد
/// المحافظ) دون الحاجة لفك تشفير الملف بالكامل في واجهة المستخدم.
class LocalBackupSummary {
  final DateTime modifiedAt;
  final int transactionCount;
  final int walletCount;
  final int byteSize;

  const LocalBackupSummary({
    required this.modifiedAt,
    required this.transactionCount,
    required this.walletCount,
    required this.byteSize,
  });
}

/// خدمة النسخ الاحتياطي المحلي — Backup V2 (نسخة منقّحة). مجلدان مستقلان
/// تمامًا (مفتاحا SharedPreferences مختلفان)، وكل واحد منهما يملك **ملفًا
/// واحدًا ثابت الاسم فقط** — لا تراكم ولا تدوير:
/// - AutoBackup.json في مجلد الـ auto.
/// - ManualBackup.json في مجلد الـ manual.
/// كتابة كل منهما آمنة عبر ملف مؤقت (`.tmp`) ثم إعادة تسمية، ولا يكتب
/// أحدهما فوق الآخر أبدًا (مجلدان ومفتاحان منفصلان بالكامل).
class LocalBackupService {
  LocalBackupService._();

  static const _autoFolderKey = 'auto_local_backup_folder';
  static const _manualFolderKey = 'manual_local_backup_folder';
  static const _lastAutoAtKey = 'last_auto_local_backup_at';
  static const _lastManualAtKey = 'last_manual_local_backup_at';
  static const _autoEnabledKey = 'auto_local_backup_enabled';

  static const _autoFileName = 'AutoBackup.json';
  static const _manualFileName = 'ManualBackup.json';

  static Future<String?> autoFolder() async =>
      (await SharedPreferences.getInstance()).getString(_autoFolderKey);

  static Future<String?> manualFolder() async =>
      (await SharedPreferences.getInstance()).getString(_manualFolderKey);

  static Future<void> setAutoFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoFolderKey, path);
  }

  static Future<void> setManualFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_manualFolderKey, path);
  }

  static Future<bool> autoEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_autoEnabledKey) ?? false;

  static Future<void> setAutoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoEnabledKey, value);
  }

  static Future<String?> lastAutoBackupAt() async =>
      (await SharedPreferences.getInstance()).getString(_lastAutoAtKey);

  static Future<String?> lastManualBackupAt() async =>
      (await SharedPreferences.getInstance()).getString(_lastManualAtKey);

  static Future<File?> autoFile() async {
    final folder = await autoFolder();
    if (folder == null) return null;
    final file = File('$folder${Platform.pathSeparator}$_autoFileName');
    return await file.exists() ? file : null;
  }

  static Future<File?> manualFile() async {
    final folder = await manualFolder();
    if (folder == null) return null;
    final file = File('$folder${Platform.pathSeparator}$_manualFileName');
    return await file.exists() ? file : null;
  }

  /// أحدث ملف تلقائي محلي (للاسترجاع) — اسم مستعار لـ [autoFile] يحافظ
  /// على توافق واجهة الاستدعاء القديمة.
  static Future<File?> latestAutoFile() => autoFile();

  /// كتابة آمنة عبر ملف مؤقت ثم rename — مشتركة بين التلقائي واليدوي.
  static Future<bool> _writeSafely(File target, String json) async {
    try {
      final tmp = File('${target.path}.tmp');
      await tmp.create(recursive: true);
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(target.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// كتابة نسخة تلقائية محلية — تستبدل AutoBackup.json دائمًا (نسخة واحدة
  /// فقط تمثّل آخر حالة تلقائية، بلا تراكم وبلا تدوير).
  static Future<bool> writeAuto(String json) async {
    final folder = await autoFolder();
    if (folder == null) return false;
    final target = File('$folder${Platform.pathSeparator}$_autoFileName');
    final ok = await _writeSafely(target, json);
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAutoAtKey, DateTime.now().toIso8601String());
    return true;
  }

  /// كتابة نسخة يدوية محلية — تستبدل ManualBackup.json. يجب استدعاء
  /// [readManualSummary] قبل هذه الدالة إن أردت عرض مقارنة/تأكيد للمستخدم
  /// قبل الاستبدال — هذه الدالة نفسها لا تسأل، تستبدل مباشرة.
  static Future<bool> writeManual(String json, String folder) async {
    final target = File('$folder${Platform.pathSeparator}$_manualFileName');
    final ok = await _writeSafely(target, json);
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastManualAtKey, DateTime.now().toIso8601String());
    return true;
  }

  /// ملخص محتوى ManualBackup.json الموجود حاليًا في مجلد الـ manual (لو
  /// وُجد) — يُستخدَم لعرض مقارنة للمستخدم قبل الاستبدال. null لو لا
  /// يوجد ملف بعد أو تعذّرت قراءته.
  static Future<LocalBackupSummary?> readManualSummary() async {
    final file = await manualFile();
    if (file == null) return null;
    try {
      final stat = await file.stat();
      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      final transactions = decoded['transactions'];
      final wallets = decoded['wallets'];
      return LocalBackupSummary(
        modifiedAt: stat.modified,
        transactionCount: transactions is List ? transactions.length : 0,
        walletCount: wallets is List ? wallets.length : 0,
        byteSize: content.length,
      );
    } catch (_) {
      return null;
    }
  }
}
