import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/services/transaction_processor.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';

void main() {
  test('reversing physical jar funding clears its reservation source', () {
    final wallet = const WalletEntity(
      id: 'wallet-1',
      name: 'Bank',
      balance: 1000,
    );
    const jar = LinkedWalletEntity(
      id: 'jar-1',
      name: 'Emergency',
      balance: 0,
      monthlyAmount: 0,
      executionDay: 1,
      fundingSource: '',
      funding: [],
      icon: 'savings',
      iconColor: '#165B47',
      automationType: '',
      categories: [],
    );
    final transaction = TransactionEntity(
      id: 'txn-1',
      walletId: wallet.id,
      fromWalletId: wallet.id,
      toWalletId: jar.id,
      amount: 150,
      type: TransactionType.transfer.value,
      transferType: TransferType.jarFundingPhysical.value,
      createdAt: DateTime(2026),
    );
    final initial = AppStateEntity.initial().copyWith(
      wallets: [wallet],
      budgetSetup: AppStateEntity.initial().budgetSetup.copyWith(
        linkedWallets: [jar],
      ),
    );

    final applied = TransactionProcessor.apply(initial, transaction);
    final fundedJar = applied.budgetSetup.linkedWallets.single;

    expect(fundedJar.balance, 150);
    expect(fundedJar.labeledTotal, 150);
    expect(fundedJar.walletSources.single.amount, 150);

    final reversed = TransactionProcessor.reverse(applied, transaction);
    final reversedJar = reversed.budgetSetup.linkedWallets.single;

    expect(reversedJar.balance, 0);
    expect(reversedJar.labeledTotal, 0);
    expect(reversedJar.walletSources, isEmpty);
    expect(reversed.transactions, isEmpty);
  });
}
