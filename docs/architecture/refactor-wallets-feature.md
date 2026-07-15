<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Architectural Refactor — Wallets Feature

## What & Why
Refactor the Wallets feature following the Mezanya Strict Architectural Refactor Specification. Zero behavior changes, zero logic modifications, zero UI changes. `wallets_screen.dart` is currently ~2,716 lines and must be decomposed into scoped widgets, models, and services.

## Done looks like
- `wallets_screen.dart` is reduced to an orchestrating screen (300–600 lines max)
- All UI sections extracted into individual widget files under `features/wallets/presentation/widgets/` (150–300 lines each)
- Wallet and jar business logic extracted into focused domain services under `features/wallets/domain/services/`
- Display models extracted under `features/wallets/domain/models/` (immutable, data-only)
- `flutter analyze` passes with zero new warnings or errors
- The app compiles and launches with visually and functionally identical output
- All wallet balances and jar balances remain identical

## Out of scope
- Any bug fixes or logic changes
- Any UI/UX redesign
- Modifying AppCubit public API
- Modifying Firestore or serialization
- Modifying TransactionProcessor
- Any other feature

## Steps

1. **Phase 1 — Extract Widgets**: Identify every distinct UI section in `wallets_screen.dart`, `full_wallets_page.dart`, `full_jars_page.dart`, and `jar_editor_screen.dart`. Extract each section into its own file under `features/wallets/presentation/widgets/`. No business logic inside widgets. Verify after each extraction with `flutter analyze`.

2. **Phase 2 — Extract Models**: Extract any inline view models or data structures into immutable model classes under `features/wallets/domain/models/`. Models are data-only — no calculations, no side effects.

3. **Phase 3 — Extract Services**: Move all business logic — wallet statistics, jar calculations, balance derivations — out of screens and into focused single-responsibility services under `features/wallets/domain/services/` (e.g., `WalletStatisticsService`). Move code exactly — never rewrite logic.

4. **Phase 4 — Extract Helpers and Constants**: Extract magic numbers, strings, paddings, and formatting into constants and utility classes. Formatting utilities only — never business rules.

5. **Phase 5 — Remove safe duplication**: Only merge provably identical duplications. Preserve intentional duplication. Verify wallet and jar balances are identical to original.

6. **Add documentation**: Every new file gets a file-level doc comment: purpose, responsibility, dependencies, why it exists, what it must never do.

## Relevant files
- `lib/features/wallets/presentation/screens/wallets_screen.dart`
- `lib/features/wallets/presentation/screens/full_wallets_page.dart`
- `lib/features/wallets/presentation/screens/full_jars_page.dart`
- `lib/features/wallets/presentation/screens/jar_editor_screen.dart`
- `lib/features/wallets/presentation/widgets/jar_details_sheet.dart`
- `lib/features/wallets/presentation/widgets/jars_section_widget.dart`
- `lib/features/wallets/presentation/widgets/wallet_shared_widgets.dart`
- `lib/features/wallets/presentation/widgets/wallets_section_widget.dart`
- `lib/features/wallets/domain/entities/wallet_entity.dart`
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
