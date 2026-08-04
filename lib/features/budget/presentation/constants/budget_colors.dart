// ignore_for_file: dangling_library_doc_comments
/// budget_colors.dart
///
/// Purpose: Defines all budget-feature-specific color constants used across
/// the budget presentation layer.
///
/// Responsibility: Centralize magic color literals so every widget and screen
/// in the budget feature references a single named source of truth. Only
/// presentation-layer colors belong here — theme colors (primary, surface,
/// error, etc.) continue to be read from the active ColorScheme via
/// Theme.of(context).
///
/// Dependencies: Flutter Material (Color only).
///
/// Why this file exists: Budget widgets and budget_tracking_screen.dart
/// contained repeated inline hex literals (Color(0xFF…)) that could only be
/// understood from context. Extracting them to named constants improves
/// readability and prevents accidental value drift between files.
///
/// Must never: Contain business logic, financial calculations, widget code,
/// or any value that is not a plain Color constant.

import 'package:flutter/material.dart';

// ── Income / Positive greens ─────────────────────────────────────────────────

/// Primary income accent — dark forest green used for income section titles,
/// entity tile amount text, lent-card icons, and as the default icon-badge
/// fallback colour string '#165b47'.
const Color kBudgetIncomeGreen = Color(0xFF165B47);

/// Medium income green used as the "healthy" start colour in the usage
/// progress gradient (_usageProgressColor).
const Color kBudgetIncomeGreenMed = Color(0xFF1D8F62);

/// Bright income green used in the cycle-summary card's progress bar and
/// analysis-cycle button chip.
const Color kBudgetIncomeGreenBright = Color(0xFF1E7F5C);

/// Default budget accent / icon-badge fallback used when no icon colour is
/// available (BudgetIconBadge hex fallback 0xFF0F9D7A) and in the setup
/// prompt icon.
const Color kBudgetDefaultAccent = Color(0xFF0F9D7A);

/// Lent-section accent (dark green used for the lent collapsed card and lent
/// detail sheet).
const Color kBudgetLentGreen = Color(0xFF1A7A4A);

// ── Warning / Usage ───────────────────────────────────────────────────────────

/// Warning yellow — mid-usage progress colour and cycle-summary health bar
/// transition colour.
const Color kBudgetWarningYellow = Color(0xFFE4B83F);

/// High-usage orange — upper portion of the usage progress gradient.
const Color kBudgetWarningOrange = Color(0xFFE78A2E);

// ── Danger ────────────────────────────────────────────────────────────────────

/// Danger orange — used for debt / overdue entities, installment cards, the
/// inline-section card default danger accent, and the lent-pending overdue
/// badge.
const Color kBudgetDangerOrange = Color(0xFFC65D2E);

/// Critical danger red — end colour of the usage progress gradient when
/// spending is at or above the limit.
const Color kBudgetDangerRed = Color(0xFFC63D32);

// ── Pending / Snoozed ─────────────────────────────────────────────────────────

/// Pending / snooze amber — used for the snooze chip on income tiles,
/// pending-distribution chips on allocation and jar tiles, and lent overdue
/// entity tint when snoozed.
const Color kBudgetPendingAmber = Color(0xFFF5A623);

// ── Transaction sheet surface colours ────────────────────────────────────────

/// Muted warm-brown text colour used for the day-group date label inside
/// BudgetDraggableFilterableTxSheet.
const Color kBudgetMutedText = Color(0xFF8A7F72);

/// Off-white background colour for transaction day-group containers inside
/// the draggable transaction sheet.
const Color kBudgetSheetSurface = Color(0xFFFFFCF8);

/// Light beige border/divider colour for transaction day-group containers and
/// their internal dividers inside the draggable transaction sheet.
const Color kBudgetSheetBorder = Color(0xFFF3EDE4);

// ── Month bar colours ─────────────────────────────────────────────────────────

/// Accent and navigation-arrow fill colour for the current-cycle month bar.
const Color kBudgetMonthBarAccentCurrent = Color(0xFF355E3B);

/// Text / accent colour for the month bar when showing a past or future cycle.
const Color kBudgetMonthBarAccentOther = Color(0xFF5C6E53);

/// Background colour of the month bar for past or future cycles.
const Color kBudgetMonthBarBgOther = Color(0xFFF6F3EA);

/// Border colour of the month bar for past or future cycles.
const Color kBudgetMonthBarBorderOther = Color(0xFFC6CFB6);

/// Background colour of the month bar for the current cycle.
const Color kBudgetMonthBarBgCurrent = Color(0xFFF5F0E6);

/// Border colour of the month bar for the current cycle.
const Color kBudgetMonthBarBorderCurrent = Color(0xFFA7B48E);

// ── Hero bar-chart colours ────────────────────────────────────────────────────

/// Normal income bar colour in the hero summary bar chart (up to planned
/// income).
const Color kBudgetChartIncomeGreen = Color(0xFF4ADE80);

/// Excess-income bar colour in the hero summary bar chart (income above the
/// planned amount).
const Color kBudgetChartIncomeExcessGreen = Color(0xFF15803D);

/// Expense bar colour in the hero summary bar chart.
const Color kBudgetChartExpenseRed = Color(0xFFF87171);

// ── Hero summary card gradient colours ───────────────────────────────────────

/// Hero card gradient — dark green (healthy state, first stop).
const Color kBudgetHeroGreenDark = Color(0xFF2F5D50);

/// Hero card gradient — mid green (healthy state, second stop).
const Color kBudgetHeroGreenMid = Color(0xFF4E7A69);

/// Hero card gradient — light green (healthy state, third stop).
const Color kBudgetHeroGreenLight = Color(0xFF93B59D);

/// Hero card gradient — dark amber (warning state, first stop).
const Color kBudgetHeroYellowDark = Color(0xFF8A6C2E);

/// Hero card gradient — mid amber (warning state, second stop).
const Color kBudgetHeroYellowMid = Color(0xFFB08B3F);

/// Hero card gradient — light amber (warning state, third stop).
const Color kBudgetHeroYellowLight = Color(0xFFD9BF78);

/// Hero card gradient — dark terracotta (danger state, first stop).
const Color kBudgetHeroRedDark = Color(0xFF7A4A3A);

/// Hero card gradient — mid terracotta (danger state, second stop).
const Color kBudgetHeroRedMid = Color(0xFFA8654D);

/// Hero card gradient — light terracotta (danger state, third stop).
const Color kBudgetHeroRedLight = Color(0xFFD19478);

// ── Setup prompt gradient ─────────────────────────────────────────────────────

/// Setup prompt icon container gradient — light green top stop.
const Color kBudgetSetupGradientLight = Color(0xFFE8F5E9);

/// Setup prompt icon container gradient — slightly deeper green bottom stop.
const Color kBudgetSetupGradientDark = Color(0xFFD8F3E5);

// ── Lent add-entry dialog gradient ───────────────────────────────────────────

/// Lent add-entry dialog hero gradient — dark green stop.
const Color kBudgetLentDialogGradientDark = Color(0xFF1A7A4A);

/// Lent add-entry dialog hero gradient — bright green stop.
const Color kBudgetLentDialogGradientLight = Color(0xFF2DAE6B);

// ── Entity tile miscellaneous ─────────────────────────────────────────────────

/// Chevron icon colour used in BudgetEntityTile trailing area.
const Color kBudgetChevronGrey = Color(0xFF9E9E9E);
