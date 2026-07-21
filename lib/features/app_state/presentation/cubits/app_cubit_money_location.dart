part of 'app_cubit.dart';

mixin AppCubitMoneyLocationMixin on AppCubitBase {
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
}
