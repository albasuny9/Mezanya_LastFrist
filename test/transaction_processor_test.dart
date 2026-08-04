import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/app_state/domain/repositories/app_repository.dart';
import 'package:mezanya_app/features/app_state/data/store/shared_prefs_store.dart';
import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/money_distribution/domain/entities/distribution_entry.dart';
import 'package:mezanya_app/features/money_distribution/domain/services/distribution_engine.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/services/transaction_processor.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // Regression test — Jar double-count bug (Finding B).
  //
  // Root cause: a single income transaction could carry BOTH
  // transferType == depositWithJarLabel (explicit manual jar deposit) AND
  // a non-null incomeSourceId matching a jar with automatic funding
  // configured for that same source. Both code paths in
  // TransactionProcessor.apply used to run independently, crediting the
  // same jar twice for the same money and creating a duplicate child
  // (parentId) sub-transaction.
  //
  // This test constructs exactly that conflicting transaction and asserts
  // the jar is credited only ONCE, and exactly one sub-transaction (not
  // two) is created as a result.
  // ═══════════════════════════════════════════════════════════════════════
  test(
      'income transaction with both a manual jar deposit and matching auto-funding '
      'credits the jar only once (Finding B regression)', () {
    const incomeSourceId = 'income-1';
    const jar = LinkedWalletEntity(
      id: 'jar-1',
      name: 'Savings',
      balance: 0,
      monthlyAmount: 0,
      executionDay: 1,
      fundingSource: incomeSourceId,
      funding: [
        LinkedWalletEntityFunding(
          id: 'fund-1',
          incomeSourceId: incomeSourceId,
          plannedAmount: 500,
        ),
      ],
      icon: 'savings',
      iconColor: '#165B47',
      automationType: 'auto',
      categories: [],
    );
    final wallet = const WalletEntity(id: 'wallet-1', name: 'Bank', balance: 0);

    // A transaction that (per the pre-fix form-controller logic) carries
    // BOTH the manual deposit-to-jar transferType AND a matching
    // incomeSourceId — exactly the conflicting shape traced in the
    // conversation's audit.
    final transaction = TransactionEntity(
      id: 'txn-1',
      walletId: wallet.id,
      toWalletId: jar.id,
      amount: 500,
      type: TransactionType.income.value,
      transferType: TransferType.depositWithJarLabel.value,
      incomeSourceId: incomeSourceId,
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

    // Credited exactly once (500), not twice (1000).
    expect(fundedJar.balance, 500);

    // Exactly the one parent transaction was recorded — no extra
    // auto-funding sub-transaction (with parentId) was created, since the
    // manual deposit path already accounted for the money.
    expect(applied.transactions.length, 1);
    expect(applied.transactions.where((t) => t.parentId != null), isEmpty);

    // Reversing the transaction must bring the jar back to exactly zero —
    // proving apply() and reverse() stay symmetric under this fix (no
    // orphaned sub-transaction reversal, no double-reversal).
    final reversed = TransactionProcessor.reverse(applied, transaction);
    expect(reversed.budgetSetup.linkedWallets.single.balance, 0);
  });

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

  test('confirming allocation distribution records a replayable transaction',
      () async {
    const walletId = 'wallet-1';
    const wallet = WalletEntity(
      id: walletId,
      name: 'Bank',
      balance: 1000,
    );
    const allocation = AllocationEntity(
      id: 'allocation-1',
      name: 'Food',
      icon: 'restaurant',
      iconColor: '#1D4ED8',
      rolloverBehavior: 'keep',
      funding: [],
      categories: [],
      pendingDistribution: 125,
      pendingDistributionWalletId: walletId,
      pendingDistributionSourceId: 'income-1',
    );
    final initial = AppStateEntity.initial().copyWith(
      wallets: [wallet],
      budgetSetup: AppStateEntity.initial().budgetSetup.copyWith(
        allocations: [allocation],
        incomeSources: const [
          IncomeSourceEntity(
            id: 'income-1',
            name: 'Salary',
            amount: 125,
            date: 1,
            type: 'confirm',
            targetWalletId: walletId,
          ),
        ],
      ),
    );
    final repository = _MemoryAppRepository(initial);
    final cubit = AppCubit(repository, await _prefsStore());

    await cubit.initialize();
    await cubit.confirmAllocationDistribution(allocation.id);

    final confirmed = cubit.state.budgetSetup.allocations
        .firstWhere((item) => item.id == allocation.id);
    expect(confirmed.balance, 125);
    expect(confirmed.walletBalances[wallet.id], 125);
    expect(confirmed.pendingDistribution, 0);
    expect(confirmed.pendingDistributionWalletId, isEmpty);
    expect(confirmed.pendingDistributionSourceId, isEmpty);

    final posted = cubit.state.transactions.single;
    expect(posted.type, TransactionType.transfer.value);
    expect(posted.transferType, TransferType.allocationFunding.value);
    expect(posted.walletId, wallet.id);
    expect(posted.toWalletId, allocation.id);
    expect(posted.amount, 125);

    final replayBase = cubit.state.copyWith(
      transactions: const [],
      budgetSetup: cubit.state.budgetSetup.copyWith(
        allocations: [
          confirmed.copyWith(
            balance: 0,
            walletBalances: const {},
          ),
        ],
      ),
    );
    final replayed = TransactionProcessor.apply(replayBase, posted);
    final replayedAllocation = replayed.budgetSetup.allocations
        .firstWhere((item) => item.id == allocation.id);

    expect(replayedAllocation.balance, confirmed.balance);
    expect(replayedAllocation.walletBalances, confirmed.walletBalances);

    await cubit.close();
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
    final cubit = AppCubit(repository, await _prefsStore());

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

Future<SharedPrefsStore> _prefsStore() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPrefsStore(await SharedPreferences.getInstance());
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
