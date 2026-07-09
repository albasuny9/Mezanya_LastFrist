import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/app_state/domain/repositories/app_repository.dart';
import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/money_distribution/domain/entities/distribution_entry.dart';
import 'package:mezanya_app/features/money_distribution/domain/services/distribution_engine.dart';
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
    final fundedSnapshot = DistributionEngine.snapshotForJar(
      entries: applied.moneyDistributions,
      jarId: jar.id,
      jarBalance: fundedJar.balance,
    );

    expect(fundedJar.balance, 150);
    expect(fundedJar.walletSources, isEmpty);
    expect(fundedSnapshot.known, 150);
    expect(fundedSnapshot.unknown, 0);

    final reversed = TransactionProcessor.reverse(applied, transaction);
    final reversedJar = reversed.budgetSetup.linkedWallets.single;

    expect(reversedJar.balance, 0);
    expect(reversedJar.walletSources, isEmpty);
    expect(reversed.moneyDistributions, isEmpty);
    expect(reversed.transactions, isEmpty);
  });

  test('existing migrated jars backfill money distributions from sources',
      () async {
    final wallet = const WalletEntity(
      id: 'wallet-cash',
      name: 'Cash',
      balance: 500,
    );
    const jar = LinkedWalletEntity(
      id: 'jar-existing',
      name: 'Existing',
      balance: 4500,
      monthlyAmount: 0,
      executionDay: 1,
      fundingSource: '',
      funding: [],
      icon: 'savings',
      iconColor: '#165B47',
      automationType: '',
      categories: [],
      walletSources: [
        JarWalletSource(walletId: 'wallet-cash', amount: 500),
      ],
    );
    final initial = AppStateEntity.initial().copyWith(
      wallets: [wallet],
      budgetSetup: AppStateEntity.initial().budgetSetup.copyWith(
        linkedWallets: [jar],
      ),
      moneyDistributionMigrationDone: true,
    );
    final repository = _MemoryAppRepository(initial);
    final cubit = AppCubit(repository);

    await cubit.initialize();
    final migrated = cubit.state;
    final migratedJar = migrated.budgetSetup.linkedWallets
        .firstWhere((linkedWallet) => linkedWallet.id == jar.id);
    final snapshot = DistributionEngine.snapshotForJar(
      entries: migrated.moneyDistributions,
      jarId: jar.id,
      jarBalance: migratedJar.balance,
    );

    expect(snapshot.known, 500);
    expect(snapshot.unknown, 4000);
    expect(migratedJar.walletSources, isEmpty);

    await cubit.close();
  });

  test('unknown distribution is zero when jar balance is negative', () {
    final entries = [
      DistributionEntry(
        id: 'dist-1',
        jarId: 'jar-negative',
        walletId: 'wallet-cash',
        amount: 500,
        origin: DistributionOrigin.manual,
        createdAt: DateTime(2026),
      ),
    ];

    expect(
      DistributionEngine.unknownForJar(
        entries: entries,
        jarId: 'jar-negative',
        jarBalance: -100,
      ),
      0,
    );
  });
}

class _MemoryAppRepository implements AppRepository {
  _MemoryAppRepository(this.state);

  AppStateEntity state;

  @override
  Future<AppStateEntity> loadState() async => state;

  @override
  Future<void> saveState(AppStateEntity state) async {
    this.state = state;
  }
}
