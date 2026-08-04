import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Phase 6.2 من خطة إعادة تصميم طبقة الـ Persistence.
///
/// [SharedPrefsStore] مسؤولة حصريًا عن الـ I/O الخام مع `SharedPreferences`
/// — قراءة/كتابة/حذف سترنج أو bool بمفتاح معيّن. **مفيش أي معرفة بـ JSON،
/// ولا entities، ولا `AppStateEntity`، ولا `LogEntryEntity`، ولا
/// serialization، ولا migration، ولا validation، ولا diagnostics، ولا
/// timing.**
///
/// المستهلِكين المقصودين: `SharedPrefsAppRepository` (حالة التطبيق)
/// و`AppCubitBase._autoSync` (علم `auto_cloud_backup_enabled` وحالة آخر
/// مزامنة — كانت بتوصل لـ `SharedPreferences.getInstance()` مباشرة، وده
/// كان تسريب معماري موثَّق في تقرير Phase 6.2؛ اتصلح بحقن `SharedPrefsStore`
/// نفسها في `AppCubit` بدل الوصول المباشر). باقي استخدامات الإعدادات في
/// المشروع (`app_settings_screen.dart`, `backup_settings_screen.dart`,
/// `local_backup_service.dart`, `backup_upload_pipeline.dart`) لسه بتستخدم
/// `SharedPreferences.getInstance()` مباشرة بشكل مقصود — دول شاشات/خدمات
/// إعدادات مستقلة، مش جزء من مسار الـ Cubit/Repository.
/// ═══════════════════════════════════════════════════════════════════════
class SharedPrefsStore {
  const SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  /// يرجّع القيمة المخزَّنة تحت [key]، أو `null` لو مش موجودة.
  String? readString(String key) => _prefs.getString(key);

  /// يخزّن [value] تحت [key].
  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  /// يرجّع قيمة bool مخزَّنة تحت [key]، أو `null` لو مش موجودة.
  bool? readBool(String key) => _prefs.getBool(key);

  /// يخزّن [value] (bool) تحت [key].
  Future<void> writeBool(String key, bool value) =>
      _prefs.setBool(key, value);

  /// يمسح القيمة المخزَّنة تحت [key] لو موجودة.
  Future<void> remove(String key) => _prefs.remove(key);

  /// هل فيه قيمة مخزَّنة تحت [key]؟
  bool contains(String key) => _prefs.containsKey(key);
}
