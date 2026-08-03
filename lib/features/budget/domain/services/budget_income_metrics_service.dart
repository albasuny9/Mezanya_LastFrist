// budget_income_metrics_service.dart
//
// Purpose: Pure calculations for income-source pool sizes, attributed spend,
// and remaining-progress ratios used in the budget tracking UI.
//
// Responsibility:
//   - Compute the "display pool" (effective income pool) for an income source.
//   - Compute the total spend attributed to an income source across
//     allocations and debts within a billing cycle.
//   - Compute the remaining-progress ratio (0.0–1.0) for an income source.
//
// Dependencies: BudgetSetupEntity, IncomeSourceEntity, TransactionEntity,
//   TransactionType.
//
// Why this file exists: These three calculations were duplicated across
// _incomeInlineCards and _openIncomeDetailsSheet inside
// budget_tracking_screen.dart. Centralising them removes duplication and
// ensures every caller uses the same financial logic.
//
// Must never: Build widgets, call BuildContext, perform navigation, access
// Firestore, or mutate any entity.

import '../../../../core/constants/transaction_types.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../entities/budget_setup_entity.dart';

class BudgetIncomeMetricsService {
  const BudgetIncomeMetricsService._();

  /// Returns the effective income pool for [source].
  ///
  /// Variable sources have no fixed pool, so 0 is returned.
  /// For fixed sources the pool is the amount actually collected this cycle.
  ///
  /// Extracted from `_incomeDisplayPool` in `budget_tracking_screen.dart`.
  static double incomeDisplayPool(
    IncomeSourceEntity source,
    double received,
  ) {
    if (source.isVariable) return 0;
    return received;
  }

  /// Returns the total amount spent this cycle that is attributed to
  /// [incomeSourceId], across both allocation-funded expenses and debt
  /// payments that are linked to this income source.
  ///
  /// Each allocation expense is weighted by the funding share that comes
  /// from [incomeSourceId]. Debt payments are counted at full face value if
  /// [debt.fundingSource] matches. Transactions are de-duplicated by id so
  /// they are never double-counted.
  ///
  /// Extracted from `_spentAttributedToIncomeSource` in
  /// `budget_tracking_screen.dart`.
  static double spentAttributedToIncomeSource(
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
    String incomeSourceId,
  ) {
    final counted = <String>{};
    var total = 0.0;

    for (final alloc in budget.allocations) {
      final fromThis = alloc.funding
          .where((f) => f.incomeSourceId == incomeSourceId)
          .fold<double>(0, (s, f) => s + f.plannedAmount);
      if (fromThis <= 0) continue;
      final plannedTotal =
          alloc.funding.fold<double>(0, (s, f) => s + f.plannedAmount);
      if (plannedTotal <= 0) continue;
      final share = fromThis / plannedTotal;
      for (final t in monthTx.where((x) =>
          x.type == TransactionType.expense.value &&
          x.allocationId == alloc.id)) {
        counted.add(t.id);
        total += t.amount * share;
      }
    }

    for (final debt in budget.debts) {
      if (debt.fundingSource != incomeSourceId) continue;
      for (final t in monthTx.where((x) =>
          x.type == TransactionType.expense.value &&
          x.notes?.contains(debt.name) == true)) {
        if (!counted.contains(t.id)) {
          counted.add(t.id);
          total += t.amount;
        }
      }
    }

    return total;
  }

  /// Returns the remaining-progress ratio (0.0–1.0) for [source], or `null`
  /// when no meaningful ratio exists (variable source or zero pool).
  ///
  /// Extracted from `_incomeRemainingProgress` in
  /// `budget_tracking_screen.dart`.
  static double? incomeRemainingProgress(
    IncomeSourceEntity source,
    double received,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) {
    if (source.isVariable) return null;
    final pool = incomeDisplayPool(source, received);
    if (pool <= 0) return null;
    final spent = spentAttributedToIncomeSource(budget, monthTx, source.id);
    final ratio = ((pool - spent) / pool).clamp(0.0, 1.0);
    return ratio;
  }
}
