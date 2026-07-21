import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../budget/domain/entities/money_location_review_entity.dart';
import '../../../budget/domain/services/money_location_engine.dart';
import '../../../transactions/domain/services/transaction_processor.dart';

import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../goals/domain/entities/goal_entity.dart';
import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../../money_distribution/domain/entities/distribution_entry.dart';
import '../../../money_distribution/domain/services/distribution_engine.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../../../notifications/domain/notification_action_copy.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/app_repository.dart';
import '../../../backup/backup_upload_pipeline.dart';
import '../../../backup/local_backup_service.dart';

part 'app_cubit_migration.dart';
part 'app_cubit_money_location.dart';
part 'app_cubit_transactions.dart';
part 'app_cubit_wallets.dart';
part 'app_cubit_budget.dart';
part 'app_cubit_jars.dart';
part 'app_cubit_allocations.dart';
part 'app_cubit_recurring.dart';
part 'app_cubit_lent.dart';
part 'app_cubit_goals.dart';
part 'app_cubit_categories.dart';
part 'app_cubit_settings.dart';
part 'app_cubit_backup.dart';
part 'app_cubit_notifications.dart';

abstract class AppCubitBase extends Cubit<AppStateEntity> {
  AppCubitBase(super.initialState);

  AppRepository get _repository;

  // عقود مجرّدة لواجهات عامة يستخدمها أكثر من mixin واحد. التنفيذ الفعلي
  // يبقى في الـ mixin المالك (transactions / budget) لتفادي تكرار المنطق؛
  // الإعلان هنا فقط يجعلها مرئية لبقية الـ mixins عبر `on AppCubitBase`.
  Future<void> addTransaction({
    String? walletId,
    String? fromWalletId,
    String? toWalletId,
    required double amount,
    required String type,
    String? allocationId,
    String? toAllocationId,
    String? budgetScope,
    String? incomeSourceId,
    String? categoryId,
    String? transferType,
    String? notes,
    DateTime? createdAt,
    String? details,
    String? notificationTitleOverride,
    bool recordInNotificationHistory = false,
  });

  Future<void> updateBudgetSetup(
    BudgetSetupEntity setup, {
    String? detailsOverride,
    String? titleOverride,
    bool recordInNotificationHistory = false,
  });

  Future<void> initialize() async {
    var appState = await _repository.loadState();
    appState = _ensureDefaultSavingsJarSync(appState);
    appState = _migrateDefaultWalletIconsSync(appState);
    appState = _migrateOrphanedDebtRecurringSync(appState);
    appState = _normalizeMoneyLocationState(appState);
    final key = _monthKey();
    if (!appState.monthlyBudgetSnapshots.containsKey(key)) {
      appState = _withMonthlySnapshot(appState, appState.budgetSetup);
    }
    await _repository.saveState(appState);
    emit(appState);
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  String _monthKey([DateTime? at]) {
    final date = at ?? DateTime.now();
    final mm = date.month.toString().padLeft(2, '0');
    return '${date.year}-$mm';
  }

  Map<String, dynamic> _coreMap(AppStateEntity appState) {
    final map = appState.toMap();
    map.remove('logs');
    return map;
  }

  AppStateEntity _withMonthlySnapshot(
    AppStateEntity source,
    BudgetSetupEntity setup, [
    DateTime? month,
  ]) {
    final snapshots = Map<String, Map<String, dynamic>>.from(
      source.monthlyBudgetSnapshots,
    );
    snapshots[_monthKey(month)] = setup.toMap();
    return source.copyWith(monthlyBudgetSnapshots: snapshots);
  }

  AppStateEntity _withMoneyDistributions(
    AppStateEntity source,
    List<DistributionEntry> entries,
  ) {
    final positiveEntries = entries.where((entry) => entry.amount > 0).toList();
    final jars = source.budgetSetup.linkedWallets
        .map((jar) => jar.copyWith(walletSources: const []))
        .toList();
    return source.copyWith(
      moneyDistributions: positiveEntries,
      budgetSetup: source.budgetSetup.copyWith(linkedWallets: jars),
    );
  }

  AppStateEntity _restoreFromCore(String coreJson, List<LogEntryEntity> logs) {
    final map = jsonDecode(coreJson) as Map<String, dynamic>;
    return _normalizeMoneyLocationState(
      AppStateEntity.fromMap(map).copyWith(logs: logs),
    );
  }

  Future<void> _applyAndLog({
    required String action,
    required String entityType,
    required String entityId,
    required String details,
    String? titleOverride,
    bool recordInNotificationHistory = false,
    required Future<AppStateEntity> Function() apply,
  }) async {
    final before = jsonEncode(_coreMap(state));
    final nextRaw = await apply();
    final after = jsonEncode(_coreMap(nextRaw));
    final title = titleOverride ?? _notificationTitle(action, entityType);
    final log = LogEntryEntity(
      id: _id('log'),
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: DateTime.now(),
      beforeState: before,
      afterState: after,
      isReverted: false,
    );
    final notifications = recordInNotificationHistory
        ? [
            NotificationEntity(
              id: _id('notif'),
              title: title,
              message: details,
              createdAt: DateTime.now(),
              type: entityType,
              relatedLogId: log.id,
              isPendingAction: true,
            ),
            ...nextRaw.notifications,
          ].take(800).toList()
        : nextRaw.notifications;
    final next = nextRaw.copyWith(
      logs: [log, ...nextRaw.logs].take(600).toList(),
      notifications: notifications,
    );
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }

  /// رفع/حفظ تلقائي بعد كل عملية حفظ (غير blocking). يشغّل مسارين
  /// مستقلين تمامًا حسب التفعيل: النسخ التلقائي السحابي (BackupUploadPipeline
  /// بخانتين متبادلتين) والنسخ التلقائي المحلي (LocalBackupService بملفين
  /// متبادلين) — كل واحد منهما مستقل عن النسخ اليدوي تمامًا ولا يكتب فوقه.
  /// يضمن وجود جلسة Firebase موثَّقة قبل أي رفع تلقائي، بدون الاعتماد
  /// على زيارة المستخدم لأي شاشة إعدادات في نفس الجلسة (كان هذا السبب
  /// الجذري لعدم عمل النسخ التلقائي السحابي إطلاقًا في الجلسات التي لا
  /// تُفتح فيها شاشة الإعدادات — راجع تحقيق الباگ في نفس هذا الالتزام).
  /// يستخدم `signInSilently()` (استرجاع صامت لجلسة Google محفوظة، بلا
  /// أي واجهة) — إن لم توجد جلسة، يخرج بأمان بلا أثر.
  Future<void> _ensureFirebaseBridged() async {
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      final account =
          googleSignIn.currentUser ?? await googleSignIn.signInSilently();
      if (account == null) return;
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (_) {
      // فشل الجسر — الرفع التلقائي هيتخطى هذه الدورة بأمان، زي حالة
      // عدم وجود مستخدم مسجَّل من الأساس.
    }
  }

  void _autoSync(AppStateEntity appState) {
    _ensureFirebaseBridged().then((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return;
      SharedPreferences.getInstance().then((prefs) {
        final enabled = prefs.getBool('auto_cloud_backup_enabled') ?? false;
        if (!enabled) return;
        BackupUploadPipeline.run(
          email: user.email!,
          displayName: user.displayName ?? user.email!,
          localState: appState,
          exportJson: () => jsonEncode(appState.toMap()),
          kind: BackupKind.auto,
        ).then((result) async {
          final p = await SharedPreferences.getInstance();
          final statusStr = switch (result.status) {
            BackupUploadStatus.uploaded => 'ok',
            BackupUploadStatus.deferredConflict => 'deferred',
            BackupUploadStatus.error => 'failed',
            BackupUploadStatus.rejectedEmpty ||
            BackupUploadStatus.rejectedShrink ||
            BackupUploadStatus.cancelled =>
              'failed',
          };
          await p.setString('last_auto_cloud_status', statusStr);
        }).catchError((_) async {
          final p = await SharedPreferences.getInstance();
          await p.setString('last_auto_cloud_status', 'failed');
        });
      }).catchError((_) {});
    }).catchError((_) {});

    LocalBackupService.autoEnabled().then((enabled) {
      if (!enabled || appState.isEmpty) return;
      LocalBackupService.writeAuto(jsonEncode(appState.toMap()));
    }).catchError((_) {});
    // لو السحابة مش متاحة أو تم تأجيل الرفع، مش بيوقف الـ app.
  }

  String _notificationTitle(String action, String entityType) {
    if (entityType == 'income' || entityType == 'transaction') {
      return 'إشعار معاملة';
    }
    if (entityType == 'budget') {
      return 'إشعار الميزانية';
    }
    if (entityType == 'recurring-transaction') {
      return 'إشعار معاملة متكررة';
    }
    if (entityType == 'goal') {
      return 'إشعار هدف';
    }
    if (action == 'delete') {
      return 'إشعار حذف';
    }
    return 'إشعار جديد';
  }

  String _transactionTypeLabel(String type) {
    if (type == TransactionType.income.value) return 'دخل';
    if (type == TransactionType.expense.value) return 'مصروف';
    if (type == TransactionType.transfer.value) return 'تحويل';
    return type;
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

class AppCubit extends AppCubitBase
    with
        AppCubitMigrationMixin,
        AppCubitMoneyLocationMixin,
        AppCubitTransactionsMixin,
        AppCubitWalletsMixin,
        AppCubitBudgetMixin,
        AppCubitJarsMixin,
        AppCubitAllocationsMixin,
        AppCubitRecurringMixin,
        AppCubitLentMixin,
        AppCubitGoalsMixin,
        AppCubitCategoriesMixin,
        AppCubitSettingsMixin,
        AppCubitBackupMixin,
        AppCubitNotificationsMixin {
  AppCubit(this._repository) : super(AppStateEntity.initial());

  @override
  final AppRepository _repository;
}
