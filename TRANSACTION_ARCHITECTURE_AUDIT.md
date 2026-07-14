# Mezanya — Transaction System Architecture Audit

**Scope:** Business-logic/domain audit of manual vs. recurring-generated transactions.
**Status:** Investigation only. No code was modified in producing this report.
**Method:** Direct file reads + read-only codebase exploration. Every claim below cites a file path and, where practical, a line number. Anything not confirmed in code is explicitly marked "unknown / not found in code" rather than assumed.

---

## Phase 1 — The Complete Transaction Pipeline

There is no classic Controller → UseCase → Repository → Database → Analytics → UI-refresh layering with distinct persistence per feature. The real pipeline is flatter:

```
User Action (UI widget)
   │
   ▼
Screen / Dialog  (add_transaction_screen.dart, recurring_transaction_composer_screen.dart,
                  recurring_transactions_screen.dart, notifications_center_screen.dart)
   │  calls a method on…
   ▼
AppCubit  (lib/features/app_state/presentation/cubits/app_cubit.dart)
   — the ONLY "controller" layer. There is no separate UseCase layer.
   Methods: addTransaction, deleteTransaction, recordRecurringIncomeOccurrence,
   recordRecurringExpenseOccurrence, _recordDebt, etc.
   │
   ▼
TransactionProcessor.apply / .reverse
   (lib/features/transactions/domain/services/transaction_processor.dart)
   — pure functions: AppStateEntity + TransactionEntity → new AppStateEntity.
   Mutates wallet balances, jar/allocation virtual balances, money distributions,
   appends to `transactions` list. This is the ONLY place balances change.
   │
   ▼
AppCubit._applyAndLog  (app_cubit.dart:~301-346)
   — wraps the state transition, writes an activity-log entry, then:
   │
   ▼
AppRepository.saveState()  →  SharedPrefsAppRepository
   (lib/features/app_state/domain/repositories/app_repository.dart,
    lib/features/app_state/data/repositories/shared_prefs_app_repository.dart:33-36)
   — the entire AppStateEntity tree is `jsonEncode(state.toMap())` and written to a
   single SharedPreferences key on every mutation. This is the ONLY "database" —
   there is no SQLite/Hive/Firestore for app data.
   │
   ▼
emit(next)  (Cubit/Bloc state emission) → UI rebuilds via BlocBuilder/BlocListener
   │
   ▼
Analytics screens (transaction_charts_screen.dart) re-derive KPIs/charts by
   filtering the SAME in-memory `state.transactions` list — there is no separate
   analytics store or pre-aggregation.
   │
   ▼ (optional, gated by a setting)
AppCubit._autoSync (app_cubit.dart:377-414) — best-effort cloud BACKUP (not sync):
   uploads the same JSON blob to Firebase Storage. This is one-way backup, not a
   two-way sync engine, and it is not in the critical path of any transaction write.
```

**Key structural fact:** There is no per-feature Repository/UseCase abstraction for transactions. `AppRepository` only knows how to load/save the whole `AppStateEntity` blob. All transaction business logic lives in two places: `AppCubit` (orchestration + logging) and `TransactionProcessor` (balance math). This is confirmed by the persistence-layer investigation (`AppRepository` interface = `loadState()`/`saveState()` only, no `TransactionRepository` exists).

---

## Phase 2 — Every Transaction-Related Model

| Class | File | Purpose | Created by | Owned/edited by | Deleted by | Balance updates by |
|---|---|---|---|---|---|---|
| `TransactionEntity` | `lib/features/transactions/domain/entities/transaction_entity.dart` | The only concrete "a money movement happened" record. Used for manual AND recurring-generated transactions — **there is no separate model for generated transactions.** | `AddTransactionScreen._submitNormal` (manual), `AppCubit.recordRecurringIncomeOccurrence`/`recordRecurringExpenseOccurrence` (generated), `TransactionProcessor.apply` (auto sub-transactions) | `AppCubit.addTransaction`/`deleteTransaction` (delete-then-recreate for edits) | `AppCubit.deleteTransaction` | `TransactionProcessor.apply`/`.reverse` |
| `RecurringTransactionEntity` | `lib/features/transactions/domain/entities/recurring_transaction_entity.dart` | A *template/rule*, not a transaction. Holds schedule, amount, target jar/allocation, execution type, and `lastHandledOccurrenceAt`. | `AddTransactionScreen._submitRecurring` via `RecurringTransactionComposerScreen` | Same composer screen (edit) | `AppCubit` recurring-delete path (screen: `recurring_transactions_screen.dart`) | Never directly — by design it should never touch balances itself (see Phase 7) |
| `RecurringExpensePrompt` | `lib/features/transactions/domain/services/recurring_schedule_engine.dart` | Ephemeral UI-only DTO describing "this rule is upcoming/due/overdue right now." Never persisted. | `RecurringScheduleEngine.expensePrompt` | n/a (pure function output) | n/a | n/a |
| `RecurringIncomePostDialogResult` | `lib/features/transactions/presentation/widgets/recurring_income_post_dialog.dart` | UI result object carrying the user-confirmed amount/date from the manual-post dialog (now shared by income and expense via the `isExpense` flag). | The dialog itself | n/a | n/a | n/a |
| `RecurringTransactionComposerResult` | `lib/features/transactions/presentation/screens/recurring_transaction_composer_screen.dart` | Navigator result wrapper: either a saved `RecurringTransactionEntity` or a delete request. | Composer screen | n/a | n/a | n/a |
| `DistributionEntry` | `lib/features/money_distribution/domain/entities/distribution_entry.dart` | Tracks how much of a jar's virtual balance came from which physical wallet (`origin: automatic/manual`). Not a transaction, but mutated by every transaction that touches a jar. | `TransactionProcessor` | `TransactionProcessor` | `TransactionProcessor` | n/a |

**No `TransactionModel`, `GeneratedTransaction`, `TransferTransaction`, `DraftTransaction`, `ScheduledTransaction`, Firestore model, or Mapper class exists anywhere in `lib/`.** Confirmed by full-repo search — the only serialization is each entity's own `toMap`/`fromMap`, and `AppStateEntity.toMap`/`fromMap` (`lib/features/app_state/domain/entities/app_state_entity.dart:154-261`) recursively composes them. There is exactly one model per concept; "Manual transaction" and "Generated transaction" are the *same class* with different construction call-sites — this is the central architectural fact the rest of this report follows from.

---

## Phase 3 — Manual vs. Recurring-Generated: Comparison Table

| Operation | Manual transaction | Recurring-generated transaction | Same pipeline? |
|---|---|---|---|
| **Create** | `AddTransactionScreen._submitNormal` → `AppCubit.addTransaction` → `TransactionProcessor.apply` | `AppCubit.recordRecurringIncomeOccurrence`/`recordRecurringExpenseOccurrence` → `TransactionProcessor.apply` | **Same processor**, different `AppCubit` entry point and different field population (see Phase 4/Bug findings below — income path sets `toWalletId` from `targetJarId`, expense path does not). |
| **Edit** | Same screen, `initialTransaction != null` → **delete old + add new** (`add_transaction_screen.dart:1137-1140`) | Identical code path — a generated transaction opened for edit goes through the exact same delete-then-add. No branch exists for `parentId`/generated origin. | Same pipeline, but see Phase 4: the *effect* differs because generated transactions carry no back-reference to their rule, so editing silently detaches them. |
| **Delete** | `AppCubit.deleteTransaction` → `TransactionProcessor.reverse` | Identical — `deleteTransaction` has no branch for generated vs. manual (confirmed, no `parentId`/rule check exists in that method). | Same pipeline. But deleting a generated transaction does **not** reset `RecurringTransactionEntity.lastHandledOccurrenceAt`, so the occurrence is permanently orphaned (never re-offered). This is a real behavioral divergence even though the code path is shared. |
| **Restore** | No restore feature exists anywhere in the codebase (`grep` found no "restore"/"undo" transaction feature). | Same — none. | N/A — feature doesn't exist for either. |
| **Undo** | None. | None. | N/A. |
| **Transfer** | Created directly in `wallets_screen.dart` (~1053-1070) via `TransferType`, processed by `TransactionProcessor.apply` (physical: 116-165; virtual: 171-221). | **No recurring transfer concept exists.** The only "automatic transfer"-like behavior is `TransferType.jarFunding`/`jarAllocation` sub-transactions auto-generated by `TransactionProcessor.apply` when an income transaction (manual or recurring-generated) carries an `incomeSourceId` tied to a budget plan. | Different: manual transfers are a first-class user action; there is no recurring-transfer rule type at all. |
| **Deposit / Withdraw** | Handled as income/expense with `toWalletId`/jar semantics. | Income path forwards `targetJarId` → `toWalletId` correctly (`app_cubit.dart` `recordRecurringIncomeOccurrence`). Expense path does **not** (confirmed bug, see below) — jar is silently dropped. | **Diverges** — this is a real bug, not by design. |
| **Goal contribution** | A distinct `GoalEntity` (`lib/features/goals/domain/entities/goal_entity.dart`) exists, separate from budget allocations/jars. Achieving a goal generates a transaction via `_openAchieveSheet` in `goals_screen.dart` (~line 754). | No recurring-goal-contribution feature exists. | Goals are manual-only; not part of the recurring engine at all. |
| **Budget contribution** | `budgetScope`/`allocationId`/`toWalletId` set from the target picker in `add_transaction_screen.dart` (shared UI). | Same field names copied from `RecurringTransactionEntity.budgetScope`/`allocationId`/`targetJarId` at execution time — but see Bug 2 below, the *source value* is already wrong for jar targets before it ever reaches the recurring path, because the picker UI is shared. | Same pipeline, shared root defect. |
| **Balance update** | `TransactionProcessor.apply` | Same function | Identical. |
| **History** | Appended to `state.transactions`; shown in transaction lists filtered by date/wallet. | Same list, same UI filters — no separate "generated transactions" history view exists. | Identical. |
| **Analytics** | `transaction_charts_screen.dart` reads `state.transactions` directly, filters out internal jar/allocation transfers via `_isJarTx` (lines 33-38/48/54). | Same screen, same filter — manual and generated transactions are **not distinguished at all** in analytics. | Identical (by design — this part is architecturally sound: there's one ledger). |
| **Cloud Sync** | `AppCubit._autoSync` uploads the whole state blob to Firebase Storage if `auto_cloud_backup_enabled`. | Same — sync operates on the whole state, not per-transaction. | Identical (it's a full-state backup, not per-record sync). |
| **Offline Sync** | N/A — the app is local-first via SharedPreferences; there is no server round-trip required to write a transaction. | Same. | Identical — "offline sync" as a distinct concept does not exist; everything is already offline-first, and the only network operation is the one-way backup upload. |

**Conclusion for Phase 3:** Manual and generated transactions use the *same* `TransactionEntity` class and the *same* `TransactionProcessor`, so at the balance/analytics/history layer there is genuinely one pipeline (this part of the architecture is not duplicated). The divergence is narrower and more dangerous than "two parallel systems": it is that the **two `AppCubit` construction call-sites for expenses (`addTransaction` vs. `recordRecurringExpenseOccurrence`) populate the `TransactionEntity` fields inconsistently**, and that **no field on `TransactionEntity` records which `RecurringTransactionEntity` (if any) produced it**, which breaks editing, deletion bookkeeping, and traceability even though the runtime balance math is shared.

---

## Phase 4 — Editing Investigation

Trace: `RecurringTransactionsScreen`/transaction list → `AddTransactionScreen` (edit mode, `initialTransaction` set) → `_submitNormal` → `AppCubit.deleteTransaction` + `AppCubit.addTransaction` → `TransactionProcessor.reverse` + `.apply` → `_repository.saveState` → `emit` → UI refresh. There is **no separate edit path for generated transactions** — confirmed by reading `add_transaction_screen.dart:1137-1193`, which contains no check for `parentId`, no check for "was this created by a recurring rule," and no reference to `RecurringTransactionEntity` at all during edit/save.

Answers to the specific questions posed:

- **Is editing blocked intentionally?** No. No guard, flag check, or dialog prevents editing a generated transaction. Confirmed absent in `add_transaction_screen.dart` and `app_cubit.dart`.
- **Is editing partially supported?** Effectively yes, but only because the generic delete+recreate path happens to work for balance purposes — not because generated transactions were designed to be editable.
- **Does editing accidentally modify recurrence rules?** No — `_submitNormal` only calls `addTransaction`/`deleteTransaction`; it never touches `state.recurringTransactions`. The `RecurringTransactionEntity` rule is untouched by editing one of its generated instances.
- **Does editing modify only one occurrence?** Yes, but as a side effect of "modify only one *transaction row*," since there was never a concept of "this row is one occurrence of rule X" to begin with (no `recurringId`/rule back-reference field exists on `TransactionEntity`).
- **Does editing create duplicated records?** No exact duplication, but it does destroy-and-recreate: the edited transaction gets a brand-new `id` (via `AppCubit._id('txn')`), so the original ID is gone.
- **Does editing break IDs?** Yes — every edit changes the transaction's ID (delete old, generate new). This is true for manual and generated transactions alike; it is a general property of the edit flow, not a recurring-specific bug.
- **Does editing break references?** Yes, specifically for generated transactions: since there is no field linking a `TransactionEntity` back to the `RecurringTransactionEntity` that produced it (see Phase 6), editing doesn't "break" a reference so much as confirm that **no reference existed to break in the first place** — the only signal that an occurrence was "handled" lives on `RecurringTransactionEntity.lastHandledOccurrenceAt`, a single scalar timestamp on the *rule*, completely decoupled from the transaction row's lifecycle. Editing or deleting the generated transaction never updates or clears that timestamp (confirmed: neither `addTransaction` nor `deleteTransaction` in `app_cubit.dart` reference `recurringTransactions` at all), so the rule continues to believe the occurrence was handled even if the user deletes or fully rewrites the generated row.

---

## Phase 5 — Source of Truth

There are effectively **two competing sources of truth**, and they are not kept in sync:

1. **`state.transactions` (the ledger)** — the list of `TransactionEntity` rows is the actual record of what happened to balances. This is authoritative for balances, history, and analytics.
2. **`RecurringTransactionEntity.lastHandledOccurrenceAt`** — a single ISO-date string on the *rule* is the sole authority for "has this period's occurrence already been posted," consumed by `RecurringScheduleEngine.wasOccurrenceHandled` (`recurring_schedule_engine.dart:307-320`).

These two sources are **not cross-checked**. There is no invariant enforcement (e.g., "there must exist a transaction dated `lastHandledOccurrenceAt` for this rule") anywhere in the code. Concretely:

- If a user deletes the generated transaction, source (1) says "no such spend happened" while source (2) still says "handled, don't ask again." The rule and the ledger disagree, and nothing detects or reconciles this (`deleteTransaction`, `app_cubit.dart:617-659`, never touches `recurringTransactions`).
- If a user edits a generated transaction, source (1) gets a brand-new row (new ID, no rule reference), while source (2) is untouched — so the rule "remembers" the occurrence via a timestamp that no longer corresponds to any specific row it can point to.

There is no Firestore, no separate "Cached Transaction" layer, and no in-memory/repository-cache split — `AppCubit`'s Bloc state *is* the in-memory cache, and `SharedPrefsAppRepository` is the only persisted copy, written synchronously on every `_applyAndLog` call (`app_cubit.dart:343`). So the local-storage-vs-memory duality that Phase 5 asks about does not itself create conflicts (they're always resolved before the state is emitted); the real conflict is the ledger-vs-rule-timestamp split described above.

---

## Phase 6 — Lifecycle Audit of a Recurring Transaction

```
1. Recurring Rule Created
   RecurringTransactionEntity built in AddTransactionScreen._submitRecurring
   (add_transaction_screen.dart:1239-13xx), saved via AppCubit (adds to
   state.recurringTransactions). No transaction exists yet.

2. Scheduler "Executes" — there is no background scheduler/cron. Due-detection is
   computed lazily, on-demand, whenever RecurringScheduleEngine functions
   (unhandledDueOccurrence / dueOccurrenceNow / expensePrompt) are called from a
   screen build (recurring_transactions_screen.dart, notifications_center_screen.dart).
   If the app is never opened, no prompt/auto-post ever fires — this is a "pull",
   not "push", scheduler.

3. Transaction Generated
   - executionType == 'auto': fires automatically the next time a relevant screen
     is built and detects a due occurrence (income: notifications_center_screen.dart
     `_recordDebt`/related; expense: same file, and the new manual-post button in
     recurring_transactions_screen.dart for on-demand posting).
   - executionType == 'confirm': RecurringExpensePrompt surfaces a dialog; user
     confirms → AppCubit.recordRecurring{Income,Expense}Occurrence is called.
   A brand-new TransactionEntity is constructed inline inside that AppCubit method
   — it is NOT copied/cloned from the RecurringTransactionEntity via any factory;
   each field is manually re-picked (and, as shown above, inconsistently for
   jar-targeted expenses).

4. Balance Updated — TransactionProcessor.apply(state, transaction).

5. Stored — the new TransactionEntity is appended to state.transactions as part of
   the same state update; RecurringTransactionEntity.lastHandledOccurrenceAt is set
   to the occurrence date in the same _applyAndLog call (app_cubit.dart, both
   recordRecurringIncomeOccurrence and recordRecurringExpenseOccurrence build
   `updatedRecurring = recurring.copyWith(lastHandledOccurrenceAt: ..., snoozedUntil: '')`
   and pass it into `_applyRecurringSync`, which is the ONLY place a generated
   transaction's existence is even acknowledged by the rule — and only via the
   timestamp, never an ID).

6. Edited — see Phase 4: delete+recreate, no interaction with the rule at all.

7. Deleted — AppCubit.deleteTransaction reverses balances; RecurringTransactionEntity
   is never touched, so lastHandledOccurrenceAt is NOT reverted (orphaning the
   occurrence — it will never be re-offered for that period).

8. Next Occurrence — RecurringScheduleEngine computes the next due date purely from
   the rule's own schedule fields (recurrencePattern, dayOfMonth/weekday/monthOfYear,
   anchorDate) plus lastHandledOccurrenceAt. It never looks at state.transactions.

9. Sync — the whole AppStateEntity (including both the transaction list and the
   recurring rules) is backed up as one JSON blob (Firebase Storage), on the schedule
   controlled by `_autoSync` (app_cubit.dart:377-414). No per-record sync exists.

10. Archive — no archival/soft-delete concept exists for either transactions or
    recurring rules; deletion is permanent removal from the respective list.
```

**Objects created per occurrence:** exactly one new `TransactionEntity` (plus, conditionally, auto-distribution sub-`TransactionEntity` rows with `parentId` pointing at *that* new transaction's id, if it's income tied to a budget income source — `transaction_processor.dart:314,335`).
**Objects destroyed:** none automatically; the rule survives indefinitely until manually deleted by the user via the recurring list screen.
**Relationships:** rule → generated transaction is **one-directional and non-persistent** — it exists only for the instant `recordRecurring*Occurrence` runs; the moment that call returns, nothing in the data model says "this transaction came from that rule."

---

## Phase 7 — Business Invariants: Held vs. Violated

| Invariant | Status | Evidence |
|---|---|---|
| Balance must equal sum of transactions | **Held** — `TransactionProcessor.apply`/`.reverse` are the sole mutators of wallet/jar/allocation balances, and every code path (manual add, recurring occurrence, delete) routes through them. | `transaction_processor.dart` (whole file); no other file mutates `WalletEntity.balance` or `LinkedWalletEntity.balance`. |
| Generated transaction must belong to exactly one recurring rule | **Violated.** No field exists anywhere on `TransactionEntity` recording which `RecurringTransactionEntity` produced it. `parentId` exists but is used exclusively for income auto-distribution sub-transactions (parent = the *triggering transaction*, not the rule) — confirmed by the only two write-sites, `transaction_processor.dart:314,335` (`parentId: transaction.id`). | grep of `parentId` across `lib/` (9 hits, all in `transaction_entity.dart` and `transaction_processor.dart`); no hit in either `app_cubit.dart` recurring-occurrence method sets `parentId` to `recurring.id`. |
| Editing one occurrence must not corrupt recurrence | **Held, trivially** — because there is no link to corrupt. The rule's schedule fields are never touched by transaction edit. But this "success" is really a symptom of the invariant above being unenforceable. |
| Deleting one occurrence must not delete the rule | **Held** — `deleteTransaction` never touches `recurringTransactions`. |
| Recurring rule must never directly affect balances | **Held** — `RecurringTransactionEntity` is never passed to `TransactionProcessor`; only the derived `TransactionEntity` is. |
| Generated transaction IDs must remain stable | **Held for the transaction's own lifetime**, but moot for correlation purposes since nothing else references that ID (see above). IDs are timestamp-based (`AppCubit._id('txn')`) and never reused, but there is no external reference to keep stable *against*. |
| (Implicit) A rule's "last handled occurrence" must reflect reality (a transaction with that date actually exists in the ledger) | **Violated** — deleting or editing the generated transaction never reconciles `lastHandledOccurrenceAt`; the rule can claim an occurrence is "handled" when no corresponding transaction exists in the ledger. |
| (Implicit) A jar-targeted recurring expense must debit that jar exactly as a jar-targeted manual expense would | **Violated** — `recordRecurringExpenseOccurrence` never maps `recurring.targetJarId` onto `TransactionEntity.toWalletId`, so `TransactionProcessor.apply`'s `virtualTargetId = transaction.allocationId ?? transaction.toWalletId` (line 407-408) never sees the jar; only the physical wallet is debited. (Established in the prior investigation turn; re-confirmed here as a Phase-7 invariant violation, not a one-off bug — it stems from the missing rule↔transaction linkage discipline described above.) |
| (Implicit) `budgetScope` must reflect the actual target type (allocation/unallocated ⇒ within-budget, jar ⇒ outside-budget) | **Violated** — the shared target picker in `add_transaction_screen.dart` sets `withinBudget` for jar selections identically to allocation selections (lines ~1824-1825, ~1886-1887, ~1919-1920), and this incorrect value is carried into both manual and recurring-generated transactions alike. |

---

## Phase 8 — Hidden Business Rules / Flags

| Flag | Location | Why it exists |
|---|---|---|
| `parentId` | `transaction_entity.dart:35` | Links an auto-generated *sub-transaction* (e.g. jar-funding distribution) to the *transaction* (not rule) that triggered it. Consumed for cascading delete/reverse (`transaction_processor.dart:622,640,667,748`). Backward-compat branches exist for old sub-transactions saved before this field existed (`t.parentId == null` fallback at line 641, matched by amount/date instead). |
| `incomeSourceId` | `transaction_entity.dart:13` | When set on an income transaction, triggers automatic/confirm distribution into jars per the budget plan (`transaction_processor.dart` distribution loop, ~258-357). |
| `transferType` | `transaction_types.dart:18` | Distinguishes physical vs. virtual transfer semantics (`jarFunding`, `jarFundingPhysical`, `jarAllocation`, `jarAllocationCancel`, `depositWithJarLabel`, etc.) so `TransactionProcessor` knows which balance bucket(s) to touch. |
| `automationType` | `transaction_types.dart:43` | `auto`/`confirm`/`manual` — controls whether a due recurring occurrence posts itself or waits for user confirmation; also reused for jar auto-distribution settings. |
| `budgetScope` | `transaction_types.dart:60-62` | Only two values exist (`within-budget`/`outside-budget`) — used for budget-vs-actual reporting. As shown in Phase 7, its assignment logic is currently wrong for jar targets. |
| `isDebtOrSubscription` / `expensePlanKind` | `recurring_transaction_entity.dart` | Marks recurring expenses that belong to the separate "Debts & Subscriptions" tracking feature; these are filtered out of the plain recurring-expenses list (`_matchesTab` in `recurring_transactions_screen.dart`) and handled via `notifications_center_screen.dart`'s `_recordDebt` instead of the generic manual-post button. |
| `isVariableIncome` | `recurring_transaction_entity.dart` | Lets the user override the amount at post-time instead of using a fixed recurring amount. |
| `snoozedUntil` | `recurring_transaction_entity.dart` | Suppresses due/overdue prompts until a chosen date; cleared (`''`) every time an occurrence is actually posted (`copyWith(snoozedUntil: '')` in both `recordRecurring*Occurrence` methods). |
| `lastHandledOccurrenceAt` | `recurring_transaction_entity.dart` | As covered extensively above — the sole, unlinked source of truth for "was this period's occurrence generated." |
| `reminderLeadDays` | `recurring_transaction_entity.dart` | Controls how far ahead of the due date an "upcoming" reminder should surface, only meaningful when `executionType == confirm`. |
| `origin` (on `DistributionEntry`) | `lib/features/money_distribution/domain/entities/distribution_entry.dart` | Distinguishes a jar's money-distribution entries created automatically by the processor vs. manually adjusted by the user. |

No `isGenerated`, `isRecurring` (as a transaction-level flag), `sourceId`, `recurringId`, or `status` field exists on `TransactionEntity` — confirmed absent by full-repo grep. The only hits for those exact terms were in unrelated features (debt-linked-recurring setup screens use a local variable named `recurringId` that is the ID of a `RecurringTransactionEntity` used for a *debt plan*, not a back-reference field on `TransactionEntity`).

---

## Phase 9 — Architectural Problems

- **No rule↔transaction linkage (root cause of most divergence).** Every editing/deletion/traceability inconsistency in this report traces back to one fact: generated `TransactionEntity` rows carry no field identifying their source `RecurringTransactionEntity`. This isn't "duplicated logic," it's a **missing relationship** in the domain model.
- **Duplicated field-population logic, not duplicated pipelines.** `AppCubit.addTransaction` and `AppCubit.recordRecurringExpenseOccurrence`/`recordRecurringIncomeOccurrence` each hand-construct a `TransactionEntity` from scratch with their own field list, rather than sharing one "build a transaction from these business inputs" constructor/factory. This is why the jar-target (`toWalletId`) field was correctly wired for the income path but forgotten for the expense path — there was no single source of truth for "how do you turn a recurring rule + occurrence into a transaction," so the two call-sites drifted independently.
- **Shared, over-generalized UI state for budget-scope selection.** `add_transaction_screen.dart` uses one `_budgetScope`/`_budgetTargetId` pair for allocation, "unallocated," and jar targets alike, and the picker sets `withinBudget` for all three uniformly. Because `RecurringTransactionComposerScreen` is a thin wrapper around this same screen, the defect automatically propagates into every recurring rule created or edited through it. This is a single-point-of-failure in the architecture: one screen's local state drives two conceptually different persisted entities (`TransactionEntity.budgetScope` directly, and `RecurringTransactionEntity.budgetScope` which is later blindly copied forward at occurrence-generation time).
- **No repository-level or Firestore-level duplication** — confirmed there is exactly one persistence path (`SharedPrefsAppRepository`) and no parallel Firestore/SQLite writer, so this class of smell does not apply here.
- **No mapper duplication** — confirmed there is exactly one `toMap`/`fromMap` pair per entity; no separate DTO layer exists to drift out of sync with the entities.
- **State duplication is minimal but present in one place:** `RecurringTransactionEntity.lastHandledOccurrenceAt` is state that *should* be derivable from `state.transactions` (i.e., "does a transaction exist for this rule at this date") but is instead stored redundantly and independently on the rule, with no reconciliation — this is the concrete manifestation of the "two sources of truth" problem from Phase 5.
- **"Delete-then-add" as the universal edit strategy** is simple and correct for balance math (delete reverses, add reapplies) but is the mechanism that guarantees any latent generated-transaction/rule linkage would be destroyed on edit even if one existed later — worth keeping in mind for any redesign.

---

## Phase 10 — Final Report Summary

**Current architecture:** Single flat pipeline — Screen → `AppCubit` (orchestration/logging) → `TransactionProcessor` (pure balance math) → `SharedPrefsAppRepository` (whole-state JSON persistence) → Bloc `emit` → UI rebuild, with a side one-way Firebase Storage backup. One transaction model (`TransactionEntity`) serves both manual and recurring-generated transactions; one rule model (`RecurringTransactionEntity`) never itself touches balances.

**Manual lifecycle:** create via `_submitNormal` → `addTransaction`; edit/delete via delete-then-recreate; fully self-contained, no external references to manage.

**Recurring lifecycle:** rule created once; each due occurrence lazily detected on screen build (`RecurringScheduleEngine`, pull-based, no background scheduler); occurrence posted via `AppCubit.recordRecurring{Income,Expense}Occurrence`, which hand-builds a fresh `TransactionEntity` and, in the same state update, advances the rule's `lastHandledOccurrenceAt`. From that moment, the generated transaction is indistinguishable from a manual one and the rule retains no reference to it.

**Source of truth:** `state.transactions` for balances/history/analytics; `RecurringTransactionEntity.lastHandledOccurrenceAt` for "has this occurrence been posted." These two are never cross-validated, which is the direct cause of the orphaning behavior described in Phases 5–7.

**Broken business rules (confirmed in code, not speculative):**
1. Generated transactions have no back-reference to their originating rule (Phase 7).
2. Deleting/editing a generated transaction never reconciles `lastHandledOccurrenceAt`, so the rule can silently believe a non-existent transaction was posted (Phase 5/7).
3. Recurring expense occurrences never populate `toWalletId` from `targetJarId`, so jar-targeted recurring expenses debit the physical wallet but never the jar (Phase 3/7; carried over from the prior investigation in this session).
4. The shared budget-target picker forces `budgetScope = within-budget` for jar selections (both manual and recurring), when only allocation/unallocated selections should get that value (Phase 3/7/9).

**Architectural risks:**
- Any future feature that needs "show me all transactions generated by rule X" (e.g. a recurring-rule detail/history view) is currently **impossible to build correctly** without first adding a linkage field, because the data to answer that query does not exist.
- The two independent `TransactionEntity`-construction call-sites (`addTransaction` vs. the two `recordRecurring*Occurrence` methods) will keep drifting apart on every new field added to the entity unless unified behind one constructor/factory.
- The single shared `_budgetScope` UI state in `add_transaction_screen.dart` means any future third target type (beyond allocation/unallocated/jar) will need the same care to avoid the same class of bug.

**Root causes:**
- Fields were added to `TransactionEntity`/`RecurringTransactionEntity` incrementally, call-site by call-site, without a shared factory/mapper enforcing parity between the manual and recurring construction paths.
- `lastHandledOccurrenceAt` was chosen as a lightweight "was it done" signal on the rule instead of querying the ledger, trading correctness (no reconciliation possible) for simplicity.
- The budget-target bottom sheet was written for allocations first and jars were added later by reusing the same state variable rather than introducing a jar-specific scope value.

**Recommended redesign (high level, no code):**
1. Add an explicit `recurringId` (or reuse-and-repurpose a dedicated field, not `parentId`) on `TransactionEntity` set at generation time by both `recordRecurringIncomeOccurrence` and `recordRecurringExpenseOccurrence`, enabling traceability and safe reconciliation.
2. Introduce a single shared "build TransactionEntity from a RecurringTransactionEntity + occurrence" factory used by both income and expense posting methods, eliminating the class of bug where one path forwards a field (`targetJarId`→`toWalletId`) and the other forgets it.
3. Replace the single-scalar `lastHandledOccurrenceAt` truth source with a derived check against the ledger (does a transaction with `recurringId == rule.id` exist for this occurrence date), or at minimum reconcile it on transaction delete.
4. Split the budget-target picker's scope assignment so jar selections set `outside-budget` (or introduce a third semantic scope if the product actually wants jars to count toward budget, which should be a deliberate product decision, not an accident of shared state).

**Migration strategy:** Since there is only one storage format (a single JSON blob via `SharedPrefsAppRepository`), any schema change is a matter of extending `TransactionEntity.fromMap` with a nullable new field (safe for old data — defaults to `null`/absent) and, if reconciliation logic is added, a one-time migration pass over existing `state.transactions`/`state.recurringTransactions` on app load to best-effort backfill (e.g. matching by date+amount+wallet for existing generated rows) — matching the backward-compat pattern already used for `parentId` (`transaction_processor.dart:641-667`).

**Risk assessment:** Low risk to implement incrementally — none of the above requires changing `TransactionProcessor`'s balance math, which is already correct and shared. The main risk is doing the `budgetScope` fix without a product decision on whether jar-targeted expenses should ever count as "within budget" under any configuration — that is a product question, not something resolvable from code alone, and is called out here as **unknown / requires product input**, not assumed.

---

### Explicitly unknown / not determinable from code
- Whether jar-targeted expenses are *ever intended* to count as within-budget under some other condition not yet implemented — this is a product decision, not visible in code.
- Whether any historical data already exists with orphaned `lastHandledOccurrenceAt` values (would require inspecting a real user's persisted state, not the source code).
