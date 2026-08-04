import 'package:flutter/material.dart';

enum DistributionPostponeChoice {
  oneDay,
  threeDays,
  skip,
}

Future<DistributionPostponeChoice?> showDistributionPostponeSheet(
  BuildContext context,
) {
  return showModalBottomSheet<DistributionPostponeChoice>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'اختر إجراء التأجيل',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _PostponeOptionTile(
                icon: Icons.today_rounded,
                label: 'تأجيل يوم',
                onTap: () =>
                    Navigator.pop(context, DistributionPostponeChoice.oneDay),
              ),
              _PostponeOptionTile(
                icon: Icons.event_repeat_rounded,
                label: 'تأجيل 3 أيام',
                onTap: () =>
                    Navigator.pop(context, DistributionPostponeChoice.threeDays),
              ),
              _PostponeOptionTile(
                icon: Icons.skip_next_rounded,
                label: 'تخطي',
                onTap: () =>
                    Navigator.pop(context, DistributionPostponeChoice.skip),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _PostponeOptionTile extends StatelessWidget {
  const _PostponeOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.onSurface),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  textDirection: TextDirection.ltr,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
