<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Jar Money Location / Reserved Money — Architectural Report

> **Scope:** Read-only investigation. No code was modified.  
> **Date:** 2026-07-07

---

## 1. Data Model

### `JarWalletSource`
**File:** `lib/features/budget/domain/entities/budget_setup_entity.dart` (lines 244–266)

```dart
class JarWalletSource {
  final String walletId;  // ID of the physical wallet that contributed this amount
  final double amount;    // how much of the jar's balance came from this wallet
}
```

> Comment on line 334: `// مصادر الحصالة — label فقط، بدون transactions فعلية`  
> This is a **label only** — it does not create or imply any physical movement of money.

| Field | Purpose | Type | Updated by | Read by |
|---|---|---|---|---|
| `walletId` | Which physical wallet funded this portion | `String` | `TransactionProcessor` (via `updateJarSourceOnly` / `updateVirtualBalance`), `relabelJarWalletSource` | `wallets_screen.dart`, `jar_details_sheet.dart`, `add_transaction_screen.dart` |
| `amount` | How much this wallet contributed | `double` | Same as above | Same; also `labeledTotal` getter |

---

### `LinkedWalletEntity` (the "Jar")
**File:** `lib/features/budget/domain/entities/budget_setup_entity.dart` (lines 297–478)

| Field | Purpose | Type | Updated by | Read by |
|---|---|---|---|---|
| `balance` | Total virtual balance of the jar | `double` | `TransactionProcessor.apply/reverse` via `updateVirtualBalance` / `reverseVirtualBalance` | UI headers, jar cards, `jar_details_sheet.dart` line 155 |
| `walletSources` | Per-wallet labels showing where the balance came from | `List<JarWalletSource>` | `TransactionProcessor` via `updateJarSourceOnly`, `updateVirtualBalance`; `relabelJarWalletSource` directly | `wallets_screen._walletReservations`, `jar_details_sheet.jarWalletDistribution`, `add_transaction_screen.dart` |
| `walletBalances` | **Legacy field** — same data as `walletSources` as a `Map<String, double>` | `Map<String, double>` | Updated in parallel with `walletSources` by `TransactionProcessor` | Backward compatibility only; real calculations use `walletSources` |
| `labeledTotal` *(getter)* | `walletSources.fold(0.0, (s, e) => s + e.amount)` | `double` | Computed | `jar_details_sheet.dart`, `unlabeledAmount` |
| `unlabeledAmount` *(getter)* | `balance - labeledTotal` — portion with no wallet attribution | `double` | Computed | Displayed as "غير محجوز" in jar details |
| `fundingSource` | Which income source funds this jar (config) | `String` | Budget setup editing | `TransactionProcessor` income path |
| `funding` | Per-income-source planned amounts + physical flag | `List<LinkedWalletEntityFunding>` | Budget setup editing | `TransactionProcessor` income path |
| `automationType` | `'auto'` or `'confirm'` | `String` | Budget setup editing | `TransactionProcessor` income path |
| `pendingDistribution` | Staged amount waiting for user confirmation (confirm-type jars) | `double` | `TransactionProcessor` income path, `postponeJarDistribution` | `confirmJarDistribution`, jar cards (pending badge) |
| `pendingDistributionWalletId` | Which wallet the pending amount comes from | `String` | Same as above | `confirmJarDistribution` |
| `pendingDistributionSourceId` | Which income source triggered the pending | `String` | Same as above | `confirmJarDistribution` |
| `pendingDistributionSnoozedUntil` | ISO datetime until which the pending badge is hidden | `String` | `snoozeJarDistribution` | `isPendingDistributionVisible` getter |

**Key mutation method:**

```dart
LinkedWalletEntity withUpdatedSource(String walletId, double amount) {
  final rest = walletSources.where((s) => s.walletId != walletId).toList();
  if (amount > 0) {
    rest.add(JarWalletSource(walletId: walletId, amount: amount));
  }
  return copyWith(walletSources: rest);
}
```

This is the **only** way `walletSources` entries are mutated on the entity.  
**If `amount ≤ 0`, the entry is removed — there is no negative reservation.**

---

### `LinkedWalletEntityFunding`
**File:** lines 268–295

| Field | Purpose |
|---|---|
| `incomeSourceId` | Links this funding plan to an income source |
| `plannedAmount` | How much to take from each income deposit |
| `isPhysical` | `true` → money moves physically out of the wallet; `false` → virtual reservation only |

---

### `TransferType` Enum
**File:** `lib/core/constants/transaction_types.dart`

| Value | String |
|---|---|
| `walletToWallet` | `'wallet-to-wallet'` |
| `internalTransfer` | `'internal-transfer'` |
| `jarFunding` | `'jar-funding'` |
| `jarFundingPhysical` | `'jar-funding-physical'` |
| `jarAllocation` | `'jar-allocation'` |
| `jarAllocationCancel` | `'jar-allocation-cancel'` |
| `jarAllocationSpend` | `'jar-allocation-spend'` |
| `depositWithJarLabel` | `'deposit-with-jar-label'` |
| `allocationToJar` | `'allocation-to-jar'` |
| `jarToAllocation` | `'jar-to-allocation'` |
| `jarToJar` | `'jar-to-jar'` |

---

## 2. Transaction Processing

All processing lives in the **pure static service** `TransactionProcessor`:  
`lib/features/transactions/domain/services/transaction_processor.dart`  

Takes `AppStateEntity` + `TransactionEntity`, returns new `AppStateEntity`. No I/O.

### Internal Helpers

**`updateVirtualBalance(id, delta, physicalWalletId, trackWalletSource=true)`**
- Finds jar (or allocation) by `id`
- `jar.balance += delta`
- If `trackWalletSource=true` AND `physicalWalletId != null`: calls `withUpdatedSource(physicalWalletId, current + delta)`

**`updateJarSourceOnly(jarId, walletId, delta)`**
- Does NOT touch `jar.balance`
- Only calls `withUpdatedSource(walletId, current + delta)` — walletSources only

---

### `jarFunding` (virtual)
**Lines:** 148–165 (apply), 522–539 (reverse)

A virtual reservation: money is conceptually "moved" from the budget into the jar. No physical wallet changes.

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ❌ unchanged | ❌ unchanged |
| `jar.balance` | ✅ `+= amount` | ✅ `-= amount` |
| `walletSources[fromWallet]` | ✅ `+= amount` | ✅ `-= amount` |

`updateVirtualBalance` is called with `trackWalletSource=false` (balance only), then `updateJarSourceOnly` updates walletSources separately. This two-step was introduced to fix a historical sync bug.

---

### `jarFundingPhysical`
**Lines:** 127–147 (apply), 497–521 (reverse)

Money physically moves from the wallet into the jar.

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ✅ `-= amount` | ✅ `+= amount` |
| `jar.balance` | ✅ `+= amount` | ✅ `-= amount` |
| `walletSources[fromWallet]` | ✅ `+= amount` | ✅ `-= amount` |

---

### `depositWithJarLabel`
**Lines:** 208–226 (apply), 568–576 (reverse)

An income deposit that simultaneously labels itself as belonging to a jar.

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ✅ `+= amount` (income path) | ✅ `-= amount` |
| `jar.balance` | ✅ `+= amount` | ✅ `-= amount` |
| `walletSources[wallet]` | ✅ `+= amount` | ✅ `-= amount` |

No companion `jarAllocation` sub-transaction is created. The comment on line 222 says this was removed to avoid double-display. The `walletSources` update is fully encoded in the single `depositWithJarLabel` transaction.

---

### `jarAllocation`
**Lines:** 95–102 (apply), 464–472 (reverse)

Pure wallet-source relabeling — only `walletSources` changes.

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ❌ | ❌ |
| `jar.balance` | ❌ | ❌ |
| `walletSources[fromWallet]` | ✅ `+= amount` | ✅ `-= amount` |

Used as an **audit record** by `relabelJarWalletSource`. The actual state change was already applied directly before this transaction was created.

---

### `jarAllocationCancel`
**Lines:** 103–111 (apply), 473–481 (reverse)

Inverse of `jarAllocation`.

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ❌ | ❌ |
| `jar.balance` | ❌ | ❌ |
| `walletSources[fromWallet]` | ✅ `-= amount` | ✅ `+= amount` |

---

### `jarAllocationSpend`
**Not a special case** in `TransactionProcessor`. Falls into the general `expense` branch (lines 351–376).

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ✅ `-= amount` | ✅ `+= amount` |
| `jar.balance` | ✅ `-= amount` | ✅ `+= amount` |
| `walletSources[spendingWallet]` | ✅ `-= amount` (`trackWalletSource=true`) | ✅ `+= amount` |

The system assumes the spending wallet is the same as the wallet that originally funded the jar. If the jar was funded from wallet A but spending comes from wallet B, wallet B's walletSource entry is decremented (see §6, Problem 3).

---

### `allocationToJar` / `jarToAllocation` / `jarToJar`
Fall into the general `else` transfer branch (lines 185–200).

| | Apply | Reverse |
|---|---|---|
| `wallet.balance` | ❌ | ❌ |
| `fromEntity.balance` | ✅ `-= amount` (+ walletSources with `physicalWalletId=transaction.walletId`) | ✅ `+= amount` |
| `toEntity.balance` | ✅ `+= amount` (+ walletSources with `physicalWalletId=transaction.walletId`) | ✅ `-= amount` |

Both balance and walletSources change on both ends. For `jarToJar`: source jar decreases, target jar increases, both attributed to the same physical walletId.

---

## 3. Reservation Flow

### User Deposits Money Into a Jar (Virtual — `jarFunding`)

```
User action: fund jar from wallet W
     ↓
AppCubit.addTransaction(
  fromWalletId: W,
  toWalletId: JAR,
  type: transfer,
  transferType: jarFunding
)
     ↓
TransactionProcessor.apply
     ↓
updateVirtualBalance(JAR, +amount, trackWalletSource=false)
  → jar.balance += amount
     ↓
updateJarSourceOnly(JAR, W, +amount)
  → jar.walletSources[W] += amount
     ↓
wallet[W].balance: UNCHANGED
```

### User Deposits Money Into a Jar (Physical — `jarFundingPhysical`)

```
User action: move cash from wallet W into jar
     ↓
TransactionProcessor.apply
     ↓
wallet[W].balance -= amount
jar.balance += amount
jar.walletSources[W] += amount
```

---

### User Spends From the Jar

```
User action: expense tagged to JAR, paid from wallet W
     ↓
TransactionProcessor.apply (expense branch)
     ↓
wallet[W].balance -= amount
updateVirtualBalance(JAR, -amount, physicalWalletId=W, trackWalletSource=true)
  → jar.balance -= amount
  → jar.walletSources[W] -= amount
     (if result ≤ 0 → entry removed silently by withUpdatedSource)
```

---

### User Deletes a Transaction

```
AppCubit.deleteTransaction(txnId)
     ↓
TransactionProcessor.reverse(state, transaction)
     ↓
Mirrors apply exactly for the specific transferType
     ↓
For income transactions: also finds and reverses all sub-transactions
  → by parentId (new records)
  → OR by createdAt + incomeSourceId + walletId (backward compat, old records)
  → sub-transactions removed from state.transactions
     ↓
Parent transaction removed from state.transactions
```

**For `jarFunding` sub-transactions within an income reverse:**  
Checks `hasMatchingSourceChild` to decide whether to reverse walletSources via `reverseVirtualBalance` or let the sibling `jarAllocation` handle it. If a `jarAllocation` sibling exists for the same jar + wallet, walletSources reversal is delegated to that sibling's reverse.

---

### User Edits a Transaction

There is **no `editTransaction` method**. Editing is:

```
1. AppCubit.deleteTransaction(oldTxnId)
   → TransactionProcessor.reverse(state, oldTxn)
   → All balances restored to pre-transaction state

2. AppCubit.addTransaction(newParams)
   → TransactionProcessor.apply(state, newTxn)
   → New balances computed
```

Objects changed: identical to delete + add combined. Risk: if `walletSources` were manually adjusted via `relabelJarWalletSource` after the original transaction, the reverse produces a different state than the original (see §6, Problem 5).

---

## 4. Invariants

### Assumed by the Code

| Invariant | Enforced? |
|---|---|
| `jar.balance` reflects the cumulative net effect of all jar-related transactions | ✅ Yes — `TransactionProcessor` is the only path that changes `jar.balance` |
| `walletSources[walletId].amount ≥ 0` always | ✅ Yes — `withUpdatedSource` removes entries at ≤ 0 |
| `jar.labeledTotal ≤ jar.balance` | ❌ Not enforced — can be violated by `relabelJarWalletSource` |
| A `jarAllocation` audit tx's walletSource effect is redundant (state was already changed directly) | ⚠️ Assumed but not documented — creates double-accounting hazard |

### Open / Not Enforced

| Question | Answer |
|---|---|
| Can `walletSources` sum exceed `jar.balance`? | **Yes** — `relabelJarWalletSource` can set labels independently of balance |
| Can `walletSources` entries be negative? | **No** — `withUpdatedSource` removes them at ≤ 0 |
| Can `jar.balance` be negative? | **Yes** — no floor check |
| Can `unlabeledAmount` be negative? | **Yes** — if `labeledTotal > balance` |
| Can reservations exist without a corresponding `jar.balance`? | **Yes** — `relabelJarWalletSource` adds walletSources independent of balance |
| Can `jar.balance` exist without any `walletSources`? | **Yes** — old data predates `walletSources`; also virtual `jarFunding` before the two-step fix |
| Can `pendingDistribution` be "invisible" to `walletSources`? | **Yes** — pending amounts are not reflected in `walletSources` until confirmed |

---

## 5. UI

### `wallets_screen.dart`

**`_walletReservations(state, walletId)` → `Map<String, double>`**
```
For every jar in state.budgetSetup.linkedWallets:
  For every source in jar.walletSources where source.walletId == walletId:
    result[jar.id] = source.amount
```
Returns: `jarId → amountReservedFromThisWallet`

**`_walletReservedAmount(state, walletId)` → `double`**
```
Sum of all values in _walletReservations(state, walletId)
```
Displayed as: **"محجوز للحصالات"** at line 256 (wallet list) and line 506 (wallet detail card).

**Available balance:**
```
availableBalance = wallet.balance - _walletReservedAmount(state, walletId)
```
Shown as "الرصيد المتاح".

---

### `jar_details_sheet.dart`

**`jarWalletDistribution(jar)` → `Map<String, double>`**
```dart
{for (final s in jar.walletSources) s.walletId: s.amount}
```
Shown in the "توزيع الفلوس" panel.

**Balance display:**
- "الرصيد الكلي" → `jar.balance` directly (line 185)
- "غير محجوز" → `jar.unlabeledAmount` = `jar.balance - jar.labeledTotal` (line 191)

**`isJarWalletLocationTransaction(transaction)` — filters jar history:**
```dart
transferType ∈ {
  jarAllocation, jarAllocationCancel, jarAllocationSpend,
  allocationToJar, jarToAllocation, jarToJar
}
```

**Adjustment dialog:** calls `AppCubit.relabelJarWalletSource`, which directly mutates `walletSources` without going through `TransactionProcessor`.

---

### `add_transaction_screen.dart`

When creating a transaction tagged to a jar, reads `jar.walletSources` (line 143) to show the current funding distribution as "virtual labels" — does not query transaction history.

---

## 6. Existing Problems

### Problem 1 — Double Accounting in `relabelJarWalletSource`

**Scenario:** User adjusts wallet distribution of a jar through the jar details sheet.

`relabelJarWalletSource` does two things:
1. Directly sets `linkedWallets[idx] = jar.copyWith(walletSources: newSources)` — state already updated.
2. Adds an audit `TransactionEntity` (`jarAllocation` or `jarAllocationCancel`) to `state.transactions`.

If the user later **deletes** this audit transaction, `TransactionProcessor.reverse` calls `reverseJarSourceOnly` and undoes the walletSource a second time. The direct state mutation made by `relabelJarWalletSource` is undone by the deletion. Result: `walletSources` diverges from what the transaction history would produce.

---

### Problem 2 — `jarAllocation` Sub-Transaction + `jarFunding` Sub-Transaction in Auto-Income Path

**Scenario:** User receives income; a non-physical auto-type jar receives its share.

For each auto jar, `TransactionProcessor.apply` creates **two** sub-transactions:
1. `jarFunding` transfer — updates `jar.balance`, walletSources **not** tracked (`trackWalletSource=false`)
2. `jarAllocation` transfer — updates walletSources via `updateJarSourceOnly`

On reverse, `hasMatchingSourceChild` checks for a sibling `jarAllocation`. The backward-compat path (old transactions without `parentId`) matches by `createdAt + incomeSourceId + walletId`. If two jars from the same income share the same timestamp, `hasMatchingSourceChild` can misattribute a sibling from one jar to another, causing a double-reverse of walletSources.

---

### Problem 3 — `jarAllocationSpend` Uses Spending Wallet, Not Funding Wallet

**Scenario:** Jar funded from wallet A (virtual). User spends; physical wallet is B.

`updateVirtualBalance` is called with `physicalWalletId = transaction.walletId` (wallet B). This decrements `walletSources[B]`. But wallet B may not be in `walletSources`. The `withUpdatedSource` call receives a value ≤ 0 and silently drops it. Meanwhile `walletSources[A]` remains unchanged. Result: `jar.balance` correctly decreases, but `walletSources` is wrong — wallet A still shows the full original reservation.

---

### Problem 4 — `withUpdatedSource` Silently Discards Negative Reservations

**Scenario:** Any operation that decrements a walletSource below zero.

`withUpdatedSource` removes entries where `amount ≤ 0` with no log or assertion. If a sequence of operations results in a net negative for a walletSource, the entry is silently dropped. Subsequent operations start from 0 for that wallet. `jar.balance` reflects the true total but `walletSources` no longer adds up to it, inflating `unlabeledAmount`.

---

### Problem 5 — Editing After Manual `relabelJarWalletSource`

**Scenario:** User funds a jar → manually adjusts wallet distribution → then edits the original funding transaction.

Edit = delete old + add new. Deleting the `jarFunding` transaction reverses `walletSources[fromWallet]` by the original amount. But `relabelJarWalletSource` had already changed `walletSources` to different values. The reverse may set `walletSources[fromWallet]` to a value that `withUpdatedSource` drops (≤ 0). The jar ends with a `balance` that is lower than `labeledTotal` from other wallets — `unlabeledAmount` becomes negative.

---

### Problem 6 — Deleting an Income With Multiple Jar Sub-Transactions (Old Data)

**Scenario:** Income auto-distributed to multiple jars on the same timestamp (old data, no `parentId`).

Backward-compat sub-transaction matching uses `createdAt + incomeSourceId + walletId`. All sub-transactions for the same income event share these three fields. The `hasMatchingSourceChild` heuristic may attribute a sibling `jarAllocation` from jar X to the `jarFunding` of jar Y (same wallet, same timestamp), reversing the wrong walletSource entry.

---

### Problem 7 — `pendingDistribution` Is Invisible to `walletSources`

**Scenario:** A confirm-type jar has a pending distribution that has not been confirmed yet.

`pendingDistribution` represents committed-but-unconfirmed money. The physical wallet balance has not decreased yet, and `walletSources` has not been updated. The wallet appears to have more available money than it will after confirmation. There is no check preventing the user from spending from the wallet before confirming, leaving insufficient balance post-confirmation.

---

### Problem 8 — Backup/Restore Preserves Inconsistencies

**Scenario:** User restores a backup.

The entire `AppStateEntity` is replaced including all `walletSources`. There is no integrity check or recomputation of `walletSources` from transaction history on restore. Any of the inconsistencies above that existed at backup time are faithfully restored with no indication to the user.

---

### Problem 9 — `labeledTotal` Can Exceed `jar.balance`

**Scenario:** `relabelJarWalletSource` increases a label without a corresponding `jarFunding`; or a backup is restored with inconsistent data.

`unlabeledAmount = jar.balance - labeledTotal`. If `labeledTotal > balance`, `unlabeledAmount < 0`. The UI would display a negative "غير محجوز" value. No code guards against this.

---

## 7. Final Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER ACTION                             │
│   (fund jar / spend / deposit with label / relabel sources)     │
└────────────────────────┬────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────────┐
│                       AppCubit                                  │
│  addTransaction / deleteTransaction / relabelJarWalletSource    │
│  confirmJarDistribution / postponeJarDistribution               │
└──────┬──────────────────────────────┬───────────────────────────┘
       │  (most paths)                │  (relabelJarWalletSource only)
       ↓                              ↓
┌─────────────────────┐   ┌──────────────────────────────────────┐
│ TransactionProcessor│   │ Direct state mutation                │
│ .apply / .reverse   │   │ jar.walletSources patched directly   │
│                     │   │ + audit TransactionEntity added      │
│ Pure function.      │   │   to state.transactions              │
│ No I/O.             │   └────────────────┬─────────────────────┘
└──────┬──────────────┘                    │
       │                                   │
       ▼                                   ▼
┌────────────────────────────────────────────────────────────────┐
│                    AppStateEntity                              │
│                                                                │
│  wallets[]                                                     │
│    └── WalletEntity { id, balance }                            │
│         ← PHYSICAL truth: money you actually have              │
│                                                                │
│  budgetSetup.linkedWallets[]                                   │
│    └── LinkedWalletEntity (Jar)                                │
│          ├── balance         ← VIRTUAL total in the jar        │
│          ├── walletSources[] ← LABELS: which physical          │
│          │    └── { walletId, amount }   wallet funded what    │
│          └── pendingDistribution ← uncommitted, NOT in sources │
│                                                                │
│  transactions[]                                                │
│    └── TransactionEntity                                       │
│          ├── type (income / expense / transfer)                │
│          ├── transferType (jarFunding / jarAllocation / …)     │
│          ├── parentId (links sub-txns to parent income)        │
│          └── walletId / fromWalletId / toWalletId              │
└────────────────────────────────────────────────────────────────┘
       │
       ↓
┌────────────────────────────────────────────────────────────────┐
│                    UI Calculations                             │
│                                                                │
│  wallets_screen                                                │
│    _walletReservedAmount = Σ jar.walletSources[this wallet]    │
│    _walletReservations   = { jarId → walletSources[wallet] }   │
│    availableBalance      = wallet.balance − reservedAmount     │
│                                                                │
│  jar_details_sheet                                             │
│    jarWalletDistribution = { walletId → source.amount }        │
│    unlabeledAmount       = jar.balance − jar.labeledTotal      │
└────────────────────────────────────────────────────────────────┘
```

---

### Source of Truth Summary

| Data | Source of Truth |
|---|---|
| Physical wallet balance | `WalletEntity.balance` — updated **only** by `TransactionProcessor` |
| Jar total balance | `LinkedWalletEntity.balance` — updated **only** by `TransactionProcessor` |
| Wallet-to-jar attribution | `LinkedWalletEntity.walletSources` — updated by `TransactionProcessor` **and** directly by `relabelJarWalletSource` |
| Transaction history | `AppStateEntity.transactions[]` — append-only (delete removes from list) |

> **Critical observation:** There is **no single source of truth** for `walletSources`.  
> It is maintained by two independent code paths (`TransactionProcessor` and `relabelJarWalletSource`) that are not coordinated.  
> Transaction history **cannot be fully replayed** to recompute `walletSources` because `relabelJarWalletSource` mutations are baked directly into the entity state, and the corresponding `jarAllocation` audit transactions are only partial records of that change.

---

## 8. Category Ownership & Scope (Jar-Linked Categories)

> **Added:** 2026-07-13, after a bug fix for jar categories appearing under the wrong Income/Expense tab.

This section is a distinct data model from the money/balance system above — it governs `CategoryEntity` objects, not wallet/jar balances — but lives in the same file because it shares the same jar/allocation container entities.

### 8.1 Ownership source of truth

A category's ownership (which jar or allocation it "belongs to", vs. being a general category) is determined **solely by list membership**:

- `LinkedWalletEntity.categories` — categories owned by a jar
- `AllocationEntity.categories` — categories owned by an allocation
- Categories not present in any jar's or allocation's list are **general** categories, read from `AppStateEntity.categories`

`CategoryEntity.walletId` and `CategoryEntity.allocationId` are **write-only / dead fields**: some creation paths set them, but no code anywhere reads them back for filtering, grouping, ownership checks, or display. Confirmed by an exhaustive repository-wide search — every real ownership check operates on list containment:

- `categories_screen.dart` `_sectionsFor`
- `add_transaction_screen.dart` jar/allocation category pickers
- `AppCubit.updateLinkedWalletCategories` / allocation equivalent

**Do not treat `walletId`/`allocationId` as authoritative.** Reconciling or removing these dead fields is a separate, not-yet-scheduled cleanup task — do not add new logic that reads them without first making that reconciliation explicit.

### 8.2 Scope is independent of ownership

Every category also carries a `scope` (`'income'` or `'expense'`), which is **orthogonal to ownership**. A single jar can and normally does hold categories of both scopes at once:

- Income-scope categories: labels used when depositing money **into** the jar (e.g. "Jar Deposit")
- Expense-scope categories: labels used when spending **from** the jar

A jar's `categories` list is **mixed-scope by design** — never assume it is single-scope, and never display or offer it without filtering by the scope relevant to the current context.

### 8.3 Bug history: Jar Deposit appearing under Expense

**Root cause (fixed 2026-07-13):**

1. `categories_screen.dart`'s `_sectionsFor` only ever rendered jar (`linkedWallets`) sections under the Expense tab. The Income tab never showed jar sections at all.
2. Because the "add category" UI for a jar was only reachable from the Expense tab, any category created from a jar section always inherited `scope: 'expense'` from the active tab — including categories meant to be income labels like "Jar Deposit".
3. `add_transaction_screen.dart`'s jar-aware category UI existed only in the expense-type transaction block; the income-type block never referenced jars and always showed the general income category list, so a jar-scoped income category could never be created or selected there either.
4. Both screens displayed a jar's full unfiltered `categories` list (mixed income + expense) rather than filtering by the scope relevant to the tab/flow.

**Fix applied:**

- `categories_screen.dart`: jar sections now render under **both** the Income and Expense tabs, each filtered to `category.scope == 'income'` or `'expense'` respectively. Category creation already used `scope: _tab`, so this alone makes jar-linked income categories creatable/visible with the correct scope.
- `add_transaction_screen.dart`: the expense-side jar category list is filtered to `scope == 'expense'`; the income-side flow gained a jar-aware category list (`scope == 'income'`, sourced from the selected income jar) that is shown/created when a jar is chosen as the income deposit target, with the resulting category persisted into that jar via `linkedWalletId` + `scope: 'income'`.

**Rule for future work:** any UI section, filter, or creation flow touching a jar's or allocation's `categories` list must filter/tag by `category.scope` explicitly. Never expose or persist-create against the raw unfiltered list, and never infer a new category's `scope` implicitly from "which tab happens to expose the add-category button" — pass it explicitly.
