import '../../../../core/constants/transaction_types.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class BudgetTransactionFilter {
  const BudgetTransactionFilter();

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
}
