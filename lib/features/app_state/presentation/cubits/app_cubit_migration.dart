part of 'app_cubit.dart';

mixin AppCubitMigrationMixin on AppCubitBase {
  /// ترحيل — يكشف تعارضات walletSources الموجودة في بيانات قديمة
  /// ويحوّلها إلى عناصر مراجعة [MoneyLocationReview] بدلاً من تركها صامتة.
  ///
  /// ## متى يعمل
  /// مرة واحدة فقط في حياة التطبيق على كل جهاز ([moneyLocationMigrationDone = false]).
  /// بعد أول تشغيل ناجح يُعيَّن العلَم إلى true لمنع إعادة الترحيل.
  /// هذا يضمن أن المستخدم يرى المراجعات مرة واحدة ولا تُعاد بعد تجاهلها.
  ///
  /// التعارضات الجديدة التي تحدث بعد التحديث تُعالَج بالمحرك مباشرةً (ليست
  /// مسؤولية هذا الترحيل).
  ///
  /// آمن تماماً: لا يُعدَّل jar.balance أو wallet.balance.
  AppStateEntity _migrateMoneyLocationInconsistenciesSync(
    AppStateEntity source,
  ) {
    // الترحيل يعمل مرة واحدة فقط — المستخدم قد يتجاهل المراجعات فلا نعيدها
    if (source.moneyLocationMigrationDone) return source;

    final jars =
        List<LinkedWalletEntity>.from(source.budgetSetup.linkedWallets);
    var changed = false;

    for (var i = 0; i < jars.length; i++) {
      final jar = jars[i];
      final snapshot = DistributionEngine.snapshotForJar(
        entries: source.moneyDistributions,
        jarId: jar.id,
        jarBalance: jar.balance,
      );
      final newReviews = MoneyLocationEngine.detectInconsistencies(
        jar: jar,
        snapshot: snapshot,
      );
      if (newReviews.isNotEmpty) {
        jars[i] = jar.copyWith(
          moneyLocationReviews: [...jar.moneyLocationReviews, ...newReviews],
        );
        changed = true;
      }
    }

    // دائماً نُعيَّن العلَم حتى لو لم تكن هناك تعارضات (لتجنب إعادة الفحص)
    return source.copyWith(
      budgetSetup: changed
          ? source.budgetSetup.copyWith(linkedWallets: jars)
          : source.budgetSetup,
      moneyLocationMigrationDone: true,
    );
  }

  AppStateEntity _migrateMoneyDistributionsSync(AppStateEntity source) {
    // الترحيل يعمل مرة واحدة فقط — بعد أن يُعيَّن العلَم لا داعي لإعادته
    if (source.moneyDistributionMigrationDone &&
        source.budgetSetup.linkedWallets.every((j) => j.walletSources.isEmpty)) {
      return source;
    }

    final knownWalletIds = source.wallets.map((wallet) => wallet.id).toSet();
    final entries =
        source.moneyDistributions.where((entry) => entry.amount > 0).toList();
    final now = DateTime.now();
    final jars =
        List<LinkedWalletEntity>.from(source.budgetSetup.linkedWallets);

    for (var jarIndex = 0; jarIndex < jars.length; jarIndex++) {
      final jar = jars[jarIndex];
      var remainingImportable = jar.balance;
      final reviews = <MoneyLocationReview>[];

      for (final walletSource in jar.walletSources) {
        if (walletSource.amount <= 0) {
          reviews.add(
            MoneyLocationReview(
              id: _id('mlr-mig'),
              amount: walletSource.amount.abs(),
              type: MoneyLocationReviewType.sourceWentNegative.value,
              createdAt: now,
              notes: 'مصدر قديم غير صالح لم يتم ترحيله.',
            ),
          );
          continue;
        }

        if (!knownWalletIds.contains(walletSource.walletId)) {
          reviews.add(
            MoneyLocationReview(
              id: _id('mlr-mig'),
              amount: walletSource.amount,
              type: MoneyLocationReviewType.labeledExceedsBalance.value,
              createdAt: now,
              notes: 'مصدر قديم مرتبط بمحفظة غير موجودة ولم يتم ترحيله.',
            ),
          );
          continue;
        }

        final alreadyImported = entries.any(
          (entry) =>
              entry.jarId == jar.id && entry.walletId == walletSource.walletId,
        );
        if (alreadyImported) {
          remainingImportable -= walletSource.amount;
          continue;
        }

        final importable = remainingImportable <= 0
            ? 0.0
            : walletSource.amount <= remainingImportable
                ? walletSource.amount
                : remainingImportable;

        if (importable > 0) {
          entries.add(
            DistributionEntry(
              id: _id('dist'),
              jarId: jar.id,
              walletId: walletSource.walletId,
              amount: importable,
              origin: DistributionOrigin.migration,
              createdAt: now,
            ),
          );
          remainingImportable -= importable;
        }

        final excess = walletSource.amount - importable;
        if (excess > 0.01) {
          reviews.add(
            MoneyLocationReview(
              id: _id('mlr-mig'),
              amount: excess,
              type: MoneyLocationReviewType.labeledExceedsBalance.value,
              createdAt: now,
              notes: 'جزء من مصدر قديم تجاوز رصيد الحصالة ولم يتم ترحيله.',
            ),
          );
        }
      }

      if (reviews.isNotEmpty) {
        jars[jarIndex] = jar.copyWith(
          moneyLocationReviews: [...jar.moneyLocationReviews, ...reviews],
        );
      }
    }

    final migrated = source.copyWith(
      budgetSetup: source.budgetSetup.copyWith(linkedWallets: jars),
      moneyDistributionMigrationDone: true,
    );
    return _withMoneyDistributions(migrated, entries);
  }

  AppStateEntity _normalizeMoneyLocationState(AppStateEntity source) {
    final withDistributions = _migrateMoneyDistributionsSync(source);
    return _migrateMoneyLocationInconsistenciesSync(withDistributions);
  }

  /// مزامنة الديون/الاشتراكات القديمة التي تُحفظ كـ RecurringTransaction
  /// بدون DebtEntity مقابلة في budget.debts
  AppStateEntity _migrateOrphanedDebtRecurringSync(AppStateEntity source) {
    final linkedIds = source.budgetSetup.debts
        .map((d) => d.recurringTransactionId)
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

    final orphaned = source.recurringTransactions
        .where(
          (r) =>
              r.isDebtOrSubscription &&
              r.type == TransactionType.expense.value &&
              r.budgetScope == BudgetScope.withinBudget.value &&
              !linkedIds.contains(r.id),
        )
        .toList();

    if (orphaned.isEmpty) return source;

    final fallbackFundingSource = source.budgetSetup.incomeSources.isNotEmpty
        ? source.budgetSetup.incomeSources.first.id
        : '';

    final newDebts = orphaned.map((r) => DebtEntity(
          id: 'debt-${r.id}',
          name: r.name,
          amount: r.amount,
          executionDay: r.dayOfMonth.clamp(1, 28),
          type: r.executionType,
          fundingSource: fallbackFundingSource,
          recurringTransactionId: r.id,
          kind: r.expensePlanKind == ExpensePlanKind.installment.value
              ? ExpensePlanKind.installment.value
              : ExpensePlanKind.subscription.value,
          principalTotal: r.debtPrincipalTotal,
          recurrencePattern: r.recurrencePattern,
          monthOfYear: r.monthOfYear,
        ));

    return source.copyWith(
      budgetSetup: source.budgetSetup.copyWith(
        debts: [...source.budgetSetup.debts, ...newDebts],
      ),
    );
  }

  /// يضمن إن المحافظ والحصالات الافتراضية عندها الأيقونات والألوان الصح
  AppStateEntity _migrateDefaultWalletIconsSync(AppStateEntity source) {
    var wallets = List<WalletEntity>.from(source.wallets);
    bool changed = false;

    // ألوان قديمة (سواء الديفولت الأصلي أو نتيجة هجرة سابقة بأيقونة خطأ)
    const legacyColors = {'#165b47', '#165B47'};

    for (var i = 0; i < wallets.length; i++) {
      final w = wallets[i];
      if (w.id == 'wallet-cash-default') {
        final needsIcon = w.icon == null || w.icon == 'payments';
        final needsColor =
            w.iconColor == null || legacyColors.contains(w.iconColor);
        if (needsIcon || needsColor) {
          wallets[i] = w.copyWith(
            icon: needsIcon ? 'cash' : w.icon,
            iconColor: needsColor ? '#165B47' : w.iconColor,
          );
          changed = true;
        }
      }
      if (w.id == 'wallet-bank-default') {
        final needsIcon = w.icon == null || w.icon == 'account_balance';
        final needsColor =
            w.iconColor == null || legacyColors.contains(w.iconColor);
        if (needsIcon || needsColor) {
          wallets[i] = w.copyWith(
            icon: needsIcon ? 'bank' : w.icon,
            iconColor: needsColor ? '#1D4ED8' : w.iconColor,
          );
          changed = true;
        }
      }
    }

    // حصالة التوفير
    var linkedWallets =
        List<LinkedWalletEntity>.from(source.budgetSetup.linkedWallets);
    for (var i = 0; i < linkedWallets.length; i++) {
      final j = linkedWallets[i];
      if (j.id == 'linked-savings-default' &&
          (j.icon == 'savings' || j.iconColor == '#0f766e')) {
        linkedWallets[i] = j.copyWith(
          icon: 'monetization_on',
          iconColor: '#D97706',
        );
        changed = true;
      }
    }

    if (!changed) return source;
    return source.copyWith(
      wallets: wallets,
      budgetSetup: source.budgetSetup.copyWith(linkedWallets: linkedWallets),
    );
  }

  AppStateEntity _ensureDefaultSavingsJarSync(AppStateEntity source) {
    final defaultIndex = source.budgetSetup.linkedWallets
        .indexWhere((w) => w.id == 'linked-savings-default');
    if (defaultIndex != -1) {
      final current = source.budgetSetup.linkedWallets[defaultIndex];
      if (current.name == 'التوفير') return source;
      final linkedWallets =
          List<LinkedWalletEntity>.from(source.budgetSetup.linkedWallets);
      linkedWallets[defaultIndex] = current.copyWith(name: 'التوفير');
      return source.copyWith(
        budgetSetup: source.budgetSetup.copyWith(linkedWallets: linkedWallets),
      );
    }
    final fallbackIncomeId = source.budgetSetup.incomeSources.isNotEmpty
        ? source.budgetSetup.incomeSources.first.id
        : '';
    final defaultJar = LinkedWalletEntity(
      id: 'linked-savings-default',
      name: 'التوفير',
      balance: 0,
      monthlyAmount: 0,
      executionDay: 1,
      fundingSource: fallbackIncomeId,
      funding: fallbackIncomeId.isEmpty
          ? const []
          : [
              LinkedWalletEntityFunding(
                id: _id('fund-linked'),
                incomeSourceId: fallbackIncomeId,
                plannedAmount: 0,
              ),
            ],
      icon: 'monetization_on',
      iconColor: '#D97706',
      automationType: AutomationType.confirm.value,
      categories: const [],
    );
    return source.copyWith(
      budgetSetup: source.budgetSetup.copyWith(
        linkedWallets: [...source.budgetSetup.linkedWallets, defaultJar],
      ),
    );
  }
}
