// BudgetSectionTitle
//
// Purpose: A styled section header row with a colored label and a divider line,
// used to visually separate content sections in the budget tracking screen.
//
// Responsibility: Pure UI — renders a pill-shaped label followed by a thin
// horizontal line. No business logic, no calculations, no side effects.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart (_sectionTitle)
// to reduce file size and isolate presentation from orchestration.
//
// Must never: Perform calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';

class BudgetSectionTitle extends StatelessWidget {
  const BudgetSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF165B47);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: accent.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}
