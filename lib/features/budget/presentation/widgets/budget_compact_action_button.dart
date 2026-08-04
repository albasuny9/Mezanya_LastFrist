// BudgetCompactActionButton
//
// Purpose: A compact-sized action button used inside budget entity tiles for
// quick actions such as recording income, paying debts, or postponing.
//
// Responsibility: Pure UI — renders either a FilledButton or an OutlinedButton
// with compact sizing and an optional accent color.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_compactActionButton) to reduce file size and isolate button presentation.
//
// Must never: Perform calculations, access state, call Cubit methods directly,
// or contain any business rules.

import 'package:flutter/material.dart';

class BudgetCompactActionButton extends StatelessWidget {
  const BudgetCompactActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              minimumSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              side: color != null ? BorderSide(color: color!) : null,
              minimumSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: Text(label),
          );
  }
}
