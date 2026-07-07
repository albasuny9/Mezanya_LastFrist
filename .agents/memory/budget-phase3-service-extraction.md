---
name: Budget Phase 3 Service Extraction
description: Phase 3 of budget feature refactor — pure business logic moved from budget_tracking_screen.dart into four domain services. Covers what was done, key decisions, and one behavioral nuance to carry forward.
---

## What was done

14 private methods moved from `budget_tracking_screen.dart` into domain services.
Screen shrunk from ~3,207 → ~2,919 lines. `flutter analyze`: no issues.

### Services extended
- `BudgetTransactionFilter` — added 3 static methods: `isJarReserveTx`, `forCycle`, `sortedForIncomeSource`
- `BudgetRecurringPlanService` — added 3 static methods: `transactionCountsTowardDebt`, `allDebtPayments`, `expensePendingMeta`

### Services created
- `BudgetCycleService` — 5 static methods: `budgetForMonth`, `incomeDueDateForMonth`, `linkedRecurringIncome`, `incomePendingMeta`, `hasPendingIncome`
- `BudgetIncomeMetricsService` — 3 static methods: `incomeDisplayPool`, `spentAttributedToIncomeSource`, `incomeRemainingProgress`

## Key behavioral nuance (carry forward)

`BudgetCycleService.incomePendingMeta()` and `hasPendingIncome()` take an explicit `isCurrentCycle` parameter.

**Rule:** At call sites inside the screen, always pass `_isCurrentMonthView()` (the method call), NOT a pre-computed `isCurrentMonthView` variable derived from a snapshot-resolved `budget`.

**Why:** `_isCurrentMonthView()` reads from `widget.cubit.state.budgetSetup` (live state). The `budget` local variable in `build()` is resolved via `budgetForMonth()` which may return a past snapshot. These two could diverge briefly under StreamBuilder timing. The original inner code always used live state; pass `_isCurrentMonthView()` to preserve that exactly.

## Import additions to screen
- `budget_cycle_service.dart`
- `budget_income_metrics_service.dart`
- `budget_transaction_filter.dart`
- Removed `dart:convert` (no longer used after `_budgetForMonth` moved out)

## Removed thin wrappers from screen
- `_nextRecurringOccurrence` — replaced with direct `RecurringScheduleEngine.nextOccurrence()` calls
- `_dueOccurrenceNow` — still in screen (called from methods that remain there)

## pub get note
After any flutter analyze failure showing `uri_does_not_exist` for `package:intl/intl.dart` in newly created domain service files, run `flutter pub get` first. The `.dart_tool/package_config.json` can become stale.
