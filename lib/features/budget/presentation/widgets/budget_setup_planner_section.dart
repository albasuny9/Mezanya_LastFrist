import 'package:flutter/material.dart';

class BudgetSetupPlannerSection extends StatelessWidget {
  const BudgetSetupPlannerSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.actionLabel,
    required this.onAction,
    required this.children,
    this.showHeaderAction = true,
    this.footerAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String actionLabel;
  final VoidCallback onAction;
  final List<Widget> children;
  final bool showHeaderAction;
  final Widget? footerAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showHeaderAction) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ),
            const SizedBox(height: 14),
          ],
          ...children,
          if (footerAction != null) ...[
            const SizedBox(height: 10),
            footerAction!,
          ],
        ],
      ),
    );
  }
}

class BudgetSetupThinAddButton extends StatelessWidget {
  const BudgetSetupThinAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.tint,
  });

  final String label;
  final VoidCallback onPressed;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.add_rounded, color: tint, size: 18),
        label: Text(
          label,
          style: TextStyle(
            color: tint,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(42),
          side: BorderSide(color: tint.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
