<!--
Status: Reference
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Money Location Engine v2 — Architecture Document

> **Date:** 2026-07-07  
> **Scope:** Redesign and implementation of the Money Location Engine  
> **Status:** Implemented

---

## 1. Problem Statement

The old system maintained `walletSources` (the "where is the money" label) through **two independent, uncoordinated code paths**:

1. **`TransactionProcessor.apply/reverse`** — incremental updates via `withUpdatedSource`
2. **`relabelJarWalletSource` in `AppCubit`** — direct state mutation bypassing TransactionProcessor

This created **9 known problems** documented in `jar_money_location_architecture.md`, the most severe being:

| # | Problem | Impact |
|---|---------|--------|
| 1 | Double accounting in `relabelJarWalletSource` | Deleting an audit tx corrupted `walletSources` |
| 3 | `jarAllocationSpend` uses spending wallet, not funding wallet | Silent corruption — wrong wallet decremented |
| 4 | `withUpdatedSource` silently discards negative amounts | Untracked divergence between balance and labels |
| 5 | Editing after manual relabel produces impossible state | Negative `unlabeledAmount` |

---

## 2. Design Goals

| Goal | How achieved |
|------|-------------|
| Financial balances always correct | `jar.balance` and `wallet.balance` untouched — managed only by `TransactionProcessor` as before |
| Money Location as separate domain | New `MoneyLocationEngine` service + `MoneyLocationReview` entity |
| User never interrupted during transactions | Reviews created silently, never blocking |
| Inconsistencies become review tasks | `MoneyLocationReview` stored in `LinkedWalletEntity.moneyLocationReviews` |
| One clear source of truth | `walletSources` updated ONLY via `MoneyLocationEngine` called from `TransactionProcessor` |
| No duplicated logic | `relabelJarWalletSource` now routes through the same single path |
| No conflicting update paths | Direct state mutation removed from `relabelJarWalletSource` |

---

## 3. New Architecture

### 3.1 Money Location — Concept

Money Location (`walletSources` / `أماكن الأموال`) represents **metadata only** — where the jar money is believed to exist physically. It is:

- **NOT** a wallet balance
- **NOT** a financial record
- A label that describes the last known location of jar money

### 3.2 New Entities

#### `MoneyLocationReview` (new)

Stored inside `LinkedWalletEntity.moneyLocationReviews`.

```dart
class MoneyLocationReview {
  final String id;
  final double amount;          // المبلغ محل المراجعة
  final String type;            // MoneyLocationReviewType.value
  final DateTime createdAt;
  final String? relatedTransactionId;
  final String? notes;
}

enum MoneyLocationReviewType {
  spendingWalletMismatch,   // صُرف من محفظة غير مدرجة في المصادر
  sourceWentNegative,       // مصدر أصبح سالباً بعد عملية عكس
  labeledExceedsBalance,    // مجموع التصنيفات يتجاوز الرصيد (ترحيل)
}
```

**Key properties:**
- Created by `MoneyLocationEngine` — never by the UI
- Displayed in jar details as "يحتاج مراجعة"
- Resolved by user via "تجاهل" button → `AppCubit.resolveMoneyLocationReview`
- Does NOT affect `jar.balance` or `wallet.balance`
- Serialized in Firestore under `linkedWallets[].moneyLocationReviews`

#### `LinkedWalletEntity` (modified)

Added field:
```dart
final List<MoneyLocationReview> moneyLocationReviews;  // default: []
```

Backward-compatible: old data deserialized to `[]`.

### 3.3 New Service: `MoneyLocationEngine`

**File:** `lib/features/budget/domain/services/money_location_engine.dart`

Single responsibility: safe mutation of `walletSources` with review creation on inconsistency.

```
MoneyLocationEngine
  ├── applyLocationDelta(jar, walletId, delta, transactionId?)
  │     → updates walletSources; creates sourceWentNegative review if delta causes negative
  ├── addSpendingMismatchReview(jar, amount, spendingWalletId, transactionId)
  │     → creates spendingWalletMismatch review (does NOT touch walletSources)
  ├── resolveReview(jar, reviewId)
  │     → removes a review by ID (user dismissal)
  ├── resolveSpendingMismatchForTransaction(jar, transactionId)
  │     → removes mismatch reviews for a transaction (used during reverse)
  └── detectInconsistencies(jar)
        → returns reviews for existing data inconsistencies (used by migration)
```

---

## 4. Transaction Behavior (Redesigned)

### `jarFunding` (virtual)

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ❌ unchanged | ❌ unchanged |
| `jar.balance` | ✅ `+= amount` | ✅ `-= amount` |
| `walletSources[fromWallet]` | ✅ `+= amount` via engine | ✅ `-= amount` via engine (review if goes negative) |
| **Pending Review** | Never | Only if out-of-order deletion causes negative |

### `jarFundingPhysical`

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ✅ `-= amount` | ✅ `+= amount` |
| `jar.balance` | ✅ `+= amount` | ✅ `-= amount` |
| `walletSources[fromWallet]` | ✅ `+= amount` via engine | ✅ `-= amount` via engine |
| **Pending Review** | Never | Only if balance mismatch |

### `depositWithJarLabel`

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ✅ `+= amount` | ✅ `-= amount` |
| `jar.balance` | ✅ `+= amount` | ✅ `-= amount` |
| `walletSources[wallet]` | ✅ `+= amount` via engine | ✅ `-= amount` via engine |
| **Pending Review** | Never | Only if out-of-order |

### `jarAllocation` (relabeling)

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ❌ | ❌ |
| `jar.balance` | ❌ | ❌ |
| `walletSources[fromWallet]` | ✅ `+= amount` via engine | ✅ `-= amount` via engine (review if goes negative) |
| **Pending Review** | Never (amount always ≥ diff from user intent) | Only if out-of-order |

### `jarAllocationCancel` (label reduction)

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ❌ | ❌ |
| `jar.balance` | ❌ | ❌ |
| `walletSources[fromWallet]` | ✅ `-= amount` via engine (**review if goes negative** — was silent before) | ✅ `+= amount` via engine |
| **Pending Review** | ✅ Created if result negative (NEW — was silent drop before) | Never |

### `jarAllocationSpend` (expense from jar)

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ✅ `-= amount` | ✅ `+= amount` |
| `jar.balance` | ✅ `-= amount` | ✅ `+= amount` |
| `walletSources[spendingWallet]` | **NEW:** Check if spendingWallet in sources: YES → `-= amount` via engine; NO → create `spendingWalletMismatch` review | **NEW:** If review exists → resolve it; else → `+= amount` via engine |
| **Pending Review** | ✅ Created if spending wallet not in sources (NEW — was silent corruption before) | ✅ Resolved if review existed |

### `allocationToJar` / `jarToAllocation` / `jarToJar`

Same as before — both `balance` and `walletSources` change on both ends via engine.

---

## 5. Key Fix: `relabelJarWalletSource`

### Old flow (broken)

```
relabelJarWalletSource(jarId, walletId, newAmount)
  ├── DIRECT MUTATION: jar.walletSources = newSources  ← bypasses TransactionProcessor
  ├── Build auditTx (jarAllocation or jarAllocationCancel)
  └── Save state with BOTH direct mutation + auditTx
  
  Problem: if user deletes auditTx later:
    TransactionProcessor.reverse(auditTx) → reverseJarSourceOnly → walletSources -= delta AGAIN
    = double reversal = data corruption
```

### New flow (correct)

```
relabelJarWalletSource(jarId, walletId, newAmount)
  ├── Compute diff = newAmount - oldAmount
  ├── If diff == 0: return (no-op)
  └── addTransaction(jarAllocation|jarAllocationCancel, amount=|diff|)
        └── TransactionProcessor.apply(auditTx)
              └── updateJarSourceOnly → MoneyLocationEngine.applyLocationDelta
                    └── walletSources updated correctly, review created if negative

  Deletion of auditTx later:
    TransactionProcessor.reverse(auditTx) → reverseJarSourceOnly → engine → correct reversal
    = single reversal = correct behavior ✓
```

---

## 6. Review Queue — User Experience

### Display

In `jar_details_sheet.dart`, a new "يحتاج مراجعة" section appears when `jar.moneyLocationReviews.isNotEmpty`.

Each item shows:
- Type description in Arabic (no technical terms like `walletSources` or `Reservation`)
- Amount
- Notes (optional, human-readable)
- "تجاهل" button to dismiss

### Resolution Flow

1. User sees review item
2. User can:
   - **Adjust wallet sources manually** via "تخصيص" dialog → calls `relabelJarWalletSource` → creates adjustment transaction → clears the source of inconsistency
   - **Dismiss** → calls `resolveMoneyLocationReview` → removes review, absorbs into `unlabeledAmount` (غير محدد)
3. After resolving all reviews, "يحتاج مراجعة" section disappears

### No interruption during transactions

A user creating a transaction NEVER sees a review dialog. Reviews are discovered AFTER the fact, inside the jar detail sheet.

---

## 7. Migration

On every `AppCubit.initialize()`, `_migrateMoneyLocationInconsistenciesSync()` runs:

1. For each jar: calls `MoneyLocationEngine.detectInconsistencies(jar)`
2. If `labeledTotal > balance + 0.01`: creates `labeledExceedsBalance` review
3. Idempotent: skips jars that already have `labeledExceedsBalance` reviews
4. Does NOT change `jar.balance` or `walletSources`

---

## 8. Files Modified

| File | Change |
|------|--------|
| `lib/features/budget/domain/entities/money_location_review_entity.dart` | **NEW** — `MoneyLocationReview` entity + `MoneyLocationReviewType` enum |
| `lib/features/budget/domain/services/money_location_engine.dart` | **NEW** — Single-responsibility engine for all `walletSources` mutations |
| `lib/features/budget/domain/entities/budget_setup_entity.dart` | Added `moneyLocationReviews` field to `LinkedWalletEntity` (backward compat) |
| `lib/features/transactions/domain/services/transaction_processor.dart` | Replace all `withUpdatedSource` calls with engine; add spending mismatch detection |
| `lib/features/app_state/presentation/cubits/app_cubit.dart` | Fix `relabelJarWalletSource`; add `resolveMoneyLocationReview`; add migration |
| `lib/features/wallets/presentation/widgets/jar_details_sheet.dart` | Add `_MoneyLocationReviewCard` widget and review section |

---

## 9. Migration Strategy

Existing user data:
- `moneyLocationReviews` field missing → deserialized as `[]` (empty) ✓
- `walletSources` with `labeledTotal > balance` → migration creates `labeledExceedsBalance` review on first launch
- All financial balances (`jar.balance`, `wallet.balance`) preserved exactly ✓
- All existing transactions preserved ✓
- No breaking changes to serialization keys ✓

---

## 10. Behavioral Changes vs. Old Architecture

| Area | Old | New |
|------|-----|-----|
| `relabelJarWalletSource` | Direct mutation + audit tx (two paths) | Only `addTransaction` → single path ✓ |
| `jarAllocationSpend` from unmatched wallet | Silent `walletSources` corruption | Review created, no corruption ✓ |
| `withUpdatedSource` going negative | Silent drop (entry removed) | Review created + entry set to 0 ✓ |
| Deleting audit tx after relabel | Double-reversal of `walletSources` | Correct single reversal ✓ |
| Transaction history replayability | NOT replayable (direct mutations) | Replayable ✓ |
| User interruption during transactions | None (existing) | None (preserved) ✓ |
| Financial balances | Correct | Correct (unchanged) ✓ |

---

## 11. Why the New Architecture Is Safer

1. **Single source of truth**: `walletSources` is updated ONLY via `MoneyLocationEngine` called from `TransactionProcessor`. No more dual-path mutation.

2. **Transaction history is authoritative**: Removing the direct mutation from `relabelJarWalletSource` means the transaction log fully describes all `walletSources` changes. Deleting a transaction correctly undoes its effect — nothing more, nothing less.

3. **No silent data loss**: Instead of silently removing entries when they go negative (Problem 4), the engine creates an auditable `MoneyLocationReview`. The user can see what happened and resolve it.

4. **Spending mismatch is explicit**: Instead of corrupting `walletSources[spendingWallet]` when the spending wallet doesn't match the funding wallet (Problem 3), the engine creates a review. Financial balance (`jar.balance`) decreases correctly; only the money location is flagged as uncertain.

5. **Non-disruptive**: All review creation happens silently, without interrupting the user during transaction creation. The user reviews discrepancies at their own pace, inside the jar detail sheet.

6. **Backward compatible**: `moneyLocationReviews` defaults to `[]` for all existing data. No data migration is required for financial fields. The migration only ADD reviews to flag existing inconsistencies — it never changes balances.
