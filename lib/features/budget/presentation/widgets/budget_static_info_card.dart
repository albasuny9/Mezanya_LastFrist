// BudgetStaticInfoCard
//
// Purpose: A simple read-only information card displayed inside budget sections
// to communicate an empty state or static message to the user.
//
// Responsibility: Pure UI — renders a styled container with a text message.
// No business logic, no calculations, no side effects.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart to reduce
// file size and separate UI presentation from orchestration logic.
//
// Must never: Perform calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';
import '../constants/budget_layout.dart';

class BudgetStaticInfoCard extends StatelessWidget {
  const BudgetStaticInfoCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(kBudgetRadiusXL),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
