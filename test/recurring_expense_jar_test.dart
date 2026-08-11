import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/app_state/domain/repositories/app_repository.dart';
import 'package:mezanya_app/features/app_state/data/store/shared_prefs_store.dart';
import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/transactions/domain/entities/recurring_transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/services/transaction_processor.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const wallet = WalletEntity(
    id: 'wallet-1',
    name: 'Bank',
    balance: 1000,
  );
  const jar = LinkedWalletEntity(
    id: 'jar-1',
    name: 'Emergency',
    balance: 500,
    monthlyAmount: 0,
    executionDay: 1,
    fundingSource: '',
    funding: [],
    icon: 'savings',
    iconColor: '#165B47',
    automationType: '',
    categories: [],
  );

  AppStateEntity baseState() => AppStateEntity.initial().copyWith(
        wallets: [wallet],
        budgetSetup: AppStateEntity.initial().budgetSetup.copyWith(
          linkedWallets: [jar],
        ),
      );

  group('Manual jar-targeted expense', () {
    test('is stored as outside-budget and updates the jar balance', () {
      final transaction = TransactionEntity(
        id: 'txn-manual-jar',
        walletId: wallet.id,
        toWalletId: jar.id,
        amount: 100,
        type: TransactionType.expense.value,
        budgetScope: BudgetScope.outsideBudget.value,
        createdAt: DateTime(2026, 7, 1),
      );

      final applied = TransactionProcessor.apply(baseState(), transaction);
      final updatedJar = applied.budgetSetup.linkedWallets.single;
      final updatedWallet = applied.wallets.single;

      expect(transaction.budgetScope, BudgetScope.outsideBudget.value);
      expect(updatedWallet.balance, 900);
      expect(updatedJar.balance, 400);
    });
  });

  group('Recurring jar-targeted expense occurrence', () {
    test(
        'preserves the jar target (toWalletId), records outside-budget, '
        'and decreases the jar balance exactly once', () async {
      final recurring = RecurringTransactionEntity(
        id: 'rec-1',
        name: 'Car maintenance',
        type: TransactionType.expense.value,
        amount: 100,
        dayOfMonth: 1,
        executionType: 'manual',
        walletId: wallet.id,
        budgetScope: BudgetScope.outsideBudget.value,
        recurrencePattern: RecurrencePattern.monthly.value,
        icon: 'category',
        iconColor: '#c65d2e',
        targetJarId: jar.id,
      );

      final repository = _MemoryAppRepository(
        baseState().copyWith(recurringTransactions: [recurring]),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      await cubit.initialize();

      await cubit.recordRecurringExpenseOccurrence(
        recurring: recurring,
        amount: 100,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Car maintenance',
        logDetails: 'posted',
      );

      final generated =
          cubit.state.transactions.where((t) => t.walletId == wallet.id).single;
      expect(generated.toWalletId, jar.id,
          reason: 'jar target must be preserved on the generated transaction');
      expect(generated.budgetScope, BudgetScope.outsideBudget.value);

      final updatedJar = cubit.state.budgetSetup.linkedWallets
          .firstWhere((j) => j.id == jar.id);
      final updatedWallet =
          cubit.state.wallets.firstWhere((w) => w.id == wallet.id);
      expect(updatedWallet.balance, 900);
      expect(updatedJar.balance, 400);

      final updatedRecurring = cubit.state.recurringTransactions
          .firstWhere((r) => r.id == recurring.id);
      expect(updatedRecurring.lastHandledOccurrenceAt,
          DateTime(2026, 7, 1).toIso8601String());

      await cubit.close();
    });

    test(
        'idempotency: recordRecurringExpenseOccurrence never creates a duplicate '
        'transaction for the same occurrence, even when called with a stale recurring entity',
        () async {
      final recurring = RecurringTransactionEntity(
        id: 'rec-2',
        name: 'Car maintenance',
        type: TransactionType.expense.value,
        amount: 100,
        dayOfMonth: 1,
        executionType: 'manual',
        walletId: wallet.id,
        budgetScope: BudgetScope.outsideBudget.value,
        recurrencePattern: RecurrencePattern.monthly.value,
        icon: 'category',
        iconColor: '#c65d2e',
        targetJarId: jar.id,
      );

      final repository = _MemoryAppRepository(
        baseState().copyWith(recurringTransactions: [recurring]),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      await cubit.initialize();

      await cubit.recordRecurringExpenseOccurrence(
        recurring: recurring,
        amount: 100,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Car maintenance',
        logDetails: 'posted',
      );

      final staleRecurring = recurring.copyWith();
      await cubit.recordRecurringExpenseOccurrence(
        recurring: staleRecurring,
        amount: 100,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Car maintenance',
        logDetails: 'posted duplicate',
      );

      expect(
        cubit.state.transactions.where((t) => t.walletId == wallet.id).length,
        1,
      );
      final updatedJar = cubit.state.budgetSetup.linkedWallets
          .firstWhere((j) => j.id == jar.id);
      expect(updatedJar.balance, 400);

      await cubit.close();
    });

    test('duplicate occurrence is recognized after app restart', () async {
      final recurring = RecurringTransactionEntity(
        id: 'rec-3',
        name: 'Car maintenance',
        type: TransactionType.expense.value,
        amount: 100,
        dayOfMonth: 1,
        executionType: 'manual',
        walletId: wallet.id,
        budgetScope: BudgetScope.outsideBudget.value,
        recurrencePattern: RecurrencePattern.monthly.value,
        icon: 'category',
        iconColor: '#c65d2e',
        targetJarId: jar.id,
      );

      final repository = _MemoryAppRepository(
        baseState().copyWith(recurringTransactions: [recurring]),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      await cubit.initialize();

      await cubit.recordRecurringExpenseOccurrence(
        recurring: recurring,
        amount: 100,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Car maintenance',
        logDetails: 'posted',
      );
      await cubit.close();

      final restartedRepository = _MemoryAppRepository(repository.state);
      final restartedCubit = AppCubit(restartedRepository, await _prefsStore());
      await restartedCubit.initialize();

      await restartedCubit.recordRecurringExpenseOccurrence(
        recurring: recurring,
        amount: 100,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Car maintenance',
        logDetails: 'posted duplicate after restart',
      );

      expect(
        restartedCubit.state.transactions.where((t) => t.walletId == wallet.id).length,
        1,
      );
      final restartedJar = restartedCubit.state.budgetSetup.linkedWallets
          .firstWhere((j) => j.id == jar.id);
      expect(restartedJar.balance, 400);

      await restartedCubit.close();
    });

    test('failed recurring execution does not mark occurrence as handled',
        () async {
      final recurring = RecurringTransactionEntity(
        id: 'rec-4',
        name: 'Car maintenance',
        type: TransactionType.expense.value,
        amount: 100,
        dayOfMonth: 1,
        executionType: 'manual',
        walletId: wallet.id,
        budgetScope: BudgetScope.outsideBudget.value,
        recurrencePattern: RecurrencePattern.monthly.value,
        icon: 'category',
        iconColor: '#c65d2e',
        targetJarId: jar.id,
      );

      final repository = _ThrowingSaveAppRepository(
        baseState().copyWith(recurringTransactions: [recurring]),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      await cubit.initialize();

      expect(
        () => cubit.recordRecurringExpenseOccurrence(
          recurring: recurring,
          amount: 100,
          occurrence: DateTime(2026, 7, 1),
          transactionNotes: 'Car maintenance',
          logDetails: 'posted',
        ),
        throwsA(isA<Exception>()),
      );

      expect(cubit.state.transactions, isEmpty);
      expect(cubit.state.recurringTransactions.single.lastHandledOccurrenceAt,
          isNull);

      await cubit.close();
    });

    test('different occurrence is allowed and creates another transaction',
        () async {
      final recurring = RecurringTransactionEntity(
        id: 'rec-5',
        name: 'Car maintenance',
        type: TransactionType.expense.value,
        amount: 100,
        dayOfMonth: 1,
        executionType: 'manual',
        walletId: wallet.id,
        budgetScope: BudgetScope.outsideBudget.value,
        recurrencePattern: RecurrencePattern.monthly.value,
        icon: 'category',
        iconColor: '#c65d2e',
        targetJarId: jar.id,
      );

      final repository = _MemoryAppRepository(
        baseState().copyWith(recurringTransactions: [recurring]),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      await cubit.initialize();

      await cubit.recordRecurringExpenseOccurrence(
        recurring: recurring,
        amount: 100,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Car maintenance',
        logDetails: 'posted',
      );
      await cubit.recordRecurringExpenseOccurrence(
        recurring: recurring,
        amount: 100,
        occurrence: DateTime(2026, 8, 1),
        transactionNotes: 'Car maintenance',
        logDetails: 'posted next occurrence',
      );

      expect(
        cubit.state.transactions.where((t) => t.walletId == wallet.id).length,
        2,
      );
      expect(cubit.state.recurringTransactions.single.lastHandledOccurrenceAt,
          DateTime(2026, 8, 1).toIso8601String());

      await cubit.close();
    });
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

class _ThrowingSaveAppRepository extends _MemoryAppRepository {
  _ThrowingSaveAppRepository(super.state);

  int _saveCount = 0;

  @override
  Future<void> saveState(AppStateEntity state) async {
    _saveCount += 1;
    if (_saveCount > 1) {
      throw Exception('forced save failure');
    }
    this.state = state;
  }
}
