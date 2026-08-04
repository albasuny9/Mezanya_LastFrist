import '../../../logs/domain/entities/log_entry_entity.dart';
import '../entities/activity_event.dart';

/// محوّل قراءة فقط بيبني [ActivityEvent] (تمثيل خفيف، بدون
/// beforeState/afterState) من [LogEntryEntity] الحالية.
///
/// ═══════════════════════════════════════════════════════════════════════
/// Phase 1 من خطة إعادة تصميم Audit Log — التعايش بين النظامين.
///
/// ليه موجود: يسمح لأي شاشة/كود جديد يعرض "تايم لاين نشاط" من غير ما يحمّل
/// أو يمرّر أي لقطة JSON ضخمة (`beforeState`/`afterState`) في الذاكرة —
/// وده بالظبط الفرق الجوهري بين "Activity Log" و"Recovery History" في
/// الفصل 11 من الـ Domain Bible. الفرق ده تحديدًا هو اللي هيحل مشكلة
/// الأداء الموصوفة سابقًا في `LogsScreen._detailRowsForLog` (فك تشفير
/// لقطة كاملة لكل عنصر ظاهر) — أي كود جديد يستخدم [ActivityEvent] مش
/// هيحمل التكلفة دي خالص، لأنه مبنيًا من غير ما يلمس `beforeState`/
/// `afterState` أصلًا.
///
/// `LogsScreen` الحالية **متأثرتش** بوجود الأدابتر ده ولسه بتشتغل زي ما
/// هي — نقلها الفعلي لاستهلاك [ActivityEvent] بدل `LogEntryEntity` مباشرة
/// هو موضوع Phase 2.
/// ═══════════════════════════════════════════════════════════════════════
class ActivityLogAdapter {
  const ActivityLogAdapter._();

  static ActivityEvent fromLog(LogEntryEntity log) {
    return ActivityEvent(
      id: 'activity-${log.id}',
      entityType: log.entityType,
      entityId: log.entityId,
      action: log.action,
      details: log.details,
      timestamp: log.timestamp,
    );
  }

  static List<ActivityEvent> fromLogs(List<LogEntryEntity> logs) {
    return logs.map(fromLog).toList();
  }

  /// آخر N حدث — مفيدة لأي widget جديد محتاج ملخّص نشاط خفيف (زي بطاقة
  /// "آخر التعديلات" في شاشة رئيسية) من غير أي تكلفة فك تشفير.
  static List<ActivityEvent> recent(List<LogEntryEntity> logs, int limit) {
    return logs.take(limit).map(fromLog).toList();
  }
}
