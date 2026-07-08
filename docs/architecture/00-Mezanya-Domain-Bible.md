# Mezanya — Domain Bible
> **Status:** Active — Primary Source of Truth  
> **Created:** 2026-07-08  
> **Scope:** Domain boundaries, responsibilities, and architectural rules for the Mezanya project

---

## 1. The Five Independent Domains

The application is composed of five domains that must never overlap in responsibility:

| # | Domain | Responsibility |
|---|--------|---------------|
| 1 | **Wallet** | Physical money — what the user actually holds |
| 2 | **Budget** | Monthly planning — income, allocations, jars, recurring |
| 3 | **Transaction** | Financial history — the immutable record of what happened |
| 4 | **Jar** | Reserved balances — virtual money set aside for a purpose |
| 5 | **Money Distribution** | Where Jar money physically exists across wallets |

### Hard Boundaries

```
Wallet      → knows nothing about Jars, Budget, Transactions, or Distribution
Budget      → knows nothing about Wallets' physical balances
Transaction → knows nothing about Distribution
Jar         → knows nothing about individual Wallets (balance-wise)
Distribution → bridges Jar ↔ Wallet; touches neither balance
```

**Distribution is the bridge. It is NOT owned by any other domain.**

---

## 2. Domain Responsibilities

### 2.1 Wallet Domain

**Owns:** `WalletEntity { id, name, balance, reservedForSavings, icon, iconColor }`

**Responsible for:**
- Physical money the user holds
- Adding, editing, removing wallets
- Opening balances

**Must never:**
- Know about Jar logic
- Compute Distribution labels
- Depend on Transaction history for its balance

---

### 2.2 Budget Domain

**Owns:** `BudgetSetupEntity`, `LinkedWalletEntity` (Jar), `AllocationEntity`, `IncomeSourceEntity`, `DebtEntity`

**Responsible for:**
- Monthly budget plan (income sources, allocation percentages)
- Jar definitions (monthly target, funding source, automation type)
- Recurring payment plans
- Debt/installment tracking

**Must never:**
- Access physical wallet balances for budget calculations
- Modify Transaction history
- Own Distribution logic (even though `walletSources` is currently stored on `LinkedWalletEntity` — this is a storage convenience, not a responsibility)

**Current coupling to Distribution (known, to be resolved in Phase 2):**
- `LinkedWalletEntity.walletSources` stores distribution data directly
- `LinkedWalletEntity.moneyLocationReviews` stores integrity flags
- These are stored here for backward compatibility, not architectural correctness

---

### 2.3 Transaction Domain

**Owns:** `TransactionEntity`, `TransactionProcessor`, `RecurringTransactionEntity`

**Responsible for:**
- Recording what happened financially (income, expense, transfer)
- Applying and reversing transactions to produce new financial state
- Sub-transaction management (income → jar funding chain)

**Must never:**
- Know about Distribution
- Call Distribution engine or validate Distribution entries
- Create or modify `walletSources` directly (current known violation — see §5)

**`TransactionProcessor` contract:**
```
apply(AppStateEntity, TransactionEntity) → AppStateEntity
reverse(AppStateEntity, TransactionEntity) → AppStateEntity
```
Pure function. No I/O. No side effects outside the returned state.
Financial balances (wallet.balance, jar.balance) are the only thing TransactionProcessor modifies.
`walletSources` updates in TransactionProcessor are a **known architectural violation** (see §5).

---

### 2.4 Jar Domain

**Owns:** `LinkedWalletEntity.balance`, `LinkedWalletEntity.pendingDistribution*`

**Responsible for:**
- Tracking total reserved balance per Jar
- Pending distribution flows (confirm/auto)

**Must never:**
- Know which specific wallet funded it (that's Distribution's job)
- Modify physical wallet balances

---

### 2.5 Money Distribution Domain

**Owns:** `DistributionEntry { jarId, walletId, amount, origin, linkedTransactionId }`

**Responsible ONLY for:**
- Creating Distribution entries
- Editing Distribution entries
- Removing Distribution entries
- Moving Distribution entries (jar-to-jar or wallet-to-wallet relabeling)
- Validating integrity of Distribution entries

**Must NEVER:**
- Change `wallet.balance`
- Change `jar.balance`
- Create or modify Transaction records
- Depend on Budget calculation results

**Current storage location:** `LinkedWalletEntity.walletSources` (list of `JarWalletSource`)  
**Future storage:** Dedicated `DistributionEntry` collection (Phase 2+)

---

## 3. The Distribution Entry

A Distribution Entry describes a single labeled allocation:

```
Jar ─→ Wallet ─→ Amount
```

with optional metadata:
- `linkedTransactionId` — the Transaction that created this entry
- `origin` — `automatic` | `manual` | `migration`
- `createdAt`, `updatedAt`

**A Distribution Entry is NOT a financial record.** It is metadata. The financial truth is always:
- `wallet.balance` — set by `TransactionProcessor`
- `jar.balance` — set by `TransactionProcessor`

Distribution Entries describe *where the jar money is believed to physically be*, but changing them never changes any balance.

---

## 4. The Distribution Engine

`DistributionEngine` is the single entry point for all Distribution mutations.

### Allowed Operations

| Method | Description |
|--------|-------------|
| `upsert` | Create a new entry or replace an existing one for a (jar+wallet) pair |
| `applyDelta` | Increase or decrease an entry's amount by a relative delta |
| `removeAllForJar` | Remove every entry belonging to a jar |
| `removeById` | Remove a single entry by its id |
| `move` | Transfer amount from one (jar+wallet) to another (jar+wallet) |

### `upsert` semantics

`upsert` replaces the existing entry for a given `(jarId, walletId)` pair with a new record (new id, new timestamps). It does not update in place. **It is not suitable for preserving entry history.** For Phase 1 this is acceptable because entries don't carry meaningful ids; Phase 2+ will introduce proper `update` when entry identity matters.

### `applyDelta` contract — explicit failure, no silent clamping

When `applyDelta` would produce a negative result, it throws `DistributionNegativeAmountException`. It does **not** clamp silently and does **not** create a `MoneyLocationReview`.

**Rationale:** Creating a review is a higher-level concern (AppCubit or a post-transaction hook). The engine is a pure function — it must report the problem clearly. The caller decides how to respond.

### Forbidden Operations

The engine must NEVER:
- Call `TransactionProcessor`
- Modify `wallet.balance`
- Modify `jar.balance`
- Create `TransactionEntity` records
- Create `MoneyLocationReview` objects (that is AppCubit's responsibility)

---

## 5. Known Architectural Violations (Documented, Not Hidden)

These violations exist in the current codebase. They are documented here so they can be properly resolved in future phases, not hidden behind additional logic.

### Violation A — TransactionProcessor updates walletSources directly

`TransactionProcessor.apply/reverse` calls `jar.withUpdatedSource(...)` to update `walletSources` after each transaction. This means the Transaction domain owns Distribution data.

**Why it exists:** Distribution was not a separate domain when `walletSources` was introduced.

**Impact:**
- Problem 3: `jarAllocationSpend` uses the spending wallet, not the funding wallet, to update walletSources. If wallet B pays for something funded by wallet A, walletSources[B] is decremented — which may not exist — while walletSources[A] is unchanged. Result: `labeledTotal` stays higher than it should.
- Problem 4: `withUpdatedSource` silently removes entries that go ≤ 0. There is no record of this happening. `unlabeledAmount` silently inflates.

**Resolution plan (Phase 2):** Move walletSources updates to a post-transaction hook in AppCubit that calls `DistributionEngine`. `TransactionProcessor` should not call any Distribution code.

### Violation B — walletSources stored on LinkedWalletEntity (Budget domain)

Distribution data is stored inside `LinkedWalletEntity`, which belongs to the Budget domain. This couples Budget and Distribution.

**Why it exists:** Storage simplicity — everything was in one `AppStateEntity`.

**Resolution plan (Phase 2+):** Introduce `DistributionEntry` as a top-level concept. Migrate `walletSources` data to proper `DistributionEntry` records.

### Violation C — relabelJarWalletSource (now fixed)

The old `relabelJarWalletSource` in AppCubit used TWO paths simultaneously:
1. Direct mutation of `jar.walletSources` (bypassing TransactionProcessor)
2. An audit `TransactionEntity` (jarAllocation/jarAllocationCancel)

This caused double-accounting: deleting the audit transaction would reverse the walletSource a second time.

**Status: Fixed.** `relabelJarWalletSource` now routes entirely through `addTransaction`, which goes through `TransactionProcessor`. The transaction record IS the source of truth for the change. This is correct behavior.

---

## 6. Integrity Validation

`DistributionValidator` detects problems only. It never modifies data.

### Detected Problems

| Issue | Description |
|-------|-------------|
| `totalExceedsJarBalance` | Sum of entries for a jar > jar.balance |
| `negativeAmount` | Any entry with amount ≤ 0 |
| `unknownWallet` | Entry references a wallet that doesn't exist |
| `unknownJar` | Entry references a jar that doesn't exist |
| `orphanedTransaction` | Entry's `linkedTransactionId` references a deleted transaction |

### Never

The validator never:
- Deletes or modifies entries
- Creates `MoneyLocationReview` objects
- Changes financial balances
- Logs corrections automatically

---

## 7. MoneyLocationReview

`MoneyLocationReview` is an implementation detail of the Distribution domain that provides user-visible signals about detected inconsistencies.

Reviews are created by:
- `MoneyLocationEngine.applyLocationDelta` — when a delta would produce a negative result
- `MoneyLocationEngine.addSpendingMismatchReview` — when spending wallet is not in sources (future, currently not active)
- `_migrateMoneyLocationInconsistenciesSync` — when migration detects `labeledTotal > balance`

Reviews are resolved by:
- `AppCubit.resolveMoneyLocationReview` — user dismissal
- (Future) `DistributionEngine` — when the underlying inconsistency is corrected

**Reviews are NOT the core architecture.** They are signals. The core architecture is the `DistributionEntry`.

---

## 8. Migration Strategy

### Phase 1 (current) — Foundation

- [x] Create `DistributionEntry` entity model
- [x] Create `DistributionEngine` service (pure operations)
- [x] Create `DistributionValidator` service (detect only)
- [x] Create Domain Bible (this document)
- [x] Fix `relabelJarWalletSource` double-accounting (Violation C)
- [x] Add one-time migration for `labeledTotal > balance` inconsistencies
- [x] Document known violations (A, B) explicitly

### Phase 2 — Separation

- [ ] Move walletSources updates OUT of `TransactionProcessor`
- [ ] Post-transaction hook in `AppCubit` → `DistributionEngine`
- [ ] Handle spending mismatch properly (Problem 3)
- [ ] Handle negative delta properly (Problem 4)
- [ ] Wire `DistributionValidator` to user-facing integrity report

### Phase 3 — Migration

- [ ] Migrate `walletSources` to proper `DistributionEntry` records
- [ ] Remove `walletSources` from `LinkedWalletEntity`
- [ ] Move `moneyLocationReviews` from `LinkedWalletEntity` to Distribution domain state

---

## 9. Architectural Rules (Non-Negotiable)

1. **One source of truth per domain.** `wallet.balance` and `jar.balance` are set ONLY by `TransactionProcessor`.
2. **Distribution never changes balances.** `DistributionEngine` and `DistributionValidator` never touch any balance.
3. **Transaction domain does not own Distribution.** Any `walletSources` update inside `TransactionProcessor` is a known violation being phased out.
4. **Never hide problems with heuristics.** Document them here and resolve them properly in subsequent phases.
5. **`relabelJarWalletSource` routes through `addTransaction`.** This is the only correct path for user-initiated Distribution changes.
6. **Reviews are signals, not solutions.** Creating a review acknowledges an inconsistency; it does not resolve it.
