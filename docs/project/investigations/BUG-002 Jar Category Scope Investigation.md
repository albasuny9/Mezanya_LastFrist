# BUG-002 — Jar Category Scope vs Owner Investigation

**Investigation Target:** Jar-related categories are mixed with expense/income categories; possible causes are incorrect stored scope, incorrect filtering, or both.
**Mode:** Forensic investigation only. No code was modified. No fix is proposed.

---

## Executive Summary

**Verdict on the reported symptom ("Jar categories are mixed with expense/income categories"): NOT PROVEN as a storage-level or section-display defect.** Every write path traced (`setCategories`, `updateAllocationCategories`, `updateLinkedWalletCategories`) keeps general, per-allocation, and per-jar categories in three structurally disjoint lists, and the Categories screen's own section rendering (`_sectionsFor`) reads each bucket separately into its own titled section — no mechanism was found by which a jar-owned category is written into, or displayed inside, the general expense/income sections or vice versa. If the reported symptom is specifically "a jar category visibly appears under the general Expense or Income section in the Categories screen," this investigation did not find a way for that to happen and did not reproduce it against a running build (see Unknowns/Next Investigation) — so it is recorded as **NOT PROVEN** rather than Confirmed or Disproven.

What *is* confirmed, and is squarely within this bug's required-investigation scope ("Separate category scope from category owner"), is that `CategoryEntity` has exactly two possible `scope` values in practice, `'expense'` and `'income'` — there is no distinct `'jar'` scope anywhere in the codebase — and that the entity's apparent "owner" fields (`allocationId`, `walletId`, `incomeSourceId`) are **write-only**: set once at creation and never read by any filtering, retrieval, or display logic anywhere in the app. `incomeSourceId` in particular is hardcoded to `null` every time a category is created through the UI, making the existing `c.incomeSourceId == null` filter predicate (used to carve "general expense" categories out of the global list) a tautology for every UI-created category. This means "category scope" (expense/income) and "category owner" (which bucket it lives in) are in practice conflated into a single mechanism — storage location — while the fields that look like they should express ownership do nothing. This is a real, confirmed design gap even though it was not shown to produce the specific "categories appear in the wrong section" symptom as reported.

A distinct, separate bug was discovered during this investigation — the Home/Charts category-breakdown widgets resolve a transaction's category name from only the general bucket, so jar/allocation-owned categories render as "uncategorized" there. That is a different symptom (miscategorized/uncategorized display, not "mixed into the wrong section") and is **not** used here to explain BUG-002; it is recorded separately in `docs/project/investigations/NBC-001 Category Breakdown General-Bucket-Only Lookup.md` per the operating protocol's rule against substituting one bug for another.

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

### 6. Display — the Categories screen itself keeps sections separate (relevant to the reported symptom)

```dart
// categories_screen.dart:78-111 (_sectionsFor, expense tab) — each bucket rendered in its own titled section
_SectionData(key: 'general-expense', ..., categories: generalExpense, ...),
...budget.allocations.map((allocation) => _SectionData(key: 'allocation-${allocation.id}', ..., categories: allocation.categories, ...)),
...budget.linkedWallets.map((wallet) => _SectionData(key: 'linked-${wallet.id}', ..., categories: wallet.categories.where((c) => c.scope == 'expense').toList(), ...)),
```

Each section pulls from exactly one bucket and renders under its own heading (e.g. "الفئات العامة" for general, the allocation's own name, the jar's own name with a "حصالة" ("jar") subtitle). No section's category list is a union of multiple buckets, and no jar/allocation category was found leaking into the `generalExpense`/`generalIncome` lists at either the storage layer (Section 3) or this display layer. This is the strongest available evidence against the literal "jar categories appear mixed into the expense/income sections" reading of the reported symptom — but it falls short of a full disproof, since it was not verified against a running build with real user data (see Unknowns).

A separate, unrelated display gap was found while examining other category-consuming screens (the Home/Charts breakdown widgets look up a transaction's category name from only the general bucket, missing jar/allocation-owned categories). That is a different symptom from what's being investigated here and is documented on its own in `NBC-001 Category Breakdown General-Bucket-Only Lookup.md` rather than folded into this conclusion.

---

## Evidence

| # | Question | Answer | Evidence |
|---|---|---|---|
| 1 | Is there a distinct `'jar'` category scope? | No. Only `'expense'`/`'income'` string values are ever assigned to `scope`. | `category_entity.dart:38` (default fallback `'expense'`); repo-wide search of `scope: '` literals → only `categories_screen.dart:668` (`widget.scope`) and `add_transaction_screen.dart:555` (`'income'`). |
| 2 | How is a category recognized as belonging to a specific Jar? | Purely by physical storage location — being an element of `LinkedWalletEntity.categories` for that jar's `id`. Not by any field on the category. | `categories_screen.dart:504-516` (`updateLinkedWalletCategories`); `app_cubit.dart:1296-1307`. |
| 3 | Are `allocationId`/`walletId`/`incomeSourceId` used anywhere to filter or resolve categories? | No confirmed read site found anywhere in the app. | Repo-wide greps in Section 4 above returned no matching read usages. |
| 4 | Is `incomeSourceId` ever set to a non-null value on a category? | No — the only UI creation path hardcodes it to `null`. | `categories_screen.dart:673` (`incomeSourceId: null,`). |
| 5 | Does the Categories screen ever render a jar/allocation category inside a general expense/income section, or vice versa? | Not proven — no such path was found in the traced write/display code, but this was not confirmed against a running build with real data. | `categories_screen.dart:44-111` (`_sectionsFor`), `481-540` (`_saveCategory`). |
| 6 | Files involved | See "Files Involved" below. | — |
| 7 | Methods involved | See "Methods Involved" below. | — |

---

## Root Cause

**For the reported symptom itself: NOT PROVEN.** There is no "smoking gun" line found that produces wrongly-mixed categories in storage or in the Categories screen's section display — the three category lists (general / per-allocation / per-jar) are kept structurally separate at write time (`setCategories` / `updateAllocationCategories` / `updateLinkedWalletCategories`) and are rendered into separate, non-overlapping sections (`_sectionsFor`), so a category cannot be shown to literally end up mixed into the wrong section through any creation/save/display path traced above. This investigation could not confirm the reported symptom, and also found no direct evidence disproving it beyond static code reading (no running-build reproduction was attempted) — hence NOT PROVEN rather than Confirmed or Disproven.

Independent of that verdict, a genuine design defect **within the scope this bug asks about** ("Separate category scope from category owner") was confirmed: `CategoryEntity` carries "owner" fields (`allocationId`, `walletId`, `incomeSourceId`) that look like they encode ownership, but no code anywhere reads them back — the real discriminator used everywhere is a combination of (a) which of the three lists holds the entity, and (b) the two-valued `scope` string, which only distinguishes expense vs. income and has no jar-specific value. The codebase already conflates "scope" and "owner" in the opposite direction from what a naive fix might assume: the owner fields exist but do no work, while `scope` plus storage location together stand in for both concerns. This is worth tracking regardless of the original symptom's verdict, since it is exactly the ownership-vs-scope conflation the Bug Backlog asked to rule in or out.

A separate display bug was discovered while examining related screens (Home/Charts breakdown widgets miscategorize jar/allocation-owned categories as "uncategorized"). Per the operating protocol, that is **not** treated as the explanation for this bug and is documented independently in `NBC-001 Category Breakdown General-Bucket-Only Lookup.md`.

---

## Confirmed Facts

- `CategoryEntity.scope` only ever takes the values `'expense'` or `'income'` in the entire codebase; no `'jar'` scope value is produced anywhere.
- Category bucket membership (general / allocation / jar) is determined solely by which of `AppStateEntity.categories`, `AllocationEntity.categories`, or `LinkedWalletEntity.categories` stores the entity — confirmed via the three disjoint write paths in `AppCubit` (`setCategories`, `updateAllocationCategories`, `updateLinkedWalletCategories`).
- `CategoryEntity.allocationId`, `.walletId`, and `.incomeSourceId` are populated at creation (`categories_screen.dart:668-673`) but have no confirmed read site anywhere in the app outside of `toMap()`/`fromMap()` persistence round-tripping.
- `incomeSourceId` is hardcoded to `null` on every category created through the UI (`categories_screen.dart:673`), making the `c.incomeSourceId == null` filter clause (`categories_screen.dart:47`, `add_transaction_screen.dart:332`) a tautology for all UI-created categories as currently used.
- The Categories screen's own section builder (`_sectionsFor`) reads each of the three buckets separately into its own titled section, with no code path found that merges or cross-lists them — no confirmed mechanism for a jar/allocation category to visibly appear inside a general expense/income section, or vice versa.

## Likely Causes

- The owner fields (`allocationId`/`walletId`/`incomeSourceId`) were likely added in anticipation of a filtering/ownership model that was never wired up, while storage-location-based separation was implemented as the actual mechanism instead — this would explain why the fields are written but never read. **Not proven**: no commit history or design doc was consulted to confirm intent versus abandonment; this is an inference from code shape, not a verified historical fact.

---

## Unknowns

- **Not proven:** what the user-reported symptom ("categories mixed with expense/income categories") was actually observed to look like on-screen — no reproduction against a running build with real user data was performed, so a genuine section-mixing defect cannot be fully ruled out even though no mechanism for it was found in the traced code.
- **Not proven:** whether category `id` values could ever collide across the three buckets (e.g. two independently-created categories in different buckets sharing an id) — the id generator (`'cat-${DateTime.now().microsecondsSinceEpoch}'`) is timestamp-based and was not stress-tested or proven collision-free. A collision could plausibly produce a "wrong category shown" symptom that would look like mixing without the buckets themselves being merged.
- **Not proven:** whether any historical version of the app (prior to the current code) ever wrote a jar/allocation category into the general bucket or vice versa, and whether stale data from that version could still exist in a user's persisted state — only the current code paths were traced, not data migration history.

---

## Files Involved

- `lib/features/categories/domain/entities/category_entity.dart`
- `lib/features/categories/presentation/screens/categories_screen.dart`
- `lib/features/budget/domain/entities/budget_setup_entity.dart` (`AllocationEntity`, `LinkedWalletEntity`)
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
- `lib/features/app_state/domain/entities/app_state_entity.dart`
- `lib/features/transactions/presentation/screens/add_transaction_screen.dart`
- `lib/features/transactions/presentation/screens/recurring_transaction_composer_screen.dart`
- `lib/features/wallets/presentation/screens/jar_editor_screen.dart` (contrast — jar creation/edit does not seed or migrate categories)

## Methods Involved

- `_CategoryEditorScreen._save` — `categories_screen.dart` (category creation, sets `scope`/owner fields)
- `_CategoriesScreenState._sectionsFor` — `categories_screen.dart` (per-bucket filtering for display)
- `_CategoriesScreenState._saveCategory` / `_deleteCategory` — `categories_screen.dart` (routes writes to one of three disjoint storage lists)
- `AppCubit.setCategories` / `updateAllocationCategories` / `updateLinkedWalletCategories` — `app_cubit.dart`
- `_visibleCategories` — `recurring_transaction_composer_screen.dart`

*(A related but distinct display bug — `getCategoryForTransaction` in `transaction_details_sheet.dart` vs. `_CategoryBreakdown`/`_IncomeBreakdown` in `transaction_charts_screen.dart` — was discovered during this investigation and is documented separately in `NBC-001 Category Breakdown General-Bucket-Only Lookup.md`; it is intentionally not listed here so this file stays scoped to the originally reported symptom.)*

---

## Next Investigation

(Provided for completeness only — no fix proposed here, per investigation scope.)
- Reproduce the reported symptom directly against a running build with real/representative data (create categories under the general bucket, an allocation, and a jar; inspect the Categories screen's sections) to move the verdict from NOT PROVEN to Confirmed or Disproven.
- If reproduced, capture the exact screen, tab, and category involved so the mechanism (if any beyond what was traced here) can be identified.
- Triage `NBC-001 Category Breakdown General-Bucket-Only Lookup.md` as its own item in the Task Plan — it does not depend on this bug's resolution.
