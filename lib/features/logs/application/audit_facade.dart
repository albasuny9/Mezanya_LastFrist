import '../../activity/domain/entities/activity_event.dart';
import '../../activity/domain/services/activity_log_service.dart';
import '../../app_state/domain/entities/app_state_entity.dart';
import '../../recovery/domain/entities/recovery_entry.dart';
import '../../recovery/domain/services/recovery_history_service.dart';
import '../domain/entities/log_entry_entity.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Phase 3 من خطة إعادة تصميم Audit Log — طبقة التطبيق (Application Layer).
///
/// [AuditFacade] هي **نقطة الدخول الوحيدة** المفروض تتعامل معاها أي شاشة/
/// widget جديد يحتاج أي حاجة متعلقة بالـ log (تايم لاين نشاط، سجل تراجع،
/// بحث، فلترة، أهلية التراجع). ولا شاشة جديدة يفترض تستدعي
/// `RecoveryHistoryService`/`ActivityLogService` مباشرة — الفاصاد ده هو
/// اللي بيعرف إزاي ينسّق بينهم.
///
/// ليه الطبقة دي ضرورية قبل أي نقل UI:
///   1. **عزل نقطة التغيير**: لما نيجي ننقل `LogsScreen`/الإشعارات فعليًا
///      (المراحل الجاية)، هيبقى فيه مكان واحد بس (الفاصاد) نغيّر فيه إزاي
///      البيانات بتتجمّع/تترتّب — مش عشرات نقاط الاستدعاء المباشرة منتشرة
///      في شاشات مختلفة.
///   2. **منع تسرّب التفاصيل**: الـ UI معرفش أصلًا إن فيه خدمتين منفصلتين
///      (Recovery/Activity) ولا إزاي كل واحدة شغالة داخليًا — بيتعامل مع
///      واجهة واحدة متماسكة، فأي إعادة هيكلة داخلية مستقبلية (زي دمج أو
///      تقسيم الخدمات) ما تكسرش أي شاشة.
///   3. **نقطة قياس/تحقق واحدة**: أي مشكلة أداء أو سلوك مستقبلية في مسار
///      الـ log-related features ممكن تتشخّص من مكان واحد بدل تتبّع كل
///      استدعاء منتشر في الكود.
///
/// ═══════════════════════════════════════════════════════════════════════
/// مهم: الفاصاد ده **مش مستخدَم من أي كود إنتاج لسه**. `LogsScreen`,
/// `NotificationsCenterScreen`, `NotificationsScreen`,
/// `app_cubit_notifications.dart` (toggleLogRevert) — **كلهم زي ما هم
/// بالحرف**، ولسه بيستخدموا `state.logs`/`LogEntryEntity` مباشرة زي
/// النهارده. النقل الفعلي لأي واحد منهم لاستخدام [AuditFacade] هو موضوع
/// مرحلة لاحقة منفصلة (feature by feature)، مش جزء من الـ commit ده.
/// ═══════════════════════════════════════════════════════════════════════
class AuditFacade {
  const AuditFacade._();

  // ── Activity Timeline ────────────────────────────────────────────────

  static List<ActivityEvent> activityTimeline(List<LogEntryEntity> logs) =>
      ActivityLogService.all(logs);

  static List<ActivityEvent> recentActivity(
    List<LogEntryEntity> logs,
    int limit,
  ) =>
      ActivityLogService.recent(logs, limit);

  static List<ActivityEvent> activityForEntity(
    List<LogEntryEntity> logs,
    String entityId,
  ) =>
      ActivityLogService.forEntity(logs, entityId);

  // ── Recovery History ─────────────────────────────────────────────────

  static List<RecoveryEntry> recoveryHistory(List<LogEntryEntity> logs) =>
      RecoveryHistoryService.all(logs);

  static RecoveryEntry? latestRecoveryForEntity(
    List<LogEntryEntity> logs,
    String entityId,
  ) =>
      RecoveryHistoryService.latestForEntity(logs, entityId);

  // ── Lookup ────────────────────────────────────────────────────────────

  static ActivityEvent? findActivityById(
    List<LogEntryEntity> logs,
    String activityId,
  ) =>
      ActivityLogService.byId(logs, activityId);

  static RecoveryEntry? findRecoveryById(
    List<LogEntryEntity> logs,
    String recoveryId,
  ) =>
      RecoveryHistoryService.byId(logs, recoveryId);

  static RecoveryEntry? findRecoveryBySourceLogId(
    List<LogEntryEntity> logs,
    String sourceLogId,
  ) =>
      RecoveryHistoryService.bySourceLogId(logs, sourceLogId);

  // ── Filtering ─────────────────────────────────────────────────────────

  static List<ActivityEvent> filterActivityByEntityType(
    List<LogEntryEntity> logs,
    Set<String> entityTypes,
  ) =>
      ActivityLogService.filterByEntityType(logs, entityTypes);

  static List<ActivityEvent> filterActivityByAction(
    List<LogEntryEntity> logs,
    String action,
  ) =>
      ActivityLogService.filterByAction(logs, action);

  static List<ActivityEvent> filterActivityByDateRange(
    List<LogEntryEntity> logs,
    DateTime start,
    DateTime end,
  ) =>
      ActivityLogService.filterByDateRange(logs, start, end);

  static List<RecoveryEntry> filterRecoveryByEntityType(
    List<LogEntryEntity> logs,
    Set<String> entityTypes,
  ) =>
      RecoveryHistoryService.filterByEntityType(logs, entityTypes);

  // ── Search ────────────────────────────────────────────────────────────

  static List<ActivityEvent> searchActivity(
    List<LogEntryEntity> logs,
    String query,
  ) =>
      ActivityLogService.search(logs, query);

  // ── Undo eligibility ──────────────────────────────────────────────────

  /// هل عنصر recovery معيّن ممكن يتعمله تراجع دلوقتي؟
  static bool isUndoEligible(RecoveryEntry entry) => entry.canRevert;

  /// نفس السؤال، لكن بدءًا من معرّف الـ log الأصلي مباشرة — مفيدة لأي شاشة
  /// عندها بس الـ id ومحتاجة تقرر تفعّل زرار "تراجع" ولا لأ.
  static bool isUndoEligibleForLog(
    List<LogEntryEntity> logs,
    String sourceLogId,
  ) =>
      RecoveryHistoryService.bySourceLogId(logs, sourceLogId)?.canRevert ??
      false;

  /// حساب نقي (بدون أي أثر جانبي) لنتيجة عملية تراجع — تمريرة مباشرة لـ
  /// [RecoveryHistoryService.computeRevert]. موجودة هنا عشان أي كود جديد
  /// في المستقبل يقدر يحسب نتيجة التراجع من غير ما يعرف أصلًا إن
  /// [RecoveryHistoryService] موجودة كخدمة منفصلة.
  static RecoveryComputationResult? computeUndo(
    AppStateEntity currentState,
    List<LogEntryEntity> logs,
    String sourceLogId,
  ) =>
      RecoveryHistoryService.computeRevert(currentState, logs, sourceLogId);
}
