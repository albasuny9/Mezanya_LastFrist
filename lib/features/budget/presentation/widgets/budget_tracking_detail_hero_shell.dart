// BudgetTrackingDetailHeroShell
//
// Purpose: A styled container used as the hero section inside tracking detail
// bottom sheets (income, allocation, debt, subscription, lent). Provides the
// tinted background and an optional edit button.
//
// Responsibility: Pure UI — wraps children in a styled Container with an
// optional settings button. Navigation or editing is triggered via [onEdit].
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_trackingDetailHeroShell) to reduce file size and isolate UI presentation.
//
// Must never: Perform calculations, access state, call Cubit methods directly,
// or contain any business rules.

import 'package:flutter/material.dart';
import '../constants/budget_layout.dart';

class BudgetTrackingDetailHeroShell extends StatelessWidget {
  const BudgetTrackingDetailHeroShell({
    super.key,
    required this.accent,
    required this.children,
    this.onEdit,
    this.strongTint = false,
  });

  final Color accent;
  final List<Widget> children;
  final VoidCallback? onEdit;
  final bool strongTint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: strongTint ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(kBudgetRadiusCard),
        border: Border.all(
          color: accent.withValues(alpha: strongTint ? 0.45 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onEdit != null)
            Align(
              alignment: Alignment.topLeft,
              child: IconButton.filledTonal(
                onPressed: onEdit,
                tooltip: 'تعديل',
                icon: const Icon(Icons.settings_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.72),
                  foregroundColor: accent,
                ),
              ),
            ),
          if (onEdit != null) const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
