import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:mezanya_app/features/app_state/domain/entities/app_state_entity.dart';
import 'package:mezanya_app/features/budget/domain/entities/budget_setup_entity.dart';
import 'package:mezanya_app/features/transactions/domain/entities/transaction_entity.dart';
import 'package:mezanya_app/features/transactions/domain/services/transaction_processor.dart';
import 'package:mezanya_app/features/wallets/presentation/screens/jar_editor_screen.dart';

void main() {
  Future<JarEditorResult?> saveJar(
    WidgetTester tester, {
    LinkedWalletEntity? current,
    String? balanceText,
    String name = 'Travel',
  }) async {
    JarEditorResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await Navigator.of(context).push<JarEditorResult>(
                  MaterialPageRoute(
                    builder: (_) => JarEditorScreen(
                      current: current,
                      incomeSources: const [],
                      idFactory: (prefix) => '$prefix-1',
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), name);
    if (balanceText != null) {
      await tester.enterText(textFields.at(1), balanceText);
    }

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    return result;
  }

  const existingJar = LinkedWalletEntity(
    id: 'jar-1',
    name: 'Emergency',
    balance: 100,
    monthlyAmount: 25,
    executionDay: 5,
    fundingSource: '',
    funding: [],
    icon: 'savings',
    iconColor: '#0F766E',
    automationType: 'confirm',
    categories: [],
    walletBalances: {'wallet-1': 30},
    walletSources: [JarWalletSource(walletId: 'wallet-1', amount: 30)],
    isHighlighted: true,
    pendingDistribution: 12,
    pendingDistributionWalletId: 'wallet-1',
    pendingDistributionSourceId: 'income-1',
    pendingDistributionSnoozedUntil: '2026-08-09T10:00:00.000',
  );

  testWidgets('creates jar with default zero balance', (tester) async {
    final result = await saveJar(tester);

    expect(result?.entity?.id, 'linked-1');
    expect(result?.entity?.balance, 0);
    expect(result?.requestedBalance, 0);
  });

  testWidgets('returns entered initial balance without mutating jar directly',
      (tester) async {
    final result = await saveJar(tester, balanceText: '125.75');

    expect(result?.entity?.balance, 0);
    expect(result?.requestedBalance, 125.75);
  });

  testWidgets('returns edited balance without mutating jar directly',
      (tester) async {
    final result = await saveJar(
      tester,
      current: existingJar,
      balanceText: '250',
    );
    final entity = result?.entity;

    expect(entity?.id, existingJar.id);
    expect(entity?.balance, existingJar.balance);
    expect(result?.requestedBalance, 250);
    expect(entity?.walletBalances, existingJar.walletBalances);
    expect(entity?.walletSources, existingJar.walletSources);
    expect(entity?.isHighlighted, isTrue);
    expect(entity?.pendingDistribution, 12);
    expect(entity?.pendingDistributionWalletId, 'wallet-1');
    expect(entity?.pendingDistributionSourceId, 'income-1');
    expect(
      entity?.pendingDistributionSnoozedUntil,
      '2026-08-09T10:00:00.000',
    );
  });

  testWidgets('edits jar balance downward', (tester) async {
    final result = await saveJar(
      tester,
      current: existingJar.copyWith(balance: 250),
      balanceText: '50',
    );

    expect(result?.entity?.balance, 250);
    expect(result?.requestedBalance, 50);
  });

  testWidgets('keeps unchanged balance when editing without changing field',
      (tester) async {
    final result = await saveJar(tester, current: existingJar);

    expect(result?.entity?.balance, existingJar.balance);
    expect(result?.requestedBalance, existingJar.balance);
  });

  testWidgets('rejects empty balance input', (tester) async {
    final result = await saveJar(tester, balanceText: '');
    expect(result, isNull);
    expect(find.text('Current balance is required.'), findsOneWidget);
  });

  testWidgets('rejects non-numeric balance input', (tester) async {
    final result = await saveJar(tester, balanceText: 'abc');
    expect(result, isNull);
    expect(
      find.text('Current balance must be a number greater than or equal to 0.'),
      findsOneWidget,
    );
  });

  testWidgets('rejects negative balance input', (tester) async {
    final result = await saveJar(tester, balanceText: '-1');
    expect(result, isNull);
    expect(
      find.text('Current balance must be a number greater than or equal to 0.'),
      findsOneWidget,
    );
  });

  test('initial jar balance is reconstructable from jar funding transaction',
      () {
    final createdJar = existingJar.copyWith(balance: 0);
    final initialState = AppStateEntity.initial().copyWith(
      budgetSetup: AppStateEntity.initial().budgetSetup.copyWith(
        linkedWallets: [createdJar],
      ),
    );

    final replayed = TransactionProcessor.apply(
      initialState,
      TransactionEntity(
        id: 'txn-initial-jar-balance',
        toWalletId: createdJar.id,
        amount: 125.75,
        type: TransactionType.transfer.value,
        transferType: TransferType.jarFunding.value,
        createdAt: DateTime(2026, 8, 9),
      ),
    );

    expect(replayed.budgetSetup.linkedWallets.single.balance, 125.75);
  });

  test('edited jar balance is reconstructable from correction transactions',
      () {
    final initialState = AppStateEntity.initial().copyWith(
      budgetSetup: AppStateEntity.initial().budgetSetup.copyWith(
        linkedWallets: [existingJar],
      ),
    );

    final increased = TransactionProcessor.apply(
      initialState,
      TransactionEntity(
        id: 'txn-increase-jar-balance',
        toWalletId: existingJar.id,
        amount: 150,
        type: TransactionType.transfer.value,
        transferType: TransferType.jarFunding.value,
        createdAt: DateTime(2026, 8, 9),
      ),
    );
    expect(increased.budgetSetup.linkedWallets.single.balance, 250);

    final decreased = TransactionProcessor.apply(
      increased,
      TransactionEntity(
        id: 'txn-decrease-jar-balance',
        toWalletId: existingJar.id,
        amount: 200,
        type: TransactionType.expense.value,
        budgetScope: BudgetScope.outsideBudget.value,
        createdAt: DateTime(2026, 8, 9),
      ),
    );

    expect(decreased.budgetSetup.linkedWallets.single.balance, 50);
  });
}
