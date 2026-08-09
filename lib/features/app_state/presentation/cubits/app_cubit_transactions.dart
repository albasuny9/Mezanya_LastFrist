part of 'app_cubit.dart';

mixin AppCubitTransactionsMixin on AppCubitBase {
  @override
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

    final defaultTitle = type == TransactionType.income.value
        ? 'دخل'
        : type == TransactionType.balanceAdjustment.value
            ? 'تسوية رصيد'
            : 'مصروف';

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
                  : incomeName ?? walletName ?? defaultTitle))
          : (notes?.isNotEmpty == true
              ? notes
              : incomeName ?? walletName ?? defaultTitle),
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
    if (type == TransactionType.balanceAdjustment.value) {
      return 'تسوية رصيد بقيمة ${amount.toStringAsFixed(2)}';
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
          'تم حذف معاملة ${AuditLogService.transactionTypeLabel(transaction.type)} بقيمة ${transaction.amount.toStringAsFixed(2)}',
      apply: () async => next,
    );
  }
}
