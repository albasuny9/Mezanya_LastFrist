import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/app_state/data/store/shared_prefs_store.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/app_state/domain/repositories/app_repository.dart';
import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/budget/domain/services/budget_income_metrics_service.dart';
import 'package:mezanya_app/features/transactions/domain/entities/recurring_transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/services/recurring_schedule_engine.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const wallet = WalletEntity(id: 'wallet-salary', name: 'Bank', balance: 0);

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
  }) => RecurringTransactionEntity(
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

  test(
    'automatic recurring income creates and applies a transaction on init',
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
    },
  );

  test(
    'confirm recurring income creates a pending notification only',
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
    },
  );

  test('recurring lifecycle advances the earliest overdue occurrence first', () async {
    final now = DateTime(2026, 6, 6);
    final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
        .copyWith(dayOfMonth: 5);
    final repository = _MemoryAppRepository(
      stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
        recurringTransactions: [recurring],
      ),
    );
    final cubit = AppCubit(repository, await _prefsStore());
    cubit.emit(repository.state);
    await cubit.processDueRecurringOperations(now: now);

    expect(cubit.state.transactions, hasLength(1));
    expect(cubit.state.transactions.single.createdAt, DateTime(2026, 6, 5));
    expect(
      cubit.state.recurringTransactions.single.handledOccurrenceIds,
      hasLength(1),
    );

    await cubit.close();
  });

  test('multiple overdue occurrences keep the earlier occurrence pending', () async {
    final now = DateTime(2026, 7, 6);
    final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
        .copyWith(dayOfMonth: 5);
    final repository = _MemoryAppRepository(
      stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
        recurringTransactions: [recurring],
      ),
    );
    final cubit = AppCubit(repository, await _prefsStore());
    cubit.emit(repository.state);
    await cubit.processDueRecurringOperations(now: now);

    expect(cubit.state.transactions, hasLength(1));
    expect(cubit.state.transactions.single.createdAt, DateTime(2026, 7, 5));
    expect(
      cubit.state.recurringTransactions.single.handledOccurrenceIds,
      contains(RecurringTransactionEntity.occurrenceIdFor(recurring.id, DateTime(2026, 7, 5))),
    );
    expect(
      cubit.state.recurringTransactions.single.handledOccurrenceIds,
      isNot(contains(RecurringTransactionEntity.occurrenceIdFor(recurring.id, DateTime(2026, 6, 5)))),
    );

    await cubit.close();
  });

  test('handled earlier occurrences do not block later overdue ones', () async {
    final now = DateTime(2026, 7, 6);
    final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
        .copyWith(
          dayOfMonth: 5,
          handledOccurrenceIds: [
            RecurringTransactionEntity.occurrenceIdFor(
              'rec-salary-handled',
              DateTime(2026, 6, 5),
            ),
          ],
        );
    final repository = _MemoryAppRepository(
      stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
        recurringTransactions: [recurring.copyWith(id: 'rec-salary-handled')],
      ),
    );
    final cubit = AppCubit(repository, await _prefsStore());
    cubit.emit(repository.state);
    await cubit.processDueRecurringOperations(now: now);

    expect(cubit.state.transactions, hasLength(1));
    expect(cubit.state.transactions.single.createdAt, DateTime(2026, 7, 5));
    expect(
      cubit.state.recurringTransactions.single.handledOccurrenceIds,
      contains(RecurringTransactionEntity.occurrenceIdFor('rec-salary-handled', DateTime(2026, 7, 5))),
    );

    await cubit.close();
  });

  test('skipping an older occurrence does not mark a later one handled', () async {
    final now = DateTime(2026, 7, 6);
    final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
        .copyWith(
          dayOfMonth: 5,
          skippedOccurrenceIds: [
            RecurringTransactionEntity.occurrenceIdFor(
              'rec-salary-skipped',
              DateTime(2026, 6, 5),
            ),
          ],
        );
    final repository = _MemoryAppRepository(
      stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
        recurringTransactions: [recurring.copyWith(id: 'rec-salary-skipped')],
      ),
    );
    final cubit = AppCubit(repository, await _prefsStore());
    cubit.emit(repository.state);
    await cubit.processDueRecurringOperations(now: now);

    expect(cubit.state.transactions, hasLength(1));
    expect(cubit.state.transactions.single.createdAt, DateTime(2026, 7, 5));
    expect(
      cubit.state.recurringTransactions.single.skippedOccurrenceIds,
      contains(RecurringTransactionEntity.occurrenceIdFor('rec-salary-skipped', DateTime(2026, 6, 5))),
    );
    expect(
      cubit.state.recurringTransactions.single.handledOccurrenceIds,
      contains(RecurringTransactionEntity.occurrenceIdFor('rec-salary-skipped', DateTime(2026, 7, 5))),
    );

    await cubit.close();
  });

  test('postponing an older occurrence preserves the later one as actionable', () async {
    final now = DateTime(2026, 7, 6);
    final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
        .copyWith(dayOfMonth: 5);
    final repository = _MemoryAppRepository(
      stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
        recurringTransactions: [recurring],
      ),
    );
    final cubit = AppCubit(repository, await _prefsStore());
    cubit.emit(repository.state);

    await cubit.recordRecurringPostpone(
      recurring: recurring,
      snoozedUntil: DateTime(2026, 7, 7),
      occurrence: DateTime(2026, 6, 5),
      logDetails: 'postpone june',
    );

    await cubit.processDueRecurringOperations(now: DateTime(2026, 7, 6));

    expect(cubit.state.transactions, hasLength(1));
    expect(cubit.state.transactions.single.createdAt, DateTime(2026, 7, 5));
    expect(
      cubit.state.recurringTransactions.single.postponedOccurrenceIds,
      contains(RecurringTransactionEntity.occurrenceIdFor(recurring.id, DateTime(2026, 6, 5))),
    );
    expect(
      cubit.state.recurringTransactions.single.handledOccurrenceIds,
      contains(RecurringTransactionEntity.occurrenceIdFor(recurring.id, DateTime(2026, 7, 5))),
    );

    await cubit.close();
  });

  test(
    'automatic recurring income does not duplicate when processed multiple times',
    () async {
      final now = DateTime(2026, 7, 6);
      final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
          .copyWith(dayOfMonth: 5);
      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      cubit.emit(repository.state);

      await cubit.processDueRecurringOperations(now: now);
      expect(cubit.state.transactions, hasLength(1));

      await cubit.processDueRecurringOperations(now: now);
      expect(cubit.state.transactions, hasLength(1));

      await cubit.close();
    },
  );

  test(
    'automatic recurring income duplicate occurrence is recognized after restart',
    () async {
      final now = DateTime(2026, 7, 6);
      final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
          .copyWith(dayOfMonth: 5);
      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      cubit.emit(repository.state);

      await cubit.processDueRecurringOperations(now: now);
      expect(cubit.state.transactions, hasLength(1));
      await cubit.close();

      final restartedRepository = _MemoryAppRepository(repository.state);
      final restartedCubit = AppCubit(restartedRepository, await _prefsStore());
      restartedCubit.emit(restartedRepository.state);
      await restartedCubit.processDueRecurringOperations(now: now);

      expect(restartedCubit.state.transactions, hasLength(1));
      expect(restartedCubit.state.wallets.single.balance, 1000);

      await restartedCubit.close();
    },
  );

  test(
    'postponed occurrence survives restart and preserves original occurrence identity',
    () async {
      final now = DateTime(2026, 7, 6);
      final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
          .copyWith(dayOfMonth: 5);
      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      cubit.emit(repository.state);

      await cubit.recordRecurringPostpone(
        recurring: recurring,
        snoozedUntil: DateTime(2026, 7, 7),
        occurrence: DateTime(2026, 6, 5),
        logDetails: 'postpone june',
      );
      await cubit.close();

      final restartedRepository = _MemoryAppRepository(repository.state);
      final restartedCubit = AppCubit(restartedRepository, await _prefsStore());
      restartedCubit.emit(restartedRepository.state);
      await restartedCubit.processDueRecurringOperations(now: DateTime(2026, 7, 8));

      expect(restartedCubit.state.transactions, hasLength(1));
      expect(restartedCubit.state.transactions.single.createdAt, DateTime(2026, 7, 5));
      expect(
        restartedCubit.state.recurringTransactions.single.postponedOccurrenceIds,
        contains(RecurringTransactionEntity.occurrenceIdFor(recurring.id, DateTime(2026, 6, 5))),
      );
      expect(
        restartedCubit.state.recurringTransactions.single.handledOccurrenceIds,
        contains(RecurringTransactionEntity.occurrenceIdFor(recurring.id, DateTime(2026, 7, 5))),
      );

      await restartedCubit.close();
    },
  );

  test(
    'postponed occurrence is not actionable while snooze is active',
    () async {
      final now = DateTime(2026, 7, 6, 12);
      final recurring = salaryRecurring(now, executionType: AutomationType.confirm.value)
          .copyWith(dayOfMonth: 5);
      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.confirm.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      cubit.emit(repository.state);

      await cubit.recordRecurringPostpone(
        recurring: recurring,
        snoozedUntil: DateTime(2026, 7, 7, 12),
        occurrence: DateTime(2026, 7, 5),
        logDetails: 'postpone due occurrence',
      );

      await cubit.processDueRecurringOperations(now: now);

      expect(cubit.state.transactions, isEmpty);
      expect(
        cubit.state.notifications.where(
          (notification) =>
              notification.type == 'recurring-income-due' &&
              notification.message.contains(recurring.id),
        ),
        isEmpty,
      );
      expect(
        RecurringScheduleEngine.unhandledDueOccurrence(
          cubit.state.recurringTransactions.single,
          now,
        ),
        isNull,
      );

      await cubit.close();
    },
  );

  test(
    'postponed occurrence becomes actionable again after snooze expires',
    () async {
      final now = DateTime(2026, 7, 8, 12);
      final originalNow = DateTime(2026, 7, 6, 12);
      final recurring = salaryRecurring(originalNow, executionType: AutomationType.confirm.value)
          .copyWith(dayOfMonth: 5);
      final repository = _MemoryAppRepository(
        stateWithSalary(originalNow, executionType: AutomationType.confirm.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      cubit.emit(repository.state);

      await cubit.recordRecurringPostpone(
        recurring: recurring,
        snoozedUntil: DateTime(2026, 7, 7, 12),
        occurrence: DateTime(2026, 7, 5),
        logDetails: 'postpone due occurrence',
      );
      await cubit.close();

      final restartedRepository = _MemoryAppRepository(repository.state);
      final restartedCubit = AppCubit(restartedRepository, await _prefsStore());
      restartedCubit.emit(restartedRepository.state);
      await restartedCubit.processDueRecurringOperations(now: now);

      expect(
        restartedCubit.state.notifications.where(
          (notification) =>
              notification.type == 'recurring-income-due' &&
              notification.message.contains(recurring.id),
        ),
        hasLength(1),
      );
      expect(restartedCubit.state.transactions, isEmpty);
      await restartedCubit.close();
    },
  );

  test(
    'skipping a due occurrence prevents it from becoming actionable',
    () async {
      final now = DateTime(2026, 7, 6, 12);
      final recurring = salaryRecurring(now, executionType: AutomationType.confirm.value)
          .copyWith(dayOfMonth: 5);
      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.confirm.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      cubit.emit(repository.state);

      await cubit.recordRecurringSkip(
        recurring: recurring,
        occurrence: DateTime(2026, 7, 5),
        logDetails: 'skip due occurrence',
      );
      await cubit.processDueRecurringOperations(now: now);

      expect(cubit.state.transactions, isEmpty);
      expect(
        cubit.state.notifications.where(
          (notification) =>
              notification.type == 'recurring-income-due' &&
              notification.message.contains(recurring.id),
        ),
        isEmpty,
      );
      expect(
        RecurringScheduleEngine.unhandledDueOccurrence(
          cubit.state.recurringTransactions.single,
          now,
        ),
        isNull,
      );
      expect(
        cubit.state.recurringTransactions.single.skippedOccurrenceIds,
        contains(RecurringTransactionEntity.occurrenceIdFor(recurring.id, DateTime(2026, 7, 5))),
      );

      await cubit.close();
    },
  );

  test(
    'manual recurring income execution blocks later automatic processing',
    () async {
      final now = DateTime(2026, 7, 5, 12);
      final recurring = salaryRecurring(now, executionType: AutomationType.auto.value)
          .copyWith(dayOfMonth: 5);
      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.auto.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      cubit.emit(repository.state);

      await cubit.recordRecurringIncomeOccurrence(
        recurring: recurring,
        amount: 1000,
        occurrence: DateTime(2026, 7, 5),
        transactionNotes: 'Salary confirmed early',
        logDetails: 'manual recurring income execution',
      );

      expect(cubit.state.transactions, hasLength(1));
      await cubit.processDueRecurringOperations(now: now);
      expect(cubit.state.transactions, hasLength(1));

      await cubit.close();
    },
  );

  test(
    'notification dismissal does not mark recurring occurrence handled',
    () async {
      final now = DateTime(2026, 7, 6);
      final recurring = salaryRecurring(now, executionType: AutomationType.confirm.value)
          .copyWith(dayOfMonth: 5);
      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.confirm.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      cubit.emit(repository.state);
      await cubit.processDueRecurringOperations(now: now);

      expect(
        cubit.state.notifications.where(
          (notification) =>
              notification.type == 'recurring-income-due' &&
              notification.message.contains(recurring.id),
        ),
        hasLength(1),
      );
      await cubit.close();

      final dismissedState = repository.state.copyWith(notifications: []);
      final dismissedRepository = _MemoryAppRepository(dismissedState);
      final dismissedCubit = AppCubit(dismissedRepository, await _prefsStore());
      dismissedCubit.emit(dismissedState);
      await dismissedCubit.processDueRecurringOperations(now: now);

      expect(
        dismissedCubit.state.notifications.where(
          (notification) =>
              notification.type == 'recurring-income-due' &&
              notification.message.contains(recurring.id),
        ),
        hasLength(1),
      );
      expect(dismissedCubit.state.transactions, isEmpty);

      await dismissedCubit.close();
    },
  );

  test(
    'recurring income idempotency: duplicate occurrence does not create a second transaction',
    () async {
      final now = DateTime(2026, 7, 1);
      final recurring = RecurringTransactionEntity(
        id: 'rec-salary-manual',
        name: 'Salary',
        type: TransactionType.income.value,
        amount: 1000,
        dayOfMonth: now.day,
        executionType: AutomationType.manual.value,
        walletId: wallet.id,
        budgetScope: BudgetScope.withinBudget.value,
        recurrencePattern: RecurrencePattern.monthly.value,
        icon: 'cash',
        iconColor: '#165b47',
        incomeSourceId: 'income-salary',
      );

      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.manual.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      await cubit.initialize();

      await cubit.recordRecurringIncomeOccurrence(
        recurring: recurring,
        amount: 1000,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Salary',
        logDetails: 'posted salary',
      );
      await cubit.recordRecurringIncomeOccurrence(
        recurring: recurring.copyWith(),
        amount: 1000,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Salary duplicate',
        logDetails: 'posted duplicate',
      );

      expect(cubit.state.transactions, hasLength(1));
      expect(cubit.state.wallets.single.balance, 1000);
      expect(
        cubit.state.recurringTransactions.single.lastHandledOccurrenceAt,
        DateTime(2026, 7, 1).toIso8601String(),
      );

      await cubit.close();
    },
  );

  test(
    'recurring income duplicate occurrence is recognized after restart',
    () async {
      final now = DateTime(2026, 7, 1);
      final recurring = RecurringTransactionEntity(
        id: 'rec-salary-manual-2',
        name: 'Salary',
        type: TransactionType.income.value,
        amount: 1000,
        dayOfMonth: now.day,
        executionType: AutomationType.manual.value,
        walletId: wallet.id,
        budgetScope: BudgetScope.withinBudget.value,
        recurrencePattern: RecurrencePattern.monthly.value,
        icon: 'cash',
        iconColor: '#165b47',
        incomeSourceId: 'income-salary',
      );

      final repository = _MemoryAppRepository(
        stateWithSalary(now, executionType: AutomationType.manual.value).copyWith(
          recurringTransactions: [recurring],
        ),
      );
      final cubit = AppCubit(repository, await _prefsStore());
      await cubit.initialize();

      await cubit.recordRecurringIncomeOccurrence(
        recurring: recurring,
        amount: 1000,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Salary',
        logDetails: 'posted salary',
      );
      await cubit.close();

      final restartedRepository = _MemoryAppRepository(repository.state);
      final restartedCubit = AppCubit(restartedRepository, await _prefsStore());
      await restartedCubit.initialize();

      await restartedCubit.recordRecurringIncomeOccurrence(
        recurring: recurring,
        amount: 1000,
        occurrence: DateTime(2026, 7, 1),
        transactionNotes: 'Salary duplicate',
        logDetails: 'posted duplicate after restart',
      );

      expect(restartedCubit.state.transactions, hasLength(1));
      expect(restartedCubit.state.wallets.single.balance, 1000);

      await restartedCubit.close();
    },
  );

  test('recurring occurrence identity is deterministic and stable', () {
    final now = DateTime(2026, 8, 3, 10, 15);
    final recurring = salaryRecurring(
      now,
      executionType: AutomationType.auto.value,
    );
    final occurrence = DateTime(2026, 8, 10, 8, 0, 30);
    final normalizedOccurrence = DateTime(2026, 8, 10, 8, 0);

    final idA = recurring.occurrenceId(occurrence);
    final idB = recurring.copyWith().occurrenceId(occurrence);
    final idC = RecurringTransactionEntity.occurrenceIdFor(
      recurring.id,
      occurrence,
    );
    final reloaded = RecurringTransactionEntity.fromMap(recurring.toMap());
    final idD = reloaded.occurrenceId(occurrence);

    expect(idA, equals(idB));
    expect(idA, equals(idC));
    expect(idA, equals(idD));
    expect(reloaded.handledOccurrenceIds, isEmpty);
    expect(reloaded.postponedOccurrenceIds, isEmpty);
    expect(reloaded.skippedOccurrenceIds, isEmpty);
    expect(idA, contains(recurring.id));
    expect(idA, contains(normalizedOccurrence.toIso8601String()));

    final differentOccurrence = normalizedOccurrence.add(
      const Duration(days: 1),
    );
    expect(recurring.occurrenceId(differentOccurrence), isNot(idA));

    final otherRecurring = recurring.copyWith(id: 'rec-salary-alt');
    expect(otherRecurring.occurrenceId(occurrence), isNot(idA));
  });

  test(
    'recurring occurrence identity works with RecurringScheduleEngine generated occurrences',
    () {
      final now = DateTime(2026, 8, 1, 9, 30);
      final recurring = salaryRecurring(
        now,
        executionType: AutomationType.auto.value,
      ).copyWith(
        scheduledTime: '08:00',
        dayOfMonth: 10,
      );

      final occurrence = RecurringScheduleEngine.nextOccurrence(recurring, now);
      expect(occurrence, isNotNull);

      final identity = recurring.occurrenceId(occurrence!);
      final expectedIdentity = RecurringTransactionEntity.occurrenceIdFor(
        recurring.id,
        occurrence,
      );

      expect(identity, equals(expectedIdentity));
      expect(identity, contains(recurring.id));
      expect(identity, contains(occurrence.toIso8601String()));
    },
  );
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
