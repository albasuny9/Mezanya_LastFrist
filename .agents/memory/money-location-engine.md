---
name: Money Location Engine
description: Key decisions and constraints for the MoneyLocationEngine redesign (walletSources domain)
---

## Rule: walletSources updated via MoneyLocationEngine ONLY

All mutations to `LinkedWalletEntity.walletSources` must go through
`MoneyLocationEngine.applyLocationDelta` (or `addSpendingMismatchReview`).
No direct mutation, no `jar.withUpdatedSource()` outside the engine.

**Why:** The old dual-path (TransactionProcessor + relabelJarWalletSource direct mutation)
caused double-accounting — deleting an audit tx would double-reverse walletSources.

**How to apply:** Any new code that changes walletSources must call the engine. The engine
is called from TransactionProcessor only; AppCubit routes through `addTransaction`.

---

## Rule: relabelJarWalletSource routes through addTransaction

`relabelJarWalletSource` now calls `addTransaction(jarAllocation|jarAllocationCancel)`,
NOT direct state mutation. This means walletSources changes are always backed by a
transaction that can be reversed correctly.

**Why:** Old code had direct mutation + audit tx → deleting audit tx double-reversed.

---

## Rule: Reverse path uses symmetric condition check (not review presence)

In `reverseVirtualBalance`, the spending mismatch detection uses:
```dart
final forwardTookMismatchPath = delta < 0 && !walletInSourcesNow && jar.walletSources.isNotEmpty;
```
NOT: checking if a `spendingWalletMismatch` review exists for the transaction.

**Why:** Review presence check breaks if user dismisses review before deleting transaction
(review gone → else branch incorrectly adds phantom source).

**How to apply:** The symmetric condition matches the forward apply condition. If wallet was
added to sources between apply and reverse, the symmetric check correctly takes the normal
reverse path (which is right because user explicitly said this wallet is a source).

---

## Rule: Migration is one-time (moneyLocationMigrationDone flag)

`_migrateMoneyLocationInconsistenciesSync` is guarded by `AppStateEntity.moneyLocationMigrationDone`.
Once migration runs (even if no inconsistencies found), the flag is set to true.
Migration never runs again on subsequent launches.

**Why:** Without the flag, migration recreates dismissed `labeledExceedsBalance` reviews
on every launch, making "ignore" non-sticky.

**How to apply:** If new migration logic is needed in future, add a new flag or version it.
Don't change the existing guard logic.

---

## Data layout

- `MoneyLocationReview` stored in `LinkedWalletEntity.moneyLocationReviews` (List, default [])
- Backward-compatible: old Firestore data deserializes to `[]`
- `AppStateEntity.moneyLocationMigrationDone` (bool, default false)
- Reviews shown in `jar_details_sheet.dart` as "_MoneyLocationReviewCard" widgets
- Dismiss calls `AppCubit.resolveMoneyLocationReview(jarId, reviewId)`

---

## Financial invariant (critical)

`jar.balance` and `wallet.balance` are NEVER touched by MoneyLocationEngine.
Only `walletSources` (label metadata) and `moneyLocationReviews` are managed by the engine.
Financial balance management remains exclusively in `TransactionProcessor`.
