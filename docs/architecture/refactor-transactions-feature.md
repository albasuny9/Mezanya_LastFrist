<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Architectural Refactor — Transactions Feature

## What & Why
Refactor the Transactions feature following the Mezanya Strict Architectural Refactor Specification. Zero behavior changes. `TransactionProcessor` is core financial infrastructure — methods may be moved or split into files but logic, order, conditions, and arithmetic must remain byte-for-byte identical. Screens must be reduced to orchestrators only.

## Done looks like
- Transaction screens (`add_transaction_screen.dart`, `recurring_transactions_screen.dart`, `debts_and_subscriptions_screen.dart`, etc.) are orchestrators only — no financial calculations inside screens
- UI sections extracted into widget files under `features/transactions/presentation/widgets/`
- `TransactionProcessor` may be split across files but all logic is identical — same methods, same order, same arithmetic, same side effects
- `flutter analyze` passes with zero new warnings
- All transaction calculations, recurring logic, debt calculations, and subscription logic are identical

## Out of scope
- Any logic changes to TransactionProcessor
- Any changes to recurring schedule engine logic
- Any UI/UX redesign
- Modifying AppCubit public API
- Modifying Firestore or serialization
- Any other feature

## Steps

1. **Phase 1 — Extract Widgets**: Extract every UI section from transaction screens into dedicated widget files under `features/transactions/presentation/widgets/`. Widgets must be presentation-only. Verify with `flutter analyze` after each extraction.

2. **Phase 2 — Extract Models**: Extract inline view models and data structures into immutable model classes under `features/transactions/domain/models/`. Data-only, no calculations.

3. **Phase 3 — Extract Services**: Move business logic out of screens into focused services under `features/transactions/domain/services/`. TransactionProcessor internals may be split into helper files but must never change logic, order, or arithmetic. Recurring schedule logic in `RecurringScheduleEngine` must remain intact.

4. **Phase 4 — Extract Helpers and Constants**: Extract magic values and formatting into constants and formatting utilities.

5. **Phase 5 — Remove safe duplication**: Only merge provably identical duplications. Preserve intentional duplication, especially in financial paths.

6. **Add documentation**: Every new file gets a file-level doc comment describing purpose, responsibility, dependencies, what it must never do.

## Relevant files
- `lib/features/transactions/domain/services/transaction_processor.dart`
- `lib/features/transactions/domain/services/recurring_schedule_engine.dart`
- `lib/features/transactions/presentation/screens/add_transaction_screen.dart`
- `lib/features/transactions/presentation/screens/recurring_transactions_screen.dart`
- `lib/features/transactions/presentation/screens/recurring_transaction_composer_screen.dart`
- `lib/features/transactions/presentation/screens/debts_and_subscriptions_screen.dart`
- `lib/features/transactions/presentation/screens/subscription_preset_selection_screen.dart`
- `lib/features/transactions/presentation/widgets/shared_transaction_card.dart`
- `lib/features/transactions/presentation/widgets/transaction_details_sheet.dart`
- `lib/features/transactions/domain/entities/transaction_entity.dart`
- `lib/features/transactions/domain/entities/recurring_transaction_entity.dart`
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
