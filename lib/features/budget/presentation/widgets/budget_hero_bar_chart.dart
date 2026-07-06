// BudgetHeroBarChart
//
// Purpose: A compact dual-bar chart embedded inside the hero summary card,
// showing the income and expense bars relative to the planned income scale.
//
// Responsibility: Pure UI — renders two progress tracks (income and expense)
// with segment colors indicating planned vs actual. No business logic.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_heroBarChart) to isolate this visual component and reduce file size.
//
// Must never: Perform calculations beyond local display ratios already passed
// in, access state, call Cubit methods, or contain any business rules.

import 'package:flutter/material.dart';

class BudgetHeroBarChart extends StatelessWidget {
  const BudgetHeroBarChart({
    super.key,
    required this.income,
    required this.expense,
    required this.plannedIncome,
  });

  final double income;
  final double expense;
  final double plannedIncome;

  @override
  Widget build(BuildContext context) {
    // المقياس المشترك للشريطين = أكبر قيمة بين الدخل المخطط والدخل الفعلي
    final scale = income > plannedIncome ? income : plannedIncome;

    double normalIncomeRatio = 0.0;
    double excessIncomeRatio = 0.0;
    if (scale > 0) {
      final withinPlan = income < plannedIncome ? income : plannedIncome;
      normalIncomeRatio = withinPlan / scale;
      if (income > plannedIncome) {
        excessIncomeRatio = (income - plannedIncome) / scale;
      }
    }

    final expenseRatio = scale > 0
        ? (expense / scale).clamp(0.0, 1.0)
        : (expense > 0 ? 1.0 : 0.0);

    Widget track({
      required List<(double, Color)> segments,
      required double amount,
      required String label,
    }) {
      final totalRatio =
          segments.fold<double>(0.0, (s, seg) => s + seg.$1).clamp(0.0, 1.0);

      return Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (totalRatio > 0)
                  FractionallySizedBox(
                    widthFactor: totalRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Row(
                        children: segments
                            .where((seg) => seg.$1 > 0)
                            .map(
                              (seg) => Expanded(
                                flex:
                                    (seg.$1 * 1000).round().clamp(1, 1000),
                                child: Container(
                                  height: 10,
                                  color: seg.$2,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount.toStringAsFixed(0),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          track(
            label: 'الدخل',
            amount: income,
            segments: [
              (
                normalIncomeRatio,
                const Color(0xFF4ADE80),
              ), // أخضر عادي = حتى الدخل المخطط
              (
                excessIncomeRatio,
                const Color(0xFF15803D),
              ), // أخضر غامق = الزيادة عن المخطط
            ],
          ),
          const SizedBox(height: 8),
          track(
            label: 'المصروف',
            amount: expense,
            segments: [
              (expenseRatio, const Color(0xFFF87171)),
            ],
          ),
        ],
      ),
    );
  }
}
