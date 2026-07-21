part of 'app_cubit.dart';

mixin AppCubitBackupMixin on AppCubitBase {
  String exportStateJson() => jsonEncode(state.toMap());

  Future<void> importStateJson(String jsonString) async {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final next = MigrationService.normalizeMoneyLocationState(AppStateEntity.fromMap(map));
    await _applyAndLog(
      action: 'import',
      entityType: 'backup',
      entityId: 'import',
      details: 'تم استيراد نسخة احتياطية',
      apply: () async => next,
    );
  }

  Future<void> mergeStateJson(String remoteJson) async {
    final remoteMap = jsonDecode(remoteJson) as Map<String, dynamic>;
    final remote = MigrationService.normalizeMoneyLocationState(AppStateEntity.fromMap(remoteMap));
    final local = state;

    final mergedWallets = {
      for (final w in [...local.wallets, ...remote.wallets]) w.id: w,
    }.values.toList();

    final mergedTx = {
      for (final t in [...local.transactions, ...remote.transactions]) t.id: t,
    }.values.toList();

    final mergedRecurring = {
      for (final r in [
        ...local.recurringTransactions,
        ...remote.recurringTransactions
      ])
        r.id: r,
    }.values.toList();

    final mergedGoals = {
      for (final g in [...local.goals, ...remote.goals]) g.id: g,
    }.values.toList();

    final mergedCategories = {
      for (final c in [...local.categories, ...remote.categories]) c.id: c,
    }.values.toList();

    final localBudgetNewer = local.lastAutoBackupAt.compareTo(
          remote.lastAutoBackupAt,
        ) >=
        0;
    final budget = localBudgetNewer ? local.budgetSetup : remote.budgetSetup;

    final next = MigrationService.normalizeMoneyLocationState(local.copyWith(
      wallets: mergedWallets,
      transactions: mergedTx,
      recurringTransactions: mergedRecurring,
      goals: mergedGoals,
      categories: mergedCategories,
      budgetSetup: budget,
    ));

    await _applyAndLog(
      action: 'import',
      entityType: 'backup',
      entityId: 'merge',
      details: 'تم دمج النسخة الاحتياطية مع البيانات المحلية',
      apply: () async => next,
    );
  }

  Future<void> resetAllData() async {
    final next = AppStateEntity.initial();
    await _applyAndLog(
      action: 'delete',
      entityType: 'all-data',
      entityId: 'reset',
      details: 'تم حذف كل بيانات التطبيق',
      apply: () async => next,
    );
  }

  Future<void> wipeDataSelective({
    bool transactions = false,
    bool logs = false,
    bool wallets = false,
    bool recurring = false,
    bool budget = false,
    bool categories = false,
    bool goals = false,
    bool notifications = false,
  }) async {
    var next = state;
    final details = <String>[];

    if (transactions) {
      next = next.copyWith(transactions: []);
      details.add('المعاملات');
    }
    if (logs) {
      next = next.copyWith(logs: []);
      details.add('سجل النشاط');
    }
    if (wallets) {
      next = next.copyWith(
        wallets: [
          const WalletEntity(
              id: 'wallet-cash-default', name: 'الكاش', balance: 0),
          const WalletEntity(
              id: 'wallet-bank-default', name: 'البنك', balance: 0),
        ],
      );
      details.add('المحافظ والأرصدة');
    }
    if (recurring) {
      next = next.copyWith(recurringTransactions: []);
      details.add('المعاملات المتكررة');
    }
    if (budget) {
      next = next.copyWith(
        budgetSetup: next.budgetSetup.copyWith(
          incomeSources: [],
          debts: [],
          allocations: [],
          linkedWallets: next.budgetSetup.linkedWallets
              .where((w) => w.id == 'linked-savings-default')
              .toList(),
        ),
      );
      details.add('خطة الميزانية');
    }
    if (categories) {
      next = next.copyWith(categories: []);
      details.add('الفئات');
    }
    if (goals) {
      next = next.copyWith(goals: []);
      details.add('الأهداف');
    }
    if (notifications) {
      next = next.copyWith(notifications: []);
      details.add('الإشعارات');
    }

    if (details.isEmpty) return;

    await _applyAndLog(
      action: 'delete',
      entityType: 'selective-wipe',
      entityId: 'reset',
      details: 'تم حذف بيانات محددة: ${details.join('، ')}',
      apply: () async => next,
    );
  }
}
