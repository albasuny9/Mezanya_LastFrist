// BudgetSummaryRow
//
// Purpose: A single label–value row used inside budget summary cards to display
// named financial figures (income, expense, remaining, etc.).
//
// Responsibility: Pure UI — renders a Row with a text label on one side and a
// formatted number (or custom suffix) on the other, with optional danger styling.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart (_row) to
// enable reuse across BudgetPastMonthSummaryCard and BudgetCycleSummaryCard.
//
// Must never: Perform calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';

class BudgetSummaryRow extends StatelessWidget {
  const BudgetSummaryRow(
    this.label,
    this.value, {
    super.key,
    this.danger = false,
    this.suffix,
  });

  final String label;
  final double value;
  final bool danger;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            suffix ?? value.toStringAsFixed(2),
            style: TextStyle(
              color: danger ? Theme.of(context).colorScheme.error : null,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
