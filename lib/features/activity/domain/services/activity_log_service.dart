import '../../../logs/domain/entities/log_entry_entity.dart';
import '../entities/activity_event.dart';
import 'activity_log_adapter.dart';

/// خدمة دومين خالصة، بلا حالة وبلا أثر جانبي — نظيرة [RecoveryHistoryService]
/// لكن لمفهوم Activity Log (الفصل 11 من الـ Domain Bible): عرض/فلترة/بحث
/// في تايم لاين الأحداث الخفيف، **بدون تحميل أي `beforeState`/`afterState`
/// خالص** — وده الفرق الجوهري اللي بيحل مشكلة الأداء الموصوفة في تقرير
/// تدقيق Audit Log السابق (`LogsScreen._detailRowsForLog` كانت بتفك تشفير
/// لقطة كاملة لكل صف ظاهر).
///
/// ═══════════════════════════════════════════════════════════════════════
/// Phase 2 من خطة إعادة تصميم Audit Log.
///
/// المسؤوليات:
///   - expose: عرض [ActivityEvent] (عبر [ActivityLogAdapter]).
///   - filtering: فلترة حسب النوع/الحدث/الفترة الزمنية — بنفس معايير
///     الفلترة الموجودة فعليًا في `LogsScreen._filtered` (النطاق الزمني،
///     التبويب حسب entityType/action، مجموعة الأنواع المختارة)، عشان تكون
///     الخدمة دي جاهزة فعليًا تستبدل منطق الفلترة اليدوي في الشاشة وقت
///     Phase 2 القادمة (نقل LogsScreen نفسها).
///   - lookup: البحث عن حدث بعينه أو أحداث كيان معيّن.
///
/// مفيش "undo" هنا عمدًا — الـ Activity Log مش مصمَّم للتراجع أصلًا حسب
/// تعريف الـ Domain Bible؛ ده المسؤولية الحصرية لـ [RecoveryHistoryService].
///
/// ═══════════════════════════════════════════════════════════════════════
/// مهم: زي [RecoveryHistoryService] بالظبط — الخدمة دي **مش مربوطة بأي
/// كود إنتاج لسه**. `LogsScreen` لسه بتشتغل بمنطقها الحالي (`_filtered`
/// على `LogEntryEntity` مباشرة). نقلها لاستخدام الخدمة دي هو خطوة منفصلة
/// (Phase 2 التالية من الـ roadmap، مش المقصودة بـ"Phase 2" في الرسالة
/// دي اللي كانت عن "إدخال الخدمات" بس).
/// ═══════════════════════════════════════════════════════════════════════
class ActivityLogService {
  const ActivityLogService._();

  // ── Expose ─────────────────────────────────────────────────────────────

  static List<ActivityEvent> all(List<LogEntryEntity> logs) =>
      ActivityLogAdapter.fromLogs(logs);

  static List<ActivityEvent> recent(List<LogEntryEntity> logs, int limit) =>
      ActivityLogAdapter.recent(logs, limit);

  // ── Lookup ─────────────────────────────────────────────────────────────

  static ActivityEvent? byId(List<LogEntryEntity> logs, String activityId) {
    for (final log in logs) {
      if ('activity-${log.id}' == activityId) {
        return ActivityLogAdapter.fromLog(log);
      }
    }
    return null;
  }

  static List<ActivityEvent> forEntity(
    List<LogEntryEntity> logs,
    String entityId,
  ) =>
      logs
          .where((log) => log.entityId == entityId)
          .map(ActivityLogAdapter.fromLog)
          .toList();

  // ── Filtering ──────────────────────────────────────────────────────────

  static List<ActivityEvent> filterByEntityType(
    List<LogEntryEntity> logs,
    Set<String> entityTypes,
  ) {
    if (entityTypes.isEmpty) return all(logs);
    return logs
        .where((log) => entityTypes.contains(log.entityType))
        .map(ActivityLogAdapter.fromLog)
        .toList();
  }

  static List<ActivityEvent> filterByAction(
    List<LogEntryEntity> logs,
    String action,
  ) =>
      logs
          .where((log) => log.action == action)
          .map(ActivityLogAdapter.fromLog)
          .toList();

  static List<ActivityEvent> filterByDateRange(
    List<LogEntryEntity> logs,
    DateTime start,
    DateTime end,
  ) =>
      logs
          .where((log) =>
              !log.timestamp.isBefore(start) && !log.timestamp.isAfter(end))
          .map(ActivityLogAdapter.fromLog)
          .toList();

  /// بحث نصّي بسيط في تفاصيل الحدث — مطابق لاحتياج شاشة السجلات المستقبلي.
  static List<ActivityEvent> search(List<LogEntryEntity> logs, String query) {
    if (query.trim().isEmpty) return all(logs);
    final needle = query.trim().toLowerCase();
    return logs
        .where((log) => log.details.toLowerCase().contains(needle))
        .map(ActivityLogAdapter.fromLog)
        .toList();
  }
}
