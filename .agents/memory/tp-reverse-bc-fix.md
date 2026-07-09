---
name: TransactionProcessor reverse backward-compat double-decrement fix
description: Root cause and fix for "Unknown = jar.balance" when deleting OLD income transactions
---

## The Bug
In `TransactionProcessor.reverse`, OLD income sub-transactions (created before parentId tracking was added) have `parentId == null`. The original code hardcoded `hasMatchingSourceChild = false` for these, causing:
1. `jarFunding` sub: `trackWalletSource = !false = true` → `updateMoneyDistribution(delta = -amount)` (first decrement)
2. `jarAllocation` sub: `reverseJarSourceOnly(delta = amount)` → `updateMoneyDistribution(delta = -amount)` (second decrement)

Net: -2× → distribution collapses to 0 → `unknown = jar.balance`.

## The Fix
For `parentId == null` (backward-compat path), search for the companion `jarAllocation` sub-tx using the old grouping criteria:
```dart
t.id != sub.id &&
t.transferType == TransferType.jarAllocation.value &&
t.toWalletId == sub.toWalletId &&
t.walletId == sub.walletId &&
t.incomeSourceId == sub.incomeSourceId &&
t.createdAt == sub.createdAt
```

**Why:** Old sub-txns were grouped by createdAt+incomeSourceId+walletId instead of parentId.

**How to apply:** Only the backward-compat branch (parentId==null) in `TransactionProcessor.reverse`, inside the `jarFunding` sub-tx loop. The new-path branch (parentId!=null) is correct as-is.

## Related fixes in the same session
- `_migrateMoneyDistributionsSync`: added early return guard when `moneyDistributionMigrationDone==true && walletSources all empty` — avoids running migration on every startup.
- `jar_details_sheet.dart`: added `autoResolveReviewsIfConsistent(jarId)` after individual entry delete/move/edit — previously only called from distribution manager save.
