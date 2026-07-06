// BudgetSectionCurtainBody
//
// Purpose: A styled container that wraps a list of child widgets inside an
// expandable section card, providing the inner body appearance.
//
// Responsibility: Pure UI — applies background, border-radius, and border to
// a Column of children. No business logic, no calculations, no side effects.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_sectionCurtainBody) to reduce file size and isolate presentation.
//
// Must never: Perform calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';
import '../constants/budget_layout.dart';

class BudgetSectionCurtainBody extends StatelessWidget {
  const BudgetSectionCurtainBody({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(kBudgetRadiusCard),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.32),
        ),
      ),
      child: Column(children: children),
    );
  }
}
