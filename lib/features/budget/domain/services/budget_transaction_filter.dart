// budget_transaction_filter.dart
//
// Purpose: Pure filtering and sorting helpers for budget-feature transaction
// lists. Contains no business calculations, no side effects, and no UI.
//
// Responsibility:
//   - Filter transactions by type (income / expense).
//   - Filter transactions to a specific billing cycle date range.
//   - Classify individual transactions (e.g. jar-reserve exclusion).
//   - Sort transaction lists for display.
//
// Dependencies: TransactionEntity, TransactionType, TransferType.
//
// Why this file exists: Centralises transaction-list filtering so that screens
// and other services can rely on one consistent implementation rather than
// duplicating filter predicates inline.
//
// Must never: Perform balance calculations, write to Firestore, access Cubits,
// call BuildContext, or contain UI code.

import '../../../../core/constants/transaction_types.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class BudgetTransactionFilter {
  const BudgetTransactionFilter();

  // ── Type filters (instance methods — kept for backwards compatibility) ──────

  List<TransactionEntity> incomeTransactions(
    List<TransactionEntity> transactions,
  ) {
    return transactions
        .where(
          (t) =>
              t.type == TransactionType.income.value &&
              t.transferType != TransferType.depositWithJarLabel.value,
        )
        .toList();
  }

  List<TransactionEntity> expenseTransactions(
    List<TransactionEntity> transactions,
  ) {
    return transactions
        .where(
          (t) => t.type == TransactionType.expense.value,
        )
        .toList();
  }

  // ── Cycle-scoped filtering (static) ──────────────────────────────────────

  /// Returns `true` if [t] is a jar-allocation reserve transfer that should be
  /// excluded from budget cycle summaries.
  ///
  /// Extracted from `_isJarReserveTx` in `budget_tracking_screen.dart`.
  static bool isJarReserveTx(TransactionEntity t) {
    return t.transferType == TransferType.allocationToJar.value;
  }

  /// Returns all transactions that fall within [cycleStart]..[cycleEnd]
  /// (inclusive on both ends), excluding jar-reserve transfers, sorted
  /// newest-first.
  ///
  /// Extracted from `_monthTransactions` in `budget_tracking_screen.dart`.
  static List<TransactionEntity> forCycle(
    List<TransactionEntity> tx,
    DateTime cycleStart,
    DateTime cycleEnd,
  ) {
    return tx
        .where((t) =>
            !t.createdAt.isBefore(cycleStart) &&
            !t.createdAt.isAfter(cycleEnd) &&
            !isJarReserveTx(t))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Returns a copy of [sourceIncomeTx] sorted newest-first.
  ///
  /// Extracted from `_monthTransactionsForIncomeSource` in
  /// `budget_tracking_screen.dart`.
  static List<TransactionEntity> sortedForIncomeSource(
    List<TransactionEntity> sourceIncomeTx,
  ) {
    final copy = [...sourceIncomeTx];
    copy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return copy;
  }
}
