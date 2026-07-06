// BudgetInlineSectionCard
//
// Purpose: An expandable/collapsible section card used in the budget tracking
// screen for income totals and allocation summaries. Displays a title, amount,
// subtitle, and optionally expands to show child widgets.
//
// Responsibility: Pure UI — all data, callbacks, and children are passed via
// constructor. Renders the animated container, the header row, and the
// expanded content. No business logic, no state access.
//
// Dependencies: Flutter Material, BudgetSectionCurtainBody.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_inlineSectionCard) to reduce file size and isolate this UI section.
//
// Must never: Perform calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';
import '../constants/budget_colors.dart';
import '../constants/budget_layout.dart';
import 'budget_section_curtain_body.dart';

class BudgetInlineSectionCard extends StatelessWidget {
  const BudgetInlineSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isExpanded,
    required this.onTap,
    this.expandedChildren = const <Widget>[],
    this.incomeTotalLayout = false,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final double amount;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<Widget> expandedChildren;
  final bool incomeTotalLayout;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncomeTotal = incomeTotalLayout && title == 'الدخل الكلي';
    final accent = accentColor ??
        (title == 'الدخل الكلي'
            ? kBudgetIncomeGreen
            : kBudgetDangerOrange);

    final Color shellColor;
    final Color shellBorder;
    final List<BoxShadow>? shellShadow;

    if (isIncomeTotal) {
      shellColor = theme.colorScheme.surface;
      shellBorder = theme.colorScheme.outlineVariant.withValues(alpha: 0.55);
      shellShadow = null;
    } else if (incomeTotalLayout) {
      shellColor = accent.withValues(alpha: isExpanded ? 0.12 : 0.08);
      shellBorder = accent.withValues(alpha: isExpanded ? 0.28 : 0.16);
      shellShadow = [
        BoxShadow(
          color: accent.withValues(alpha: isExpanded ? 0.12 : 0.07),
          blurRadius: isExpanded ? 26 : 22,
          offset: const Offset(0, 10),
        ),
      ];
    } else {
      shellColor = accent.withValues(alpha: 0.10);
      shellBorder = accent.withValues(alpha: 0.22);
      shellShadow = null;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(kBudgetRadiusCard),
        onTap: onTap,
        child: AnimatedContainer(
          duration: kBudgetAnimMed,
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(
            incomeTotalLayout ? 18 : 16,
            incomeTotalLayout ? 18 : 16,
            incomeTotalLayout ? 18 : 16,
            incomeTotalLayout ? 16 : 14,
          ),
          decoration: BoxDecoration(
            color: shellColor,
            borderRadius: BorderRadius.circular(kBudgetRadiusCard),
            border: Border.all(color: shellBorder),
            boxShadow: shellShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: isIncomeTotal
                                      ? theme.colorScheme.onSurface
                                      : (incomeTotalLayout
                                          ? theme.colorScheme.onSurface
                                          : accent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              amount.toStringAsFixed(2),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: isIncomeTotal
                                    ? kBudgetIncomeGreen
                                    : (incomeTotalLayout
                                        ? accent.withValues(alpha: 0.96)
                                        : null),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isIncomeTotal
                        ? theme.colorScheme.onSurfaceVariant
                        : accent,
                    size: 28,
                  ),
                ],
              ),
              if (isExpanded && expandedChildren.isNotEmpty) ...[
                Padding(
                  padding:
                      EdgeInsets.only(top: incomeTotalLayout ? 16 : 14),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: isIncomeTotal
                        ? theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.45)
                        : accent.withValues(alpha: 0.14),
                  ),
                ),
                if (incomeTotalLayout) const SizedBox(height: 8),
                incomeTotalLayout
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: expandedChildren,
                      )
                    : BudgetSectionCurtainBody(children: expandedChildren),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
