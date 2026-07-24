import '../../activity/domain/entities/activity_event.dart';
import '../../activity/domain/services/activity_log_service.dart';
import '../../app_state/domain/entities/app_state_entity.dart';
import '../../recovery/domain/entities/recovery_entry.dart';
import '../../recovery/domain/services/recovery_history_service.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Phase 3 من خطة إعادة تصميم Audit Log — طبقة التطبيق (Application Layer).
///
/// [AuditFacade] هي **نقطة الدخول الوحيدة** المفروض تتعامل معاها أي شاشة/
/// widget يحتاج أي حاجة متعلقة بالـ log (تايم لاين نشاط، سجل تراجع، بحث،
/// فلترة، أهلية التراجع). ولا شاشة يفترض تستدعي
/// `RecoveryHistoryService`/`ActivityLogService` مباشرة — الفاصاد ده هو
/// اللي بيعرف إزاي ينسّق بينهم.
///
/// ملاحظة تصميم (اتضافت وقت Phase 4، أول استخدام حقيقي للفاصاد): كل الدوال
/// هنا بتاخد [AppStateEntity] كاملة بدل `List<LogEntryEntity>` مباشرة —
/// عمدًا. الهدف إن الكود المستهلِك (Notifications مثلًا) **ميحتاجش
/// يعرف أصلًا إن `logs` موجودة جوه `AppStateEntity` كـ حقل منفصل** — هو
/// بيمرّر الـ state اللي عنده أصلًا لأي غرض تاني، والفاصاد هو المسؤول
/// الوحيد عن استخراج واستخدام `state.logs` داخليًا. ده اللي بيخلي
/// "Notifications become completely unaware of LogEntryEntity" ممكنة
/// فعليًا، مش بس على مستوى الـ import.
///
/// ليه الطبقة دي ضرورية قبل أي نقل UI:
///   1. **عزل نقطة التغيير**: أي تعديل مستقبلي في مصدر بيانات الـ
///      recovery/activity (نقل لـ store منفصل، الفصل 5/6 من الخطة) هيحصل
///      جوه الفاصاد بس — المستهلِكين (Notifications, LogsScreen لاحقًا)
///      مش هيحسّوا بيه خالص.
///   2. **منع تسرّب التفاصيل**: الـ UI معرفش أصلًا إن فيه خدمتين منفصلتين
///      (Recovery/Activity) ولا إزاي كل واحدة شغالة داخليًا.
///   3. **نقطة قياس/تحقق واحدة**: أي مشكلة أداء أو سلوك مستقبلية ممكن
///      تتشخّص من مكان واحد.
/// ═══════════════════════════════════════════════════════════════════════
class AuditFacade {
  const AuditFacade._();

  // ── Activity Timeline ────────────────────────────────────────────────

  static List<ActivityEvent> activityTimeline(AppStateEntity state) =>
      ActivityLogService.all(state.logs);

  static List<ActivityEvent> recentActivity(
    AppStateEntity state,
    int limit,
  ) =>
      ActivityLogService.recent(state.logs, limit);

  static List<ActivityEvent> activityForEntity(
    AppStateEntity state,
    String entityId,
  ) =>
      ActivityLogService.forEntity(state.logs, entityId);

  // ── Recovery History ─────────────────────────────────────────────────

  static List<RecoveryEntry> recoveryHistory(AppStateEntity state) =>
      RecoveryHistoryService.all(state.logs);

  static RecoveryEntry? latestRecoveryForEntity(
    AppStateEntity state,
    String entityId,
  ) =>
      RecoveryHistoryService.latestForEntity(state.logs, entityId);

  // ── Lookup ────────────────────────────────────────────────────────────

  static ActivityEvent? findActivityById(
    AppStateEntity state,
    String activityId,
  ) =>
      ActivityLogService.byId(state.logs, activityId);

  static RecoveryEntry? findRecoveryById(
    AppStateEntity state,
    String recoveryId,
  ) =>
      RecoveryHistoryService.byId(state.logs, recoveryId);

  /// هات عنصر الـ Recovery المرتبط بـ log id أصلي معيّن — دي الدالة اللي
  /// أي شاشة إشعارات محتاجاها (`NotificationEntity.relatedLogId` بيخزّن
  /// نفس هذا الـ id).
  static RecoveryEntry? findRecoveryBySourceLogId(
    AppStateEntity state,
    String sourceLogId,
  ) =>
      RecoveryHistoryService.bySourceLogId(state.logs, sourceLogId);

  // ── Filtering ─────────────────────────────────────────────────────────

  static List<ActivityEvent> filterActivityByEntityType(
    AppStateEntity state,
    Set<String> entityTypes,
  ) =>
      ActivityLogService.filterByEntityType(state.logs, entityTypes);

  static List<ActivityEvent> filterActivityByAction(
    AppStateEntity state,
    String action,
  ) =>
      ActivityLogService.filterByAction(state.logs, action);

  static List<ActivityEvent> filterActivityByDateRange(
    AppStateEntity state,
    DateTime start,
    DateTime end,
  ) =>
      ActivityLogService.filterByDateRange(state.logs, start, end);

  static List<RecoveryEntry> filterRecoveryByEntityType(
    AppStateEntity state,
    Set<String> entityTypes,
  ) =>
      RecoveryHistoryService.filterByEntityType(state.logs, entityTypes);

  // ── Search ────────────────────────────────────────────────────────────

  static List<ActivityEvent> searchActivity(
    AppStateEntity state,
    String query,
  ) =>
      ActivityLogService.search(state.logs, query);

  // ── Undo eligibility ──────────────────────────────────────────────────

  /// هل عنصر recovery معيّن ممكن يتعمله تراجع دلوقتي؟
  static bool isUndoEligible(RecoveryEntry entry) => entry.canRevert;

  /// نفس السؤال، لكن بدءًا من معرّف الـ log الأصلي مباشرة — مفيدة لأي شاشة
  /// عندها بس الـ id ومحتاجة تقرر تفعّل زرار "تراجع" ولا لأ.
  static bool isUndoEligibleForLog(
    AppStateEntity state,
    String sourceLogId,
  ) =>
      RecoveryHistoryService.bySourceLogId(state.logs, sourceLogId)
          ?.canRevert ??
      false;

  /// حساب نقي (بدون أي أثر جانبي) لنتيجة عملية تراجع — تمريرة مباشرة لـ
  /// [RecoveryHistoryService.computeRevert]. موجودة هنا عشان أي كود جديد
  /// في المستقبل يقدر يحسب نتيجة التراجع من غير ما يعرف أصلًا إن
  /// [RecoveryHistoryService] موجودة كخدمة منفصلة.
  static RecoveryComputationResult? computeUndo(
    AppStateEntity currentState,
    String sourceLogId,
  ) =>
      RecoveryHistoryService.computeRevert(
        currentState,
        currentState.logs,
        sourceLogId,
      );
}
