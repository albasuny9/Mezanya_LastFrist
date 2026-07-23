import '../../../logs/domain/entities/log_entry_entity.dart';

/// يمثّل عنصر "Recovery History" حسب التعريف المعتمد في الـ Domain Bible
/// (`11 - Financial Ledger.md`, §2ب): لقطة استرجاع مؤقتة الغرض منها التراجع
/// (Undo) فقط — لا تشارك أبدًا في الحساب المالي أو التقارير أو الـ Timeline.
///
/// ═══════════════════════════════════════════════════════════════════════
/// مرحلة التعايش (Phase 1 من خطة إعادة تصميم Audit Log):
/// الكيان ده لسه مش مصدر تخزين مستقل — هو تمثيل قراءة فقط (read-only view)
/// فوق `LogEntryEntity`/`state.logs` الحاليين، عبر [RecoveryHistoryAdapter].
/// مفيش أي كود موجود (toggleLogRevert, LogsScreen, النوتيفكيشن) اتغيّر أو
/// هيتأثر بوجود الكيان ده — استخدامه اختياري لأي كود جديد فقط.
/// ═══════════════════════════════════════════════════════════════════════
class RecoveryEntry {
  const RecoveryEntry({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.beforeState,
    required this.afterState,
    required this.timestamp,
    required this.isReverted,
    this.revertedAt,
    this.sourceLogId,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String action;

  /// JSON كامل لحالة التطبيق قبل العملية — نفس محتوى
  /// `LogEntryEntity.beforeState` بالحرف، منسوخ مش مُعاد بناؤه.
  final String beforeState;

  /// JSON كامل لحالة التطبيق بعد العملية.
  final String afterState;

  final DateTime timestamp;
  final bool isReverted;
  final DateTime? revertedAt;

  /// معرّف الـ [LogEntryEntity] الأصلي اللي اتبنى منه العنصر ده — بيسمح لأي
  /// كود جديد يستدعي آلية التراجع الحالية (`toggleLogRevert(sourceLogId)`)
  /// من غير ما يحتاج يعرف تفاصيل `LogEntryEntity` نفسها.
  final String? sourceLogId;

  bool get canRevert => !isReverted;
}
