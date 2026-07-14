# BUG-001 — Wallet Transfer Investigation

**Investigation Target:** Wallet Transfer loses its wallet effects after editing Notes.
**Mode:** Forensic investigation only. No code was modified. No fix is proposed.

---

## Executive Summary

Editing an existing wallet-to-wallet transfer transaction — even a notes-only edit — routes through a "delete old, then add new" save strategy in `AddTransactionScreen`. The "add new" step reconstructs the transaction from scratch and **never passes `fromWalletId`, `toWalletId`, or `transferType`** for a plain wallet-to-wallet transfer. The reconstructed transaction therefore has `type == 'transfer'` but `fromWalletId == null` and `toWalletId == null`. `TransactionProcessor.apply()` falls through to a branch that does nothing when both wallet IDs are null. Result: the old transfer's wallet balances are correctly reversed (delete step), but the new transaction's wallet balances are never re-applied (add step silently no-ops), while the transaction record itself is still appended to `state.transactions` and therefore still visible in the Timeline/Logs.

A structurally identical bug for **jar-to-jar** transfers was already found and fixed by routing jar-to-jar edits through a dedicated `_openJarToJarEditor`, with an explicit code comment documenting the exact same root cause. **Plain wallet-to-wallet transfers (`transferType == 'wallet-to-wallet'`) were not included in that exclusion list** and still fall through to the general-purpose `AddTransactionScreen` editor.

---

## Investigation Scope

- Entry point: user presses Save while editing an existing Wallet-to-Wallet transfer (`TransactionEntity.type == 'transfer'`, `transferType == TransferType.walletToWallet.value` i.e. `'wallet-to-wallet'`).
- Excluded from scope (already confirmed to use a different, non-buggy path): jar-to-jar transfers (`transferType == 'jarToJar'`), jar funding/allocation transfers.
- Files read directly (not inferred): `add_transaction_screen.dart`, `app_cubit.dart`, `transaction_processor.dart`, `transaction_entity.dart`, `transaction_details_sheet.dart`, `wallets_screen.dart`, `transaction_types.dart`.

---

## Execution Flow

### 1. UI entry point
A wallet-to-wallet transfer is created from `WalletsScreen._openWalletTransferDialog()`:

```dart
// lib/features/wallets/presentation/screens/wallets_screen.dart:1589-1596
await widget.cubit.addTransaction(
  type: TransactionType.transfer.value,
  amount: amount,
  fromWalletId: fromId,
  toWalletId: toId,
  transferType: 'wallet-to-wallet',
  notes: 'تحويل بين المحافظ',
);
```

Editing any transaction (opened from a transaction list / details sheet) goes through `_openTransactionEditor()`:

```dart
// lib/features/transactions/presentation/widgets/transaction_details_sheet.dart:664-701
Future<void> _openTransactionEditor(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
  required bool closeBeforeEdit,
}) async {
  if (closeBeforeEdit) Navigator.pop(context);
  if (transaction.transferType == TransferType.jarFunding.value ||
      transaction.transferType == TransferType.jarFundingPhysical.value ||
      transaction.transferType == TransferType.jarAllocation.value) {
    await _openJarReserveEditor(context, cubit: cubit, transaction: transaction);
    return;
  }
  if (transaction.transferType == TransferType.jarToJar.value) {
    await _openJarToJarEditor(context, cubit: cubit, transaction: transaction);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => FractionallySizedBox(
      heightFactor: 0.96,
      child: AddTransactionScreen(
        cubit: cubit,
        initialTransaction: transaction,
      ),
    ),
  );
}
```

**A `transferType == 'wallet-to-wallet'` transaction does not match any of the three excluded cases above**, so it falls through to the generic `AddTransactionScreen(initialTransaction: transaction)` sheet.

Immediately above `_openJarToJarEditor`, the code contains a comment that documents the exact same failure mode for a *different* transfer subtype:

```dart
// lib/features/transactions/presentation/widgets/transaction_details_sheet.dart:703-705
/// محرر مخصص لمعاملات التحويل بين حصالتين (jarToJar).
/// لا يستخدم الشاشة العامة لأنها لا تدعم نوع transfer ولا تمرر
/// fromWalletId عند الحفظ — مما كان سيمحو أثر التحويل بالكامل عند التعديل.
```//
Translation: "Custom editor for jar-to-jar transfers. Does not use the general screen, because it doesn't support the transfer type and doesn't pass fromWalletId on save — which would erase the transfer's effect entirely when edited."

This confirms the team already diagnosed and patched this exact mechanism for jar-to-jar, but the same exclusion was not applied to plain wallet-to-wallet transfers.

### 2. `AddTransactionScreen` state hydration from `initialTransaction`

```dart
// lib/features/transactions/presentation/screens/add_transaction_screen.dart:88-96
final t = widget.initialTransaction;
if (t != null) {
  _type = t.type;                       // = 'transfer'
  _date = t.createdAt;
  _time = TimeOfDay(hour: t.createdAt.hour, minute: t.createdAt.minute);
  _walletId = t.walletId ?? _walletId;  // t.walletId is null for a wallet-to-wallet transfer
  _amountController.text = t.amount.toStringAsFixed(2);
  _notesController.text = t.notes ?? '';
  ...
}
```

`t.walletId` is `null` for a wallet-to-wallet transfer (it uses `fromWalletId`/`toWalletId` instead), so `_walletId` falls back to whatever it was already initialized to (the first wallet in the list, from the field declaration higher in the file) — **not** the transfer's actual source wallet. `_fromWalletId`/`_toWalletId` fields do not exist in `_AddTransactionScreenState`; grep of the file confirms `fromWalletId`/`toWalletId` are never read from `t` here.

### 3. UI has no representation for the `transfer` type

The type toggle only supports two states:

```dart
// lib/features/transactions/presentation/screens/add_transaction_screen.dart:888-889
Widget _typeSegmentedToggle(ThemeData theme) {
  final activeOnRight = _type == TransactionType.income.value;
  ...
```

and the body's conditional sections are gated only on `_type == TransactionType.expense.value` or `_type == TransactionType.income.value` (lines 460, 487, 533, etc.) — there is **no branch for `_type == TransactionType.transfer.value`**. A user opening this sheet for a wallet-to-wallet transfer sees an expense/income-shaped form (with `_type` silently still `'transfer'` internally) and can, at minimum, edit the Notes field and press Save without touching anything else.

### 4. Save handler — "delete old, then add new"

```dart
// lib/features/transactions/presentation/screens/add_transaction_screen.dart:780-840
} else {
  if (widget.initialTransaction != null) {
    await widget.cubit.deleteTransaction(
      widget.initialTransaction!.id,
    );
  }
  await widget.cubit.addTransaction(
    walletId: _walletId == 'no-wallet' ? null : _walletId,
    toWalletId: _type == TransactionType.income.value &&
            _incomeBudgetScope == BudgetScope.withinBudget.value &&
            _incomeJarId.isNotEmpty
        ? _incomeJarId
        : selectedJarId,
    amount: amount,
    type: _type,
    createdAt: DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute),
    allocationId: _type == TransactionType.expense.value &&
            _budgetScope == BudgetScope.withinBudget.value &&
            _budgetTargetId.startsWith('alloc:')
        ? _budgetTargetId.replaceFirst('alloc:', '')
        : null,
    budgetScope: _type == TransactionType.expense.value
        ? _budgetScope
        : _type == TransactionType.income.value
            ? _incomeBudgetScope
            : null,
    incomeSourceId: _type == TransactionType.income.value &&
            _incomeSourceId != 'wallet-only'
        ? _incomeSourceId
        : null,
    transferType: widget.initialTransaction?.transferType ==
                TransferType.jarFundingPhysical.value &&
            _type == TransactionType.expense.value
        ? TransferType.jarFundingPhysical.value
        : _type == TransactionType.income.value && _incomeJarId.isNotEmpty
            ? TransferType.depositWithJarLabel.value
            : null,
    notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    categoryId: _type == TransactionType.income.value
        ? _selectedIncomeCategoryId
        : _selectedCategoryId,
  );
}
```

For a transfer being edited here:
- `walletId:` is passed as `_walletId` (a fallback/default wallet id — not the transfer's original `fromWalletId`).
- **`fromWalletId:` is never passed at all** (no such named argument appears in this call).
- `toWalletId:` is only ever set to `_incomeJarId` or `selectedJarId` (both are jar-allocation concepts) — for a wallet-to-wallet transfer neither applies, so it resolves to `null`.
- `transferType:` is only preserved for the `jarFundingPhysical` case or set for the income-jar-label case; for `'wallet-to-wallet'` it resolves to `null`.
- `type:` is passed through as `_type`, i.e. still `'transfer'`.

### 5. Cubit — `addTransaction` constructs a brand-new `TransactionEntity`

```dart
// lib/features/app_state/presentation/cubits/app_cubit.dart:459-514 (relevant fields)
Future<void> addTransaction({
  String? walletId,
  String? fromWalletId,
  String? toWalletId,
  required double amount,
  required String type,
  ...
  String? transferType,
  String? notes,
  DateTime? createdAt,
  ...
}) async {
  ...
  final transaction = TransactionEntity(
    id: _id('txn'),
    walletId: walletId,
    fromWalletId: fromWalletId,
    toWalletId: toWalletId,
    ...
    transferType: transferType,
    amount: amount,
    type: type,
    notes: notes,
    createdAt: createdAt ?? DateTime.now(),
  );
  ...
  await _applyAndLog(
    ...
    apply: () async => TransactionProcessor.apply(state, transaction),
    ...
  );
}
```

`addTransaction` has no memory of the previous transaction — it is a pure constructor call driven entirely by the arguments it receives. Since the caller (Section 4) never supplies `fromWalletId`, the constructed `transaction.fromWalletId` is `null`. `TransactionEntity` has **no `copyWith` method** (confirmed by reading the full class, `transaction_entity.dart:1-77`) — there is no in-place-patch code path available to have been used or misused here; the loss happens purely because the caller in `add_transaction_screen.dart` omits the field when re-constructing arguments for the new transaction.

`deleteTransaction` is a separate, correct call:

```dart
// lib/features/app_state/presentation/cubits/app_cubit.dart:617-624
Future<void> deleteTransaction(String transactionId) async {
  final target = state.transactions.where((t) => t.id == transactionId).toList();
  if (target.isEmpty) return;
  final transaction = target.first;
  var next = TransactionProcessor.reverse(state, transaction);
  ...
}
```

This uses the **original** transaction object (with its correct `fromWalletId`/`toWalletId`), so the reversal in step 6 below is correct. The defect is entirely in what gets passed to the subsequent `addTransaction` call.

### 6. `TransactionProcessor` — apply/reverse for plain wallet-to-wallet transfers

```dart
// lib/features/transactions/domain/services/transaction_processor.dart:133-138 (apply, condition)
} else {
  final isPhysicalFrom = wallets.any((w) => w.id == transaction.fromWalletId);
  final isPhysicalTo = wallets.any((w) => w.id == transaction.toWalletId);

  if (isPhysicalFrom && isPhysicalTo) {
    wallets = wallets.map((w) {
      if (w.id == transaction.fromWalletId) {
        return w.copyWith(balance: w.balance - transaction.amount);
      }
      if (w.id == transaction.toWalletId) {
        return w.copyWith(balance: w.balance + transaction.amount);
      }
      return w;
    }).toList();
  } else if (... other specific transferType branches ...) {
    ...
  } else {
    // lines 206-221 — the fallback branch reached when fromWalletId/toWalletId
    // are null (or match nothing in `wallets`)
    if (transaction.fromWalletId != null) {
      updateVirtualBalance(id: transaction.fromWalletId!, delta: -transaction.amount, physicalWalletId: transaction.walletId);
    }
    if (transaction.toWalletId != null) {
      updateVirtualBalance(id: transaction.toWalletId!, delta: transaction.amount, physicalWalletId: transaction.walletId);
    }
  }
}
```

When the reconstructed transaction has `fromWalletId == null` and `toWalletId == null`:
- `isPhysicalFrom` and `isPhysicalTo` are both `false` (`wallets.any(...)` over a `null` id matches nothing) → the `isPhysicalFrom && isPhysicalTo` branch (which moves real wallet balances) is **skipped**.
- None of the other `else if` branches match either (they all require `transferType` values the reconstructed transaction does not have, or a non-null `toWalletId`).
- Execution falls to the final `else` (lines 206-221): both `if` guards (`fromWalletId != null` / `toWalletId != null`) are false, so **neither `updateVirtualBalance` call executes**. No wallet, jar, or allocation balance is touched.

Crucially, regardless of any of this, the top of `apply()` unconditionally appends the transaction to the returned list:

```dart
// lib/features/transactions/domain/services/transaction_processor.dart:33-36
var transactions = <TransactionEntity>[
  ...current.transactions,
  transaction,
];
```

So the (now effect-less) transaction record is still stored and returned as part of the new state, and `return current.copyWith(..., transactions: transactions)` at the end of `apply()` includes it.

### 7. Persistence

```dart
// lib/features/app_state/data/repositories/shared_prefs_app_repository.dart
```
`_applyAndLog` (called by both `deleteTransaction` and `addTransaction`) computes the next `AppStateEntity` and the resulting state, including the now-desynced `wallets` list and the `transactions` list containing the effect-less record, is persisted as a single JSON blob via the repository's save method — confirmed by the repository operating on one `AppStateEntity` per save call, not per-field updates.

### 8. Read model / UI refresh

`_applyAndLog` emits the new state via the Cubit (`emit(...)`), which is how `WalletsScreen`, `MoneyScreen`, and the Timeline/Logs screen (`LogsScreen`, which reads `state.transactions`) all re-render. Because the transaction record persists in `state.transactions` (Section 6/7) while `state.wallets` no longer reflects its balance effect, the Timeline continues to display the transfer while wallet balances behave as if it never happened (net effect after the whole edit: the *old* transfer's balances are reversed and the *new* one's are never applied).

---

## Evidence

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | How does the system recognize a transaction is a Wallet Transfer? | `transaction.type == TransactionType.transfer.value` (`'transfer'`) together with `transaction.transferType == TransferType.walletToWallet.value` (`'wallet-to-wallet'`), or, for the balance-mutation logic in `TransactionProcessor`, implicitly by whether `fromWalletId`/`toWalletId` both resolve to entries in `wallets` (`isPhysicalFrom && isPhysicalTo`). | `transaction_types.dart:19` (`walletToWallet('wallet-to-wallet')`); `wallets_screen.dart:1590,1594`; `transaction_processor.dart:134-138`. |
| 2 | Does any logic depend on Notes/Description/localized text/parsing? | No business-logic branch inspected in the transfer path reads `.notes` or `.description` to make a decision. `notes` is only ever used for display strings and notification titles. | `app_cubit.dart:561-570` (`notes?.isNotEmpty == true ? notes : ...` — only builds a *display* title); `transaction_details_sheet.dart:647` (`notes ?? 'لا توجد ملاحظات'` — display only). No occurrence found where `.notes`/`.description` feeds into `TransferType`, `TransactionType`, or a wallet/jar balance calculation. |
| 3 | Which object is reconstructed / reused / deleted when editing a transfer? | The **old** `TransactionEntity` is deleted (and correctly reversed via `TransactionProcessor.reverse`, reusing the old object's `fromWalletId`/`toWalletId`). A **brand-new** `TransactionEntity` is constructed from scratch inside `AppCubit.addTransaction`, built from the raw parameters `AddTransactionScreen`'s Save handler passes in — none of which include the old transaction's `fromWalletId`, and none of which correctly reconstruct `toWalletId`/`transferType` for this case. No object is ever mutated in place — `TransactionEntity` has no `copyWith`. | `add_transaction_screen.dart:781-786` (delete then add); `app_cubit.dart:499-514` (`final transaction = TransactionEntity(...)`); `transaction_entity.dart:1-77` (full class — no `copyWith`). |
| 4 | Why does changing Notes only cause wallet balances to revert while Timeline keeps the transaction? | The Save handler always runs delete-then-add regardless of which field changed (there is no dirty-field diffing). Delete reverses the old transfer's wallet balances correctly. Add reconstructs a transaction that is missing `fromWalletId`/`toWalletId`/`transferType`, so `TransactionProcessor.apply` cannot identify it as a physical wallet-to-wallet transfer and takes the no-op fallback branch. The transaction record itself, however, is unconditionally appended to `transactions` at the top of `apply()`, independent of which (if any) balance branch ran, so it still shows up wherever the UI reads `state.transactions` (e.g., Timeline/Logs). | `add_transaction_screen.dart:780-840`; `transaction_processor.dart:33-36` (unconditional append) vs. `:206-221` (no-op fallback when both wallet ids are null). |
| 5 | Files involved | See "Files Involved" below. | — |
| 6 | Methods involved | See "Methods Involved" below. | — |
| 7 | Exact line where the wallet effect is lost | Two joint points: (a) `add_transaction_screen.dart`, the `addTransaction(...)` call in the Save handler (`lines 786-839`) — omits `fromWalletId` entirely and passes `toWalletId: null`/`transferType: null` for this case; (b) `transaction_processor.dart`, lines `206-221` (the final `else` branch of `apply()`), where both wallet-id-null guards fail and no balance update happens as a consequence of (a). | Quoted in Sections 4 and 6 above. |

---

## Root Cause

`_openTransactionEditor` in `transaction_details_sheet.dart` routes transactions to a dedicated, transfer-aware editor only for `transferType` values `jarFunding`, `jarFundingPhysical`, `jarAllocation`, and `jarToJar`. Plain wallet-to-wallet transfers (`transferType == 'wallet-to-wallet'`) are **not** in that list and fall through to the generic `AddTransactionScreen`, which:
1. Has no UI representation for `type == 'transfer'` (toggle and form sections only handle expense/income).
2. Hydrates `_walletId` from `t.walletId`, which is `null` for a wallet-to-wallet transfer, and never hydrates `fromWalletId`/`toWalletId` into any state field.
3. On Save, performs delete-then-add, and the add call never supplies `fromWalletId` and only supplies `toWalletId`/`transferType` for unrelated (jar) cases.

Because the reconstructed transaction loses `fromWalletId`/`toWalletId`, `TransactionProcessor.apply()` cannot route it through the physical wallet-to-wallet balance branch and instead takes a no-op fallback, while the transaction record is still unconditionally retained in `transactions`. This reproduces regardless of which field the user actually edits (including a notes-only edit), because the delete-then-add strategy has no field-level diffing — any Save on a wallet-to-wallet transfer through this screen destroys its wallet effects.

This is the same class of bug that was already identified and fixed for `jarToJar` transfers (see the comment at `transaction_details_sheet.dart:703-705`), but the fix's exclusion list was not extended to cover `'wallet-to-wallet'`.

---

## Confirmed Facts

- `_openTransactionEditor` (`transaction_details_sheet.dart:664-701`) routes `transferType` values `jarFunding`, `jarFundingPhysical`, `jarAllocation`, and `jarToJar` to dedicated editors; `'wallet-to-wallet'` is not in that list and falls through to the generic `AddTransactionScreen`.
- `AddTransactionScreen` has no UI branch for `_type == TransactionType.transfer.value` — only expense/income are represented in the toggle and form sections (`add_transaction_screen.dart:888-889` and surrounding conditionals).
- `initState` hydrates `_walletId` from `t.walletId`, which is `null` for a wallet-to-wallet transfer, and never reads `fromWalletId`/`toWalletId` into any state field (`add_transaction_screen.dart:88-96`).
- The Save handler performs delete-then-add with no dirty-field diffing; the `addTransaction(...)` call it issues omits `fromWalletId` entirely and resolves `toWalletId`/`transferType` to `null` for this case (`add_transaction_screen.dart:780-840`).
- `AppCubit.addTransaction` constructs a brand-new `TransactionEntity` purely from the arguments it receives, with no memory of the transaction being replaced (`app_cubit.dart:459-514`). `TransactionEntity` has no `copyWith` (`transaction_entity.dart:1-77`), so there is no in-place-patch path that could have been used instead.
- `AppCubit.deleteTransaction` correctly reverses the **original** transaction's wallet balances using the original object's `fromWalletId`/`toWalletId` (`app_cubit.dart:617-624`) — the defect is isolated to the subsequent add step.
- `TransactionProcessor.apply()` requires non-null `fromWalletId` and `toWalletId` resolving to entries in `wallets` to take the physical wallet-to-wallet balance branch; when both are `null` it falls to a no-op branch that touches no balances (`transaction_processor.dart:133-138, 206-221`).
- Regardless of which balance branch runs (or doesn't), `apply()` unconditionally appends the transaction to `transactions` at the top of the function (`transaction_processor.dart:33-36`), so the effect-less record still renders in the Timeline/Logs.
- No business-logic branch in the transfer path reads `.notes`/`.description` to make a routing or balance decision — `notes` is used only for display/notification strings (`app_cubit.dart:561-570`, `transaction_details_sheet.dart:647`). The bug reproduces on *any* Save through this screen, not specifically because Notes was the field edited.
- The same failure mode was previously identified and fixed for `jarToJar` transfers, with an explanatory code comment documenting it (`transaction_details_sheet.dart:703-705`); that fix's exclusion list was never extended to `'wallet-to-wallet'`.

## Likely Causes

- None beyond what is stated in Confirmed Facts / Root Cause — every mechanical step in the execution flow was traced to and verified against actual source code, so no unverified inference was required to explain the reported symptom.

---

## Unknowns

- **Not proven:** whether any other `transferType` values besides `jarFunding`, `jarFundingPhysical`, `jarAllocation`, `jarToJar`, and `wallet-to-wallet` exist and are similarly affected — a full enumeration of `TransferType` was not exhaustively cross-checked against `_openTransactionEditor`'s exclusion list beyond what is quoted above.
- **Not proven:** whether recurring wallet-to-wallet transfers (`widget.recurringMode`) exhibit the same defect — the recurring-mode Save path (lines 705-779) was not traced in the same depth, since the bug report is specifically about editing an existing (non-recurring) transaction.
- **Not proven:** the exact UI affordances a user sees when `_type` is silently `'transfer'` inside `AddTransactionScreen` (e.g., whether the expense-shaped form fields visually mislead the user) — this was inferred from the absence of a transfer-specific conditional branch, not from a rendered screenshot or widget test.

---

## Files Involved

- `lib/features/transactions/presentation/widgets/transaction_details_sheet.dart`
- `lib/features/transactions/presentation/screens/add_transaction_screen.dart`
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
- `lib/features/transactions/domain/services/transaction_processor.dart`
- `lib/features/transactions/domain/entities/transaction_entity.dart`
- `lib/features/wallets/presentation/screens/wallets_screen.dart` (creation path, for contrast)
- `lib/core/constants/transaction_types.dart` (`TransferType` enum values)

## Methods Involved

- `_openTransactionEditor` — `transaction_details_sheet.dart`
- `_openJarToJarEditor` — `transaction_details_sheet.dart` (contrast: the already-fixed sibling case)
- `_AddTransactionScreenState.initState` (hydration of `_type`/`_walletId` from `initialTransaction`) — `add_transaction_screen.dart`
- `_typeSegmentedToggle` — `add_transaction_screen.dart`
- The Save `FilledButton.onPressed` handler — `add_transaction_screen.dart`
- `AppCubit.addTransaction` — `app_cubit.dart`
- `AppCubit.deleteTransaction` — `app_cubit.dart`
- `TransactionProcessor.apply` — `transaction_processor.dart`
- `TransactionProcessor.reverse` — `transaction_processor.dart`
- `_openWalletTransferDialog` — `wallets_screen.dart` (creation path, for contrast)

---

## Next Investigation

(Provided for completeness only — no fix proposed here, per investigation scope.)
- Confirm the complete `TransferType` enum member list and check each value against `_openTransactionEditor`'s routing conditions to find any other transferType left unprotected the same way `'wallet-to-wallet'` is.
- Trace the recurring-mode Save path for wallet-to-wallet transfers to determine if it shares this defect or has independent handling.
