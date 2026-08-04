// ignore_for_file: dangling_library_doc_comments
/// budget_layout.dart
///
/// Purpose: Defines layout constants (border radii, animation durations) for
/// the budget feature's presentation layer.
///
/// Responsibility: Centralize repeated magic numbers so widgets and screens in
/// the budget feature reference consistent, named values instead of inline
/// literals.
///
/// Dependencies: Flutter Material (Duration only — radii are plain doubles).
///
/// Why this file exists: Border-radius and duration literals were scattered
/// across budget widgets with no obvious semantic grouping. Named constants
/// clarify intent (e.g. "pill shape" vs "card radius") and prevent accidental
/// inconsistency when the same radius is used in multiple files.
///
/// Must never: Contain business logic, financial calculations, widget code,
/// Colors, or EdgeInsets (those are one-off and need no centralisation).

// ── Border radii (double, used with BorderRadius.circular) ───────────────────

/// Icon-container radius — used for small icon badge containers inside cards
/// (e.g. installment card's credit-card icon container).
const double kBudgetRadiusIcon = 10.0;

/// Extra-small radius — used for section-title pill label containers.
const double kBudgetRadiusXS = 12.0;

/// Small radius — used for cycle-summary analysis button, inline-section
/// card InkWell chip, lent-pending overdue badge, installment icon container.
const double kBudgetRadiusS = 14.0;

/// Medium radius — used for transaction day-group containers in the draggable
/// sheet.
const double kBudgetRadiusM = 16.0;

/// Medium-large radius — used for the draggable sheet option tiles, entity
/// tile embedded-in-income-card decoration, installment card container, and
/// installment payment row containers.
const double kBudgetRadiusMd = 18.0;

/// Large radius — used for the draggable sheet top rounded corners and the
/// lent-pending card container.
const double kBudgetRadiusL = 20.0;

/// Extra-large radius — used for section-empty-card and static-info-card
/// containers.
const double kBudgetRadiusXL = 22.0;

/// Primary card radius — the standard rounded-rectangle radius for entity
/// tiles, cycle-summary card, tracking-detail hero shell, inline-section card,
/// past-month summary card, and the lent collapsed card.
const double kBudgetRadiusCard = 24.0;

/// Setup-prompt card radius — slightly larger card for the setup prompt.
const double kBudgetRadiusSetupCard = 28.0;

/// Hero card radius — the large rounded-rectangle used by the hero summary
/// card.
const double kBudgetRadiusHero = 30.0;

/// Pill radius — used for fully rounded shapes such as progress bars and
/// grab handles.
const double kBudgetRadiusPill = 999.0;

// ── Animation durations ───────────────────────────────────────────────────────

/// Fast micro-animation — used for the installment-card expand/collapse
/// AnimatedCrossFade and the installment chevron rotation.
const Duration kBudgetAnimFast = Duration(milliseconds: 200);

/// Medium section-card animation — used for the inline-section card
/// AnimatedContainer expand/collapse transition.
const Duration kBudgetAnimMed = Duration(milliseconds: 220);

/// Month-bar navigation animation — used for the BudgetMonthBar
/// AnimatedContainer colour/border transition when switching cycles.
const Duration kBudgetAnimMonthBar = Duration(milliseconds: 250);
