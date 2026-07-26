import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Phase 6.2 من خطة إعادة تصميم طبقة الـ Persistence.
///
/// [SharedPrefsStore] مسؤولة حصريًا عن الـ I/O الخام مع `SharedPreferences`
/// — قراءة/كتابة/حذف سترنج بمفتاح معيّن. **مفيش أي معرفة بـ JSON، ولا
/// entities، ولا `AppStateEntity`، ولا `LogEntryEntity`، ولا serialization،
/// ولا migration، ولا validation، ولا diagnostics، ولا timing.** المسؤولية
/// دي كلها في مكوّنات تانية (`AppStateSerializer` للـ serialization، وباقي
/// المكوّنات المقترَحة في تقرير المعمارية لسه هتتعمل تباعًا).
///
/// `SharedPrefsAppRepository` هي المستهلِك الوحيد المقصود للكلاس ده — أي
/// كود تاني محتاج يخزّن حاجة في `SharedPreferences` (إعدادات، أعلام مؤقتة،
/// إلخ) لازم يستخدم `SharedPreferences.getInstance()` مباشرة زي ما هو
/// معمول حاليًا في باقي المشروع (`app_settings_screen.dart`,
/// `backup_settings_screen.dart`, `local_backup_service.dart`,
/// `backup_upload_pipeline.dart`) — دول استخدامات "إعدادات"/"أعلام مؤقتة"
/// مختلفة تمامًا عن تخزين حالة التطبيق، ومقصود إنها متفضلش برّه نطاق
/// الاستخراج ده (راجع تصنيف الاستخدامات في تقرير Phase 6.2).
/// ═══════════════════════════════════════════════════════════════════════
class SharedPrefsStore {
  const SharedPrefsStore(this._prefs);

  final SharedPreferences _prefs;

  /// يرجّع القيمة المخزَّنة تحت [key]، أو `null` لو مش موجودة.
  String? readString(String key) => _prefs.getString(key);

  /// يخزّن [value] تحت [key].
  Future<void> writeString(String key, String value) =>
      _prefs.setString(key, value);

  /// يمسح القيمة المخزَّنة تحت [key] لو موجودة.
  Future<void> remove(String key) => _prefs.remove(key);

  /// هل فيه قيمة مخزَّنة تحت [key]؟
  bool contains(String key) => _prefs.containsKey(key);
}
