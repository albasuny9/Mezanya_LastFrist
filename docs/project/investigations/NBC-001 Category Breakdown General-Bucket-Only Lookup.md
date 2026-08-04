# NBC-001 — New Bug Candidate: Category Breakdown Charts Only Search the General Category Bucket

**Status:** New Bug Candidate (discovered during BUG-002 investigation). Not yet added to the Task Plan's prioritized queue — awaiting triage.
**Discovered while investigating:** BUG-002 — Jar categories mixed with expense/income categories.
**Why this is a separate bug, not part of BUG-002:** BUG-002's reported symptom is that jar-related categories are mixed into / appear inside the wrong category *sections* (the Categories screen's expense/income lists). This candidate is a distinct symptom: a transaction correctly categorized under a Jar- or Allocation-owned category renders as **uncategorized** in the Home/Charts breakdown, even though the category itself is not "mixed" anywhere in storage. These are different mechanisms and must not be conflated or used to explain each other. Per the operating protocol, this is recorded here as its own candidate rather than substituted into the BUG-002 write-up.
**Mode:** Forensic investigation only. No code was modified. No fix is proposed.

---

## Summary

`_CategoryBreakdown` and `_IncomeBreakdown` (the expense/income pie-style breakdowns in the Home/Charts screen) resolve a transaction's category name by searching only `AppCubit.state.categories` — the **general** category bucket. They never search `budget.allocations[*].categories` or `budget.linkedWallets[*].categories` (the per-allocation and per-jar buckets). Any transaction whose `categoryId` points into one of those two buckets will fail this lookup and be grouped/displayed as if it had no category at all.

This is confirmed to be inconsistent with `getCategoryForTransaction` (used by the transaction details sheet), which does search all three buckets and resolves the same category correctly.

---

## Evidence

```dart
// lib/features/home/presentation/screens/transaction_charts_screen.dart:60
final categories = widget.cubit.state.categories;   // general bucket only — passed to both breakdown widgets
```

```dart
// lib/features/home/presentation/screens/transaction_charts_screen.dart:700-706 (_CategoryBreakdown.build)
final cat = e.key == '__none__'
    ? null
    : categories.where((c) => c.id == e.key).firstOrNull;
```

```dart
// lib/features/home/presentation/screens/transaction_charts_screen.dart:1069-1074 (_IncomeBreakdown.build)
final cat = e.key == '__none__'
    ? null
    : categories.where((c) => c.id == e.key).firstOrNull;
```

Contrast — the correct, all-buckets lookup used elsewhere:

```dart
// lib/features/transactions/presentation/widgets/transaction_details_sheet.dart:15-31 (getCategoryForTransaction)
for (final c in state.categories) { if (c.id == categoryId) return c; }
for (final alloc in state.budgetSetup.allocations) { for (final c in alloc.categories) { if (c.id == categoryId) return c; } }
for (final jar in state.budgetSetup.linkedWallets) { for (final c in jar.categories) { if (c.id == categoryId) return c; } }
```

## Confirmed Facts

- `_CategoryBreakdown` and `_IncomeBreakdown` both receive only the general category list and both resolve category identity via a plain `categories.where((c) => c.id == e.key).firstOrNull` against that list only.
- `getCategoryForTransaction`, used elsewhere in the app for the same underlying data (transaction → category name), searches all three buckets.
- No seed/copy mechanism was found that duplicates jar/allocation categories into the general bucket (see BUG-002 investigation), so this gap is not compensated for anywhere.

## Likely Causes

- Most likely an oversight when Jar/Allocation-scoped categories were introduced after these chart widgets were originally written against only the general bucket — **not proven**, no commit history consulted.

## Unknowns

- **Not proven:** how visible/frequent this is in practice — depends on how often users categorize transactions under jar/allocation-owned categories versus general ones, which was not measured against real data.
- **Not proven:** whether any other screen has the same general-bucket-only gap; only the two Home/Charts breakdown widgets were checked in this pass.

## Files Involved

- `lib/features/home/presentation/screens/transaction_charts_screen.dart` (`_CategoryBreakdown`, `_IncomeBreakdown`)
- `lib/features/transactions/presentation/widgets/transaction_details_sheet.dart` (`getCategoryForTransaction` — contrast reference)

## Suggested Triage

- Add to the Task Plan's priority queue as its own bug (does not require BUG-002 to be resolved first — the two are independent).
- If promoted, the required investigation would be: reproduce against a running build (categorize a transaction under a jar/allocation category, open Home/Charts, confirm it shows as uncategorized) before any fix is considered.
