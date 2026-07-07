import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/features/budget/domain/services/budget_metrics_service.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';

void main() {
  group('BudgetMetricsService.computeActualBudgetExpense', () {
    test(
      'counts within-budget expenses and virtual jar funding, '
      'excludes outside-budget jar purchases',
      () {
        final txList = [
          // Allocation expense — within-budget → counted
          TransactionEntity(
            id: 'tx-1',
            amount: 5000,
            type: 'expense',
            budgetScope: 'within-budget',
            createdAt: DateTime(2025, 1, 10),
          ),
          // Virtual jar funding (transfer/jar-funding/within-budget) → counted
          TransactionEntity(
            id: 'tx-2',
            amount: 2000,
            type: 'transfer',
            transferType: 'jar-funding',
            budgetScope: 'within-budget',
            createdAt: DateTime(2025, 1, 10),
          ),
          // Jar purchase (expense/outside-budget) → NOT counted
          TransactionEntity(
            id: 'tx-3',
            amount: 2000,
            type: 'expense',
            budgetScope: 'outside-budget',
            createdAt: DateTime(2025, 1, 15),
          ),
        ];

        final result =
            BudgetMetricsService.computeActualBudgetExpense(txList);

        // Income 10 000, jar funding 2 000, allocation expense 5 000,
        // jar purchase 2 000 → Expenses = 7 000 (not 9 000)
        expect(result, equals(7000.0));
      },
    );

    test('returns 0 for empty list', () {
      expect(BudgetMetricsService.computeActualBudgetExpense([]), equals(0.0));
    });

    test('excludes wallet-to-wallet transfers', () {
      final txList = [
        TransactionEntity(
          id: 'tx-ww',
          amount: 3000,
          type: 'transfer',
          transferType: 'wallet-to-wallet',
          budgetScope: 'within-budget',
          createdAt: DateTime(2025, 1, 10),
        ),
      ];
      expect(
        BudgetMetricsService.computeActualBudgetExpense(txList),
        equals(0.0),
      );
    });

    test('excludes jar-allocation-reserve transfers', () {
      final txList = [
        TransactionEntity(
          id: 'tx-jar-res',
          amount: 1500,
          type: 'transfer',
          transferType: 'jar-allocation',
          budgetScope: 'within-budget',
          createdAt: DateTime(2025, 1, 10),
        ),
      ];
      expect(
        BudgetMetricsService.computeActualBudgetExpense(txList),
        equals(0.0),
      );
    });
  });
}
