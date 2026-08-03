// budget_cycle_service.dart
//
// Purpose: Pure domain logic for resolving budget cycles and computing
// income-source pending/due metadata.
//
// Responsibility:
//   - Resolve the correct BudgetSetupEntity snapshot for a given billing
//     cycle (current, or historical via Monthly Budget Snapshots).
//   - Compute the due date for an income source within a specific month.
//   - Find the linked recurring transaction for a given income source.
//   - Determine whether an income source has a pending or early reminder.
//   - Aggregate pending income status across all income sources.
//
// Dependencies: AppStateEntity, BudgetSetupEntity, IncomeSourceEntity,
//   RecurringTransactionEntity, TransactionEntity, TransactionType,
//   BudgetScope, DateFormat.
//
// Domain Bible compliance (`11 - Financial Ledger.md`): this service must
// never read the Audit Log / Recovery History / Activity Log as a data
// source for Budget History. Historical BudgetSetupEntity resolution
// depends exclusively on Monthly Budget Snapshots, falling back to Current
// State when no snapshot exists — never on `AppStateEntity.logs`.
//
// Why this file exists: These calculations were embedded inside
// budget_tracking_screen.dart as private methods. They are pure domain
// calculations with no Widget or BuildContext dependency and belong in a
// dedicated service.
//
// Must never: Build widgets, call BuildContext, perform navigation, show
// dialogs, access Firestore directly, modify state, or mutate any entity.

import 'package:intl/intl.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';
import '../entities/budget_setup_entity.dart';

class BudgetCycleService {
  const BudgetCycleService._();

  // ── Cycle resolution ─────────────────────────────────────────────────────

  /// Resolves the correct [BudgetSetupEntity] for the billing cycle that spans
  /// [cycleStart]..[cycleEnd].
  ///
  /// Resolution order:
  ///   1. If [isCurrentCycle] is true, returns [state.budgetSetup] directly
  ///      so the user always sees the latest configuration.
  ///   2. Tries the cycle-keyed monthly snapshot.
  ///   3. Falls back to the old year-month keyed snapshot for backward
  ///      compatibility.
  ///   4. If no snapshot exists for that cycle, returns [state.budgetSetup]
  ///      (the current, best-known configuration).
  ///
  /// Per the Domain Bible (`11 - Financial Ledger.md`, §2a/§3): Read Models
  /// — and Monthly Budget Snapshots are exactly that — must be derived only
  /// from the authoritative source (Current State / the snapshot pipeline
  /// itself), never from Recovery History or the Activity Log. This method
  /// previously fell back to scanning `state.logs` (Audit Log) and
  /// reconstructing a full historical AppState from a log's `afterState`
  /// snapshot to extract `budgetSetup` — that was an architectural leak
  /// coupling Budget History to Recovery/Activity data it must never depend
  /// on, and it made this lookup cost grow linearly with total log count.
  ///
  /// Why a snapshot can legitimately be missing for a past cycle: snapshots
  /// are written only at two points (`AppCubitBase.initialize()` on app
  /// launch, and `updateBudgetSetup()` on edit), both only for whichever
  /// month is current *at that moment*. A month that was never "current"
  /// during any app session (the app wasn't opened at all that month, and
  /// the budget wasn't edited that month) never gets a snapshot recorded —
  /// there is no way to reconstruct what the configuration truly was for a
  /// month that was never observed live, without fabricating history. In
  /// that situation, falling back to the current configuration is the
  /// domain-correct behavior (it is honest about not having historical
  /// data), not a workaround.
  ///
  /// Extracted from `_budgetForMonth` in `budget_tracking_screen.dart`.
  static BudgetSetupEntity budgetForMonth(
    AppStateEntity state,
    DateTime cycleStart,
    DateTime cycleEnd,
    bool isCurrentCycle,
  ) {
    final budget = state.budgetSetup;

    // الدورة الحالية: دايمًا نستخدم budgetSetup الحالي لضمان ظهور آخر التحديثات
    if (isCurrentCycle) return state.budgetSetup;

    final cycleKey = budget.cycleKeyFor(cycleStart);

    // جرب الـ snapshot الجديد بمفتاح الدورة
    final cycleSnapshot = state.monthlyBudgetSnapshots[cycleKey];
    if (cycleSnapshot != null && cycleSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(cycleSnapshot);
    }

    // fallback: مفتاح الشهر القديم للتوافق مع البيانات السابقة
    final oldKey =
        '${cycleStart.year}-${cycleStart.month.toString().padLeft(2, '0')}';
    final oldSnapshot = state.monthlyBudgetSnapshots[oldKey];
    if (oldSnapshot != null && oldSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(oldSnapshot);
    }

    // لا يوجد snapshot لهذه الدورة — نرجع للإعداد الحالي (Current State) بدل
    // محاولة إعادة بناء تاريخ من الـ Audit Log. هذا يتوافق مع Domain Bible
    // الفصل 11: Read Models لا تعتمد أبدًا على Recovery History/Activity Log.
    return state.budgetSetup;
  }

  // ── Income due-date calculation ──────────────────────────────────────────

  /// Returns the concrete due date for [source] in [month], clamping to the
  /// last day of the month when necessary.
  ///
  /// Extracted from `_incomeDueDateForMonth` in `budget_tracking_screen.dart`.
  static DateTime incomeDueDateForMonth(
    IncomeSourceEntity source,
    DateTime month,
  ) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = source.date.clamp(1, lastDay);
    return DateTime(month.year, month.month, day);
  }

  // ── Income source recurring linkage ──────────────────────────────────────

  /// Returns the [RecurringTransactionEntity] linked to [source], or `null`
  /// if none is found.
  ///
  /// Extracted from `_linkedRecurringIncome` in `budget_tracking_screen.dart`.
  static RecurringTransactionEntity? linkedRecurringIncome(
    AppStateEntity state,
    IncomeSourceEntity source,
  ) {
    final linked = state.recurringTransactions.where(
      (item) =>
          item.type == TransactionType.income.value &&
          item.budgetScope == BudgetScope.withinBudget.value &&
          (item.incomeSourceId == source.id ||
              ((item.incomeSourceId ?? '').isEmpty &&
                  item.name == source.name &&
                  item.walletId == source.targetWalletId)),
    );
    if (linked.isEmpty) {
      return null;
    }
    return linked.first;
  }

  // ── Income pending meta ───────────────────────────────────────────────────

  /// Returns a metadata map describing whether [source] has a pending or early
  /// income reminder for the current cycle, or `null` when no prompt applies.
  ///
  /// Keys: `pending` (bool), `snoozed` (bool), `canEarly` (bool),
  /// `isDueOrLate` (bool), `status` (String), `dateLabel` (String),
  /// `timeLabel` (String?).
  ///
  /// [isCurrentCycle] must be `true` for a prompt to ever be returned; pass
  /// `_isCurrentMonthView()` from the screen.
  /// [month] is the cycle month used to compute the due date.
  ///
  /// Extracted from `_incomePendingMeta` in `budget_tracking_screen.dart`.
  static Map<String, dynamic>? incomePendingMeta(
    AppStateEntity state,
    IncomeSourceEntity source,
    List<TransactionEntity> sourceTx,
    bool isCurrentCycle,
    DateTime month,
  ) {
    if (source.isVariable || sourceTx.isNotEmpty || !isCurrentCycle) {
      return null;
    }
    final recurring = linkedRecurringIncome(state, source);
    final now = DateTime.now();
    final dueDate = recurring == null
        ? incomeDueDateForMonth(source, month)
        : RecurringScheduleEngine.dueOccurrenceNow(recurring, now) ??
            incomeDueDateForMonth(source, month);
    final reminderLeadDays = (recurring?.reminderLeadDays ?? 0).clamp(0, 3);
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = dueDate.subtract(Duration(days: reminderLeadDays));
    final canEarly = reminderLeadDays > 0 &&
        !today.isBefore(reminderDate) &&
        today.isBefore(dueDate);
    final isDueOrLate = !today.isBefore(dueDate);
    if (!canEarly && !isDueOrLate) return null;

    // ── snooze check ──────────────────────────────────────────────────────
    final recurringSnoozedUntil =
        recurring?.snoozedUntil == null || recurring!.snoozedUntil!.isEmpty
            ? null
            : DateTime.tryParse(recurring.snoozedUntil!);
    final snoozedUntil = recurringSnoozedUntil ?? source.snoozedUntilDate;
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
      final until = snoozedUntil;
      return <String, dynamic>{
        'pending': false,
        'snoozed': true,
        'canEarly': false,
        'isDueOrLate': isDueOrLate,
        'status': 'مؤجل حتى ${DateFormat('d/M - HH:mm', 'ar').format(until)}',
        'dateLabel': '${dueDate.day}/${dueDate.month}',
        'timeLabel': null,
      };
    }

    final dateLabel = '${dueDate.day}/${dueDate.month}';
    final timeLabel = recurring?.scheduledTime?.isNotEmpty == true
        ? recurring!.scheduledTime!
        : null;
    final status = isDueOrLate
        ? 'مستحق الآن • $dateLabel${timeLabel == null ? '' : ' • $timeLabel'}'
        : 'بكر • $dateLabel${timeLabel == null ? '' : ' • $timeLabel'}';
    return <String, dynamic>{
      'pending': true,
      'snoozed': false,
      'canEarly': canEarly,
      'isDueOrLate': isDueOrLate,
      'status': status,
      'dateLabel': dateLabel,
      'timeLabel': timeLabel,
    };
  }

  // ── Aggregate pending check ───────────────────────────────────────────────

  /// Returns `true` if any income source in [budget] has a pending reminder
  /// in the current cycle.
  ///
  /// [isCurrentCycle] and [month] are forwarded to [incomePendingMeta].
  ///
  /// Extracted from `_hasPendingIncome` in `budget_tracking_screen.dart`.
  static bool hasPendingIncome(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> incomeTx,
    bool isCurrentCycle,
    DateTime month,
  ) {
    for (final source in budget.incomeSources) {
      final sourceTx =
          incomeTx.where((t) => t.incomeSourceId == source.id).toList();
      final pendingMeta =
          incomePendingMeta(state, source, sourceTx, isCurrentCycle, month);
      if (pendingMeta?['pending'] == true) {
        return true;
      }
    }
    return false;
  }
}
