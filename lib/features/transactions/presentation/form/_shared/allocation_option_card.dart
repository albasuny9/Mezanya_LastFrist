import 'package:flutter/material.dart';

/// Tappable container used in allocation and income-target picker sheets.
class AllocationOptionCard extends StatelessWidget {
  const AllocationOptionCard({
    super.key,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? const Color(0xFF1E7F5C).withValues(alpha: 0.07)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1E7F5C).withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant
                      .withValues(alpha: 0.55),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
