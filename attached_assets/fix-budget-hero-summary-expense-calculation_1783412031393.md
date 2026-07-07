# Fix Budget Hero Summary — Expense Double-Counting

## What & Why
The Budget Hero Summary (and Cycle Analysis screen) currently calculates Actual Expenses as **all `type=expense` transactions** in the cycle. This double-counts jar spending: when income funds a jar, the budget already consumed that money; later purchases *from* the jar wrongly reduce the monthly budget a second time.

The fix adds a single method to `BudgetMetricsService` that owns the entire calculation and returns a `double`. The screen calls the service and receives a final number — no filtering, no folding, no financial logic in the presentation layer.

---

## Investigation Findings

### How each transaction kind is stored inside `TransactionEntity`

| Kind | `type` | `transferType` | `budgetScope` |
|---|---|---|---|
| Allocation expense | `expense` | null | `within-budget` |
| Physical jar funding (auto, income-triggered) | `expense` | `jar-funding-physical` | `within-budget` |
| Virtual jar funding (auto, income-triggered) | `transfer` | `jar-funding` | `within-budget` |
| Jar allocation reserve (internal) | `transfer` | `jar-allocation` | `within-budget` |
| Jar purchase / spending from jar | `expense` | `jar-allocation-spend` or null | `outside-budget` |
| Debt / installment / subscription payment | `expense` | null | `within-budget` |
| Wallet-to-wallet transfer | `transfer` | `wallet-to-wallet` | — |
| Internal transfer | `transfer` | `internal-transfer` | — |
| Manual jar deposit | `income` | `deposit-with-jar-label` | — |

### Where Actual Monthly Budget Expenses are currently calculated

**Exactly one calculation site:**
`lib/features/budget/presentation/screens/budget_tracking_screen.dart` lines 155–163:
```dart
final expenseTx = monthTx
    .where((t) => t.type == TransactionType.expense.value)
    .toList();
final totalExpenseActual = expenseTx.fold<double>(0, (s, t) => s + t.amount);
```
`totalExpenseActual` is passed as a constructor argument to `BudgetHeroSummaryCard`, `BudgetCycleSummaryCard`, `BudgetPastMonthSummaryCard`, and `CycleAnalysisScreen`. None of those widgets recalculate it.

### Other `.where(type == expense)` occurrences that are NOT this calculation

- `budget_tracking_screen.dart:1041` — filters lent-money personal notes for a specific person's loan summary. Unrelated domain; must NOT be changed.
- `budget_draggable_tx_sheet.dart:83` — UI display filter for a tab that shows expense-type rows to the user. Not a financial total; must NOT be changed.

---

## Correct Budget Expense Formula

Monthly budget expenses = transactions that **consume the monthly budget**:

```
computeActualBudgetExpense(txList) =
  sum of amounts where:
    (type == 'expense' AND budgetScope == 'within-budget')
    OR
    (type == 'transfer' AND transferType == 'jar-funding' AND budgetScope == 'within-budget')
```

Excluded (must never be counted):
- `type=expense` + `budgetScope=outside-budget` → jar purchases, spending from jar balance
- Any `type=transfer` that is NOT `jar-funding` + `within-budget` → wallet-to-wallet, internal, jar-allocation-reserve, etc.

---

## Architecture Requirement

**The presentation layer must not perform financial calculations.**

The screen must call the domain layer and receive a single `double`. No `where()`, no `fold()`, no filtering in the screen.

Correct API shape:
```dart
// domain service — owns the full calculation
class BudgetMetricsService {
  static double computeActualBudgetExpense(List<TransactionEntity> txList) { ... }
}

// screen — receives a number only
final totalExpenseActual = BudgetMetricsService.computeActualBudgetExpense(monthTx);
```

---

## Done looks like
- The Budget Hero Summary card shows correct remaining income that does not decrease when a user spends from a jar balance
- The example holds: Income 10 000, jar funding 2 000, allocation spend 5 000, jar purchase 2 000 → Expenses = 7 000, Remaining = 3 000 (not 9 000 / 1 000)
- `budget_tracking_screen.dart` contains no `where()` or `fold()` call for the expense total — only `BudgetMetricsService.computeActualBudgetExpense(monthTx)`
- `flutter analyze` passes with zero new warnings or errors
- `flutter test` passes (new unit test added)
- No UI changes — no widget hierarchy, spacing, colors, or navigation changes

## Out of scope
- Changing any other calculation (income, remaining, planned values)
- Modifying `TransactionProcessor` logic
- Modifying `TransactionEntity` fields or serialization
- Modifying Firestore
- Changing `budget_draggable_tx_sheet.dart` (display filter, not a financial calculation)
- Changing `budget_tracking_screen.dart:1041` (lent-money domain, unrelated)
- Any widget extraction or architectural refactoring
- Fixing any other bug

---

## Steps

1. **Inspect & confirm transaction metadata** — Read `BudgetTransactionFilter`, `budget_tracking_screen.dart` (lines 140–170), and `transaction_processor.dart` (lines 260–310) to verify `budgetScope` and `transferType` values exactly match the findings table above before writing any code.

2. **Search for all monthly budget expense calculations** — Search the entire codebase for every pattern that could represent a monthly actual expense total (e.g., `type.*expense.*fold`, `fold.*expense`, `totalExpense`, `actualExpense`). Confirm there is exactly one real calculation site. Document any other hits with an explanation of why they are not the same calculation (see findings above). This is the single-source-of-truth audit.

3. **Add `computeActualBudgetExpense` to `BudgetMetricsService`** — Add a static method with the signature `static double computeActualBudgetExpense(List<TransactionEntity> txList)` to `lib/features/budget/domain/services/budget_metrics_service.dart`. The method applies the correct formula from above and returns the summed `double`. No list is returned. No filtering is exposed. The method is self-contained. Add a doc comment explaining the formula, what is included, and what is intentionally excluded.

4. **Replace the calculation in `budget_tracking_screen.dart`** — Remove lines 155–163 (the `expenseTx` list and its `fold`) and replace them with a single call: `final totalExpenseActual = BudgetMetricsService.computeActualBudgetExpense(monthTx);`. The variable name `totalExpenseActual` must not change. `remainingIncome` calculation on the following line is unchanged. No other lines in the file change.

5. **Write a unit test** — Add a test in `test/budget_metrics_service_test.dart` (create if needed) that constructs the exact scenario from the spec: income 10 000, virtual jar funding 2 000 (`type=transfer`, `transferType=jar-funding`, `budgetScope=within-budget`), allocation expense 5 000 (`type=expense`, `budgetScope=within-budget`), jar purchase 2 000 (`type=expense`, `budgetScope=outside-budget`). Assert that `BudgetMetricsService.computeActualBudgetExpense(txList)` returns `7000.0`, not `9000.0`.

6. **Run `flutter analyze` and `flutter test`** — Both must pass with zero new warnings or failures before finishing.

7. **Provide the final report** — Classification table, confirmed single calculation location, new calculation location (`BudgetMetricsService.computeActualBudgetExpense`), formula used, files modified, `flutter analyze` result, `flutter test` result.

---

## Relevant files
- `lib/features/budget/domain/services/budget_metrics_service.dart`
- `lib/features/budget/domain/services/budget_transaction_filter.dart`
- `lib/features/budget/presentation/screens/budget_tracking_screen.dart:140-170`
- `lib/features/transactions/domain/services/transaction_processor.dart:260-310`
- `lib/core/constants/transaction_types.dart`
- `lib/features/transactions/domain/entities/transaction_entity.dart`
- `lib/features/budget/presentation/widgets/budget_hero_summary_card.dart`
- `lib/features/budget/presentation/screens/cycle_analysis_screen.dart:295-340`
- `lib/features/budget/presentation/widgets/budget_draggable_tx_sheet.dart:75-94`
- `test/transaction_processor_test.dart`
