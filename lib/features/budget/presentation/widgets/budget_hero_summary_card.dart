// BudgetHeroSummaryCard
//
// Purpose: The main hero card at the top of the budget tracking screen,
// displaying the remaining income with a health-based gradient and an
// embedded bar chart comparing income and expense.
//
// Responsibility: Pure UI — renders the gradient card, background icons,
// remaining income amount, and the BudgetHeroBarChart. No business logic.
//
// Dependencies: Flutter Material, BudgetHeroBarChart.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_heroSummaryCard) to reduce file size and isolate this presentation section.
//
// Must never: Perform business calculations, access state, call Cubit methods,
// modify financial values, or contain any business rules.

import 'package:flutter/material.dart';
import 'budget_hero_bar_chart.dart';

class BudgetHeroSummaryCard extends StatelessWidget {
  const BudgetHeroSummaryCard({
    super.key,
    required this.totalIncomeActual,
    required this.totalExpenseActual,
    required this.remainingIncome,
    required this.plannedIncome,
  });

  final double totalIncomeActual;
  final double totalExpenseActual;
  final double remainingIncome;
  final double plannedIncome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // نسبة الصحة المالية: 1.0 = كل الدخل متبقٍ، 0.0 = خلصت الفلوس، سالب = عجز
    final healthRatio = totalIncomeActual <= 0
        ? 1.0
        : (remainingIncome / totalIncomeActual).clamp(-0.5, 1.0);

    // Green (Olive)
    const cGreen1 = Color(0xFF2F5D50);
    const cGreen2 = Color(0xFF4E7A69);
    const cGreen3 = Color(0xFF93B59D);

    // Amber
    const cYellow1 = Color(0xFF8A6C2E);
    const cYellow2 = Color(0xFFB08B3F);
    const cYellow3 = Color(0xFFD9BF78);

    // Terracotta
    const cRed1 = Color(0xFF7A4A3A);
    const cRed2 = Color(0xFFA8654D);
    const cRed3 = Color(0xFFD19478);

    Color g1, g2, g3, shadow;
    if (healthRatio <= 0.0) {
      g1 = cRed1;
      g2 = cRed2;
      g3 = cRed3;
      shadow = cRed1;
    } else if (healthRatio < 0.35) {
      final t = healthRatio / 0.35;
      g1 = Color.lerp(cRed1, cYellow1, t)!;
      g2 = Color.lerp(cRed2, cYellow2, t)!;
      g3 = Color.lerp(cRed3, cYellow3, t)!;
      shadow = g1;
    } else if (healthRatio < 0.65) {
      final t = (healthRatio - 0.35) / 0.30;
      g1 = Color.lerp(cYellow1, cGreen1, t)!;
      g2 = Color.lerp(cYellow2, cGreen2, t)!;
      g3 = Color.lerp(cYellow3, cGreen3, t)!;
      shadow = g1;
    } else {
      g1 = cGreen1;
      g2 = cGreen2;
      g3 = cGreen3;
      shadow = cGreen1;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [g1, g2, g3],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: shadow.withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: 5,
            end: 10,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 92,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          PositionedDirectional(
            bottom: -18,
            end: 4,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 82,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الباقي من الدخل ',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.96),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                remainingIncome.toStringAsFixed(2),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              BudgetHeroBarChart(
                income: totalIncomeActual,
                expense: totalExpenseActual,
                plannedIncome: plannedIncome,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
