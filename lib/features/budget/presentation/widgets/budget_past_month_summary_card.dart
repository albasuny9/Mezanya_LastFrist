// BudgetPastMonthSummaryCard
//
// Purpose: A summary card shown when the user is viewing a past budget cycle,
// displaying final income, expense, and net totals for that period.
//
// Responsibility: Pure UI — renders a styled container with three summary rows.
// No business logic, no calculations, no side effects.
//
// Dependencies: Flutter Material, BudgetSummaryRow.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_pastMonthSummaryCard) to reduce file size and isolate UI presentation.
//
// Must never: Perform calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';
import '../constants/budget_layout.dart';
import 'budget_summary_row.dart';

class BudgetPastMonthSummaryCard extends StatelessWidget {
  const BudgetPastMonthSummaryCard({
    super.key,
    required this.totalIncomeActual,
    required this.totalExpenseActual,
    required this.remainingIncome,
  });

  final double totalIncomeActual;
  final double totalExpenseActual;
  final double remainingIncome;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(kBudgetRadiusCard),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص هذا الشهر',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'هذا الشهر للعرض فقط. يمكنك مراجعة ما حدث داخل الخطة والمعاملات.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          BudgetSummaryRow('إجمالي الدخل', totalIncomeActual),
          BudgetSummaryRow('إجمالي المصروف', totalExpenseActual),
          BudgetSummaryRow(
            'الصافي النهائي',
            remainingIncome,
            danger: remainingIncome < 0,
          ),
        ],
      ),
    );
  }
}
