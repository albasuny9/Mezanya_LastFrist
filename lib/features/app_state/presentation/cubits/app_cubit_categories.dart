part of 'app_cubit.dart';

mixin AppCubitCategoriesMixin on AppCubitBase {
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
}
