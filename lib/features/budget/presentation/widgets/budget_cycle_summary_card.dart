// BudgetCycleSummaryCard
//
// Purpose: A card at the bottom of the budget tracking screen summarising the
// full financial picture of the current cycle: actual vs planned income,
// allocations, jars, debts, spending progress, and net saving.
//
// Responsibility: Pure UI — all computed values are passed via constructor.
// Includes navigation to CycleAnalysisScreen via a passed callback to keep
// navigation orchestration in the screen.
//
// Dependencies: Flutter Material, BudgetSummaryRow.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_cycleSummaryCard) to reduce file size and isolate this presentation block.
//
// Must never: Perform financial calculations, access state directly,
// modify any business values, or contain any business rules.

import 'package:flutter/material.dart';
import '../constants/budget_colors.dart';
import '../constants/budget_layout.dart';
import 'budget_summary_row.dart';

class BudgetCycleSummaryCard extends StatelessWidget {
  const BudgetCycleSummaryCard({
    super.key,
    required this.totalIncomeActual,
    required this.totalExpenseActual,
    required this.remainingIncome,
    required this.plannedIncome,
    required this.plannedAllocations,
    required this.plannedJars,
    required this.plannedDebts,
    required this.unallocatedAmount,
    required this.onViewAnalysis,
  });

  final double totalIncomeActual;
  final double totalExpenseActual;
  final double remainingIncome;
  final double plannedIncome;
  final double plannedAllocations;
  final double plannedJars;
  final double plannedDebts;
  final double unallocatedAmount;
  final VoidCallback onViewAnalysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final netSaving = remainingIncome.clamp(0, double.infinity).toDouble();
    final spendRatio = totalIncomeActual <= 0
        ? 0.0
        : (totalExpenseActual / totalIncomeActual).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(kBudgetRadiusCard),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'ملخص الدورة',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                // زرار تحليل الدورة
                InkWell(
                  onTap: onViewAnalysis,
                  borderRadius: BorderRadius.circular(kBudgetRadiusS),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color:
                          kBudgetIncomeGreenBright.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(kBudgetRadiusS),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_graph_rounded,
                            size: 16, color: kBudgetIncomeGreenBright),
                        const SizedBox(width: 5),
                        Text(
                          'تحليل الدورة',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: kBudgetIncomeGreenBright,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // ── Spend progress ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'المستهلك',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(spendRatio * 100).round()}٪  ·  ${totalExpenseActual.toStringAsFixed(0)}',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(kBudgetRadiusPill),
                  child: LinearProgressIndicator(
                    value: spendRatio,
                    minHeight: 8,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      spendRatio < 0.7
                          ? kBudgetIncomeGreenBright
                          : spendRatio < 0.9
                              ? kBudgetWarningYellow
                              : kBudgetDangerOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          // ── Rows ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                BudgetSummaryRow('الدخل الفعلي', totalIncomeActual),
                BudgetSummaryRow(
                  'إجمالي المصروف',
                  totalExpenseActual,
                  danger: totalExpenseActual > totalIncomeActual,
                ),
                BudgetSummaryRow(
                  'المتبقي',
                  remainingIncome,
                  danger: remainingIncome < 0,
                ),
                const Divider(height: 20),
                BudgetSummaryRow('الدخل المخطط', plannedIncome),
                BudgetSummaryRow('المخصصات', plannedAllocations),
                BudgetSummaryRow('الحصالات', plannedJars),
                BudgetSummaryRow('الالتزامات في الدورة', plannedDebts),
                const Divider(height: 20),
                BudgetSummaryRow(
                  'غير المخصص',
                  unallocatedAmount,
                  danger: unallocatedAmount < 0,
                ),
                BudgetSummaryRow('التوفير المتوقع', netSaving),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
