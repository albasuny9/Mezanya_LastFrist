// BudgetSetupPromptCard
//
// Purpose: A call-to-action card prompting the user to set up their budget
// for the current or a future cycle when no budget plan exists yet.
//
// Responsibility: Pure UI — renders an icon, title, description, and a
// FilledButton. Navigation is triggered via the [onSetup] callback passed by
// the screen. No business logic, no calculations, no side effects.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_budgetSetupPromptCard) to reduce file size and isolate UI presentation.
//
// Must never: Perform calculations, access state, call Cubit methods directly,
// or contain any business rules.

import 'package:flutter/material.dart';
import '../constants/budget_colors.dart';
import '../constants/budget_layout.dart';

class BudgetSetupPromptCard extends StatelessWidget {
  const BudgetSetupPromptCard({
    super.key,
    required this.futureMonth,
    required this.isPastMonth,
    required this.onSetup,
  });

  final bool futureMonth;
  final bool isPastMonth;
  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(kBudgetRadiusSetupCard),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kBudgetSetupGradientLight, kBudgetSetupGradientDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(kBudgetRadiusCard),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              size: 42,
              color: kBudgetDefaultAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            futureMonth
                ? 'خطط لهذا الشهر بشكل مسبق'
                : 'ابدأ إعداد الميزانية الشهرية',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            futureMonth
                ? 'هذا الشهر لم يبدأ بعد. يمكنك تجهيز خطته الآن، لكنها لن تتحول إلى عرض الميزانية والمعاملات إلا عندما يبدأ الشهر فعليًا.'
                : 'أضف أي عنصر في الخطة مثل دخل أو مخصص أو حصالة أو التزام، وبعدها ستظهر لك شاشة متابعة الميزانية هنا.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: isPastMonth ? null : onSetup,
            icon: const Icon(Icons.tune_rounded),
            label: Text(
              futureMonth
                  ? 'إعداد هذا الشهر مسبقًا'
                  : 'إعداد الميزانية الشهرية',
            ),
          ),
        ],
      ),
    );
  }
}
