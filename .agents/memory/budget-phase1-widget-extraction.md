<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

---
name: Budget Phase 1 Widget Extraction
description: Decisions and lessons from extracting widgets out of budget_tracking_screen.dart into individual files
---

## Status
Complete — `flutter analyze lib/features/budget/presentation/` → No issues found.

## Key decisions

**`_colorFromHex` → `BudgetIconBadge.colorFromHex()`**
Migrated as a static method so callers use `BudgetIconBadge.colorFromHex(hex)` throughout the screen.

**`replace_all: true` for call-site renames is safe** as long as you then delete the (now-renamed) method definitions afterward. The tool renames signatures too, but you remove the whole block immediately after.

**Parallel Edit calls can conflict** when all submitted at once to the same file. Each Edit returned "+1/-1" suggesting sequential application. Verify with grep after parallel edits.

**Removing large file sections**: use ShellExec with `sed -i 'N,Md'` in reverse-line-order so earlier ranges stay valid. Much faster than multiple Edit calls on a 5000-line file.

**Dangling library doc comments**: widget files that start with `///` block comments before any `library` declaration trigger `dangling_library_doc_comments` info warnings. Fix by replacing `///` with `//` at the top of each file (`sed -i 's|^///|//|g' file`).

**Unused imports to remove after extraction**: `app_theme.dart`, `app_icon_picker_dialog.dart` (used only in extracted widgets), `budget_section_curtain_body.dart`, `budget_summary_row.dart` (used only inside other extracted widgets, not the screen).

## Execution order for future phases
Budget → Wallets → Transactions → Notifications → Home → Settings+AppCubit
Within each feature: Phase 1 Extract Widgets → Phase 2 Models → Phase 3 Services → Phase 4 Constants → Phase 5 Remove duplication.

## Why
Zero behavior changes throughout. Financial logic is immutable. Only UI code moved.
