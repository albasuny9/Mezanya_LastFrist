<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Architectural Refactor — Budget Feature

## What & Why
Refactor the Budget feature following the Mezanya Strict Architectural Refactor Specification. The goal is structural improvement only — zero behavior changes, zero logic modifications, zero UI changes. `budget_tracking_screen.dart` is currently ~5,273 lines and must be decomposed into properly scoped widgets, models, and services.

## Done looks like
- `budget_tracking_screen.dart` is reduced to an orchestrating screen (300–600 lines max) that only builds widgets, handles navigation, dialogs, and state observation
- All business logic, calculations, and filtering are inside focused domain services under `features/budget/domain/services/`
- All UI sections are extracted into individual widget files under `features/budget/presentation/widgets/` (150–300 lines each)
- All display models are extracted under `features/budget/domain/models/` (immutable, no side effects, no calculations)
- All magic numbers, colors, paddings, durations are extracted to constants
- `flutter analyze` passes with zero new warnings or errors
- The app compiles and launches with visually and functionally identical output
- Every financial calculation (budget balances, allocation balances, cycle metrics) returns identical values

## Out of scope
- Any bug fixes
- Any logic changes or improvements
- Any UI/UX redesign
- Modifying AppCubit public API
- Modifying Firestore collections, documents, or serialization
- Modifying TransactionProcessor logic
- Any other feature

## Steps

1. **Phase 1 — Extract Widgets**: Identify every distinct UI section in `budget_tracking_screen.dart` and `budget_setup_screen.dart`. Extract each into its own file under `features/budget/presentation/widgets/`. Pass all required data via constructor parameters — no business logic inside widgets. Run `flutter analyze` and verify the app launches identically after each extraction.

2. **Phase 2 — Extract Models**: Identify any inline data structures, view models, or DTOs built inside screens or services. Extract them as immutable model classes under `features/budget/domain/models/`. Models must represent data only — no calculations, no side effects. Run `flutter analyze` and verify.

3. **Phase 3 — Extract Services**: Move all business logic, calculations, filtering, and statistics that currently live inside screens into focused single-responsibility services under `features/budget/domain/services/`. Existing services (`BudgetMetricsService`, `BudgetTransactionFilter`, `BudgetRecurringPlanService`) may receive additional extracted logic. Never change the logic — move it exactly. Run `flutter analyze` and verify.

4. **Phase 4 — Extract Helpers and Constants**: Extract all magic numbers, magic strings, repeated padding/radius/duration values into constants files. Extract any formatting logic into utility classes under `features/budget/domain/utils/` (formatting only, never business rules). Run `flutter analyze` and verify.

5. **Phase 5 — Remove safe duplication**: Only merge truly duplicated code where input, output, side effects, execution order, and behavior are provably identical. Preserve intentional duplication. Run `flutter analyze`, verify the app launches, and confirm all budget calculations are identical to the original.

6. **Add documentation**: Every new file must have a file-level doc comment explaining its purpose, responsibility, dependencies, why it exists, and what it must never do.

## Relevant files
- `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
- `lib/features/budget/presentation/screens/budget_setup_screen.dart`
- `lib/features/budget/presentation/screens/cycle_analysis_screen.dart`
- `lib/features/budget/domain/services/budget_metrics_service.dart`
- `lib/features/budget/domain/services/budget_transaction_filter.dart`
- `lib/features/budget/domain/services/budget_recurring_plan_service.dart`
- `lib/features/budget/domain/models/budget_metrics.dart`
- `lib/features/budget/domain/entities/budget_setup_entity.dart`
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
