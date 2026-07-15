<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Architectural Refactor — Settings, AppShell & AppCubit

## What & Why
Refactor the Settings, AppShell, and AppCubit following the Mezanya Strict Architectural Refactor Specification. Zero behavior changes. AppCubit (~1,866 lines) must NOT be redesigned or replaced — only extract methods into dedicated services while keeping the public API identical. Settings and AppShell screens become orchestrators.

## Done looks like
- `app_cubit.dart` public API is unchanged; internal methods that perform business logic are extracted into dedicated services (e.g., `BackupOrchestrationService`, `StorageService`) that AppCubit delegates to — logic is moved, not rewritten
- `app_settings_screen.dart` and `backup_settings_screen.dart` are lean orchestrators
- AppShell screens and widgets are clean — no business logic inside `main_shell_screen.dart`
- `flutter analyze` passes with zero new warnings
- All settings behavior, backup behavior, navigation, and state transitions are identical

## Out of scope
- Redesigning or replacing AppCubit
- Migrating state management
- Modifying Firestore or serialization
- Any UI/UX redesign
- Any behavior changes

## Steps

1. **Phase 1 — Extract Widgets**: Extract UI sections from settings screens and AppShell widgets into properly scoped widget files. Verify with `flutter analyze`.

2. **Phase 2 — Extract Models**: Extract inline data structures into immutable model classes.

3. **Phase 3 — Extract Services from AppCubit**: Identify cohesive groups of methods inside AppCubit (e.g., backup logic, storage orchestration, profile management) and extract them into focused services. AppCubit delegates to these services. Public API of AppCubit must remain identical. Move logic exactly — never rewrite.

4. **Phase 4 — Extract Constants**: Extract magic values, strings, durations, and formatting utilities.

5. **Phase 5 — Remove safe duplication**: Only provably identical duplications.

6. **Add documentation**: Every new file gets a file-level doc comment explaining purpose, responsibility, dependencies, and what it must never do.

## Relevant files
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
- `lib/features/settings/presentation/screens/app_settings_screen.dart`
- `lib/features/settings/presentation/screens/backup_settings_screen.dart`
- `lib/features/settings/presentation/widgets/app_settings_sections.dart`
- `lib/features/app_shell/presentation/screens/main_shell_screen.dart`
- `lib/features/app_shell/presentation/widgets/main_shell_app_bar.dart`
- `lib/features/app_shell/presentation/widgets/main_shell_bottom_navigation.dart`
- `lib/features/app_shell/presentation/widgets/more_tab_content.dart`
- `lib/features/backup/backup_service.dart`
- `lib/features/backup/backup_conflict_dialog.dart`
- `lib/features/backup/restore_prompt_dialog.dart`
- `lib/core/di/bootstrap.dart`
