import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/app_state/domain/repositories/app_repository.dart';
import 'package:mezanya_app/features/app_state/presentation/cubits/app_cubit.dart';
import 'package:mezanya_app/features/wallets/domain/entities/wallet_entity.dart';

/// BUG-003 validation: simulates the exact save sequence performed by the
/// new `_openWalletToWalletEditor` (transaction_details_sheet.dart) —
/// delete the old transfer, then add a new one that carries the full
/// business identity (fromWalletId/toWalletId/transferType). Confirms wallet
/// balances stay correct across notes-only, amount, date/time, and
/// source/destination wallet edits, with no duplicate transfer created.
void main() {
  AppCubit buildCubit() {
    final walletA = const WalletEntity(id: 'w-a', name: 'A', balance: 1000);
    final walletB = const WalletEntity(id: 'w-b', name: 'B', balance: 500);
    final walletC = const WalletEntity(id: 'w-c', name: 'C', balance: 200);
    final initial = AppStateEntity.initial().copyWith(
      wallets: [walletA, walletB, walletC],
    );
    return AppCubit(_MemoryAppRepository(initial));
  }

  double balanceOf(AppCubit cubit, String id) =>
      cubit.state.wallets.firstWhere((w) => w.id == id).balance;

  test('notes-only edit preserves wallet effects (BUG-003 / BUG-001 fix)',
      () async {
    final cubit = buildCubit();
    await cubit.initialize();

    await cubit.addTransaction(
      type: TransactionType.transfer.value,
      amount: 100,
      fromWalletId: 'w-a',
      toWalletId: 'w-b',
      transferType: TransferType.walletToWallet.value,
      notes: 'تحويل بين المحافظ',
    );
    expect(balanceOf(cubit, 'w-a'), 900);
    expect(balanceOf(cubit, 'w-b'), 600);

    final created = cubit.state.transactions.single;

    // Simulate the editor's save handler: delete then re-add with the same
    // business identity, only Notes changed.
    await cubit.deleteTransaction(created.id);
    await cubit.addTransaction(
      fromWalletId: created.fromWalletId,
      toWalletId: created.toWalletId,
      amount: created.amount,
      type: TransactionType.transfer.value,
      transferType: TransferType.walletToWallet.value,
      notes: 'ملاحظة معدّلة',
      createdAt: created.createdAt,
    );

    expect(cubit.state.transactions.length, 1,
        reason: 'no duplicate transfer should exist after edit');
    expect(balanceOf(cubit, 'w-a'), 900,
        reason: 'source wallet balance must remain correctly debited');
    expect(balanceOf(cubit, 'w-b'), 600,
        reason: 'destination wallet balance must remain correctly credited');

    await cubit.close();
  });

  test('amount edit updates balances correctly', () async {
    final cubit = buildCubit();
    await cubit.initialize();

    await cubit.addTransaction(
      type: TransactionType.transfer.value,
      amount: 100,
      fromWalletId: 'w-a',
      toWalletId: 'w-b',
      transferType: TransferType.walletToWallet.value,
    );
    final created = cubit.state.transactions.single;

    await cubit.deleteTransaction(created.id);
    await cubit.addTransaction(
      fromWalletId: created.fromWalletId,
      toWalletId: created.toWalletId,
      amount: 250,
      type: TransactionType.transfer.value,
      transferType: TransferType.walletToWallet.value,
      createdAt: created.createdAt,
    );

    expect(cubit.state.transactions.length, 1);
    expect(balanceOf(cubit, 'w-a'), 750);
    expect(balanceOf(cubit, 'w-b'), 750);

    await cubit.close();
  });

  test('changing source and destination wallet reverses old effect and '
      'applies the new one', () async {
    final cubit = buildCubit();
    await cubit.initialize();

    await cubit.addTransaction(
      type: TransactionType.transfer.value,
      amount: 100,
      fromWalletId: 'w-a',
      toWalletId: 'w-b',
      transferType: TransferType.walletToWallet.value,
    );
    final created = cubit.state.transactions.single;
    expect(balanceOf(cubit, 'w-a'), 900);
    expect(balanceOf(cubit, 'w-b'), 600);
    expect(balanceOf(cubit, 'w-c'), 200);

    // Editor: change source from w-a to w-c, keep destination w-b.
    await cubit.deleteTransaction(created.id);
    await cubit.addTransaction(
      fromWalletId: 'w-c',
      toWalletId: 'w-b',
      amount: created.amount,
      type: TransactionType.transfer.value,
      transferType: TransferType.walletToWallet.value,
      createdAt: created.createdAt,
    );

    expect(cubit.state.transactions.length, 1);
    expect(balanceOf(cubit, 'w-a'), 1000, reason: 'old source fully reversed');
    expect(balanceOf(cubit, 'w-b'), 600, reason: 'destination unchanged');
    expect(balanceOf(cubit, 'w-c'), 100, reason: 'new source debited');

    await cubit.close();
  });

  test('date/time edit does not affect balances or duplicate the transfer',
      () async {
    final cubit = buildCubit();
    await cubit.initialize();

    await cubit.addTransaction(
      type: TransactionType.transfer.value,
      amount: 100,
      fromWalletId: 'w-a',
      toWalletId: 'w-b',
      transferType: TransferType.walletToWallet.value,
      createdAt: DateTime(2026, 1, 1, 9, 0),
    );
    final created = cubit.state.transactions.single;

    await cubit.deleteTransaction(created.id);
    await cubit.addTransaction(
      fromWalletId: created.fromWalletId,
      toWalletId: created.toWalletId,
      amount: created.amount,
      type: TransactionType.transfer.value,
      transferType: TransferType.walletToWallet.value,
      notes: created.notes,
      createdAt: DateTime(2026, 1, 5, 14, 30),
    );

    expect(cubit.state.transactions.length, 1);
    expect(cubit.state.transactions.single.createdAt, DateTime(2026, 1, 5, 14, 30));
    expect(balanceOf(cubit, 'w-a'), 900);
    expect(balanceOf(cubit, 'w-b'), 600);

    await cubit.close();
  });
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
