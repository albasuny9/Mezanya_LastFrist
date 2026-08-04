<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

---
name: Budget Phase 2 Constants Extraction
description: What was done and key decisions from Phase 2 of the budget feature refactor — extracting named constants and date-format helpers.
---

## What Phase 2 Did

Extracted all inline magic literals (Color hex values, border-radius doubles, animation Durations, and DateFormat patterns) from the 19 budget widget files and `budget_tracking_screen.dart` into three new centralized files.

## New Files

- `lib/features/budget/presentation/constants/budget_colors.dart` — named Color constants
- `lib/features/budget/presentation/constants/budget_layout.dart` — border-radius doubles + animation Durations
- `lib/features/budget/domain/utils/budget_date_format.dart` — DateFormat helper functions

## Key Decisions

- `// ignore_for_file: dangling_library_doc_comments` added to all three new files because triple-slash file-level doc comments without a `library` directive trigger lint warnings. This is the minimal fix without adding `library;` directives.
- `budget_setup_screen.dart` was deliberately left untouched — it is out of Phase 2 scope.
- DateFormat patterns used with time (`HH:mm`, `h:mm a`, `d/M - HH:mm`, `d MMMM - h:mm a`) were not extracted to helpers because they mix date+time or use formats not cleanly covered by the seven helper functions. Extracting them would require adding more helpers or overloading existing ones, which Phase 2 did not call for.
- `kBudgetRadiusIcon = 10.0` added for icon container inside installment card — was discovered after initial extraction pass.
- `BorderRadius.circular(100)` in month-bar arrow InkWell ripples maps to `kBudgetRadiusPill` (999) since both values exceed the button dimensions and produce a circle ripple.

**Why:** Pure structural refactor — no behavior, UI, or financial value changes. Zero flutter analyze issues at completion.
