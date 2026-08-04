// BudgetEntityTile
//
// Purpose: A reusable entity tile used to display budget items (income sources,
// allocations, jars, debts, subscriptions) with a leading icon, title, meta
// text, amount, optional progress bar, and action buttons.
//
// Responsibility: Pure UI — all data is passed via constructor parameters.
// Contains no calculations, no state access, and no Cubit calls.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_entityTile) to reduce file size and enable reuse across budget widgets.
//
// Must never: Perform business calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';
import '../constants/budget_colors.dart';
import '../constants/budget_layout.dart';

class BudgetEntityTile extends StatelessWidget {
  const BudgetEntityTile({
    super.key,
    required this.title,
    required this.leading,
    required this.amountText,
    required this.metaText,
    required this.onTap,
    this.supportingText,
    this.supportingCustom,
    this.trailingTopText,
    this.actions = const <Widget>[],
    this.progress,
    this.progressColor,
    this.tint,
    this.amountColor,
    this.compactMeta = false,
    this.embeddedInIncomeCard = false,
    this.strongTint = false,
  });

  final String title;
  final Widget leading;
  final String amountText;
  final String metaText;
  final VoidCallback onTap;
  final String? supportingText;
  final Widget? supportingCustom;
  final String? trailingTopText;
  final List<Widget> actions;
  final double? progress;
  final Color? progressColor;
  final Color? tint;
  final Color? amountColor;
  final bool compactMeta;
  final bool embeddedInIncomeCard;
  final bool strongTint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileTint = tint ?? theme.colorScheme.surface;
    final accentStrip = tint ?? kBudgetDefaultAccent;
    final decoration = embeddedInIncomeCard
        ? BoxDecoration(
            color: accentStrip.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(kBudgetRadiusMd),
            border: Border.all(
              color: accentStrip.withValues(alpha: 0.22),
            ),
          )
        : BoxDecoration(
            color: tint == null
                ? theme.colorScheme.surface
                : tileTint.withValues(alpha: strongTint ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(kBudgetRadiusCard),
            border: Border.all(
              color: tint == null
                  ? theme.colorScheme.outlineVariant
                  : tileTint.withValues(alpha: strongTint ? 0.45 : 0.24),
            ),
          );
    final radius = embeddedInIncomeCard ? kBudgetRadiusMd : kBudgetRadiusCard;
    return Container(
      margin: EdgeInsets.only(bottom: embeddedInIncomeCard ? 8 : 10),
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              embeddedInIncomeCard ? 12 : 14,
              embeddedInIncomeCard ? 12 : 14,
              embeddedInIncomeCard ? 12 : 14,
              embeddedInIncomeCard ? 12 : 14,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metaText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compactMeta ? 11 : 12,
                              color: strongTint
                                  ? Color.lerp(tileTint, Colors.black, 0.35)
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: compactMeta
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                            ),
                          ),
                          if (supportingCustom != null) ...[
                            const SizedBox(height: 4),
                            supportingCustom!,
                          ] else if (supportingText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              supportingText!,
                              style: TextStyle(
                                fontSize: 12,
                                color: strongTint
                                    ? Color.lerp(tileTint, Colors.black, 0.35)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amountText,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ).copyWith(
                            color: amountColor ?? kBudgetIncomeGreen,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: kBudgetChevronGrey,
                        ),
                      ],
                    ),
                  ],
                ),
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kBudgetRadiusPill),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      color: progressColor ?? theme.colorScheme.primary,
                      backgroundColor: (strongTint
                              ? tileTint
                              : theme.colorScheme.onSurface)
                          .withValues(alpha: strongTint ? 0.18 : 0.08),
                    ),
                  ),
                ],
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        Expanded(child: actions[i]),
                        if (i != actions.length - 1) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
