part of 'app_cubit.dart';

mixin AppCubitWalletsMixin on AppCubitBase {
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
}
