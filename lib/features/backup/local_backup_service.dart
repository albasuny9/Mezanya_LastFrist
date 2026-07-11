import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// خدمة النسخ الاحتياطي المحلي — Backup V2. مجلدان مستقلان تمامًا:
/// التلقائي (يدور بين ملفين، يحتفظ بآخر نسختين) واليدوي (ملف واحد ثابت لا
/// يُستبدَل إلا بضغطة المستخدم الصريحة على "إنشاء نسخة يدوية").
///
/// ADR-0003 وتوجيه محمد الصريح ببدء Backup V2 (فصل تلقائي/يدوي بالكامل،
/// تخزين منفصل لكل مجلد، عدم الكتابة فوق بعضهما إطلاقًا).
class LocalBackupService {
  LocalBackupService._();

  static const _autoFolderKey = 'auto_local_backup_folder';
  static const _manualFolderKey = 'manual_local_backup_folder';
  static const _lastAutoAtKey = 'last_auto_local_backup_at';
  static const _lastManualAtKey = 'last_manual_local_backup_at';
  static const _autoEnabledKey = 'auto_local_backup_enabled';

  static const _autoFileNames = [
    'mezanya_auto_backup_0.json',
    'mezanya_auto_backup_1.json',
  ];
  static const _manualFileName = 'mezanya_manual_backup.json';

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

  /// كتابة نسخة تلقائية محلية. يدور بين ملفين ثابتي الاسم في مجلد الـ
  /// auto فقط — لا علاقة له بمجلد النسخ اليدوي إطلاقًا. يكتب فوق أقدم
  /// الملفين (أو الملف غير الموجود)، فيبقى دائمًا آخر نسختين فقط.
  static Future<bool> writeAuto(String json) async {
    final folder = await autoFolder();
    if (folder == null) return false;

    final files = _autoFileNames
        .map((name) => File('$folder${Platform.pathSeparator}$name'))
        .toList();

    File target;
    final exists = await Future.wait(files.map((f) => f.exists()));
    if (!exists[0]) {
      target = files[0];
    } else if (!exists[1]) {
      target = files[1];
    } else {
      final t0 = (await files[0].stat()).modified;
      final t1 = (await files[1].stat()).modified;
      target = t0.isBefore(t1) ? files[0] : files[1];
    }

    try {
      await target.create(recursive: true);
      await target.writeAsString(json, flush: true);
    } catch (_) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAutoAtKey, DateTime.now().toIso8601String());
    return true;
  }

  /// كتابة نسخة يدوية محلية — ملف ثابت واحد في مجلد الـ manual فقط، لا
  /// علاقة له بمجلد النسخ التلقائي إطلاقًا. لا يُستدعى إلا من ضغطة
  /// المستخدم الصريحة على "إنشاء نسخة يدوية".
  static Future<bool> writeManual(String json, String folder) async {
    try {
      final file = File('$folder${Platform.pathSeparator}$_manualFileName');
      await file.create(recursive: true);
      await file.writeAsString(json, flush: true);
    } catch (_) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastManualAtKey, DateTime.now().toIso8601String());
    return true;
  }

  /// أحدث ملف من نسختي الـ auto (للاسترجاع) — null لو لا توجد أي نسخة بعد
  /// أو المجلد غير مضبوط.
  static Future<File?> latestAutoFile() async {
    final folder = await autoFolder();
    if (folder == null) return null;

    final files = _autoFileNames
        .map((name) => File('$folder${Platform.pathSeparator}$name'))
        .toList();
    final exists = await Future.wait(files.map((f) => f.exists()));

    if (!exists[0] && !exists[1]) return null;
    if (!exists[0]) return files[1];
    if (!exists[1]) return files[0];

    final t0 = (await files[0].stat()).modified;
    final t1 = (await files[1].stat()).modified;
    return t1.isAfter(t0) ? files[1] : files[0];
  }

  /// ملف النسخة اليدوية الحالي — null لو لا يوجد أو المجلد غير مضبوط.
  static Future<File?> manualFile() async {
    final folder = await manualFolder();
    if (folder == null) return null;
    final file = File('$folder${Platform.pathSeparator}$_manualFileName');
    return await file.exists() ? file : null;
  }
}
