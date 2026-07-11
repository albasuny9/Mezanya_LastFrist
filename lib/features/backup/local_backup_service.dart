import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// خدمة النسخ الاحتياطي المحلي — Backup V2. مجلدان مستقلان تمامًا:
/// التلقائي (يدور بين ملفين، يحتفظ بآخر نسختين، كتابة آمنة عبر ملف مؤقت)
/// واليدوي (أسماء ملفات بالطابع الزمني، لا يُحذف أو يُستبدَل أي منها
/// تلقائيًا أبدًا — يتراكم حتى يحذفها المستخدم يدويًا من نظام الملفات).
///
/// ADR-0003 وتوجيه محمد الصريح ببدء Backup V2.
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
  static const _manualFilePrefix = 'mezanya_manual_backup_';

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

  /// كتابة نسخة تلقائية محلية — آمنة عبر ملف مؤقت (`.tmp`) ثم إعادة تسمية
  /// (rename) بدل الكتابة المباشرة فوق الملف الهدف. لو انقطعت الكتابة في
  /// منتصفها لأي سبب، الملف الهدف القديم يبقى كما هو سليمًا تمامًا —
  /// الاستبدال يحدث فقط بعد اكتمال الكتابة الجديدة بنجاح.
  ///
  /// يدور بين ملفين ثابتي الاسم في مجلد الـ auto فقط، فيحتفظ دائمًا بآخر
  /// نسختين ناجحتين فقط ولا يتراكم بلا حدود.
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
      final tmp = File('${target.path}.tmp');
      await tmp.create(recursive: true);
      await tmp.writeAsString(json, flush: true);
      // الكتابة نجحت بالكامل — الآن فقط نستبدل الهدف. rename على نفس
      // الـ filesystem عملية شبه-ذرية، فلا يوجد وقت يظهر فيه الملف الهدف
      // بمحتوى ناقص.
      await tmp.rename(target.path);
    } catch (_) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAutoAtKey, DateTime.now().toIso8601String());
    return true;
  }

  /// كتابة نسخة يدوية محلية — **ملف جديد بالطابع الزمني في اسمه في كل
  /// مرة**، في مجلد الـ manual فقط. لا يُحذف ولا يُستبدَل أي ملف يدوي
  /// سابق تلقائيًا أبدًا — يتراكم حتى يحذفه المستخدم بنفسه من نظام
  /// الملفات. لا يُستدعى إلا من ضغطة المستخدم الصريحة على "إنشاء نسخة
  /// يدوية".
  static Future<bool> writeManual(String json, String folder) async {
    try {
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File(
        '$folder${Platform.pathSeparator}$_manualFilePrefix$stamp.json',
      );
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

  /// كل ملفات النسخ اليدوية المحلية الموجودة في مجلد الـ manual، مرتّبة
  /// من الأحدث للأقدم (بحسب الطابع الزمني في اسم الملف). قائمة فارغة لو
  /// لا يوجد مجلد أو لا توجد نسخ بعد.
  static Future<List<File>> manualFiles() async {
    final folder = await manualFolder();
    if (folder == null) return const [];
    final dir = Directory(folder);
    if (!await dir.exists()) return const [];

    final files = await dir
        .list()
        .where((e) => e is File && e.path.contains(_manualFilePrefix))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path)); // اسم الملف = طابع زمني
    return files;
  }

  /// أحدث نسخة يدوية محلية (للاسترجاع الافتراضي بضغطة واحدة) — null لو لا
  /// توجد أي نسخة بعد.
  static Future<File?> manualFile() async {
    final files = await manualFiles();
    return files.isEmpty ? null : files.first;
  }
}
