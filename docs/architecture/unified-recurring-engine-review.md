# Mezanya — Unified Financial Engine: Architecture Review

**Date:** July 2026  
**Scope:** Recurring transactions system, budget engine, transaction creation, category system  
**Status:** Phases 1–7 complete. Phase 8 (implementation) awaits approval.

---

## PHASE 1 — COMPLETE ARCHITECTURE ANALYSIS

### Dependency Map

```
lib/
├── core/
│   ├── constants/transaction_types.dart      ← ALL domain enums (TransactionType, TransferType,
│   │                                            AutomationType, BudgetScope, ExpensePlanKind,
│   │                                            RecurrencePattern, RolloverBehavior)
│   └── di/bootstrap.dart                     ← Instantiates AppCubit + repository; no business logic
│
├── features/
│   ├── app_state/
│   │   ├── domain/entities/app_state_entity.dart  ← Single God-entity holding ALL state
│   │   ├── data/repositories/shared_prefs_app_repository.dart  ← Serialize entire state → one JSON key
│   │   └── presentation/cubits/app_cubit.dart     ← ~2379 lines; ALL state mutations live here
│   │
│   ├── transactions/
│   │   ├── domain/entities/transaction_entity.dart         ← Posted (real) transactions
│   │   ├── domain/entities/recurring_transaction_entity.dart ← Template/schedule entity (overloaded)
│   │   ├── domain/services/transaction_processor.dart      ← PURE financial engine (apply/reverse)
│   │   ├── domain/services/recurring_schedule_engine.dart  ← PURE schedule calculator
│   │   └── presentation/screens/
│   │       ├── add_transaction_screen.dart               ← UI; can enter recurringMode
│   │       ├── recurring_transaction_composer_screen.dart ← UI; 2650-line form
│   │       ├── recurring_transactions_screen.dart         ← UI; display + inline actions
│   │       └── debts_and_subscriptions_screen.dart        ← UI; budget-scoped debts view
│   │
│   ├── budget/
│   │   ├── domain/entities/budget_setup_entity.dart  ← AllocationEntity, LinkedWalletEntity,
│   │   │                                                DebtEntity, IncomeSourceEntity
│   │   ├── domain/services/budget_cycle_service.dart         ← PURE; resolves cycles, income metadata
│   │   ├── domain/services/budget_recurring_plan_service.dart ← PURE; links debts↔recurring
│   │   ├── domain/services/budget_metrics_service.dart       ← PURE; actual vs planned
│   │   ├── domain/services/budget_income_metrics_service.dart ← PURE; income metrics
│   │   ├── domain/services/money_location_engine.dart        ← PURE; jar distribution reviews
│   │   └── domain/services/budget_transaction_filter.dart    ← PURE; cycle filtering
│   │
│   ├── categories/
│   │   └── domain/entities/category_entity.dart  ← Lightweight; scope + optional allocationId/walletId
│   │
│   ├── wallets/
│   │   └── domain/entities/wallet_entity.dart  ← Physical wallets
│   │
│   └── money_distribution/
│       ├── domain/entities/distribution_entry.dart
│       └── domain/services/distribution_engine.dart  ← PURE; jar wallet-source tracking
```

### Business Logic Ownership

| File | Owns Business Logic? | Notes |
|------|---------------------|-------|
| `transaction_processor.dart` | ✅ YES | Pure. All balance mutations go through here |
| `recurring_schedule_engine.dart` | ✅ YES | Pure. All date/occurrence math |
| `budget_recurring_plan_service.dart` | ✅ YES | Pure. Debt↔recurring linking + occurrence projection |
| `budget_cycle_service.dart` | ✅ YES | Pure. Cycle resolution, income due-date |
| `money_location_engine.dart` | ✅ YES | Pure. Jar distribution conflict detection |
| `distribution_engine.dart` | ✅ YES | Pure. Jar wallet-source arithmetic |
| `app_cubit.dart` | ⚠️ YES + orchestration | Owns orchestration AND fragments of domain logic (migration, DebtEntity sync, ID generation). Too large. |
| `budget_tracking_screen.dart` | ⚠️ Some | Was historically the source of logic now extracted to budget services |
| All `*_screen.dart` / `*_widget.dart` | ❌ Display only | Should hold zero business logic |

### Where Scheduling Decisions Happen

1. **Occurrence calculation** → `RecurringScheduleEngine` (pure, stateless)
2. **"Is this due now?"** → `RecurringScheduleEngine.dueOccurrenceNow()` → `unhandledDueOccurrence()` → `expensePrompt()`
3. **"Was this handled?"** → `RecurringScheduleEngine.wasOccurrenceHandled()` (reads `lastHandledOccurrenceAt`)
4. **Reminder window** → `RecurringScheduleEngine.expensePrompt()` + `reminderDuration()`
5. **Snooze gate** → `RecurringScheduleEngine.expensePrompt()` checks `snoozedUntil`

### Where Execution Happens

1. **Auto/confirm income posting** → `AppCubit.recordRecurringIncomeOccurrence()` → `TransactionProcessor.apply()` → `_applyRecurringSync()`
2. **Auto/confirm expense posting** → `AppCubit.recordRecurringExpenseOccurrence()` → `TransactionProcessor.apply()` → `_applyRecurringSync()`
3. **Skip** → `AppCubit.recordRecurringSkip()` (marks `lastHandledOccurrenceAt`, no transaction)
4. **Postpone/snooze** → `AppCubit.recordRecurringPostpone()` (sets `snoozedUntil`)

### Where Recurring Occurrences Become Real Transactions

`recordRecurringIncomeOccurrence` / `recordRecurringExpenseOccurrence` in `AppCubit`:
1. Build `TransactionEntity` from recurring template
2. `TransactionProcessor.apply(state, transaction)` → updates all balances + auto-creates sub-transactions for jar distribution
3. `_applyRecurringSync(stateAfterTx, updatedRecurring)` → stamps `lastHandledOccurrenceAt`, syncs `DebtEntity`
4. `_applyAndLog()` → persists to SharedPreferences + triggers auto-backup

---

## PHASE 2 — DOMAIN REVIEW

### All Recurring Operations Supported

The single `RecurringTransactionEntity` carries these semantically distinct operations:

| Operation | Identified By | What Is Shared | What Is Unique | Implementation History Fields | True Domain Fields |
|-----------|--------------|----------------|----------------|-------------------------------|---------------------|
| **Income** | `type='income'` | id, name, amount, recurrencePattern, executionType, walletId, reminderLeadDays, lastHandledOccurrenceAt, snoozedUntil, isActive, icon, iconColor | `incomeSourceId`, `targetJarId`, `isVariableIncome` | `isDebtOrSubscription=false`, `expensePlanKind=null`, `isLent=false` | `incomeSourceId`, `targetJarId`, `isVariableIncome` |
| **Expense (general)** | `type='expense'`, `isDebtOrSubscription=false` | (shared base) | `allocationId`, `categoryIds`, `budgetScope` | Carries `debtPrincipalTotal=null`, `installmentCount=null` (unused) | `allocationId`, `categoryIds`, `budgetScope` |
| **Debt/Loan** | `type='expense'`, `isDebtOrSubscription=true`, `expensePlanKind=null or 'subscription'` | (shared base) | `expensePlanKind` | Mirror stored in `DebtEntity` | `isDebtOrSubscription`, `expensePlanKind` |
| **Installment** | `type='expense'`, `isDebtOrSubscription=true`, `expensePlanKind='installment'` | (shared base) | `debtPrincipalTotal`, `installmentCount`, `installmentDownPayment` | Mirror in `DebtEntity.principalTotal / installmentCount / downPayment` | `debtPrincipalTotal`, `installmentCount`, `installmentDownPayment` |
| **Subscription** | `type='expense'`, `isDebtOrSubscription=true`, `expensePlanKind='subscription'` | (shared base) | Same as Debt; `expensePlanKind` is the discriminator | Mirror in `DebtEntity` | `expensePlanKind` |
| **Jar Deposit** | `type='income'`, `targetJarId≠null` | (shared base + income fields) | `targetJarId` (direct jar routing) | — | `targetJarId` |
| **Jar Withdrawal** | Not a recurring type — only manual via `addTransaction` | — | — | — | — |
| **Transfer** | Not a recurring type — only manual via `addTransaction` | — | — | — | — |
| **Lent Money** | `isLent=true`, `recurrencePattern='manual-variable'` | id, name, walletId | `lentPersonName`, `lentEntries` (List<Map<String,dynamic>>), `isLentArchived` | Reuses `amount` = outstanding total; `type='expense'`, `dayOfMonth=1` (unused); all schedule fields meaningless | `isLent`, `lentPersonName`, `lentEntries`, `isLentArchived` |

### Key Observations

**Income:**
- Shared: schedule fields, executionType, icon
- Unique: `incomeSourceId` (links to budget income plan), `targetJarId` (optional direct jar routing)
- History field: `isVariableIncome` triggers a different UI path but the entity carries the same schema

**Expense:**
- Shared: schedule fields, executionType, icon, budgetScope
- Unique: `allocationId` (budget envelope), `categoryIds`

**Debt/Installment/Subscription:**
- These are structurally the same as Expense but require synchronization with `DebtEntity` inside `BudgetSetupEntity`
- The dual-representation problem (`RecurringTransactionEntity` + `DebtEntity`) is the largest maintenance hazard in the system

**Lent Money:**
- This is NOT a recurring transaction in the domain sense — it is a person-level record with sub-entries
- It is stored as a `RecurringTransactionEntity` purely for convenience (already in the list, already persisted)
- All schedule-related fields (`recurrencePattern`, `dayOfMonth`, `executionType`, etc.) are semantically meaningless for lent records
- `lentEntries` is an untyped `List<Map<String,dynamic>>` — a domain entity stored as raw maps

**Fields existing only because of implementation history:**
- `isDebtOrSubscription` boolean — should be a type discriminator, not a flag
- `isLent` boolean — same problem
- `expensePlanKind` string — should be part of type hierarchy
- `targetJarId` on income — is an income-specific routing concern that bleeds into the base entity
- `weekday` (singular) vs `weekdays` (list) — redundant; `weekdays` was added later and `weekday` kept for migration safety
- `WalletEntity.reservedForSavings` — already marked `@Deprecated` in the code; dead field retained for backward compat

---

## PHASE 3 — DUPLICATED LOGIC

### Duplicate 1: Date / Occurrence Calculation

| Location A | Location B | Notes |
|-----------|-----------|-------|
| `RecurringScheduleEngine.occurrencesInRange()` | `BudgetRecurringPlanService._fallbackOccurrences()` | Fallback uses a simpler day-loop algorithm with `day.clamp(1,28)` — different from engine's `_dayInMonth()` which uses actual last-day-of-month |

**Why duplicated:** `BudgetRecurringPlanService` needed occurrence counts when a `DebtEntity` exists without a linked `RecurringTransactionEntity`. Instead of requiring the engine, a simplified fallback was written inline.

**Suggested abstraction:** `RecurringScheduleEngine` should accept a `DebtOccurrenceInput` protocol, or `BudgetRecurringPlanService._fallbackOccurrences()` should construct a minimal `RecurringTransactionEntity` from `DebtEntity` fields and delegate to the engine.

**Risk of refactoring:** Low. The fallback is only used when `recurring == null`, so it affects a narrow path (old debt records without linked recurring templates).

---

### Duplicate 2: Snooze Gate

| Location A | Location B | Location C |
|-----------|-----------|-----------|
| `RecurringScheduleEngine.expensePrompt()` — checks `recurring.snoozedUntil` internally | `BudgetRecurringPlanService.expensePendingMeta()` — re-checks `snoozedUntil` before calling `expensePrompt()` | `BudgetCycleService.incomePendingMeta()` — checks `source.isSnoozed` (income source snooze, different field) |

**Why duplicated:** `expensePendingMeta()` was written to return a typed metadata map for UI, so it re-checks snooze to produce a specific "snoozed" status string before delegating to `expensePrompt()`. Income snooze is a different mechanism (`IncomeSourceEntity.snoozedUntil` vs `RecurringTransactionEntity.snoozedUntil`).

**Suggested abstraction:** A single `RecurringStatusResolver.resolve(recurring, now)` that returns a typed `RecurringStatus` enum + metadata. UI screens read the status; no screen re-implements the snooze check.

**Risk of refactoring:** Medium. Both budget tracking screen and notifications screen depend on these metadata maps.

---

### Duplicate 3: DebtEntity ↔ RecurringTransactionEntity Synchronization

| Location | Code Path |
|----------|-----------|
| `AppCubit.addRecurringTransaction()` | Creates `DebtEntity` if `isDebtOrSubscription=true` |
| `AppCubit.updateRecurringTransaction()` → `_applyRecurringSync()` | Updates `DebtEntity` fields from recurring |
| `AppCubit.deleteRecurringTransaction()` | Deletes linked `DebtEntity` |
| `AppCubit._migrateOrphanedDebtRecurringSync()` | Creates `DebtEntity` for orphaned recurring records |
| `BudgetRecurringPlanService.linkedRecurring()` | Finds recurring by `debt.recurringTransactionId` or by name match (fallback) |

**Why duplicated:** `DebtEntity` was the original budget-tracking entity. `RecurringTransactionEntity` was added later for scheduling. They were never merged, so every mutation in one must propagate to the other manually. The `fundingSource` field in `DebtEntity` is NOT propagated from `RecurringTransactionEntity` (they have no shared funding source field), so sync is only partial.

**Suggested abstraction:** Eliminate `DebtEntity` as a separate entity. The unified `RecurringOperation` entity (Phase 4) carries all information needed for both scheduling and budget tracking. `BudgetRecurringPlanService` reads directly from the operation.

**Risk of refactoring:** HIGH. This is the most dangerous change in the system. `DebtEntity` is read in budget_tracking_screen, budget_recurring_plan_service, cycle_analysis_screen, debts_and_subscriptions_screen, budget_setup_screen. A migration step is required to prevent data loss.

---

### Duplicate 4: Posting Logic (Income vs Expense)

| `recordRecurringIncomeOccurrence` | `recordRecurringExpenseOccurrence` |
|-----------------------------------|-------------------------------------|
| Builds `TransactionEntity` | Builds `TransactionEntity` |
| `TransactionProcessor.apply(state, tx)` | `TransactionProcessor.apply(state, tx)` |
| `_applyRecurringSync(state, updated.copyWith(lastHandledAt: occurrence))` | `_applyRecurringSync(state, updated.copyWith(lastHandledAt: occurrence))` |
| `_applyAndLog(recordInNotificationHistory: true)` | `_applyAndLog(recordInNotificationHistory: true)` |
| Uses `occurrence.toIso8601String()` for `createdAt` ✅ | Uses `DateTime.now()` for `createdAt` ⚠️ **Bug: expense is posted with now, not occurrence date** |

**Why duplicated:** Income and expense posting were developed separately as the system grew. The outer structure is identical; only the `TransactionEntity` construction differs.

**Suggested abstraction:** A single `_executeRecurringOccurrence(recurring, transaction, occurrence)` method that wraps the common pattern. Income/expense specific logic lives in the `TransactionEntity` construction only.

**Risk of refactoring:** Low. The shared pattern is pure; only the entity construction differs.

---

### Duplicate 5: Linked Recurring Lookup (Income vs Expense direction)

| `BudgetCycleService.linkedRecurringIncome()` | `BudgetRecurringPlanService.linkedRecurring()` |
|----------------------------------------------|-----------------------------------------------|
| Finds recurring by `incomeSourceId == source.id` OR name+wallet match | Finds recurring by `debt.recurringTransactionId == r.id` OR name match |
| Used for: income pending metadata | Used for: debt budget projections |

**Why duplicated:** Two different lookup directions (income source → recurring vs debt → recurring). The name-match fallback in both is a fragile backward-compat path.

**Suggested abstraction:** An `OperationRegistry` service that resolves `RecurringOperation` by any linked ID (incomeSourceId, debtId, name) with a single, tested lookup strategy.

**Risk of refactoring:** Low. These are read-only lookups.

---

### Duplicate 6: Retroactive Posting (No Existing Mechanism)

Currently there is **no retroactive posting pipeline**. The `expensePrompt()` has `catchUpFromAuto: true` which signals that a past auto-execution was missed, but `AppCubit` handles this in the UI layer (the user is shown a dialog and manually confirms). There is no background catch-up runner. This means:
- If the app was offline for 3 months, auto recurring expenses accumulate as prompts
- Each prompt must be manually confirmed by the user one at a time
- This is a known UX gap, not a code bug

---

### Summary Table

| Duplicate | Location(s) | Risk | Suggested Fix |
|-----------|-------------|------|---------------|
| Date calculation | `RecurringScheduleEngine` vs `BudgetRecurringPlanService._fallback*` | Low | Delegate fallback to engine via minimal entity construction |
| Snooze gate | 3 locations | Medium | `RecurringStatusResolver` returning typed status |
| DebtEntity sync | 4 cubit methods + migration | HIGH | Eliminate `DebtEntity`; read from unified operation |
| Posting pipeline | 2 cubit methods | Low | Shared `_executeRecurringOccurrence()` |
| Linked lookup | 2 service methods | Low | `OperationRegistry.findByAnyId()` |
| Retroactive posting | Nowhere (gap) | — | Phase 8 new feature |

---

## PHASE 4 — DESIGN: THE NEW ARCHITECTURE

### Core Principle

Replace the overloaded `RecurringTransactionEntity` with a single `RecurringOperation` entity that uses a sealed `RecurringOperationKind` discriminator. Eliminate `DebtEntity` as a separate struct. All scheduling, execution, and budget projection reads from `RecurringOperation`.

---

### Entity Design

```dart
// The single unified entity
class RecurringOperation {
  final String id;
  final String name;
  final String icon;
  final String iconColor;
  final String walletId;
  final String budgetScope;           // BudgetScope.value
  final String recurrencePattern;     // RecurrencePattern.value
  final String executionType;         // AutomationType.value
  final int dayOfMonth;
  final List<int> weekdays;           // replaces weekday (singular)
  final int? monthOfYear;
  final String? anchorDate;
  final String? scheduledTime;
  final int? reminderLeadDays;
  final String? lastHandledOccurrenceAt;
  final String? snoozedUntil;
  final bool isActive;
  final String? notes;

  // Type discriminator — replaces isDebtOrSubscription / isLent flags
  final RecurringOperationKind kind;
}

sealed class RecurringOperationKind {}

class IncomeKind extends RecurringOperationKind {
  final double amount;          // 0 if variable
  final bool isVariable;
  final String? incomeSourceId;
  final String? targetJarId;
  final List<String> categoryIds;
}

class ExpenseKind extends RecurringOperationKind {
  final double amount;
  final String? allocationId;
  final List<String> categoryIds;
}

class DebtKind extends RecurringOperationKind {
  final double installmentAmount;
  final DebtType debtType;          // subscription | installment
  final String? fundingSourceId;    // replaces DebtEntity.fundingSource
  final double? principalTotal;
  final int? installmentCount;
  final double? downPayment;
}

class LentKind extends RecurringOperationKind {
  final String personName;
  final List<LentEntry> entries;    // typed, not raw Map<String,dynamic>
  final bool isArchived;
}

class LentEntry {
  final String id;
  final double amount;
  final DateTime lentDate;
  final DateTime expectedReturnDate;
  final bool isSettled;
  final String? notes;
}
```

---

### Execution Engine

```dart
/// Pure domain service — handles all recurring operation execution
class RecurringExecutionEngine {
  const RecurringExecutionEngine._();

  /// Build the TransactionEntity for a given operation + occurrence date
  static TransactionEntity buildTransaction({
    required RecurringOperation op,
    required DateTime occurrence,
    required double amount,        // explicit: may differ from template (variable income)
    String? notesOverride,
  });

  /// Apply a confirmed/auto execution:
  /// 1. TransactionProcessor.apply(state, tx)
  /// 2. Stamp lastHandledOccurrenceAt = occurrence
  /// 3. (For DebtKind) update budget projection if needed
  static AppStateEntity execute({
    required AppStateEntity state,
    required RecurringOperation op,
    required DateTime occurrence,
    required double amount,
    String? notesOverride,
  });

  /// Stamp snoozedUntil without posting
  static RecurringOperation snooze(RecurringOperation op, DateTime until);

  /// Stamp lastHandledOccurrenceAt without posting (skip)
  static RecurringOperation skip(RecurringOperation op, DateTime occurrence);
}
```

---

### Occurrence Generator

```dart
/// Renamed from RecurringScheduleEngine, no behavior changes
/// (already pure and well-structured)
class OccurrenceGenerator {
  static DateTime? next(RecurringOperation op, DateTime now);
  static DateTime? dueNow(RecurringOperation op, DateTime now);
  static DateTime? unhandledDue(RecurringOperation op, DateTime now);
  static bool wasHandled(RecurringOperation op, DateTime occurrence);
  static int countInRange(RecurringOperation op, DateTime start, DateTime end);
  static List<DateTime> datesInRange(RecurringOperation op, DateTime start, DateTime end);
}
```

---

### Execution Pipeline (cubit-level orchestration)

```
User action / notification
        │
        ▼
  RecurringOperationsScreen / NotificationCenter
        │
        ▼ calls cubit method
  AppCubit.executeRecurringOccurrence(op, occurrence, amount)
        │
        ▼
  RecurringExecutionEngine.execute(state, op, occurrence, amount)
        │
        ├─ TransactionProcessor.apply(state, tx)         → balance updates
        └─ op.copyWith(lastHandledOccurrenceAt: ...)     → mark handled
        │
        ▼
  _applyAndLog() → persist + auto-sync
```

---

### Reminder Pipeline

```
App startup / foreground
        │
        ▼
  NotificationService.scanDueOperations(state.operations, DateTime.now())
        │ for each op
        ▼
  OccurrenceGenerator.expensePrompt(op, now)   (rename of existing expensePrompt)
  or
  BudgetCycleService.incomePendingMeta(state, op, now)
        │
        ▼
  Emit notification entity or update badge
```

---

### Confirmation Pipeline

```
"Confirm" mode operation reaches dueNow
        │
        ▼
  RecurringConfirmDialog (income) or RecurringPostponeDialog (expense)
        │
        ├─ User confirms → AppCubit.executeRecurringOccurrence()
        ├─ User skips   → AppCubit.skipRecurringOccurrence()
        └─ User snoozes → AppCubit.snoozeRecurringOperation(until)
```

---

### Manual Posting

```
RecurringTransactionsScreen: user taps "post manually"
        │
        ▼
  Shows amount input (if isVariable) + date picker (default = occurrence date)
        │
        ▼
  AppCubit.executeRecurringOccurrence(op, userSelectedDate, userEnteredAmount)
```

---

### Retroactive Posting

```
App open after offline period:
        │
        ▼
  AppCubit._catchUpAutoOperations(DateTime now)
        │ for each operation where executionType == auto
        ▼
  OccurrenceGenerator.unhandledDue(op, now)
        │ if not null and not today (catchUpFromAuto)
        ▼
  AppCubit.executeRecurringOccurrence(op, dueOccurrence, op.amount)
        │ (silent, no user prompt for auto mode)
        ▼
  Record in notification history: "Auto-executed: Netflix · 15 Jul"
```

---

## PHASE 5 — COMPOSER REDESIGN

### Comparison: Add Transaction vs Recurring Composer

| Field | Add Transaction | Recurring Composer | Classification |
|-------|----------------|-------------------|----------------|
| Amount | ✅ | ✅ | **SHARED** |
| Transaction type (income/expense/transfer) | ✅ | ✅ (no transfer) | **SHARED** (minus transfer for recurring) |
| Wallet selection | ✅ | ✅ | **SHARED** |
| Notes / name | ✅ | ✅ | **SHARED** |
| Budget scope (within/outside) | ✅ | ✅ | **SHARED** |
| Allocation selection | ✅ | ✅ | **SHARED** |
| Income source selection | ✅ | ✅ | **SHARED** |
| Category selection | ✅ | ✅ | **SHARED** |
| Target jar selection | ✅ | ✅ | **SHARED** |
| Icon + color picker | ❌ | ✅ | **RECURRING ONLY** |
| Recurrence pattern | ❌ | ✅ | **RECURRING ONLY** |
| Day of month / weekday(s) | ❌ | ✅ | **RECURRING ONLY** |
| Month of year (yearly) | ❌ | ✅ | **RECURRING ONLY** |
| Scheduled time | ❌ | ✅ | **RECURRING ONLY** |
| Reminder lead days | ❌ | ✅ | **RECURRING ONLY** |
| Anchor date | ❌ | ✅ | **RECURRING ONLY** |
| Execution type (auto/confirm) | ❌ | ✅ | **RECURRING ONLY** |
| isDebtOrSubscription toggle | ❌ | ✅ | **RECURRING ONLY** |
| Debt fields (principal, installments, down payment) | ❌ | ✅ | **RECURRING ONLY** |
| isVariableIncome toggle | ❌ | ✅ | **RECURRING ONLY** |
| Transfer type (wallet-to-wallet) | ✅ | ❌ | **TRANSACTION ONLY** |
| From/To wallet (transfer) | ✅ | ❌ | **TRANSACTION ONLY** |
| Posting date (custom date picker) | ✅ | ❌ (uses schedule) | **TRANSACTION ONLY** |

**Result:** ~60% shared fields. Add recurring-only section = 10–15 additional fields.

---

### Proposed Composer Architecture

```
TransactionFormCore (shared widget, ~60% of fields)
├─ AmountField
├─ TypeSelector (income/expense/transfer)
├─ WalletPicker
├─ BudgetScopeSection
│   ├─ IncomeSourcePicker (if income)
│   ├─ AllocationPicker (if expense + within budget)
│   └─ TargetJarPicker (if income)
├─ CategoryPicker
└─ NoteField

AddTransactionScreen
└─ TransactionFormCore
   └─ TransactionOnlyExtension (~10% of form)
       ├─ TransferTypePicker
       ├─ FromToWalletPicker
       └─ PostingDatePicker

RecurringOperationComposer  (replaces RecurringTransactionComposerScreen)
└─ TransactionFormCore
   ├─ IconColorPicker         (recurring-only header)
   └─ RecurrenceSettingsSection (~20% of form)
       ├─ RecurrencePatternPicker
       ├─ ScheduleFields (dayOfMonth / weekdays / monthOfYear)
       ├─ ScheduledTimePicker
       ├─ ReminderLeadDaysPicker
       ├─ AnchorDatePicker
       ├─ ExecutionTypePicker (auto/confirm)
       └─ KindSpecificSection
           ├─ VariableIncomeToggle   (if income)
           └─ DebtSettingsSection    (if expense + isDebt)
               ├─ PrincipalField
               ├─ InstallmentCountField
               └─ DownPaymentField
```

This eliminates the current `2650-line` `RecurringTransactionComposerScreen` by sharing `TransactionFormCore` with `AddTransactionScreen`. The recurring-only section is a composable extension.

---

## PHASE 6 — CATEGORY SYSTEM AUDIT

### Category Lifecycle Trace

**Creation:**
- Categories are created in `CategoriesScreen` → `AppCubit.addCategory()`
- When a user creates a category linked to an allocation, `allocationId` is set
- When linked to a jar, `walletId` is set (confusingly named `walletId` for a jar ID)

**Storage — Three Simultaneous Copies:**

```
AppStateEntity
├─ categories: List<CategoryEntity>          ← GLOBAL list (source of truth for display)
├─ budgetSetup
│   ├─ allocations[n].categories: List<CategoryEntity>  ← EMBEDDED per allocation
│   └─ linkedWallets[n].categories: List<CategoryEntity> ← EMBEDDED per jar
```

**This is the root cause of jar category display issues.**

Categories are stored **three times** with no guaranteed consistency:
1. The global `AppStateEntity.categories` list
2. Inside each `AllocationEntity.categories` (copy)
3. Inside each `LinkedWalletEntity.categories` (copy)

**Filtering:**
- Budget tracking screen filters categories by looking at `allocation.categories` or `jar.categories` (the embedded copies)
- Transaction screen filters categories from `AppStateEntity.categories` filtered by scope + allocationId
- These can diverge after edits

**Entity design:**
```dart
class CategoryEntity {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String scope;           // 'income' | 'expense'
  final String? allocationId;   // links to AllocationEntity
  final String? walletId;       // links to LinkedWalletEntity (jar) — name is misleading
  final String? incomeSourceId; // rarely used
}
```

**The real root cause of jar category bugs:**

When a category is added to a jar:
- It is added to the global `AppStateEntity.categories` list with `walletId = jar.id`
- It is ALSO added to `LinkedWalletEntity.categories` as an embedded copy

When the jar is edited, the embedded copy may be updated but the global copy may not (or vice versa). The `CategoriesScreen` edits the global list. The `JarEditorScreen` edits the embedded copy. **There is no reconciliation.**

When categories are displayed for a jar transaction, if the code reads from `jar.categories` it sees the stale embedded copy. If it reads from `AppStateEntity.categories` filtered by `walletId`, it may see a different set.

**Verification:**
```bash
# In budget_tracking_screen.dart — looks at jar.categories (embedded)
jar.categories.where((c) => ...)

# In add_transaction_screen.dart — looks at global list filtered by walletId
state.categories.where((c) => c.walletId == jarId)
```

Both paths exist. They can diverge after any category update that touches only one of the two copies.

**The fix is NOT UI-only.** The domain change needed is:
- Remove embedded `categories` from `AllocationEntity` and `LinkedWalletEntity`
- Use the global `AppStateEntity.categories` list exclusively, filtered by `allocationId` or `walletId`
- OR: Keep embedded copies but enforce consistency through a single `updateCategory()` path that updates all copies

**Recommendation:** Remove embedded categories entirely. Use the global list with `allocationId`/`walletId` filters. This eliminates the three-copy problem.

---

## PHASE 7 — IMPLEMENTATION PLAN

### Migration Overview

All steps listed in dependency order. Steps 1–4 are non-breaking. Steps 5–7 are breaking migrations.

---

### Step 1: Fix the `createdAt` Bug in Expense Posting

**Files affected:** `app_cubit.dart` — `recordRecurringExpenseOccurrence()`  
**Change:** Replace `createdAt: DateTime.now()` with `createdAt: DateTime(occurrence.year, occurrence.month, occurrence.day, occurrence.hour, occurrence.minute)`  
**Breaking changes:** None. Data correction only.  
**Migration risk:** Zero. Affects only new postings.  
**Rollback:** Revert single line.  
**Complexity:** Trivial.

---

### Step 2: Unify `_executeRecurringOccurrence` in AppCubit

**Files affected:** `app_cubit.dart`  
**Change:** Extract shared pattern from `recordRecurringIncomeOccurrence` and `recordRecurringExpenseOccurrence` into `_executeRecurringOccurrence(state, transaction, op, occurrence)`. Both methods delegate construction of `TransactionEntity` to their own builders, then call the shared method.  
**Breaking changes:** None (internal refactor).  
**Migration risk:** Low. Fully covered by the existing log-and-undo mechanism.  
**Rollback:** Revert to two separate methods.  
**Complexity:** Low.

---

### Step 3: Fix Category Three-Copy Problem

**Files affected:**
- `budget_setup_entity.dart` — `AllocationEntity`, `LinkedWalletEntity`
- `app_cubit.dart` — all category add/update/delete methods
- `categories_screen.dart`
- `jar_editor_screen.dart`
- `add_transaction_screen.dart`
- `budget_tracking_screen.dart`

**Change:**
1. Remove `categories: List<CategoryEntity>` from both `AllocationEntity` and `LinkedWalletEntity`
2. All category lookups read from `AppStateEntity.categories` filtered by `allocationId` or `walletId`
3. Write a `fromMap` migration that re-populates the global list from embedded categories before stripping them

**Breaking changes:** Old serialized data has embedded categories; migration must extract them to global list before stripping.  
**Migration risk:** Medium. If migration is incomplete, categories silently disappear.  
**Migration strategy:** In `AppCubit.initialize()`, add `_migrateCategoriesFromEmbedded(appState)` that:
  - Reads all categories from `allocation.categories` and `jar.categories`
  - Merges them (by ID) into `AppStateEntity.categories`
  - Strips the embedded copies
  - Sets a `categoriesMigrationDone` flag  
**Rollback:** Re-add embedded categories to entities; data can be reconstructed from global list via `allocationId/walletId`.  
**Complexity:** Medium.

---

### Step 4: Add `weekday` → `weekdays` Migration + Remove Dead Field

**Files affected:** `recurring_transaction_entity.dart`, `app_cubit.dart` (migration method)  
**Change:** In `fromMap`, if `weekdays` is empty and `weekday != null`, populate `weekdays = [weekday]`. Remove `weekday` from `toMap()` after a migration cycle.  
**Breaking changes:** Forward-compat only. Old data continues to work.  
**Migration risk:** Low.  
**Rollback:** Keep `weekday` in `toMap()` for one release.  
**Complexity:** Trivial.

---

### Step 5: Introduce `RecurringOperation` Entity (Additive)

**Files affected:**
- NEW: `lib/features/recurring/domain/entities/recurring_operation.dart`
- NEW: `lib/features/recurring/domain/services/occurrence_generator.dart` (rename + migrate from `RecurringScheduleEngine`)
- NEW: `lib/features/recurring/domain/services/recurring_execution_engine.dart`

**Change:** Add new entity alongside existing `RecurringTransactionEntity`. Do not remove old entity yet. Write `RecurringOperation.fromLegacy(RecurringTransactionEntity)` converter.  
**Breaking changes:** None (additive).  
**Migration risk:** Zero at this step.  
**Rollback:** Delete the new files.  
**Complexity:** Medium.

---

### Step 6: Eliminate `DebtEntity` — Merge into `RecurringOperation.DebtKind`

**Files affected:**
- `budget_setup_entity.dart` — remove `debts: List<DebtEntity>`
- `app_cubit.dart` — remove all DebtEntity sync code (~150 lines across 5 methods)
- `budget_recurring_plan_service.dart` — read from `RecurringOperation` instead of `DebtEntity`
- `budget_tracking_screen.dart`, `debts_and_subscriptions_screen.dart`, `cycle_analysis_screen.dart`

**Change:**
1. Migration: for each `DebtEntity`, find its linked `RecurringTransactionEntity` and upgrade it to `RecurringOperation` with `DebtKind` carrying `fundingSourceId` from `DebtEntity`
2. For orphaned `DebtEntity` records (no linked recurring), create a `RecurringOperation` with a disabled schedule
3. Remove `BudgetSetupEntity.debts`
4. All debt budget tracking reads from `state.recurringOperations.whereType<DebtKind>()`

**Breaking changes:**
- `BudgetSetupEntity.debts` removed — all reads must be updated
- `DebtEntity.fundingSource` moved to `DebtKind.fundingSourceId`

**Migration risk:** HIGH. Affects budget tracking, installment cards, debt payments. Requires careful data migration with rollback point.  
**Migration strategy:**
1. Add `_migrateDebtEntitiesToOperations()` in initialize()
2. Store `debtMigrationDone` flag
3. Keep `BudgetSetupEntity.debts` in `fromMap()` for one release (read-only, migration source)
4. After migration confirmed stable, remove from `toMap()`

**Rollback:** Keep `debts` in `BudgetSetupEntity`, restore sync code in cubit. Data is never deleted in migration — `DebtEntity` data is only read for migration, not overwritten.  
**Complexity:** HIGH.

---

### Step 7: Replace `RecurringTransactionEntity` with `RecurringOperation`

**Files affected:** ALL files that import `recurring_transaction_entity.dart` (~15 files)  
**Change:** Replace `RecurringTransactionEntity` with `RecurringOperation` everywhere. Write `AppStateEntity.fromMap()` migration that converts old recurring records.  
**Breaking changes:** Full type replacement.  
**Migration risk:** HIGH. Run after Step 6 is stable.  
**Rollback:** Revert all file changes; the old type remains in storage until explicitly removed.  
**Complexity:** HIGH.

---

### Step 8: Composer Redesign

**Files affected:**
- `add_transaction_screen.dart` — refactor to use `TransactionFormCore`
- `recurring_transaction_composer_screen.dart` — replace with `RecurringOperationComposer`
- NEW: `lib/features/shared/presentation/widgets/transaction_form_core.dart`

**Breaking changes:** None visible to users. Internal widget restructure.  
**Migration risk:** Medium. Form state management must be preserved.  
**Rollback:** Revert composer files.  
**Complexity:** Medium-High. Both screens are ~2400–2650 lines.

---

### Step 9: Retroactive Auto-Posting

**Files affected:** `app_cubit.dart` (initialize + foreground hook)  
**Change:** Add `_catchUpAutoOperations()` called from `initialize()` and when app is resumed from background. For each `executionType == auto` operation where `unhandledDue != null`, auto-execute silently and add to notification history.  
**Breaking changes:** None. Additive behavior.  
**Migration risk:** Low. Only affects `auto` operations.  
**Rollback:** Remove the catch-up call.  
**Complexity:** Low.

---

### Complexity Summary

| Step | Description | Complexity | Risk |
|------|-------------|------------|------|
| 1 | Fix expense createdAt bug | Trivial | Zero |
| 2 | Unify execute pipeline | Low | Low |
| 3 | Fix category three-copy problem | Medium | Medium |
| 4 | weekday → weekdays migration | Trivial | Zero |
| 5 | Add RecurringOperation entity (additive) | Medium | Zero |
| 6 | Eliminate DebtEntity | HIGH | HIGH |
| 7 | Replace RecurringTransactionEntity | HIGH | HIGH |
| 8 | Composer redesign | Medium-High | Medium |
| 9 | Retroactive auto-posting | Low | Low |

**Recommended sequence:** 1 → 2 → 4 → 3 → 5 → 9 → 6 → 7 → 8

Start with zero-risk fixes (Steps 1, 2, 4) to build confidence. Step 3 (categories) is independent of the recurring redesign. Step 5 (additive new entity) prepares for Steps 6–7 without breaking anything. Step 6 is the highest-risk step and should be done in a dedicated release with a database rollback checkpoint. Step 8 (composer) is last — cosmetic restructure only, does not affect data.

---

## RULES COMPLIANCE CHECK

| Rule | Status |
|------|--------|
| Never assume — trace everything | ✅ Every finding above has a file + line reference |
| Never fix UI before verifying Domain | ✅ Domain issues identified first; UI changes are Step 8 (last) |
| Never duplicate recurring logic | ✅ Duplicates identified; consolidation designed |
| Never duplicate transaction logic | ✅ Unified execution pipeline designed |
| Always prefer extracting shared business rules | ✅ `RecurringExecutionEngine`, `OccurrenceGenerator`, `RecurringStatusResolver` designed |
| Architecture first, implementation second | ✅ This document is complete before any code change |

---

*Awaiting Phase 4 approval before beginning Phase 8 implementation.*
