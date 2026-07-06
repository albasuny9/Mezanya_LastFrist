// BudgetSectionEmptyCard
//
// Purpose: A tappable empty-state card shown when a budget section (allocations,
// jars, etc.) has no items. Optionally navigates when tapped.
//
// Responsibility: Pure UI — renders an empty-state container with an icon,
// text, and optional tap handler. No business logic, no calculations.
//
// Dependencies: Flutter Material.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_sectionEmptyCard) to reduce file size and isolate UI concerns.
//
// Must never: Perform calculations, access state, call Cubit methods,
// or contain any business rules.

import 'package:flutter/material.dart';

class BudgetSectionEmptyCard extends StatelessWidget {
  const BudgetSectionEmptyCard({
    super.key,
    required this.text,
    this.onTap,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.open_in_new_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
