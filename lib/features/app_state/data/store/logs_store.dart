import '../../../../core/storage/shared_prefs_keys.dart';
import 'shared_prefs_store.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Phase 6.3 من خطة إعادة تصميم طبقة الـ Persistence.
///
/// [LogsStore] مسؤولة حصريًا عن تخزين/استرجاع الـ **payload الخام** بتاع
/// الـ logs (سترنج JSON) — تحت مفتاح `SharedPrefsKeys.appStateLogs`
/// تحديدًا. نفس مبدأ [CoreStateStore] بالحرف، بس لمفتاح الـ logs المنفصل.
///
/// ملاحظة: الاسم "LogsStore" هنا بيقصد **تخزين الـ payload الخام بس** —
/// مش أي علاقة بـ `RecoveryHistoryService`/`ActivityLogService` (اللي هما
/// جزء من إعادة تصميم الـ Audit Log domain layer، موضوع مختلف تمامًا عن
/// إعادة تصميم طبقة الـ Persistence دي). الكلاس ده مش بيعرف حتى إن فيه
/// حاجة اسمها `LogEntryEntity` — بيتعامل مع سترنج بس.
/// ═══════════════════════════════════════════════════════════════════════
class LogsStore {
  const LogsStore(this._store);

  final SharedPrefsStore _store;

  /// يرجّع الـ payload الخام المخزَّن للـ logs، أو `null` لو مفيش حاجة.
  String? loadLogs() => _store.readString(SharedPrefsKeys.appStateLogs);

  /// يخزّن [payload] كما هو، بلا أي تعديل.
  Future<void> saveLogs(String payload) =>
      _store.writeString(SharedPrefsKeys.appStateLogs, payload);
}
