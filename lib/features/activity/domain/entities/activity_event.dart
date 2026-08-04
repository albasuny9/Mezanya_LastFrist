/// يمثّل عنصر "Activity Log" حسب التعريف المعتمد في الـ Domain Bible
/// (`11 - Financial Ledger.md`, §2ب): سجل أحداث إداري خفيف (إنشاء/تعديل/حذف
/// ميزانية، حصالة، هدف، إلخ) — **بدون** أي لقطة حالة كاملة، لأنه مش مصمَّم
/// للتراجع، بس للعرض والشفافية.
///
/// ═══════════════════════════════════════════════════════════════════════
/// مرحلة التعايش (Phase 1): نفس مبدأ [RecoveryEntry] — تمثيل قراءة فقط فوق
/// `state.logs` الحالية عبر [ActivityLogAdapter]. مفيش تخزين مستقل بعد،
/// ومفيش أي كود موجود اتغيّر.
/// ═══════════════════════════════════════════════════════════════════════
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String action;

  /// نص جاهز للعرض المباشر — نفس `LogEntryEntity.details` بالحرف، مش
  /// مشتق من أي لقطة JSON.
  final String details;

  final DateTime timestamp;
}
