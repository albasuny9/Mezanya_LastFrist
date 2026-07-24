import 'dart:convert';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/domain/services/migration_service.dart';
import '../../../logs/domain/entities/log_entry_entity.dart';
import '../entities/recovery_entry.dart';
import 'recovery_history_adapter.dart';

/// نتيجة حساب عملية تراجع (undo) — بدون أي أثر جانبي، جاهزة يستخدمها
/// الـ caller (الـ Cubit) عشان يحفظها/يعرضها زي ما يشوف.
class RecoveryComputationResult {
  const RecoveryComputationResult({
    required this.restoredState,
    required this.entryAfterToggle,
  });

  /// الحالة الكاملة الناتجة عن تطبيق التراجع.
  final AppStateEntity restoredState;

  /// نسخة [RecoveryEntry] بعد قلب `isReverted` — الـ caller مسؤول عن دمجها
  /// جوه قائمة الـ logs الفعلية وحفظها.
  final RecoveryEntry entryAfterToggle;
}

/// خدمة دومين خالصة (pure domain service) — بلا حالة، بلا اعتماد على
/// AppCubit/Repository/SharedPreferences، بلا أي أثر جانبي. كل الدوال هنا
/// تاخد بيانات وترجع بيانات بس.
///
/// ═══════════════════════════════════════════════════════════════════════
/// Phase 2 من خطة إعادة تصميم Audit Log.
///
/// المسؤوليات:
///   - expose: عرض [RecoveryEntry] (عبر [RecoveryHistoryAdapter]).
///   - filtering: فلترة حسب النوع/الكيان/الفترة الزمنية/قابلية التراجع.
///   - lookup: البحث عن عنصر بعينه أو آخر عنصر لكيان معيّن.
///   - undo: حساب نقي (pure) لنتيجة عملية التراجع — بدون تنفيذها فعليًا.
///
/// ═══════════════════════════════════════════════════════════════════════
/// مهم: الخدمة دي **لسه مش مربوطة بأي كود إنتاج**. `toggleLogRevert` في
/// `app_cubit_notifications.dart` لسه هي المسؤولة فعليًا عن تنفيذ التراجع
/// (بما فيه الحفظ والـ emit) — زي ما هي بالحرف، من غير أي تغيير. دالة
/// [computeRevert] هنا بتحسب **نفس نتيجة** المنطق الموجود في
/// `toggleLogRevert`/`AppCubitBase._restoreFromCore` بشكل نقي ومستقل،
/// استعدادًا لـ Phase 3 لما ننقل `toggleLogRevert` فعليًا لاستخدامها بدل
/// تكرار نفس المنطق جوه الـ Cubit.
/// ═══════════════════════════════════════════════════════════════════════
class RecoveryHistoryService {
  const RecoveryHistoryService._();

  // ── Expose ─────────────────────────────────────────────────────────────

  static List<RecoveryEntry> all(List<LogEntryEntity> logs) =>
      RecoveryHistoryAdapter.fromLogs(logs);

  // ── Lookup ─────────────────────────────────────────────────────────────

  static RecoveryEntry? byId(List<LogEntryEntity> logs, String recoveryId) {
    for (final log in logs) {
      if ('recovery-${log.id}' == recoveryId) {
        return RecoveryHistoryAdapter.fromLog(log);
      }
    }
    return null;
  }

  static RecoveryEntry? bySourceLogId(
    List<LogEntryEntity> logs,
    String sourceLogId,
  ) {
    for (final log in logs) {
      if (log.id == sourceLogId) return RecoveryHistoryAdapter.fromLog(log);
    }
    return null;
  }

  static RecoveryEntry? latestForEntity(
    List<LogEntryEntity> logs,
    String entityId,
  ) =>
      RecoveryHistoryAdapter.latestForEntity(logs, entityId);

  // ── Filtering ──────────────────────────────────────────────────────────

  static List<RecoveryEntry> filterByEntityType(
    List<LogEntryEntity> logs,
    Set<String> entityTypes,
  ) {
    if (entityTypes.isEmpty) return all(logs);
    return logs
        .where((log) => entityTypes.contains(log.entityType))
        .map(RecoveryHistoryAdapter.fromLog)
        .toList();
  }

  static List<RecoveryEntry> filterByAction(
    List<LogEntryEntity> logs,
    String action,
  ) =>
      logs
          .where((log) => log.action == action)
          .map(RecoveryHistoryAdapter.fromLog)
          .toList();

  static List<RecoveryEntry> filterByDateRange(
    List<LogEntryEntity> logs,
    DateTime start,
    DateTime end,
  ) =>
      logs
          .where((log) =>
              !log.timestamp.isBefore(start) && !log.timestamp.isAfter(end))
          .map(RecoveryHistoryAdapter.fromLog)
          .toList();

  /// العناصر القابلة للتراجع فعليًا دلوقتي (مش متراجَع عنها بالفعل).
  static List<RecoveryEntry> revertible(List<LogEntryEntity> logs) => logs
      .where((log) => !log.isReverted)
      .map(RecoveryHistoryAdapter.fromLog)
      .toList();

  // ── Undo (حساب نقي، بدون أي أثر جانبي) ────────────────────────────────

  /// يحسب نتيجة قلب حالة التراجع لعنصر معيّن — **بدون** حفظ أو emit أو أي
  /// تعديل فعلي على أي حالة. مطابق دلاليًا لمنطق `toggleLogRevert` الحالي
  /// (`app_cubit_notifications.dart`)، بس كدالة نقية قابلة للاختبار
  /// بمعزل عن الـ Cubit.
  ///
  /// [currentState] لازم تكون الحالة الحالية الكاملة (المطلوبة لأن عملية
  /// الاسترجاع بتحتاج تطبيّق [MigrationService.normalizeMoneyLocationState]
  /// على النتيجة، زي ما بتعمل `_restoreFromCore` بالظبط).
  static RecoveryComputationResult? computeRevert(
    AppStateEntity currentState,
    List<LogEntryEntity> logs,
    String sourceLogId,
  ) {
    final matches = logs.where((log) => log.id == sourceLogId).toList();
    if (matches.isEmpty) return null;
    final log = matches.first;

    final targetJson = log.isReverted ? log.afterState : log.beforeState;
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(targetJson) as Map<String, dynamic>;
    } catch (_) {
      return null; // لقطة معطوبة — لا نحاول التراجع بدلًا من الانهيار
    }

    final restored = MigrationService.normalizeMoneyLocationState(
      AppStateEntity.fromMap(map).copyWith(logs: currentState.logs),
    );

    final toggled = log.copyWith(
      isReverted: !log.isReverted,
      revertedAt: log.isReverted ? null : DateTime.now(),
    );

    return RecoveryComputationResult(
      restoredState: restored,
      entryAfterToggle: RecoveryHistoryAdapter.fromLog(toggled),
    );
  }
}
