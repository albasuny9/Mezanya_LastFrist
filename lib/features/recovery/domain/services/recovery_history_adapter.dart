import '../../../logs/domain/entities/log_entry_entity.dart';
import '../entities/recovery_entry.dart';

/// محوّل قراءة فقط (read-only adapter) بيبني [RecoveryEntry] من
/// [LogEntryEntity] الحالية — بدون أي تخزين جديد وبدون أي تغيير في مصدر
/// الحقيقة (`state.logs`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// Phase 1 من خطة إعادة تصميم Audit Log — التعايش بين النظامين.
///
/// ليه موجود: يسمح لأي كود جديد يتعامل مع مفهوم "Recovery History" الصحيح
/// دومينيًا (الفصل 11 من الـ Domain Bible) من غير ما ننتظر نقل آلية
/// التراجع الفعلية (`toggleLogRevert` في app_cubit_notifications.dart) —
/// دي هتتنقل في مرحلة لاحقة (Phase 3) بعد ما نتأكد من سلوك الأدابتر ده في
/// الإنتاج.
///
/// ملاحظة تصنيف مهمة: في المرحلة دي، *كل* الـ logs بتتحوّل لـ
/// [RecoveryEntry] (مفيش استبعاد لأي نوع) — لأن ده فعليًا نفس القدرة
/// الحقيقية الموجودة النهارده (أي log عنده `beforeState`/`afterState`
/// صالحين قابل نظريًا للتراجع عبر `toggleLogRevert`). قرار تضييق النطاق
/// (مثلاً استبعاد `backup`/`all-data` من الـ Recovery الحقيقي، أو تطبيق
/// سياسة احتفاظ زمنية بدل الاحتفاظ الكامل) هو قرار Phase 3، مش قرار
/// الأدابتر ده — الأدابتر لسه بيعكس الواقع الحالي بأمانة، مش بيفرض سياسة
/// جديدة.
/// ═══════════════════════════════════════════════════════════════════════
class RecoveryHistoryAdapter {
  const RecoveryHistoryAdapter._();

  static RecoveryEntry fromLog(LogEntryEntity log) {
    return RecoveryEntry(
      id: 'recovery-${log.id}',
      entityType: log.entityType,
      entityId: log.entityId,
      action: log.action,
      beforeState: log.beforeState,
      afterState: log.afterState,
      timestamp: log.timestamp,
      isReverted: log.isReverted,
      revertedAt: log.revertedAt,
      sourceLogId: log.id,
    );
  }

  static List<RecoveryEntry> fromLogs(List<LogEntryEntity> logs) {
    return logs.map(fromLog).toList();
  }

  /// أحدث عنصر قابل للتراجع لكيان معيّن — مفيدة لأي شاشة جديدة محتاجة
  /// "آخر عملية على المعاملة دي قابلة للتراجع".
  static RecoveryEntry? latestForEntity(
    List<LogEntryEntity> logs,
    String entityId,
  ) {
    for (final log in logs) {
      if (log.entityId == entityId && !log.isReverted) {
        return fromLog(log);
      }
    }
    return null;
  }
}
