import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/debug/financial_integrity/financial_integrity_analyzer.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/transactions/domain/entities/recurring_transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/services/transaction_processor.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';

void main() {
  group('FinancialIntegrityAnalyzer', () {
    test('reports healthy data after replaying root transaction history', () {
      final state = _applyAll(_baseState(), [
        _income(
          id: 'income-1',
          amount: 1000,
          incomeSourceId: _incomeSourceId,
        ),
      ]);

      final report = FinancialIntegrityAnalyzer.analyze(state);

      expect(report.status, FinancialIntegrityStatus.healthy);
      expect(report.violations, isEmpty);
      expect(report.warnings, isEmpty);
      expect(report.walletResults.single.difference, closeTo(0, 0.01));
      expect(report.jarResults.single.difference, closeTo(0, 0.01));
      expect(report.allocationResults.single.difference, closeTo(0, 0.01));
    });

    test('detects broken wallet balances', () {
      final healthy = _applyAll(_baseState(), [_income(amount: 500)]);
      final broken = healthy.copyWith(
        wallets: [
          healthy.wallets.single.copyWith(balance: 999),
        ],
      );

      final report = FinancialIntegrityAnalyzer.analyze(broken);

      expect(report.status, FinancialIntegrityStatus.corrupted);
      expect(report.hasViolation('stored-balance-mismatch'), isTrue);
      expect(report.walletResults.single.difference, isNot(closeTo(0, 0.01)));
    });

    test('detects broken jar balances', () {
      final healthy = _applyAll(_baseState(), [
        _transfer(
          id: 'jar-funding-1',
          fromWalletId: _walletId,
          toWalletId: _jarId,
          amount: 150,
          transferType: TransferType.jarFundingPhysical.value,
        ),
      ]);
      final broken = healthy.copyWith(
        budgetSetup: healthy.budgetSetup.copyWith(
          linkedWallets: [
            healthy.budgetSetup.linkedWallets.single.copyWith(balance: 10),
          ],
        ),
      );

      final report = FinancialIntegrityAnalyzer.analyze(broken);

      expect(report.status, FinancialIntegrityStatus.corrupted);
      expect(report.hasViolation('stored-balance-mismatch'), isTrue);
      expect(report.jarResults.single.difference, isNot(closeTo(0, 0.01)));
    });

    test('detects broken allocation balances', () {
      final healthy = _applyAll(_baseState(), [
        _income(
          id: 'income-allocation-1',
          amount: 1000,
          incomeSourceId: _incomeSourceId,
        ),
      ]);
      final broken = healthy.copyWith(
        budgetSetup: healthy.budgetSetup.copyWith(
          allocations: [
            healthy.budgetSetup.allocations.single.copyWith(balance: 12),
          ],
        ),
      );

      final report = FinancialIntegrityAnalyzer.analyze(broken);

      expect(report.status, FinancialIntegrityStatus.corrupted);
      expect(report.hasViolation('stored-balance-mismatch'), isTrue);
      expect(
        report.allocationResults.single.difference,
        isNot(closeTo(0, 0.01)),
      );
    });

    test('detects orphan subtransactions and missing parents', () {
      final orphan = _transfer(
        id: 'child-1',
        parentId: 'missing-parent',
        fromWalletId: _walletId,
        toWalletId: _jarId,
        amount: 50,
        transferType: TransferType.jarFunding.value,
      );
      final state = _baseState().copyWith(transactions: [orphan]);

      final report = FinancialIntegrityAnalyzer.analyze(state);

      expect(report.hasViolation('missing-parent'), isTrue);
      expect(report.hasViolation('orphan-subtransaction'), isTrue);
      expect(
        report.firstDivergence.transactionId,
        orphan.id,
      );
    });

    test('detects duplicate transaction ids', () {
      final tx = _income(id: 'dup-1', amount: 200);
      final state = _baseState().copyWith(
        transactions: [
          tx,
          _income(id: 'dup-1', amount: 300),
        ],
      );

      final report = FinancialIntegrityAnalyzer.analyze(state);

      expect(report.status, FinancialIntegrityStatus.corrupted);
      expect(report.hasViolation('duplicate-transaction-id'), isTrue);
    });

    test('detects deleted entity references', () {
      final state = _baseState().copyWith(
        transactions: [
          _income(id: 'missing-wallet-1', walletId: 'deleted-wallet'),
        ],
      );

      final report = FinancialIntegrityAnalyzer.analyze(state);

      expect(report.status, FinancialIntegrityStatus.corrupted);
      expect(report.hasViolation('missing-wallet-reference'), isTrue);
    });

    test('checks recurring transaction references without mutating state', () {
      final state = _baseState().copyWith(
        recurringTransactions: [
          _recurring(id: 'recurring-ok'),
          _recurring(id: 'recurring-broken', walletId: 'deleted-wallet'),
        ],
      );

      final report = FinancialIntegrityAnalyzer.analyze(state);

      expect(report.hasViolation('recurring-missing-wallet-reference'), isTrue);
      expect(state.recurringTransactions.length, 2);
      expect(state.transactions, isEmpty);
    });

    test('replays wallet-to-wallet transfer chains', () {
      final state = _applyAll(_twoWalletState(), [
        _income(id: 'income-1', walletId: _walletId, amount: 1000),
        _transfer(
          id: 'transfer-1',
          fromWalletId: _walletId,
          toWalletId: _wallet2Id,
          amount: 300,
          transferType: TransferType.walletToWallet.value,
        ),
        _transfer(
          id: 'transfer-2',
          fromWalletId: _wallet2Id,
          toWalletId: _walletId,
          amount: 75,
          transferType: TransferType.walletToWallet.value,
        ),
      ]);

      final report = FinancialIntegrityAnalyzer.analyze(state);

      expect(report.status, FinancialIntegrityStatus.healthy);
      expect(
        report.walletResults
            .firstWhere((result) => result.id == _walletId)
            .storedBalance,
        775,
      );
      expect(
        report.walletResults
            .firstWhere((result) => result.id == _wallet2Id)
            .storedBalance,
        225,
      );
    });

    test('accepts jar balance adjustment as replayable financial operation',
        () {
      final state = _applyAll(_baseState(), [
        _jarAdjustment(
          id: 'adjust-up',
          amount: 160,
          transferType: TransferType.jarBalanceAdjustmentIncrease.value,
        ),
        _jarAdjustment(
          id: 'adjust-down',
          amount: 40,
          transferType: TransferType.jarBalanceAdjustmentDecrease.value,
        ),
      ]);

      final report = FinancialIntegrityAnalyzer.analyze(state);

      expect(report.status, FinancialIntegrityStatus.healthy);
      expect(report.violations, isEmpty);
      expect(report.jarResults.single.storedBalance, 120);
      expect(report.walletResults.single.storedBalance, 0);
      expect(report.allocationResults.single.storedBalance, 0);
    });

    test('detects corrupted jar balance after valid adjustment replay', () {
      final healthy = _applyAll(_baseState(), [
        _jarAdjustment(
          id: 'adjust-up',
          amount: 160,
          transferType: TransferType.jarBalanceAdjustmentIncrease.value,
        ),
      ]);
      final broken = healthy.copyWith(
        budgetSetup: healthy.budgetSetup.copyWith(
          linkedWallets: [
            healthy.budgetSetup.linkedWallets.single.copyWith(balance: 999),
          ],
        ),
      );

      final report = FinancialIntegrityAnalyzer.analyze(broken);

      expect(report.status, FinancialIntegrityStatus.corrupted);
      expect(report.hasViolation('stored-balance-mismatch'), isTrue);
      expect(report.jarResults.single.expectedBalance, 160);
    });
  });
}

const _walletId = 'wallet-1';
const _wallet2Id = 'wallet-2';
const _jarId = 'jar-1';
const _allocationId = 'allocation-1';
const _incomeSourceId = 'income-source-1';

AppStateEntity _baseState() {
  return AppStateEntity.initial().copyWith(
    wallets: const [
      WalletEntity(id: _walletId, name: 'Cash', balance: 0),
    ],
    budgetSetup: AppStateEntity.initial().budgetSetup.copyWith(
      incomeSources: const [
        IncomeSourceEntity(
          id: _incomeSourceId,
          name: 'Salary',
          amount: 1000,
          date: 1,
          type: 'auto',
          targetWalletId: _walletId,
        ),
      ],
      linkedWallets: const [
        LinkedWalletEntity(
          id: _jarId,
          name: 'Emergency',
          monthlyAmount: 0,
          executionDay: 1,
          fundingSource: _incomeSourceId,
          funding: [
            LinkedWalletEntityFunding(
              id: 'jar-funding-rule-1',
              incomeSourceId: _incomeSourceId,
              plannedAmount: 200,
            ),
          ],
          icon: 'savings',
          iconColor: '#165B47',
          automationType: 'auto',
          categories: [],
        ),
      ],
      allocations: const [
        AllocationEntity(
          id: _allocationId,
          name: 'Food',
          icon: 'restaurant',
          iconColor: '#1D4ED8',
          rolloverBehavior: 'keep',
          automationType: 'auto',
          funding: [
            AllocationFundingEntity(
              id: 'allocation-funding-rule-1',
              incomeSourceId: _incomeSourceId,
              plannedAmount: 300,
            ),
          ],
          categories: [],
        ),
      ],
    ),
  );
}

AppStateEntity _twoWalletState() {
  return _baseState().copyWith(
    wallets: const [
      WalletEntity(id: _walletId, name: 'Cash', balance: 0),
      WalletEntity(id: _wallet2Id, name: 'Bank', balance: 0),
    ],
    budgetSetup: _baseState().budgetSetup.copyWith(
      linkedWallets: const [],
      allocations: const [],
      incomeSources: const [],
    ),
  );
}

AppStateEntity _applyAll(
  AppStateEntity state,
  List<TransactionEntity> transactions,
) {
  var current = state;
  for (final transaction in transactions) {
    current = TransactionProcessor.apply(current, transaction);
  }
  return current;
}

TransactionEntity _income({
  String id = 'income-1',
  String walletId = _walletId,
  double amount = 100,
  String? incomeSourceId,
}) {
  return TransactionEntity(
    id: id,
    walletId: walletId,
    amount: amount,
    type: TransactionType.income.value,
    incomeSourceId: incomeSourceId,
    createdAt: DateTime(2026, 1, 1),
  );
}

TransactionEntity _transfer({
  required String id,
  required String fromWalletId,
  required String toWalletId,
  required double amount,
  required String transferType,
  String? parentId,
}) {
  return TransactionEntity(
    id: id,
    walletId: fromWalletId,
    fromWalletId: fromWalletId,
    toWalletId: toWalletId,
    amount: amount,
    type: TransactionType.transfer.value,
    transferType: transferType,
    parentId: parentId,
    createdAt: DateTime(2026, 1, 2),
  );
}

TransactionEntity _jarAdjustment({
  required String id,
  required double amount,
  required String transferType,
}) {
  return TransactionEntity(
    id: id,
    toWalletId: _jarId,
    amount: amount,
    type: TransactionType.balanceAdjustment.value,
    transferType: transferType,
    createdAt: DateTime(2026, 1, 3),
  );
}

RecurringTransactionEntity _recurring({
  required String id,
  String walletId = _walletId,
}) {
  return RecurringTransactionEntity(
    id: id,
    name: id,
    type: TransactionType.income.value,
    amount: 100,
    dayOfMonth: 1,
    executionType: 'auto',
    walletId: walletId,
    budgetScope: BudgetScope.outsideBudget.value,
    recurrencePattern: RecurrencePattern.monthly.value,
    icon: 'income',
    iconColor: '#165B47',
  );
}
