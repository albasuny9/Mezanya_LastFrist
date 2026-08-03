import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/app_state/data/store/shared_prefs_store.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/app_state/domain/repositories/app_repository.dart';
import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/budget/domain/services/budget_income_metrics_service.dart';
import 'package:mezanya_app/features/transactions/domain/entities/recurring_transaction_entity.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const wallet = WalletEntity(
    id: 'wallet-salary',
    name: 'Bank',
    balance: 0,
  );

  IncomeSourceEntity salarySource(DateTime now) => IncomeSourceEntity(
        id: 'income-salary',
        name: 'Salary',
        amount: 1000,
        date: now.day,
        type: AutomationType.confirm.value,
        targetWalletId: wallet.id,
      );

  RecurringTransactionEntity salaryRecurring(
    DateTime now, {
    required String executionType,
  }) =>
      RecurringTransactionEntity(
        id: 'rec-salary',
        name: 'Salary',
        type: TransactionType.income.value,
        amount: 1000,
        dayOfMonth: now.day,
        executionType: executionType,
        walletId: wallet.id,
        budgetScope: BudgetScope.withinBudget.value,
        recurrencePattern: RecurrencePattern.monthly.value,
        icon: 'cash',
        iconColor: '#165b47',
        incomeSourceId: 'income-salary',
        scheduledTime: '00:00',
      );

  AppStateEntity stateWithSalary(
    DateTime now, {
    required String executionType,
  }) {
    final source = salarySource(now);
    return AppStateEntity.initial().copyWith(
      wallets: [wallet],
      budgetSetup: AppStateEntity.initial().budgetSetup.copyWith(
        incomeSources: [source],
      ),
      recurringTransactions: [
        salaryRecurring(now, executionType: executionType),
      ],
    );
  }

  test('budget income pool is zero until an income transaction exists', () {
    final source = salarySource(DateTime(2026, 8, 3));

    expect(
      BudgetIncomeMetricsService.incomeDisplayPool(source, 0),
      0,
      reason: 'planned recurring income is intent, not available money',
    );
    expect(
      BudgetIncomeMetricsService.incomeRemainingProgress(
        source,
        0,
        AppStateEntity.initial().budgetSetup,
        const [],
      ),
      isNull,
    );
  });

  test('automatic recurring income creates and applies a transaction on init',
      () async {
    final now = DateTime.now();
    final repository = _MemoryAppRepository(
      stateWithSalary(now, executionType: AutomationType.auto.value),
    );
    final cubit = AppCubit(repository, await _prefsStore());

    await cubit.initialize();

    expect(cubit.state.transactions, hasLength(1));
    final transaction = cubit.state.transactions.single;
    expect(transaction.type, TransactionType.income.value);
    expect(transaction.incomeSourceId, 'income-salary');
    expect(cubit.state.wallets.single.balance, 1000);
    expect(
      cubit.state.recurringTransactions.single.lastHandledOccurrenceAt,
      isNotNull,
    );

    await cubit.close();
  });

  test('confirm recurring income creates a pending notification only',
      () async {
    final now = DateTime.now();
    final repository = _MemoryAppRepository(
      stateWithSalary(now, executionType: AutomationType.confirm.value),
    );
    final cubit = AppCubit(repository, await _prefsStore());

    await cubit.initialize();

    expect(cubit.state.transactions, isEmpty);
    expect(cubit.state.wallets.single.balance, 0);
    expect(
      cubit.state.notifications.where(
        (notification) =>
            notification.type == 'recurring-income-due' &&
            notification.message.contains('rec-salary'),
      ),
      hasLength(1),
    );
    expect(
      cubit.state.recurringTransactions.single.lastHandledOccurrenceAt,
      isNull,
    );

    await cubit.close();
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
