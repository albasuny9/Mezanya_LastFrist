# BUG-002 — Jar Category Scope vs Owner Investigation

**Investigation Target:** Jar-related categories are mixed with expense/income categories; possible causes are incorrect stored scope, incorrect filtering, or both.
**Mode:** Forensic investigation only. No code was modified. No fix is proposed.

---

## Executive Summary

`CategoryEntity` has exactly two possible `scope` values in practice, `'expense'` and `'income'` — there is no distinct `'jar'` scope anywhere in the codebase. A category's membership in the "general" bucket vs. a specific Jar (`LinkedWalletEntity`) or Allocation is determined **entirely by which physical list stores it** (`AppStateEntity.categories` vs. `LinkedWalletEntity.categories` vs. `AllocationEntity.categories`), not by any field on the category itself. The entity does carry apparent "owner" fields (`allocationId`, `walletId`, `incomeSourceId`), but they are **write-only** — set once at creation and never read by any filtering, retrieval, or display logic anywhere in the app. In particular, `incomeSourceId` is hardcoded to `null` every time a category is created through the UI, which makes the existing `c.incomeSourceId == null` filter predicate (used to carve "general expense" categories out of the global list) always true for every UI-created category — it currently does no discriminating work.

Because storage location is the *only* real discriminator, any code path that reads categories from just one bucket while a transaction's `categoryId` actually points into a different bucket will silently fail to resolve that category. This is independently confirmed in the category breakdown charts (`_CategoryBreakdown`, `_IncomeBreakdown` in `transaction_charts_screen.dart`), which look a transaction's `categoryId` up only inside `state.categories` (the general bucket) and never search `budget.allocations[*].categories` or `budget.linkedWallets[*].categories`. A transaction categorized under a Jar- or Allocation-owned category therefore renders as "uncategorized" in these charts, even though the same transaction correctly resolves its category name elsewhere (e.g. `getCategoryForTransaction` in `transaction_details_sheet.dart`, which does search all three buckets).

---

## Investigation Scope

- Entity under investigation: `CategoryEntity` (`lib/features/categories/domain/entities/category_entity.dart`).
- Lifecycle traced: creation → saved entity shape → stored scope/owner → retrieval → filtering → display, per the Bug Backlog's required investigation steps.
- "Jar" in this codebase refers to `LinkedWalletEntity` (UI label "حصالة")، not `AllocationEntity` ("مخصص") — confirmed from UI strings in `categories_screen.dart` (`'فئات الحصالة أو الحساب المرتبط "${wallet.name}"'`) and `add_transaction_screen.dart` (`'حصالة: ${selectedJar.first.name}'` referring to `budget.linkedWallets`).
- Files read directly: `category_entity.dart`, `categories_screen.dart`, `budget_setup_entity.dart`, `app_cubit.dart`, `add_transaction_screen.dart`, `recurring_transaction_composer_screen.dart`, `transaction_details_sheet.dart`, `transaction_charts_screen.dart`, `jar_editor_screen.dart`.

---

## Execution Flow

### 1. Entity shape

```dart
// lib/features/categories/domain/entities/category_entity.dart:1-43
class CategoryEntity {
  final String id;
  final String name;
  final String icon;
  final String color;
  final String scope;              // 'expense' | 'income'
  final String? allocationId;
  final String? walletId;
  final String? incomeSourceId;

  factory CategoryEntity.fromMap(Map<String, dynamic> map) => CategoryEntity(
        ...
        scope: map['scope'] as String? ?? 'expense',
        allocationId: map['allocationId'] as String?,
        walletId: map['walletId'] as String?,
        incomeSourceId: map['incomeSourceId'] as String?,
      );
}
```

There is no `CategoryScope`/`CategoryType` enum backing `scope` — it is a raw `String`. A repo-wide search for the literal `scope: '` finds only two constructor call sites that assign it (`categories_screen.dart:668` → `widget.scope`, `add_transaction_screen.dart:555` → `'income'` hardcoded for a recurring-income category shortcut). Neither ever assigns anything other than `'expense'` or `'income'` — no `'jar'` value is ever produced.

### 2. Creation and the "owner" fields

```dart
// lib/features/categories/presentation/screens/categories_screen.dart:653-676 (_save)
Navigator.of(context).pop(
  CategoryEntity(
    id: widget.current?.id ?? 'cat-${DateTime.now().microsecondsSinceEpoch}',
    name: name,
    icon: _selectedIcon,
    color: _selectedColor,
    scope: widget.scope,                                                  // = _tab ('expense' | 'income')
    allocationId: widget.target.kind == 'allocation' ? widget.target.id : null,
    walletId: widget.target.kind == 'linked-wallet' ? widget.target.id : null,
    incomeSourceId: null,                                                  // always null, unconditionally
  ),
);
```

`scope` here comes from `_tab`, the Categories screen's own top-level UI toggle state (`'expense'` or `'income'`), **not** from which target (general / allocation / jar) the category is being added to. `allocationId`/`walletId` are populated based on `target.kind`, but — per Section 3 below — nothing ever reads them back out.

### 3. Where a category actually ends up (storage)

```dart
// lib/features/categories/presentation/screens/categories_screen.dart:481-540 (_saveCategory)
if (target.kind == 'allocation') {
  ... await widget.cubit.updateAllocationCategories(allocationId: target.id, categories: next);
  return;
}
if (target.kind == 'linked-wallet') {
  ... await widget.cubit.updateLinkedWalletCategories(linkedWalletId: target.id, categories: next);
  return;
}
// otherwise: written into the global bucket
await widget.cubit.setCategories(next);
```

```dart
// lib/features/app_state/presentation/cubits/app_cubit.dart:1272-1307
Future<void> setCategories(List<CategoryEntity> categories) async { ... state.copyWith(categories: categories) ... }
Future<void> updateAllocationCategories({...}) async {
  final allocations = state.budgetSetup.allocations
      .map((item) => item.id == allocationId ? item.copyWith(categories: categories) : item)
      .toList();
  ...
}
Future<void> updateLinkedWalletCategories({...}) async {
  final linkedWallets = state.budgetSetup.linkedWallets
      .map((item) => item.id == linkedWalletId ? item.copyWith(categories: categories) : item)
      .toList();
  ...
}
```

A category is stored in exactly one of three disjoint lists — `AppStateEntity.categories` (general), `AllocationEntity.categories` (per-allocation), or `LinkedWalletEntity.categories` (per-jar) — chosen by `target.kind` at save time. This structural placement, not the `scope`/`allocationId`/`walletId` fields on the entity itself, is what actually determines "which bucket" a category belongs to.

### 4. The "owner" fields are never read back

A repo-wide search for reads of these fields (as opposed to the two write sites in Section 2 and the `fromMap`/`toMap` pass-through) returns no results:

- `grep -rn "c\.walletId\|category\.walletId\|cat\.walletId\|\.allocationId ==" lib/` → only unrelated hits on `TransactionEntity.allocationId` (a different class, used for budget-tracking filters on transactions, not categories).
- `grep -rn "incomeSourceId:" lib/features/categories` → only the `fromMap` deserialization line and the hardcoded `incomeSourceId: null` write in `_save()`.

So `CategoryEntity.allocationId`, `.walletId`, and `.incomeSourceId` are populated at creation but **no filtering, retrieval, or display code anywhere reads them** to decide anything. They persist in storage (`toMap()`/`fromMap()` round-trip them faithfully) but are functionally inert.

### 5. Filtering that *is* actually used — all keyed on `scope` + storage location

```dart
// categories_screen.dart:46-50
final generalExpense = state.categories.where((c) => c.scope == 'expense' && c.incomeSourceId == null).toList();
final generalIncome = state.categories.where((c) => c.scope == 'income').toList();
// ...and per-jar sections read wallet.categories.where((c) => c.scope == 'income'/'expense')
```

```dart
// add_transaction_screen.dart:318-338
final jarCategories = selectedJar.first.categories.where((c) => c.scope == 'expense').toList();
final incomeJarCategories = selectedIncomeJar.first.categories.where((c) => c.scope == 'income').toList();
final generalExpenseCategories = state.categories.where((c) => c.scope == 'expense' && c.incomeSourceId == null).toList();
```

```dart
// recurring_transaction_composer_screen.dart:1858-1879 (_visibleCategories)
if (_type == expense && _withinBudget) {
  if (_allocationId != null) return allocation.first.categories;   // no scope filter at all
  if (_targetJarId != null) return jar.first.categories;           // no scope filter at all
}
return allCategories.where((category) => category.scope == _type).toList();  // general bucket only
```

Every one of these predicates filters by `scope` (`'expense'`/`'income'`) combined with **which list is being iterated** (general / this allocation's / this jar's own `categories`). None of them ever consult `allocationId`/`walletId`/`incomeSourceId` to decide membership — consistent with Section 4's finding that those fields are unread. Because `incomeSourceId` is always `null` in practice (Section 2), the `&& c.incomeSourceId == null` clause used to isolate "general expense" categories is currently a tautology for any UI-created category — it does not exclude anything that wouldn't already be excluded by scope + bucket membership.

### 6. Display — category-name lookup is inconsistent across the app

```dart
// transaction_details_sheet.dart:15-32 (getCategoryForTransaction) — searches ALL three buckets
for (final c in state.categories) { if (c.id == categoryId) return c; }
for (final alloc in state.budgetSetup.allocations) { for (final c in alloc.categories) { if (c.id == categoryId) return c; } }
for (final jar in state.budgetSetup.linkedWallets) { for (final c in jar.categories) { if (c.id == categoryId) return c; } }
```

```dart
// transaction_charts_screen.dart:60 + 706, 1074 — searches ONLY the general bucket
final categories = widget.cubit.state.categories;   // general only
...
final cat = e.key == '__none__' ? null : categories.where((c) => c.id == e.key).firstOrNull;  // in both _CategoryBreakdown (706) and _IncomeBreakdown (1074)
```

`_CategoryBreakdown` and `_IncomeBreakdown` (the expense/income pie-chart-style breakdowns in the Home/Charts screen) receive only `widget.cubit.state.categories` (`transaction_charts_screen.dart:60`) and never look inside `budget.allocations[*].categories` or `budget.linkedWallets[*].categories`. Any transaction whose `categoryId` points at an allocation- or jar-owned category will fail this lookup (`firstOrNull` → `null`) and be grouped/rendered as if uncategorized, even though the transaction detail sheet (using `getCategoryForTransaction`) correctly resolves and displays the same category's name.

---

## Evidence

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | Is there a distinct `'jar'` category scope? | No. Only `'expense'`/`'income'` string values are ever assigned to `scope`. | `category_entity.dart:38` (default fallback `'expense'`); repo-wide search of `scope: '` literals → only `categories_screen.dart:668` (`widget.scope`) and `add_transaction_screen.dart:555` (`'income'`). |
| 2 | How is a category recognized as belonging to a specific Jar? | Purely by physical storage location — being an element of `LinkedWalletEntity.categories` for that jar's `id`. Not by any field on the category. | `categories_screen.dart:504-516` (`updateLinkedWalletCategories`); `app_cubit.dart:1296-1307`. |
| 3 | Are `allocationId`/`walletId`/`incomeSourceId` used anywhere to filter or resolve categories? | No confirmed read site found anywhere in the app. | Repo-wide greps in Section 4 above returned no matching read usages. |
| 4 | Is `incomeSourceId` ever set to a non-null value on a category? | No — the only UI creation path hardcodes it to `null`. | `categories_screen.dart:673` (`incomeSourceId: null,`). |
| 5 | Does a jar-owned category's name resolve correctly everywhere it's displayed? | Inconsistent: `getCategoryForTransaction` searches all three buckets and resolves correctly; the Home/Charts breakdown widgets search only the general bucket and will show such a transaction as uncategorized. | `transaction_details_sheet.dart:15-32` vs. `transaction_charts_screen.dart:60,706,1074`. |
| 6 | Files involved | See "Files Involved" below. | — |
| 7 | Methods involved | See "Methods Involved" below. | — |

---

## Root Cause

There is no single "smoking gun" line producing wrongly-mixed categories in storage — the three category lists (general / per-allocation / per-jar) are kept structurally separate at write time (`setCategories` / `updateAllocationCategories` / `updateLinkedWalletCategories`), so a category cannot literally end up in the wrong list through the creation/save path traced above.

The underlying design defect is that **`CategoryEntity` carries "owner" fields (`allocationId`, `walletId`, `incomeSourceId`) that look like they encode ownership/scope, but no code anywhere reads them** — the real discriminator used everywhere is a combination of (a) which of the three lists holds the entity, and (b) the two-valued `scope` string, which only distinguishes expense vs. income and has no jar-specific value. This satisfies the Bug Backlog's caution not to conflate "category scope" with "category owner": the codebase already conflates them in the opposite direction — the owner fields exist but do no work, while `scope` (a pure expense/income flag) and storage location together stand in for both concerns.

The practical, user-visible consequence of this design gap that was independently confirmed in this investigation is in **display**, not storage: because `_CategoryBreakdown`/`_IncomeBreakdown` only search the general bucket for a category's display name, any transaction categorized under a Jar- or Allocation-owned category is misrepresented as uncategorized in the Home/Charts screen, producing an apparent "categories are missing/mixed up" symptom from the user's point of view, while `getCategoryForTransaction` elsewhere in the app resolves the same category correctly.

---

## Confirmed Facts

- `CategoryEntity.scope` only ever takes the values `'expense'` or `'income'` in the entire codebase; no `'jar'` scope value is produced anywhere.
- Category bucket membership (general / allocation / jar) is determined solely by which of `AppStateEntity.categories`, `AllocationEntity.categories`, or `LinkedWalletEntity.categories` stores the entity — confirmed via the three disjoint write paths in `AppCubit` (`setCategories`, `updateAllocationCategories`, `updateLinkedWalletCategories`).
- `CategoryEntity.allocationId`, `.walletId`, and `.incomeSourceId` are populated at creation (`categories_screen.dart:668-673`) but have no confirmed read site anywhere in the app outside of `toMap()`/`fromMap()` persistence round-tripping.
- `incomeSourceId` is hardcoded to `null` on every category created through the UI (`categories_screen.dart:673`), making the `c.incomeSourceId == null` filter clause (`categories_screen.dart:47`, `add_transaction_screen.dart:332`) a tautology for all UI-created categories as currently used.
- `_CategoryBreakdown` and `_IncomeBreakdown` (`transaction_charts_screen.dart`) resolve a transaction's category name by searching only `state.categories` (the general bucket), while `getCategoryForTransaction` (`transaction_details_sheet.dart`) searches all three buckets. This is a confirmed inconsistency between two display code paths for the same underlying data.

## Likely Causes

- The owner fields (`allocationId`/`walletId`/`incomeSourceId`) were likely added in anticipation of a filtering/ownership model that was never wired up, while storage-location-based separation was implemented as the actual mechanism instead — this would explain why the fields are written but never read. **Not proven**: no commit history or design doc was consulted to confirm intent versus abandonment; this is an inference from code shape, not a verified historical fact.

---

## Unknowns

- **Not proven:** whether the user-reported symptom ("categories mixed with expense/income categories") refers to the Home/Charts breakdown miscategorization confirmed here, to some other screen not yet inspected, or to a data-corruption scenario (e.g. duplicate IDs across buckets) that was not reproduced or found in this investigation.
- **Not proven:** whether any other screen besides `_CategoryBreakdown`/`_IncomeBreakdown` reads only the general bucket while a transaction could reference a jar/allocation category id — a full inventory of every `categories.where(...)`/`categories.firstWhere(...)` call site in the app was not exhaustively completed beyond the call sites quoted above.
- **Not proven:** whether category `id` values could ever collide across the three buckets (e.g. two independently-created categories in different buckets sharing an id) — the id generator (`'cat-${DateTime.now().microsecondsSinceEpoch}'`) is timestamp-based and was not stress-tested or proven collision-free.
- **Not proven:** whether recurring-transaction flows (`recurring_transaction_composer_screen.dart`) have any additional display sites with the same general-bucket-only lookup gap — only `_visibleCategories`/`_firstSelectedCategory` were traced, not every category-name render in that file.

---

## Files Involved

- `lib/features/categories/domain/entities/category_entity.dart`
- `lib/features/categories/presentation/screens/categories_screen.dart`
- `lib/features/budget/domain/entities/budget_setup_entity.dart` (`AllocationEntity`, `LinkedWalletEntity`)
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
- `lib/features/app_state/domain/entities/app_state_entity.dart`
- `lib/features/transactions/presentation/screens/add_transaction_screen.dart`
- `lib/features/transactions/presentation/screens/recurring_transaction_composer_screen.dart`
- `lib/features/transactions/presentation/widgets/transaction_details_sheet.dart`
- `lib/features/home/presentation/screens/transaction_charts_screen.dart`
- `lib/features/wallets/presentation/screens/jar_editor_screen.dart` (contrast — jar creation/edit does not seed or migrate categories)

## Methods Involved

- `_CategoryEditorScreen._save` — `categories_screen.dart` (category creation, sets `scope`/owner fields)
- `_CategoriesScreenState._sectionsFor` — `categories_screen.dart` (per-bucket filtering for display)
- `_CategoriesScreenState._saveCategory` / `_deleteCategory` — `categories_screen.dart` (routes writes to one of three disjoint storage lists)
- `AppCubit.setCategories` / `updateAllocationCategories` / `updateLinkedWalletCategories` — `app_cubit.dart`
- `getCategoryForTransaction` — `transaction_details_sheet.dart` (searches all three buckets — contrast case)
- `_visibleCategories` — `recurring_transaction_composer_screen.dart`
- `_CategoryBreakdown.build` / `_IncomeBreakdown.build` — `transaction_charts_screen.dart` (searches general bucket only — confirmed gap)

---

## Next Investigation

(Provided for completeness only — no fix proposed here, per investigation scope.)
- Reproduce the reported symptom directly against a running build (create a Jar category, categorize a transaction under it, open Home/Charts) to confirm the breakdown-widget gap identified here is the actual symptom the user/bug-reporter observed, rather than inferring it purely from static code reading.
- Enumerate every category-list read site in the app (`grep`-complete, not sample-based) to close the "Unknowns" item about other screens with the same general-bucket-only gap.
- If a fix is later authorized, evaluate whether the intended design is (a) making all display/lookup sites search all three buckets like `getCategoryForTransaction` does, or (b) actually wiring up the currently-inert owner fields as the single source of truth — this is a design decision outside forensic-investigation scope.
