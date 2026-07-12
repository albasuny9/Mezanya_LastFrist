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
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/app_repository.dart';
import '../../../backup/backup_upload_pipeline.dart';
import '../../../backup/local_backup_service.dart';

class AppCubit extends Cubit<AppStateEntity> {
  AppCubit(this._repository) : super(AppStateEntity.initial());

  final AppRepository _repository;

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

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
  String _monthKey([DateTime? at]) {
    final date = at ?? DateTime.now();
    final mm = date.month.toString().padLeft(2, '0');
    return '${date.year}-$mm';
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

  Map<String, dynamic> _coreMap(AppStateEntity appState) {
    final map = appState.toMap();
    map.remove('logs');
    return map;
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
  void _autoSync(AppStateEntity appState) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
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
    }

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

  Future<void> addWallet({
    required String name,
    required double openingBalance,
    String? icon,
    String? iconColor,
  }) async {
    final wallet = WalletEntity(
      id: _id('wallet'),
      name: name,
      balance: openingBalance,
      icon: icon,
      iconColor: iconColor,
    );
    await _applyAndLog(
      action: 'add',
      entityType: 'wallet',
      entityId: wallet.id,
      details: 'تمت إضافة محفظة جديدة: $name',
      apply: () async => state.copyWith(
        wallets: [...state.wallets, wallet],
      ),
    );
  }

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
  }) async {
    final walletName = walletId == null
        ? null
        : state.wallets
            .where((w) => w.id == walletId)
            .map((w) => w.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);
    final incomeName = incomeSourceId == null
        ? null
        : state.budgetSetup.incomeSources
            .where((i) => i.id == incomeSourceId)
            .map((i) => i.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);
    final allocationName = allocationId == null
        ? null
        : state.budgetSetup.allocations
            .where((a) => a.id == allocationId)
            .map((a) => a.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);

    final transaction = TransactionEntity(
      id: _id('txn'),
      walletId: walletId,
      fromWalletId: fromWalletId,
      toWalletId: toWalletId,
      allocationId: allocationId,
      toAllocationId: toAllocationId,
      budgetScope: budgetScope,
      incomeSourceId: incomeSourceId,
      categoryId: categoryId,
      transferType: transferType,
      amount: amount,
      type: type,
      notes: notes,
      createdAt: createdAt ?? DateTime.now(),
    );
    // صرف مباشر من حصالة بدون اختيار محفظة: لا يجوز أن يمنع المعاملة
    // (الحصالات يجوز أن يصير رصيدها سالبًا). نحسب هنا — قبل تطبيق المعاملة —
    // هل المبلغ سيتجاوز الرصيد غير الممول (Unknown) في الحصالة، لإنشاء
    // مراجعة Money Location بعد نجاح المعاملة بدل رفضها.
    LinkedWalletEntity? jarNeedingMismatchReview;
    var mismatchReviewWalletId = 'no-wallet';
    if (type == TransactionType.expense.value && toWalletId != null) {
      final jar = state.budgetSetup.linkedWallets
          .where((j) => j.id == toWalletId)
          .firstOrNull;
      if (jar != null) {
        final snapshot = DistributionEngine.snapshotForJar(
          entries: state.moneyDistributions,
          jarId: jar.id,
          jarBalance: jar.balance,
        );
        final explainableAmount = walletId == null
            ? snapshot.unknown
            : DistributionEngine.totalFromWalletForJar(
                state.moneyDistributions,
                jar.id,
                walletId,
              );
        if (amount > explainableAmount + 0.01) {
          jarNeedingMismatchReview = jar;
          mismatchReviewWalletId = walletId ?? 'no-wallet';
        }
      }
    }

    await _applyAndLog(
      action: type == TransactionType.transfer.value ? 'transfer' : 'add',
      entityType: 'transaction',
      entityId: transaction.id,
      details: details ??
          _transactionDetails(
            type: type,
            amount: amount,
            walletName: walletName,
            incomeName: incomeName,
            allocationName: allocationName,
            budgetScope: budgetScope,
          ),
      titleOverride: recordInNotificationHistory
          ? (notificationTitleOverride ??
              details ??
              (notes?.isNotEmpty == true
                  ? notes
                  : incomeName ??
                      walletName ??
                      (type == TransactionType.income.value ? 'دخل' : 'مصروف')))
          : (notes?.isNotEmpty == true
              ? notes
              : incomeName ??
                  walletName ??
                  (type == TransactionType.income.value ? 'دخل' : 'مصروف')),
      apply: () async => TransactionProcessor.apply(state, transaction),
      recordInNotificationHistory: recordInNotificationHistory,
    );

    if (jarNeedingMismatchReview != null) {
      final jars =
          List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
      final idx = jars.indexWhere((j) => j.id == jarNeedingMismatchReview!.id);
      if (idx != -1) {
        jars[idx] = MoneyLocationEngine.addSpendingMismatchReview(
          jar: jars[idx],
          amount: amount,
          spendingWalletId: mismatchReviewWalletId,
          transactionId: transaction.id,
        );
        await updateBudgetSetup(
          state.budgetSetup.copyWith(linkedWallets: jars),
        );
      }
    }
  }

  String _transactionDetails({
    required String type,
    required double amount,
    String? walletName,
    String? incomeName,
    String? allocationName,
    String? budgetScope,
  }) {
    if (type == TransactionType.income.value) {
      final source = incomeName ?? 'مصدر غير محدد';
      final wallet = walletName ?? 'محفظة غير محددة';
      return 'معاملة دخل بقيمة ${amount.toStringAsFixed(2)} من $source إلى $wallet';
    }
    if (type == TransactionType.expense.value) {
      final budgetLabel = budgetScope == BudgetScope.withinBudget.value
          ? 'داخل الميزانية'
          : 'خارج الميزانية';
      final alloc = allocationName == null ? '' : ' ضمن مخصص $allocationName';
      final wallet = walletName ?? 'محفظة غير محددة';
      return 'معاملة مصروف بقيمة ${amount.toStringAsFixed(2)} من $wallet ($budgetLabel)$alloc';
    }
    return 'معاملة تحويل بقيمة ${amount.toStringAsFixed(2)}';
  }

  Future<void> deleteTransaction(String transactionId) async {
    final target =
        state.transactions.where((t) => t.id == transactionId).toList();
    if (target.isEmpty) return;
    final transaction = target.first;

    // TransactionProcessor.reverse يعكس الأرصدة ويحذف الـ sub-transactions تلقائياً
    var next = TransactionProcessor.reverse(state, transaction);

    // تنظيف أي Money Location review مرتبط بهذه المعاملة (مثلاً review من نوع
    // spendingWalletMismatch أُنشئ عبر addSpendingMismatchReview) — بدون هذا
    // التنظيف يبقى الـ review يتيماً يشير إلى معاملة لم تعد موجودة.
    final jarsWithOrphanReviews = next.budgetSetup.linkedWallets
        .where((jar) => jar.moneyLocationReviews
            .any((r) => r.relatedTransactionId == transactionId))
        .toList();
    if (jarsWithOrphanReviews.isNotEmpty) {
      final jars =
          List<LinkedWalletEntity>.from(next.budgetSetup.linkedWallets);
      for (final jar in jarsWithOrphanReviews) {
        final idx = jars.indexWhere((j) => j.id == jar.id);
        if (idx == -1) continue;
        jars[idx] = jars[idx].copyWith(
          moneyLocationReviews: jars[idx]
              .moneyLocationReviews
              .where((r) => r.relatedTransactionId != transactionId)
              .toList(),
        );
      }
      next = next.copyWith(
        budgetSetup: next.budgetSetup.copyWith(linkedWallets: jars),
      );
    }

    await _applyAndLog(
      action: 'delete',
      entityType: 'transaction',
      entityId: transactionId,
      details:
          'تم حذف معاملة ${_transactionTypeLabel(transaction.type)} بقيمة ${transaction.amount.toStringAsFixed(2)}',
      apply: () async => next,
    );
  }

  Future<void> updateBudgetSetup(
    BudgetSetupEntity setup, {
    String? detailsOverride,
    String? titleOverride,
    bool recordInNotificationHistory = false,
  }) async {
    final details = detailsOverride ?? 'تم تعديل إعدادات الميزانية';
    await _applyAndLog(
      action: 'edit',
      entityType: 'budget',
      entityId: 'budget-setup',
      details: details,
      titleOverride:
          recordInNotificationHistory ? (titleOverride ?? details) : null,
      recordInNotificationHistory: recordInNotificationHistory,
      apply: () async {
        final raw = state.copyWith(budgetSetup: setup);
        return _withMonthlySnapshot(raw, setup);
      },
    );
  }

  Future<void> updateWallet({
    required String id,
    String? name,
    double? balance,
    String? icon,
    String? iconColor,
  }) async {
    final wallets = state.wallets
        .map((wallet) => wallet.id == id
            ? wallet.copyWith(
                name: name, balance: balance, icon: icon, iconColor: iconColor)
            : wallet)
        .toList();
    final next = state.copyWith(wallets: wallets);
    await _applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: id,
      details: 'تم تعديل بيانات المحفظة',
      apply: () async => next,
    );
  }

  Future<void> reorderWallets(List<WalletEntity> ordered) async {
    final next = state.copyWith(wallets: ordered);
    await _applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: 'wallets-order',
      details: 'تم إعادة ترتيب المحافظ',
      apply: () async => next,
    );
  }

  Future<void> reorderJars(List<LinkedWalletEntity> ordered) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: ordered),
    );
  }

  Future<void> toggleWalletHighlight(String walletId) async {
    final wallets = state.wallets.map((w) {
      if (w.id != walletId) return w;
      return w.copyWith(isHighlighted: !w.isHighlighted);
    }).toList();
    final next = state.copyWith(wallets: wallets);
    await _applyAndLog(
      action: 'edit',
      entityType: 'wallet',
      entityId: walletId,
      details: 'تبديل تلوين المحفظة',
      apply: () async => next,
    );
  }

  Future<void> toggleJarHighlight(String jarId) async {
    final jars = state.budgetSetup.linkedWallets.map((j) {
      if (j.id != jarId) return j;
      return j.copyWith(isHighlighted: !j.isHighlighted);
    }).toList();
    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: jars),
    );
  }

  Future<void> deleteWallet(String id) async {
    final hasDistribution = state.moneyDistributions.any(
      (entry) => entry.walletId == id && entry.amount > 0,
    );
    if (hasDistribution) {
      throw const DistributionValidationException(
        'لا يمكن حذف محفظة تحتوي على أماكن فلوس محجوزة.',
      );
    }

    final next = state.copyWith(
        wallets: state.wallets.where((wallet) => wallet.id != id).toList());
    await _applyAndLog(
      action: 'delete',
      entityType: 'wallet',
      entityId: id,
      details: 'تم حذف محفظة',
      apply: () async => next,
    );
  }

  /// يعدّل تصنيف مكان فلوس محفظة في الحصالة (walletSources فقط).
  ///
  /// ## التغيير المعماري
  /// النسخة السابقة كانت تجمع بين:
  ///   1. طفرة مباشرة على walletSources (خارج TransactionProcessor)
  ///   2. إضافة transaction مراجعة (audit)
  ///
  /// هذا أدى إلى تعارض: حذف الـ audit transaction كان يُعيد عكس walletSources
  /// مرة ثانية رغم أن الطفرة المباشرة لم تُعكس بعد (المشكلة #1 في التوثيق).
  ///
  /// ## السلوك الجديد
  /// تمرير التغيير عبر [addTransaction] فقط ← [TransactionProcessor.apply]
  /// ← [MoneyLocationEngine.applyLocationDelta].
  /// هذا يجعل walletSources قابلاً للإعادة الكاملة من سجل المعاملات.
  Future<void> relabelJarWalletSource({
    required String jarId,
    required String walletId,
    required double newAmount,
  }) async {
    final oldAmount = DistributionEngine.totalFromWalletForJar(
      state.moneyDistributions,
      jarId,
      walletId,
    );
    final diff = newAmount - oldAmount;
    if (diff > 0.01) {
      await addMoneyDistribution(
        jarId: jarId,
        walletId: walletId,
        amount: diff,
      );
    } else if (diff < -0.01) {
      await removeMoneyDistribution(
        jarId: jarId,
        walletId: walletId,
        amount: diff.abs(),
      );
    }
  }

  Future<void> addMoneyDistribution({
    required String jarId,
    required String walletId,
    required double amount,
  }) async {
    final jar = state.budgetSetup.linkedWallets
        .where((item) => item.id == jarId)
        .firstOrNull;
    if (jar == null) return;

    await _applyAndLog(
      action: 'edit',
      entityType: 'money-distribution',
      entityId: jarId,
      details: 'تم تعديل مكان الفلوس',
      apply: () async => _withMoneyDistributions(
        state,
        DistributionEngine.addReservation(
          entries: state.moneyDistributions,
          jarId: jarId,
          walletId: walletId,
          amount: amount,
          jarBalance: jar.balance,
          knownWalletIds: state.wallets.map((wallet) => wallet.id).toSet(),
          origin: DistributionOrigin.manual,
        ),
      ),
    );
  }

  Future<void> removeMoneyDistribution({
    required String jarId,
    required String walletId,
    required double amount,
  }) async {
    await _applyAndLog(
      action: 'edit',
      entityType: 'money-distribution',
      entityId: jarId,
      details: 'تم تعديل مكان الفلوس',
      apply: () async => _withMoneyDistributions(
        state,
        DistributionEngine.removeReservation(
          entries: state.moneyDistributions,
          jarId: jarId,
          walletId: walletId,
          amount: amount,
          knownWalletIds: state.wallets.map((wallet) => wallet.id).toSet(),
        ),
      ),
    );
  }

  Future<void> transferMoneyDistribution({
    required String jarId,
    required String fromWalletId,
    required String toWalletId,
    required double amount,
  }) async {
    final jar = state.budgetSetup.linkedWallets
        .where((item) => item.id == jarId)
        .firstOrNull;
    if (jar == null) return;

    await _applyAndLog(
      action: 'edit',
      entityType: 'money-distribution',
      entityId: jarId,
      details: 'تم نقل مكان الفلوس',
      apply: () async => _withMoneyDistributions(
        state,
        DistributionEngine.transferReservation(
          entries: state.moneyDistributions,
          jarId: jarId,
          fromWalletId: fromWalletId,
          toWalletId: toWalletId,
          amount: amount,
          jarBalance: jar.balance,
          knownWalletIds: state.wallets.map((wallet) => wallet.id).toSet(),
        ),
      ),
    );
  }

  Future<void> moveMoneyDistributionEntry({
    required String entryId,
    required String toWalletId,
  }) async {
    await _applyAndLog(
      action: 'edit',
      entityType: 'money-distribution',
      entityId: entryId,
      details: 'تم نقل مكان الفلوس',
      apply: () async => _withMoneyDistributions(
        state,
        DistributionEngine.moveEntry(
          entries: state.moneyDistributions,
          entryId: entryId,
          toWalletId: toWalletId,
          knownWalletIds: state.wallets.map((wallet) => wallet.id).toSet(),
        ),
      ),
    );
  }

  Future<void> editMoneyDistributionEntryAmount({
    required String entryId,
    required double amount,
  }) async {
    final entry =
        state.moneyDistributions.where((item) => item.id == entryId).toList();
    if (entry.isEmpty) return;
    final jar = state.budgetSetup.linkedWallets
        .where((item) => item.id == entry.first.jarId)
        .firstOrNull;
    if (jar == null) return;

    await _applyAndLog(
      action: 'edit',
      entityType: 'money-distribution',
      entityId: entryId,
      details: 'تم تعديل مكان الفلوس',
      apply: () async => _withMoneyDistributions(
        state,
        DistributionEngine.editEntryAmount(
          entries: state.moneyDistributions,
          entryId: entryId,
          amount: amount,
          jarBalance: jar.balance,
        ),
      ),
    );
  }

  Future<void> deleteMoneyDistributionEntry(String entryId) async {
    await _applyAndLog(
      action: 'delete',
      entityType: 'money-distribution',
      entityId: entryId,
      details: 'تم حذف مكان الفلوس',
      apply: () async => _withMoneyDistributions(
        state,
        DistributionEngine.deleteEntry(
          entries: state.moneyDistributions,
          entryId: entryId,
        ),
      ),
    );
  }

  /// يحل (يحذف) عنصر مراجعة مكان فلوس من حصالة معينة.
  ///
  /// يُستخدم بعد مراجعة المستخدم للتعارض وتصحيحه يدوياً، أو تجاهله.
  /// لا يُعدَّل jar.balance أو wallet.balance.
  Future<void> resolveMoneyLocationReview({
    required String jarId,
    required String reviewId,
  }) async {
    final jars = List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
    final idx = jars.indexWhere((j) => j.id == jarId);
    if (idx == -1) return;

    jars[idx] = MoneyLocationEngine.resolveReview(
      jar: jars[idx],
      reviewId: reviewId,
    );

    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: jars),
    );
  }

  /// بعد كل حفظ في مدير مكان الفلوس: يُعيد حساب التوزيع لكل نوع مراجعة.
  ///
  /// كل نوع مراجعة له شرط تحقق خاص به:
  /// - labeled-exceeds-balance  → يُحلّ عندما يكون الإجمالي المعروف ≤ رصيد الحصالة
  /// - source-went-negative     → يُحلّ عندما لا يوجد أي entry بمبلغ سالب
  /// - spending-wallet-mismatch → يُحلّ عندما يوجد تخصيص واحد على الأقل (totalKnown > 0)
  ///
  /// لا يُعدَّل jar.balance أو wallet.balance أو أي رصيد مالي.
  Future<void> autoResolveReviewsIfConsistent(String jarId) async {
    final jar =
        state.budgetSetup.linkedWallets.where((j) => j.id == jarId).firstOrNull;
    if (jar == null || jar.moneyLocationReviews.isEmpty) return;

    final snapshot = DistributionEngine.snapshotForJar(
      entries: state.moneyDistributions,
      jarId: jarId,
      jarBalance: jar.balance,
    );

    bool isInconsistencyResolved(MoneyLocationReview review) {
      switch (review.type) {
        case 'labeled-exceeds-balance':
          return !snapshot.knownExceedsBalance;
        case 'source-went-negative':
          return snapshot.entries.every((e) => e.amount > 0);
        case 'spending-wallet-mismatch':
          return snapshot.known > 0 || snapshot.unknown > 0;
        default:
          return false;
      }
    }

    var updatedJar = jar;
    var anyResolved = false;
    for (final review in List.of(jar.moneyLocationReviews)) {
      if (isInconsistencyResolved(review)) {
        updatedJar = MoneyLocationEngine.resolveReview(
          jar: updatedJar,
          reviewId: review.id,
        );
        anyResolved = true;
      }
    }
    if (!anyResolved) return;

    final jars = state.budgetSetup.linkedWallets
        .map((j) => j.id == jarId ? updatedJar : j)
        .toList();
    await updateBudgetSetup(state.budgetSetup.copyWith(linkedWallets: jars));
  }

  Future<void> addLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(state.budgetSetup.copyWith(
        linkedWallets: [...state.budgetSetup.linkedWallets, linkedWallet]));
  }

  Future<void> updateLinkedWallet(LinkedWalletEntity linkedWallet) async {
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .map((item) => item.id == linkedWallet.id ? linkedWallet : item)
            .toList(),
      ),
    );
  }

  /// تأكيد توزيع الراتب على حصالة "يحتاج تأكيد"
  Future<void> confirmJarDistribution(String jarId) async {
    final jars = List<LinkedWalletEntity>.from(state.budgetSetup.linkedWallets);
    final idx = jars.indexWhere((j) => j.id == jarId);
    if (idx == -1) return;
    final jar = jars[idx];
    final amount = jar.pendingDistribution;
    if (amount <= 0) return;
    final isPhysical = _isJarPendingPhysical(jar);

    final clearedPending = jars
        .map((item) => item.id == jarId
            ? item.copyWith(
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
                pendingDistributionSnoozedUntil: '',
              )
            : item)
        .toList();
    final stagedState = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: clearedPending),
    );

    emit(stagedState);
    await _repository.saveState(stagedState);

    final historyTitle = isPhysical
        ? jarPhysicalConfirmTitle(jarName: jar.name)
        : jarAllocationConfirmTitle(jarName: jar.name);
    final historyMessage = isPhysical
        ? jarPhysicalConfirmMessage(amount: amount, jarName: jar.name)
        : jarAllocationConfirmMessage(amount: amount, jarName: jar.name);

    await addTransaction(
      walletId: jar.pendingDistributionWalletId.isNotEmpty
          ? jar.pendingDistributionWalletId
          : null,
      fromWalletId: !isPhysical && jar.pendingDistributionWalletId.isNotEmpty
          ? jar.pendingDistributionWalletId
          : null,
      toWalletId: jar.id,
      amount: amount,
      type: isPhysical
          ? TransactionType.expense.value
          : TransactionType.transfer.value,
      budgetScope: BudgetScope.withinBudget.value,
      incomeSourceId: jar.pendingDistributionSourceId.isNotEmpty
          ? jar.pendingDistributionSourceId
          : null,
      transferType: isPhysical
          ? TransferType.jarFundingPhysical.value
          : TransferType.jarFunding.value,
      notes: null,
      details: historyMessage,
      notificationTitleOverride: historyTitle,
      recordInNotificationHistory: true,
    );
  }

  /// تأجيل (إلغاء) توزيع معلّق على حصالة
  Future<void> postponeJarDistribution(String jarId) async {
    final jar = state.budgetSetup.linkedWallets.firstWhere(
      (j) => j.id == jarId,
      orElse: () => state.budgetSetup.linkedWallets.first,
    );
    final amount = jar.pendingDistribution;
    final jars = state.budgetSetup.linkedWallets
        .map((j) => j.id == jarId
            ? j.copyWith(
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
                pendingDistributionSnoozedUntil: '',
              )
            : j)
        .toList();
    final historyTitle = jarAllocationSkipTitle(jarName: jar.name);
    final historyMessage =
        jarAllocationSkipMessage(amount: amount, jarName: jar.name);
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(linkedWallets: jars),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'jar',
      entityId: jarId,
      details: historyMessage,
      titleOverride: historyTitle,
      recordInNotificationHistory: true,
      apply: () async => next,
    );
  }

  /// تأكيد توزيع الراتب على مخصصة "يحتاج تأكيد"
  Future<void> confirmAllocationDistribution(String allocationId) async {
    final allocations =
        List<AllocationEntity>.from(state.budgetSetup.allocations);
    final idx = allocations.indexWhere((a) => a.id == allocationId);
    if (idx == -1) return;
    final alloc = allocations[idx];
    final amount = alloc.pendingDistribution;
    if (amount <= 0) return;

    final nextBalances = Map<String, double>.from(alloc.walletBalances);
    if (alloc.pendingDistributionWalletId.isNotEmpty) {
      nextBalances[alloc.pendingDistributionWalletId] =
          (nextBalances[alloc.pendingDistributionWalletId] ?? 0) + amount;
    }
    allocations[idx] = alloc.copyWith(
      balance: alloc.balance + amount,
      walletBalances: nextBalances,
      pendingDistribution: 0,
      pendingDistributionWalletId: '',
      pendingDistributionSourceId: '',
      pendingDistributionSnoozedUntil: '',
    );

    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(allocations: allocations),
    );
    final historyTitle = allocationConfirmTitle(name: alloc.name);
    final historyMessage =
        allocationConfirmMessage(amount: amount, name: alloc.name);
    await _applyAndLog(
      action: 'edit',
      entityType: 'allocation',
      entityId: allocationId,
      details: historyMessage,
      titleOverride: historyTitle,
      recordInNotificationHistory: true,
      apply: () async => next,
    );
  }

  /// تأجيل (إلغاء) توزيع معلّق على مخصصة
  Future<void> postponeAllocationDistribution(String allocationId) async {
    final alloc = state.budgetSetup.allocations.firstWhere(
      (a) => a.id == allocationId,
      orElse: () => state.budgetSetup.allocations.first,
    );
    final amount = alloc.pendingDistribution;
    final allocations = state.budgetSetup.allocations
        .map((a) => a.id == allocationId
            ? a.copyWith(
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
                pendingDistributionSnoozedUntil: '',
              )
            : a)
        .toList();
    final next = state.copyWith(
      budgetSetup: state.budgetSetup.copyWith(allocations: allocations),
    );
    final historyTitle = allocationSkipTitle(name: alloc.name);
    final historyMessage =
        allocationSkipMessage(amount: amount, name: alloc.name);
    await _applyAndLog(
      action: 'edit',
      entityType: 'allocation',
      entityId: allocationId,
      details: historyMessage,
      titleOverride: historyTitle,
      recordInNotificationHistory: true,
      apply: () async => next,
    );
  }

  Future<void> snoozeAllocationDistribution(
    String allocationId,
    DateTime until,
  ) async {
    final allocations = state.budgetSetup.allocations
        .map(
          (a) => a.id == allocationId
              ? a.copyWith(
                  pendingDistributionSnoozedUntil: until.toIso8601String(),
                )
              : a,
        )
        .toList();
    await updateBudgetSetup(
      state.budgetSetup.copyWith(allocations: allocations),
    );
  }

  Future<void> snoozeJarDistribution(String jarId, DateTime until) async {
    final jars = state.budgetSetup.linkedWallets
        .map(
          (j) => j.id == jarId
              ? j.copyWith(
                  pendingDistributionSnoozedUntil: until.toIso8601String(),
                )
              : j,
        )
        .toList();
    await updateBudgetSetup(
      state.budgetSetup.copyWith(linkedWallets: jars),
    );
  }

  bool _isJarPendingPhysical(LinkedWalletEntity jar) {
    final sourceId = jar.pendingDistributionSourceId;
    if (sourceId.isEmpty) return false;
    return jar.funding.any(
      (entry) => entry.incomeSourceId == sourceId && entry.isPhysical,
    );
  }

  /// تحديث مصادر الحصالة (label فقط — بدون تغيير الرصيد أو إنشاء transaction)

  Future<void> deleteLinkedWallet(String id) async {
    if (id == 'linked-savings-default') {
      return;
    }
    await updateBudgetSetup(
      state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .where((wallet) => wallet.id != id)
            .toList(),
      ),
    );
  }

  Future<void> setCategories(List<CategoryEntity> categories) async {
    final next = state.copyWith(categories: categories);
    await _applyAndLog(
      action: 'edit',
      entityType: 'category',
      entityId: 'categories',
      details: 'تم تحديث الفئات',
      apply: () async => next,
    );
  }

  Future<void> updateAllocationCategories({
    required String allocationId,
    required List<CategoryEntity> categories,
  }) async {
    final allocations = state.budgetSetup.allocations
        .map((item) => item.id == allocationId
            ? item.copyWith(categories: categories)
            : item)
        .toList();
    await updateBudgetSetup(
        state.budgetSetup.copyWith(allocations: allocations));
  }

  Future<void> updateLinkedWalletCategories({
    required String linkedWalletId,
    required List<CategoryEntity> categories,
  }) async {
    final linkedWallets = state.budgetSetup.linkedWallets
        .map((item) => item.id == linkedWalletId
            ? item.copyWith(categories: categories)
            : item)
        .toList();
    await updateBudgetSetup(
        state.budgetSetup.copyWith(linkedWallets: linkedWallets));
  }

  Future<void> updateSettings({
    String? userName,
    String? currencyCode,
    bool? notificationsEnabled,
    String? googleEmail,
    String? backupDirectoryPath,
    String? autoBackupMode,
    String? profileImageUrl,
  }) async {
    final next = state.copyWith(
      userName: userName,
      currencyCode: currencyCode,
      notificationsEnabled: notificationsEnabled,
      googleEmail: googleEmail,
      backupDirectoryPath: backupDirectoryPath,
      autoBackupMode: autoBackupMode,
      profileImageUrl: profileImageUrl,
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'settings',
      entityId: 'app-settings',
      details: 'تم تعديل إعدادات التطبيق',
      apply: () async => next,
    );
  }

  Future<void> updateAutoBackupTimestamp(DateTime at) async {
    final next = state.copyWith(lastAutoBackupAt: at.toIso8601String());
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }

  Future<void> addRecurringTransaction({
    String? id,
    required String name,
    required String type,
    required double amount,
    required int dayOfMonth,
    required String executionType,
    required String walletId,
    required String budgetScope,
    required String recurrencePattern,
    required String icon,
    required String iconColor,
    int? weekday,
    List<int>? weekdays,
    int? monthOfYear,
    String? anchorDate,
    String? scheduledTime,
    int? reminderLeadDays,
    String? allocationId,
    String? targetJarId,
    String? incomeSourceId,
    List<String>? categoryIds,
    bool isVariableIncome = false,
    bool isDebtOrSubscription = false,
    String? expensePlanKind,
    double? debtPrincipalTotal,
    int? installmentCount,
    double? installmentDownPayment,
    String? notes,
  }) async {
    final recurring = RecurringTransactionEntity(
      id: id ?? _id('rec'),
      name: name,
      type: type,
      amount: amount,
      dayOfMonth: dayOfMonth,
      executionType: executionType,
      walletId: walletId,
      budgetScope: budgetScope,
      recurrencePattern: recurrencePattern,
      icon: icon,
      iconColor: iconColor,
      weekday: weekday,
      weekdays: weekdays ?? const [],
      monthOfYear: monthOfYear,
      anchorDate: anchorDate,
      scheduledTime: scheduledTime,
      reminderLeadDays: reminderLeadDays,
      allocationId: allocationId,
      targetJarId: targetJarId,
      incomeSourceId: incomeSourceId,
      categoryIds: categoryIds ?? const [],
      isVariableIncome: isVariableIncome,
      isDebtOrSubscription: isDebtOrSubscription,
      expensePlanKind: expensePlanKind,
      debtPrincipalTotal: debtPrincipalTotal,
      installmentCount: installmentCount,
      installmentDownPayment: installmentDownPayment,
      notes: notes,
    );

    // زامن DebtEntity في budget.debts عند إضافة اشتراك/دين من خارج شاشة الميزانية
    final alreadyLinked = state.budgetSetup.debts
        .any((d) => d.recurringTransactionId == recurring.id);
    final nextBudget = (isDebtOrSubscription && !alreadyLinked)
        ? state.budgetSetup.copyWith(debts: [
            ...state.budgetSetup.debts,
            DebtEntity(
              id: 'debt-${recurring.id}',
              name: recurring.name,
              amount: recurring.amount,
              executionDay: recurring.dayOfMonth.clamp(1, 28),
              type: recurring.executionType,
              fundingSource: state.budgetSetup.incomeSources.isNotEmpty
                  ? state.budgetSetup.incomeSources.first.id
                  : '',
              recurringTransactionId: recurring.id,
              kind:
                  recurring.expensePlanKind == ExpensePlanKind.installment.value
                      ? ExpensePlanKind.installment.value
                      : ExpensePlanKind.subscription.value,
              principalTotal: recurring.debtPrincipalTotal,
              installmentCount: recurring.installmentCount,
              downPayment: recurring.installmentDownPayment,
              recurrencePattern: recurring.recurrencePattern,
              monthOfYear: recurring.monthOfYear,
            ),
          ])
        : state.budgetSetup;

    final next = state.copyWith(
      recurringTransactions: [...state.recurringTransactions, recurring],
      budgetSetup: nextBudget,
    );
    await _applyAndLog(
      action: 'add',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: _recurringTransactionDetails('إضافة معاملة متكررة', recurring),
      apply: () async => next,
    );
  }

  Future<void> updateRecurringTransaction(
    RecurringTransactionEntity recurring, {
    String? detailsOverride,
  }) async {
    final next = _applyRecurringSync(state, recurring);
    await _applyAndLog(
      action: 'edit',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: detailsOverride ??
          _recurringTransactionDetails('تعديل معاملة متكررة', recurring),
      titleOverride: recurring.name,
      apply: () async => next,
    );
  }

  AppStateEntity _applyRecurringSync(
    AppStateEntity source,
    RecurringTransactionEntity recurring,
  ) {
    BudgetSetupEntity nextBudget = source.budgetSetup;
    if (recurring.isDebtOrSubscription) {
      final linkedIndex = source.budgetSetup.debts
          .indexWhere((d) => d.recurringTransactionId == recurring.id);
      if (linkedIndex >= 0) {
        final existing = source.budgetSetup.debts[linkedIndex];
        final updated = existing.copyWith(
          name: recurring.name,
          amount: recurring.amount,
          executionDay: recurring.dayOfMonth.clamp(1, 28),
          type: recurring.executionType,
          kind: recurring.expensePlanKind == ExpensePlanKind.installment.value
              ? ExpensePlanKind.installment.value
              : ExpensePlanKind.subscription.value,
          principalTotal: recurring.debtPrincipalTotal,
          installmentCount: recurring.installmentCount,
          downPayment: recurring.installmentDownPayment,
          recurrencePattern: recurring.recurrencePattern,
          monthOfYear: recurring.monthOfYear,
        );
        final updatedDebts = List<DebtEntity>.from(source.budgetSetup.debts)
          ..[linkedIndex] = updated;
        nextBudget = source.budgetSetup.copyWith(debts: updatedDebts);
      }
    }
    return source.copyWith(
      recurringTransactions: source.recurringTransactions
          .map((item) => item.id == recurring.id ? recurring : item)
          .toList(),
      budgetSetup: nextBudget,
    );
  }

  Future<void> recordRecurringIncomeOccurrence({
    required RecurringTransactionEntity recurring,
    required double amount,
    required DateTime occurrence,
    required String transactionNotes,
    required String logDetails,
    String? titleOverride,
  }) async {
    final jarId = recurring.targetJarId?.trim();
    final hasJarTarget = jarId != null && jarId.isNotEmpty;
    final incomeSourceId = recurring.incomeSourceId?.trim();
    final hasBudgetSource = incomeSourceId != null && incomeSourceId.isNotEmpty;

    final transaction = TransactionEntity(
      id: _id('txn'),
      walletId: recurring.walletId,
      toWalletId: hasJarTarget ? jarId : null,
      amount: amount,
      type: TransactionType.income.value,
      budgetScope: hasBudgetSource
          ? BudgetScope.withinBudget.value
          : BudgetScope.outsideBudget.value,
      incomeSourceId: hasBudgetSource ? incomeSourceId : null,
      transferType:
          hasJarTarget ? TransferType.depositWithJarLabel.value : null,
      categoryId:
          recurring.categoryIds.isNotEmpty ? recurring.categoryIds.first : null,
      notes:
          transactionNotes.trim().isEmpty ? recurring.name : transactionNotes,
      createdAt: DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
        occurrence.hour,
        occurrence.minute,
      ),
    );

    final updatedRecurring = recurring.copyWith(
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );

    await _applyAndLog(
      action: 'add',
      entityType: 'recurring-income-handled',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? logDetails,
      recordInNotificationHistory: true,
      apply: () async {
        final stateAfterTx = TransactionProcessor.apply(state, transaction);
        return _applyRecurringSync(stateAfterTx, updatedRecurring);
      },
    );
  }

  Future<void> recordRecurringExpenseOccurrence({
    required RecurringTransactionEntity recurring,
    required double amount,
    required DateTime occurrence,
    required String transactionNotes,
    required String logDetails,
    String? titleOverride,
  }) async {
    final transaction = TransactionEntity(
      id: _id('txn'),
      walletId: recurring.walletId,
      amount: amount,
      type: TransactionType.expense.value,
      budgetScope: recurring.budgetScope,
      allocationId: recurring.allocationId,
      categoryId:
          recurring.categoryIds.isNotEmpty ? recurring.categoryIds.first : null,
      notes: transactionNotes,
      createdAt: DateTime.now(),
    );

    final updatedRecurring = recurring.copyWith(
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );

    await _applyAndLog(
      action: 'add',
      entityType: 'recurring-expense-handled',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? logDetails,
      recordInNotificationHistory: true,
      apply: () async {
        // 1. Add physical transaction (updates balance/allocations)
        final stateAfterTx = TransactionProcessor.apply(state, transaction);
        // 2. Update recurring state & sync debt in one go
        return _applyRecurringSync(stateAfterTx, updatedRecurring);
      },
    );
  }

  Future<void> recordRecurringPostpone({
    required RecurringTransactionEntity recurring,
    required DateTime snoozedUntil,
    required String logDetails,
    String? titleOverride,
  }) async {
    final updatedRecurring = recurring.copyWith(
      snoozedUntil: snoozedUntil.toIso8601String(),
    );

    await _applyAndLog(
      action: 'edit',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? logDetails,
      recordInNotificationHistory: true,
      apply: () async => _applyRecurringSync(state, updatedRecurring),
    );
  }

  Future<void> recordRecurringSkip({
    required RecurringTransactionEntity recurring,
    required DateTime occurrence,
    required String logDetails,
    String? titleOverride,
  }) async {
    final updatedRecurring = recurring.copyWith(
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );

    await _applyAndLog(
      action: 'skip',
      entityType: 'recurring-transaction',
      entityId: recurring.id,
      details: logDetails,
      titleOverride: titleOverride ?? logDetails,
      recordInNotificationHistory: true,
      apply: () async => _applyRecurringSync(state, updatedRecurring),
    );
  }

  // ── سلفة: أضف سجل سلفة وأخصم من المحفظة فوراً ──────────────────────────
  Future<void> addLentRecord({
    required String personName,
    required double amount,
    required String walletId,
    required DateTime expectedReturnDate,
    DateTime? lentDate,
    bool isMonthlyInstallments = false,
    String? existingPersonId,
    String? notes,
  }) async {
    final effectiveLentDate = lentDate ?? DateTime.now();
    final walletName = state.wallets
        .where((w) => w.id == walletId)
        .map((w) => w.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    final entryId = _id('lent-entry');
    final newEntry = <String, dynamic>{
      'id': entryId,
      'amount': amount,
      'lentDate': effectiveLentDate.toIso8601String(),
      'expectedReturnDate': expectedReturnDate.toIso8601String(),
      'notes': notes,
      'isSettled': false,
    };

    final txn = TransactionEntity(
      id: _id('txn'),
      walletId: walletId,
      amount: amount,
      type: TransactionType.expense.value,
      notes: 'سلفة لـ $personName',
      createdAt: effectiveLentDate,
    );

    List<RecurringTransactionEntity> updatedList;
    String personId;

    final existing = existingPersonId != null
        ? state.recurringTransactions
            .where((r) => r.id == existingPersonId)
            .cast<RecurringTransactionEntity?>()
            .firstWhere((_) => true, orElse: () => null)
        : null;

    if (existing != null) {
      personId = existing.id;
      final updatedPerson = existing.copyWith(
        walletId: walletId,
        lentEntries: [...existing.lentEntries, newEntry],
        isLentArchived: false,
        amount: existing.outstandingLentAmount + amount,
      );
      updatedList = state.recurringTransactions
          .map((r) => r.id == personId ? updatedPerson : r)
          .toList();
    } else {
      personId = _id('rec');
      final person = RecurringTransactionEntity(
        id: personId,
        name: personName,
        type: TransactionType.expense.value,
        amount: amount,
        dayOfMonth: 1,
        executionType: AutomationType.confirm.value,
        walletId: walletId,
        budgetScope: BudgetScope.outsideBudget.value,
        recurrencePattern: RecurrencePattern.manualVariable.value,
        icon: 'handshake',
        iconColor: '#1a7a4a',
        isLent: true,
        lentPersonName: personName,
        lentEntries: [newEntry],
      );
      updatedList = [...state.recurringTransactions, person];
    }

    await _applyAndLog(
      action: 'add',
      entityType: 'lent-record',
      entityId: personId,
      details:
          'سلفة لـ $personName بمبلغ ${amount.toStringAsFixed(2)} من ${walletName ?? walletId}',
      titleOverride: personName,
      apply: () async {
        final stateAfterTx = TransactionProcessor.apply(state, txn);
        return stateAfterTx.copyWith(recurringTransactions: updatedList);
      },
    );
  }

  // ── سلفة: استرداد سلفة فردية ────────────────────────────────────────────
  Future<void> settleLentEntry(String personId, String entryId) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;

    final entry = person.lentEntries
        .where((e) => e['id'] == entryId)
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);
    if (entry == null) return;

    final entryAmount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final updatedEntries = person.lentEntries
        .map((e) => e['id'] == entryId ? {...e, 'isSettled': true} : e)
        .toList();
    final allSettled = updatedEntries.every((e) => e['isSettled'] == true);
    final updatedPerson = person.copyWith(
      lentEntries: updatedEntries,
      amount: (person.outstandingLentAmount - entryAmount)
          .clamp(0, double.infinity),
      isLentArchived: allSettled,
    );

    final txn = TransactionEntity(
      id: _id('txn'),
      walletId: person.walletId,
      amount: entryAmount,
      type: TransactionType.income.value,
      notes: 'استرداد سلفة من ${person.lentPersonName ?? person.name}',
      createdAt: DateTime.now(),
    );

    final updatedList = state.recurringTransactions
        .map((r) => r.id == personId ? updatedPerson : r)
        .toList();

    await _applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          'استرداد سلفة من ${person.lentPersonName ?? person.name} بمبلغ ${entryAmount.toStringAsFixed(2)}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async {
        final stateAfterTx = TransactionProcessor.apply(state, txn);
        return stateAfterTx.copyWith(recurringTransactions: updatedList);
      },
    );
  }

  // ── سلفة: تنازل عن سلفة فردية ──────────────────────────────────────────
  Future<void> writeOffLentEntry(String personId, String entryId) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;

    final entryAmount = (person.lentEntries
                .where((e) => e['id'] == entryId)
                .cast<Map<String, dynamic>?>()
                .firstWhere((_) => true, orElse: () => null)?['amount'] as num?)
            ?.toDouble() ??
        0;

    final updatedEntries = person.lentEntries
        .map((e) => e['id'] == entryId ? {...e, 'isSettled': true} : e)
        .toList();
    final allSettled = updatedEntries.every((e) => e['isSettled'] == true);
    final updatedPerson = person.copyWith(
      lentEntries: updatedEntries,
      amount: (person.outstandingLentAmount - entryAmount)
          .clamp(0, double.infinity),
      isLentArchived: allSettled,
    );
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((r) => r.id == personId ? updatedPerson : r)
          .toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          'تنازل عن سلفة ${person.lentPersonName ?? person.name} بمبلغ ${entryAmount.toStringAsFixed(2)}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  // ── سلفة: تأجيل موعد سلفة فردية ─────────────────────────────────────────
  Future<void> postponeLentEntry(
      String personId, String entryId, DateTime newDate) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final updatedEntries = person.lentEntries
        .map((e) => e['id'] == entryId
            ? {...e, 'expectedReturnDate': newDate.toIso8601String()}
            : e)
        .toList();
    final updatedPerson = person.copyWith(lentEntries: updatedEntries);
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((r) => r.id == personId ? updatedPerson : r)
          .toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          'تأجيل سلفة ${person.lentPersonName ?? person.name} إلى ${newDate.day}/${newDate.month}/${newDate.year}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  // ── سلفة: أرشفة / إلغاء أرشفة شخص ─────────────────────────────────────
  Future<void> archiveLentPerson(String personId, {bool archive = true}) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final updated = person.copyWith(isLentArchived: archive);
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((r) => r.id == personId ? updated : r)
          .toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details: archive
          ? 'أرشفة ${person.lentPersonName ?? person.name}'
          : 'إلغاء أرشفة ${person.lentPersonName ?? person.name}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  // ── Legacy stubs — implemented to delegate to per-entry methods ──────────
  Future<void> settleLentRecord(String personId) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final outstanding =
        person.lentEntries.where((e) => e['isSettled'] != true).toList();
    for (final entry in outstanding) {
      final entryId = entry['id'] as String?;
      if (entryId != null) await settleLentEntry(personId, entryId);
    }
  }

  Future<void> writeOffLentRecord(String personId) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final outstanding =
        person.lentEntries.where((e) => e['isSettled'] != true).toList();
    for (final entry in outstanding) {
      final entryId = entry['id'] as String?;
      if (entryId != null) await writeOffLentEntry(personId, entryId);
    }
  }

  Future<void> postponeLentRecord(String personId, DateTime newDate) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final outstanding =
        person.lentEntries.where((e) => e['isSettled'] != true).toList();
    for (final entry in outstanding) {
      final entryId = entry['id'] as String?;
      if (entryId != null) await postponeLentEntry(personId, entryId, newDate);
    }
  }

  Future<void> deleteRecurringTransaction(String id) async {
    final target =
        state.recurringTransactions.where((item) => item.id == id).toList();
    final deleted = target.isEmpty ? null : target.first;

    // احذف DebtEntity المرتبط لو وُجد
    final nextBudget = state.budgetSetup.copyWith(
      debts: state.budgetSetup.debts
          .where((d) => d.recurringTransactionId != id)
          .toList(),
    );

    final next = state.copyWith(
      recurringTransactions:
          state.recurringTransactions.where((item) => item.id != id).toList(),
      budgetSetup: nextBudget,
    );
    await _applyAndLog(
      action: 'delete',
      entityType: 'recurring-transaction',
      entityId: id,
      details: deleted == null
          ? 'تم حذف معاملة متكررة'
          : _recurringTransactionDetails('حذف معاملة متكررة', deleted),
      apply: () async => next,
    );
  }

  String _transactionTypeLabel(String type) {
    if (type == TransactionType.income.value) return 'دخل';
    if (type == TransactionType.expense.value) return 'مصروف';
    if (type == TransactionType.transfer.value) return 'تحويل';
    return type;
  }

  String _executionTypeLabel(String type) {
    if (type == AutomationType.auto.value) return 'تلقائي';
    if (type == AutomationType.confirm.value) return 'يحتاج تأكيد';
    if (type == AutomationType.manual.value) return 'يدوي';
    return type;
  }

  String _budgetScopeLabel(String scope) {
    return scope == BudgetScope.withinBudget.value
        ? 'داخل الميزانية'
        : 'خارج الميزانية';
  }

  String _recurrenceLabel(String pattern) {
    if (pattern == RecurrencePattern.daily.value) return 'يومي';
    if (pattern == RecurrencePattern.weekly.value) return 'أسبوعي';
    if (pattern == RecurrencePattern.biweekly.value) return 'كل أسبوعين';
    if (pattern == RecurrencePattern.every3Weeks.value) return 'كل 3 أسابيع';
    if (pattern == RecurrencePattern.monthly.value) return 'شهري';
    if (pattern == RecurrencePattern.every2Months.value) return 'كل شهرين';
    if (pattern == RecurrencePattern.every3Months.value) return 'كل 3 شهور';
    if (pattern == RecurrencePattern.every6Months.value) return 'كل 6 شهور';
    if (pattern == RecurrencePattern.yearly.value) return 'سنوي';
    if (pattern == RecurrencePattern.manualVariable.value) return 'يدوي متغير';
    return pattern;
  }

  String _recurringTransactionDetails(
    String action,
    RecurringTransactionEntity recurring,
  ) {
    final type = _transactionTypeLabel(recurring.type);
    final amount = recurring.isVariableIncome
        ? 'دخل متغير'
        : recurring.amount.toStringAsFixed(2);
    final debtLabel = recurring.isDebtOrSubscription
        ? recurring.expensePlanKind == ExpensePlanKind.installment.value
            ? ' · تقسيط'
            : recurring.expensePlanKind == ExpensePlanKind.subscription.value
                ? ' · اشتراك'
                : ' · دين أو اشتراك'
        : '';
    return '$action: ${recurring.name} · النوع: $type · القيمة: $amount · التكرار: ${_recurrenceLabel(recurring.recurrencePattern)} · التنفيذ: ${_executionTypeLabel(recurring.executionType)} · ${_budgetScopeLabel(recurring.budgetScope)}$debtLabel';
  }

  Future<void> ensureDefaultSavingsJar() async {
    final next = _ensureDefaultSavingsJarSync(state);
    if (identical(next, state)) return;
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
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

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    required DateTime startDate,
    required DateTime endDate,
    String icon = 'savings',
    String iconColor = '#2f6f5e',
    String? notes,
  }) async {
    final goal = GoalEntity(
      id: _id('goal'),
      name: name,
      targetAmount: targetAmount,
      startDate: startDate,
      endDate: endDate,
      icon: icon,
      iconColor: iconColor,
      notes: notes,
    );
    final next = state.copyWith(goals: [...state.goals, goal]);
    await _applyAndLog(
      action: 'add',
      entityType: 'goal',
      entityId: goal.id,
      details: 'تمت إضافة هدف: $name',
      apply: () async => next,
    );
  }

  Future<void> updateGoal(GoalEntity goal) async {
    final next = state.copyWith(
      goals:
          state.goals.map((item) => item.id == goal.id ? goal : item).toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'goal',
      entityId: goal.id,
      details: 'تم تعديل هدف',
      apply: () async => next,
    );
  }

  Future<void> deleteGoal(String id) async {
    final next = state.copyWith(
        goals: state.goals.where((item) => item.id != id).toList());
    await _applyAndLog(
      action: 'delete',
      entityType: 'goal',
      entityId: id,
      details: 'تم حذف هدف',
      apply: () async => next,
    );
  }

  String exportStateJson() => jsonEncode(state.toMap());

  Future<void> importStateJson(String jsonString) async {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    final next = _normalizeMoneyLocationState(AppStateEntity.fromMap(map));
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
    final remote = _normalizeMoneyLocationState(AppStateEntity.fromMap(remoteMap));
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

    final next = _normalizeMoneyLocationState(local.copyWith(
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

  Future<void> toggleLogRevert(String logId) async {
    final target = state.logs.where((log) => log.id == logId).toList();
    if (target.isEmpty) return;
    final log = target.first;

    final updatedLogs = state.logs
        .map((item) => item.id == logId
            ? item.copyWith(
                isReverted: !item.isReverted,
                revertedAt: item.isReverted ? null : DateTime.now())
            : item)
        .toList();

    final restored = _restoreFromCore(
        log.isReverted ? log.afterState : log.beforeState, updatedLogs);
    final revertLog = LogEntryEntity(
      id: _id('log'),
      action: 'revert',
      entityType: log.entityType,
      entityId: log.entityId,
      details: log.isReverted
          ? 'تم التراجع عن التراجع'
          : 'تم التراجع عن العملية الأصلية',
      timestamp: DateTime.now(),
      beforeState: jsonEncode(_coreMap(state.copyWith(logs: updatedLogs))),
      afterState: jsonEncode(_coreMap(restored)),
      isReverted: false,
    );
    final revertNotification = NotificationEntity(
      id: _id('notif'),
      title: 'إشعار تراجع',
      message: revertLog.details,
      createdAt: DateTime.now(),
      type: 'revert-system', // Changed to hide from history UI
      relatedLogId: revertLog.id,
    );
    final next = restored.copyWith(
      logs: [revertLog, ...updatedLogs].take(600).toList(),
      notifications:
          [revertNotification, ...state.notifications].take(800).toList(),
    );
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }

  Future<void> markNotificationRead(String notificationId) async {
    final updated = state.notifications
        .map((n) => n.id == notificationId && !n.isRead
            ? n.copyWith(readAt: DateTime.now())
            : n)
        .toList();
    final next = state.copyWith(notifications: updated);
    await _repository.saveState(next);
    emit(next);
    _autoSync(next);
  }
}
