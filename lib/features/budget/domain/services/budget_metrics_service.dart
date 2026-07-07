import 'package:flutter/foundation.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';

class BudgetMetrics {
  // Actual
  final double actualIncome;
  final double actualExpense;

  // Planned
  final double plannedIncome;

  // Jar
  final double virtualJarReserved;
  final double physicalJarFunding;

  // Result
  final double remainingIncome;

  const BudgetMetrics({
    required this.actualIncome,
    required this.actualExpense,
    required this.plannedIncome,
    required this.virtualJarReserved,
    required this.physicalJarFunding,
    required this.remainingIncome,
  });
}

class BudgetMetricsService {
  /// Computes the actual budget expense for a given list of transactions.
  ///
  /// **Included** (transactions that consume the monthly budget):
  /// - `type=expense` + `budgetScope=within-budget`
  ///   → allocation expenses, debt/installment payments, physical jar funding
  /// - `type=transfer` + `transferType=jar-funding` + `budgetScope=within-budget`
  ///   → virtual jar funding (income-triggered, counts against the budget)
  ///
  /// **Excluded** (must never be counted):
  /// - `type=expense` + `budgetScope=outside-budget`
  ///   → jar purchases / spending from a jar balance (already consumed on funding)
  /// - Any `type=transfer` that is NOT `jar-funding` + `within-budget`
  ///   → wallet-to-wallet, internal-transfer, jar-allocation-reserve, etc.
  ///
  /// This ensures jar spending is never double-counted: the budget is debited
  /// when income funds the jar, not again when the user spends from the jar.
  static double computeActualBudgetExpense(List<TransactionEntity> txList) {
    // TODO(debug): remove before release
    debugPrint('── computeActualBudgetExpense (${txList.length} txns) ───────');
    double total = 0;
    for (final t in txList) {
      final isWithinBudget = t.budgetScope == BudgetScope.withinBudget.value;
      final isExpenseWithinBudget =
          t.type == TransactionType.expense.value && isWithinBudget;
      final isVirtualJarFunding =
          t.type == TransactionType.transfer.value &&
          t.transferType == TransferType.jarFunding.value &&
          isWithinBudget;
      final included = isExpenseWithinBudget || isVirtualJarFunding;
      // TODO(debug): remove before release
      debugPrint(
        '  [${included ? 'INCLUDED' : 'EXCLUDED'}]'
        '  amount=${t.amount}'
        '  type=${t.type}'
        '  budgetScope=${t.budgetScope ?? 'null'}'
        '  transferType=${t.transferType ?? 'null'}',
      );
      if (included) {
        total += t.amount;
      }
    }
    debugPrint('  → total: $total');
    debugPrint('────────────────────────────────────────────────────────────');
    return total;
  }
}
