import '../../../../core/constants/transaction_types.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../budget/domain/entities/money_location_review_entity.dart';
import '../../../budget/domain/services/money_location_engine.dart';
import '../../../money_distribution/domain/entities/distribution_entry.dart';
import '../../../money_distribution/domain/services/distribution_engine.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/app_state_entity.dart';
import 'money_distribution_service.dart';

/// خدمة مسؤولة حصريًا عن كل عمليات ترحيل البيانات القديمة (data migration)
/// التي كانت تعمل مرة واحدة عند بدء تشغيل التطبيق أو عند استعادة نسخة
/// احتياطية قديمة.
///
/// استُخرجت بالكامل من AppCubitBase — لا تغيير في المنطق أو السلوك أو
/// ترتيب التنفيذ، فقط نقل موقع التعريف. AppCubit مسؤول فقط عن استدعائها.
class MigrationService {
  const MigrationService._();

  static String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  static final RegExp _legacyMonthKeyPattern = RegExp(r'^\d{4}-\d{2}$');

  /// ═══════════════════════════════════════════════════════════════════════
  /// Correctness fix (not a refactor): Monthly Budget Snapshot key format
  /// unification.
  ///
  /// WHY THIS MIGRATION EXISTS:
  /// Snapshots were written using `"YYYY-MM"` (calendar-month key, via the
  /// old `_monthKey()` helper) from the feature's introduction
  /// (2026-04-14) onward. On 2026-04-29, cycle-aware reads were introduced
  /// (`BudgetSetupEntity.cycleKeyFor`, format `"YYYY-MM-DD"`, aligned to the
  /// user's configured cycle start day per the Domain Bible's definition of
  /// the financial cycle — `02 - Financial Cycle.md`: "the system is not
  /// tied to the calendar month"), but the WRITE side was never updated to
  /// match. Every snapshot ever written by any installation up to this fix
  /// is therefore keyed in the old, non-canonical `"YYYY-MM"` format — the
  /// new-format read path could never find anything (dead code), and every
  /// lookup silently depended on the old-format fallback instead.
  ///
  /// WHAT THIS DOES:
  /// Converts every legacy `"YYYY-MM"` key in `monthlyBudgetSnapshots` to
  /// the canonical `cycleKeyFor` format (`"YYYY-MM-DD"`), reconstructing
  /// the correct cycle-start day from that historical snapshot's OWN
  /// `startDay` (not today's), so a user who has since changed their cycle
  /// start day still gets historically-accurate keys for old snapshots. No
  /// snapshot content is modified — only its map key changes.
  ///
  /// WHICH VERSIONS IT SUPPORTS:
  /// Any installation whose `monthlyBudgetSnapshots` still contains
  /// `"YYYY-MM"`-format keys, i.e. any installation that has not yet run
  /// this migration once. New installations (created after this fix ships)
  /// never produce legacy keys, since the write side now writes
  /// `cycleKeyFor` directly (see `AppCubitBase._withMonthlySnapshot`).
  ///
  /// IDEMPOTENCY: keys already in `"YYYY-MM-DD"` format do not match
  /// [_legacyMonthKeyPattern] and are left untouched. Running this twice
  /// (or on an already-migrated install) is a guaranteed no-op — the second
  /// run finds zero legacy keys and returns `source` unchanged (`identical`
  /// short-circuit below).
  ///
  /// ATOMICITY: a single new map is built locally and only swapped into the
  /// returned state once, in one `copyWith` call. There is no intermediate
  /// state where some keys are migrated and others are not — either this
  /// call has run to completion and returned a fully-migrated map, or it
  /// hasn't run at all (nothing is ever partially written, and the caller,
  /// `AppCubitBase.initialize()`, only persists the state once — after ALL
  /// migrations, including this one, have completed in memory).
  ///
  /// WHEN IT CAN BE REMOVED: once we are confident no installation still
  /// running an old app version (pre-fix) exists in the wild — practically,
  /// this can be deleted a few release cycles after this fix ships, once
  /// every real install has had the chance to launch at least once and
  /// migrate. Until then it must stay, because every historical snapshot
  /// for every existing user is only reachable via the legacy key today.
  /// ═══════════════════════════════════════════════════════════════════════
  static AppStateEntity migrateMonthlyBudgetSnapshotKeysSync(
    AppStateEntity source,
  ) {
    final legacyEntries = source.monthlyBudgetSnapshots.entries
        .where((entry) => _legacyMonthKeyPattern.hasMatch(entry.key));
    if (legacyEntries.isEmpty) return source; // idempotent no-op

    final migrated = Map<String, Map<String, dynamic>>.from(
      source.monthlyBudgetSnapshots,
    );

    for (final entry in legacyEntries) {
      final oldKey = entry.key;
      final snapshotMap = entry.value;
      final parts = oldKey.split('-');
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null) continue; // defensively skip

      BudgetSetupEntity historicalSetup;
      try {
        historicalSetup = BudgetSetupEntity.fromMap(snapshotMap);
      } catch (_) {
        continue; // corrupted snapshot payload — leave it under its
        // original key rather than losing it or crashing the migration.
      }

      final cycleStartDay = historicalSetup.startDay.clamp(1, 28);
      final newKey = historicalSetup.cycleKeyFor(
        DateTime(year, month, cycleStartDay),
      );

      if (!migrated.containsKey(newKey)) {
        migrated[newKey] = snapshotMap;
      }
      // لو الـ newKey موجود بالفعل (احتمال نادر: تصادم)، نسيب القيمة
      // الموجودة زي ما هي بدل الكتابة فوقها — لا نفقد أي بيانات.
      migrated.remove(oldKey);
    }

    return source.copyWith(monthlyBudgetSnapshots: migrated);
  }

  /// يشغّل ترحيلي توزيعات الأموال وتعارضات مواقعها بالترتيب الصحيح.
  static AppStateEntity normalizeMoneyLocationState(AppStateEntity source) {
    final withDistributions = _migrateMoneyDistributionsSync(source);
    return _migrateMoneyLocationInconsistenciesSync(withDistributions);
  }

  /// مزامنة الديون/الاشتراكات القديمة التي تُحفظ كـ RecurringTransaction
  /// بدون DebtEntity مقابلة في budget.debts
  static AppStateEntity migrateOrphanedDebtRecurringSync(
    AppStateEntity source,
  ) {
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
  static AppStateEntity migrateDefaultWalletIconsSync(AppStateEntity source) {
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

  static AppStateEntity ensureDefaultSavingsJarSync(AppStateEntity source) {
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
  static AppStateEntity _migrateMoneyLocationInconsistenciesSync(
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

  static AppStateEntity _migrateMoneyDistributionsSync(AppStateEntity source) {
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
    return MoneyDistributionService.withMoneyDistributions(migrated, entries);
  }
}
