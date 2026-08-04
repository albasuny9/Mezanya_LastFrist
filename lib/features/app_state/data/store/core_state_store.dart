import '../../../../core/storage/shared_prefs_keys.dart';
import 'shared_prefs_store.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Phase 6.3 من خطة إعادة تصميم طبقة الـ Persistence.
///
/// [CoreStateStore] مسؤولة حصريًا عن تخزين/استرجاع الـ **payload الخام**
/// بتاع الـ core state (سترنج JSON، بدون logs) — تحت مفتاح
/// `SharedPrefsKeys.appState` تحديدًا. **مفيش أي معرفة بـ JSON نفسه (مش
/// بتعمل decode/encode)، ولا بـ entities، ولا validation، ولا migration.**
/// كل ده مسؤولية مكوّنات تانية (`AppStateSerializer`, الـ Repository نفسها
/// اللي بتنسّق بينهم).
///
/// الفرق بينها وبين [SharedPrefsStore] العامة: `SharedPrefsStore` بتاخد
/// مفتاح كـ parameter لأي استخدام؛ `CoreStateStore` بتعرف **بالضبط** مين
/// المفتاح بتاعها (`appState`) وبتديه اسم واضح المعنى (`loadCore`/
/// `saveCore`)، فالـ Repository معادش محتاج يعرف اسم المفتاح نفسه أصلًا.
/// ═══════════════════════════════════════════════════════════════════════
class CoreStateStore {
  const CoreStateStore(this._store);

  final SharedPrefsStore _store;

  /// يرجّع الـ payload الخام المخزَّن، أو `null` لو مفيش حاجة متخزّنة.
  String? loadCore() => _store.readString(SharedPrefsKeys.appState);

  /// يخزّن [payload] كما هو، بلا أي تعديل.
  Future<void> saveCore(String payload) =>
      _store.writeString(SharedPrefsKeys.appState, payload);
}
