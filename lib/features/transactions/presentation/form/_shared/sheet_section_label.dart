import 'package:flutter/material.dart';

/// Divider with a centred label used in bottom-sheet pickers.
class SheetSectionLabel extends StatelessWidget {
  const SheetSectionLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
            child: Divider(color: theme.colorScheme.outlineVariant)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: Divider(color: theme.colorScheme.outlineVariant)),
      ],
    );
  }
}
