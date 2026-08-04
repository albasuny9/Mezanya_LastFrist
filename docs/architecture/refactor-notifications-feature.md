<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Architectural Refactor — Notifications Feature

## What & Why
Refactor the Notifications feature following the Mezanya Strict Architectural Refactor Specification. Zero behavior changes. Notification generation logic, history generation, and action copy must remain identical. Screens become orchestrators; widgets become presentation-only.

## Done looks like
- `notifications_center_screen.dart` and `notifications_screen.dart` are orchestrators only
- All UI sections extracted into widget files under `features/notifications/presentation/widgets/`
- `notification_history_helper.dart` and `notification_history_filters.dart` logic is correctly scoped into domain services — no logic changes
- `flutter analyze` passes with zero new warnings
- All notification generation, history, and action copy behavior is identical

## Out of scope
- Any logic changes to notification generation, history, or filtering
- Any UI/UX redesign
- Modifying AppCubit public API
- Modifying Firestore or serialization
- Any other feature

## Steps

1. **Phase 1 — Extract Widgets**: Extract every UI section from notification screens into dedicated widget files under `features/notifications/presentation/widgets/`. Verify with `flutter analyze`.

2. **Phase 2 — Extract Models**: Extract inline view models into immutable model classes under `features/notifications/domain/models/`. Data-only.

3. **Phase 3 — Extract Services**: Move any business logic remaining in screens into domain services under `features/notifications/domain/services/`. `NotificationHistoryHelper` and `NotificationHistoryFilters` should be reviewed and scoped correctly — never change their logic.

4. **Phase 4 — Extract Constants**: Extract magic values, strings, and formatting.

5. **Phase 5 — Remove safe duplication**: Only provably identical duplications.

6. **Add documentation**: Every new file gets a file-level doc comment.

## Relevant files
- `lib/features/notifications/presentation/screens/notifications_center_screen.dart`
- `lib/features/notifications/presentation/screens/notifications_screen.dart`
- `lib/features/notifications/presentation/widgets/notification_center_widgets.dart`
- `lib/features/notifications/presentation/widgets/distribution_postpone_sheet.dart`
- `lib/features/notifications/presentation/widgets/notification_history_details_sheet.dart`
- `lib/features/notifications/domain/notification_history_helper.dart`
- `lib/features/notifications/domain/notification_history_filters.dart`
- `lib/features/notifications/domain/notification_action_copy.dart`
- `lib/features/notifications/domain/entities/notification_entity.dart`
- `lib/features/app_state/presentation/cubits/app_cubit.dart`
