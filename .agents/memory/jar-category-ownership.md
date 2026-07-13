---
name: Jar category ownership & scope
description: How jar-linked categories determine Income vs Expense scope, and which ownership field is authoritative vs dead.
---

## Ownership source of truth
A category's jar ownership is determined **solely by list membership** in
`LinkedWalletEntity.categories` (or `AllocationEntity.categories` for
allocations) — never by an ID field on the category itself.

`CategoryEntity.walletId` and `CategoryEntity.allocationId` are write-only /
dead fields: they get set in some creation paths (e.g. the Categories
management screen) but are never read anywhere in the app for filtering,
grouping, or display. Do not treat them as authoritative and do not add new
logic that reads them without first making them the real source of truth
(a planned future refactor removes/reconciles them).

**Why:** confirmed by an exhaustive grep — every actual ownership check in
the codebase (`_sectionsFor` in categories_screen.dart, the jar/allocation
category pickers in add_transaction_screen.dart, `AppCubit.updateLinkedWalletCategories`)
operates on list containment, never on `.walletId`/`.allocationId`.

## Scope vs owner must stay independent
Categories have two independent axes: `scope` ('income'/'expense') and
owner (general vs a specific jar/allocation). A jar can and should hold
both income categories (e.g. "jar deposit") and expense categories
(spending from the jar) simultaneously — never assume a jar's category
list is single-scope.

**How to apply:** any UI section, filter, or creation flow that shows or
adds a jar's categories must filter/tag by `category.scope` explicitly
(`wallet.categories.where((c) => c.scope == 'income'/'expense')`). Never
dump a jar's full unfiltered category list, and never hardcode a creation
flow's `scope` based only on which screen/tab happens to expose the "add
category" affordance — that was the root cause of a real bug where jar
income categories were silently created/stored as `scope: 'expense'`.
