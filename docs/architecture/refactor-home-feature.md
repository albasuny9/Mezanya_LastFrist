# Architectural Refactor — Home Feature

## What & Why
Refactor the Home feature following the Mezanya Strict Architectural Refactor Specification. Zero behavior changes. `money_screen.dart` (~852 lines) and related screens must become orchestrators. All financial summary calculations (monthly summaries, remaining income) must move into domain services — never changed, only moved.

## Done looks like
- `money_screen.dart` is a lean orchestrator (300–600 lines max)
- `all_transactions_screen.dart` and `transaction_charts_screen.dart` are orchestrators
- All UI sections extracted into widget files under `features/home/presentation/widgets/`
- All financial summary logic extracted into domain services under `features/home/domain/services/`
- `flutter analyze` passes with zero new warnings
- All monthly summaries, remaining income calculations, and transaction charts are visually and numerically identical

## Out of scope
- Any calculation changes
- Any UI/UX redesign
- Modifying AppCubit public API
- Modifying Firestore or serialization
- Any other feature

## Steps

1. **Phase 1 — Extract Widgets**: Extract every distinct UI section from home screens into dedicated widget files under `features/home/presentation/widgets/`. Verify with `flutter analyze`.

2. **Phase 2 — Extract Models**: Extract inline view models or chart data structures into immutable model classes under `features/home/domain/models/`.

3. **Phase 3 — Extract Services**: Move any financial summaries, transaction filtering, or statistics calculations out of screens into focused domain services (e.g., `HomeStatisticsService`, `TransactionSummaryService`). Move code exactly.

4. **Phase 4 — Extract Constants**: Extract magic values and formatting utilities.

5. **Phase 5 — Remove safe duplication**: Only provably identical duplications.

6. **Add documentation**: Every new file gets a file-level doc comment.

## Relevant files
- `lib/features/home/presentation/screens/money_screen.dart`
- `lib/features/home/presentation/screens/all_transactions_screen.dart`
- `lib/features/home/presentation/screens/transaction_charts_screen.dart`
- `lib/features/home/presentation/widgets/money_overview_widgets.dart`
- `lib/features/home/presentation/widgets/recent_transaction_card.dart`
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
