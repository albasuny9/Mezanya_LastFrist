// budget_cycle_service.dart
//
// Purpose: Pure domain logic for resolving budget cycles and computing
// income-source pending/due metadata.
//
// Responsibility:
//   - Resolve the correct BudgetSetupEntity snapshot for a given billing
//     cycle (current, past via snapshot, or log fallback).
//   - Compute the due date for an income source within a specific month.
//   - Find the linked recurring transaction for a given income source.
//   - Determine whether an income source has a pending or early reminder.
//   - Aggregate pending income status across all income sources.
//
// Dependencies: AppStateEntity, BudgetSetupEntity, IncomeSourceEntity,
//   RecurringTransactionEntity, TransactionEntity, TransactionType,
//   BudgetScope, DateFormat, dart:convert.
//
// Why this file exists: These calculations were embedded inside
// budget_tracking_screen.dart as private methods. They are pure domain
// calculations with no Widget or BuildContext dependency and belong in a
// dedicated service.
//
// Must never: Build widgets, call BuildContext, perform navigation, show
// dialogs, access Firestore directly, modify state, or mutate any entity.

import 'dart:convert';

import 'package:intl/intl.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
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
  ///   4. Walks [state.logs] to find the most recent snapshot before
  ///      [cycleEnd].
  ///   5. If all lookups fail, returns [state.budgetSetup].
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

    for (final log in state.logs) {
      if (log.timestamp.isAfter(cycleEnd)) continue;
      try {
        final map = jsonDecode(log.afterState) as Map<String, dynamic>;
        return AppStateEntity.fromMap(map).budgetSetup;
      } catch (_) {
        continue;
      }
    }
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
    final dueDate = incomeDueDateForMonth(source, month);
    final reminderLeadDays = (recurring?.reminderLeadDays ?? 0).clamp(0, 3);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = dueDate.subtract(Duration(days: reminderLeadDays));
    final canEarly = reminderLeadDays > 0 &&
        !today.isBefore(reminderDate) &&
        today.isBefore(dueDate);
    final isDueOrLate = !today.isBefore(dueDate);
    if (!canEarly && !isDueOrLate) return null;

    // ── snooze check ──────────────────────────────────────────────────────
    if (source.isSnoozed) {
      final until = source.snoozedUntilDate!;
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
