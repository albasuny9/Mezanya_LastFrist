import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum PostponeChoice {
  skip,
  tomorrow,
  threeDays,
  custom,
}

class RecurringPostponeDialog extends StatelessWidget {
  const RecurringPostponeDialog({
    super.key,
    required this.name,
    required this.amount,
    required this.kindLabel,
    required this.occurrence,
    required this.allowSkip,
  });

  final String name;
  final double amount;
  final String kindLabel;
  final DateTime occurrence;
  final bool allowSkip;

  static Future<dynamic> show(
    BuildContext context, {
    required String name,
    required double amount,
    required String kindLabel,
    required DateTime occurrence,
    required bool allowSkip,
  }) {
    return showDialog<dynamic>(
      context: context,
      builder: (context) => RecurringPostponeDialog(
        name: name,
        amount: amount,
        kindLabel: kindLabel,
        occurrence: occurrence,
        allowSkip: allowSkip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = const Color(0xFF9B6B2F);
    final amountLabel = amount <= 0 ? 'مجاني' : amount.toStringAsFixed(2);
    final now = DateTime.now();

    DateTime atMorning(DateTime date) =>
        DateTime(date.year, date.month, date.day, 9);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: const Text(
        'تأجيل معاملة متكررة',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Transaction Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kindLabel,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 5),
                      Text(
                        'استحقاق ${DateFormat('d MMMM yyyy', 'ar').format(occurrence)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.payments_rounded, size: 14, color: accent),
                      const SizedBox(width: 5),
                      Text(
                        'المبلغ: $amountLabel',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'اختر موعداً جديداً للتذكير:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),

            if (allowSkip)
              _OptionTile(
                icon: Icons.skip_next_rounded,
                label: 'تخطي هذه المرة',
                subtitle: 'اعتبارها منتهية والانتقال للدورة التالية',
                accent: Colors.blueGrey,
                onTap: () => Navigator.pop(context, PostponeChoice.skip),
              ),
            _OptionTile(
              icon: Icons.today_rounded,
              label: 'تأجيل حتى الغد',
              subtitle: 'سأقوم بالدفع صباح الغد',
              accent: accent,
              onTap: () => Navigator.pop(
                  context, atMorning(now.add(const Duration(days: 1)))),
            ),
            _OptionTile(
              icon: Icons.event_repeat_rounded,
              label: 'تأجيل 3 أيام',
              subtitle: 'ذكرني لاحقاً في منتصف الأسبوع',
              accent: accent,
              onTap: () => Navigator.pop(
                  context, atMorning(now.add(const Duration(days: 3)))),
            ),
            _OptionTile(
              icon: Icons.edit_calendar_rounded,
              label: 'تحديد تاريخ مخصص',
              subtitle: 'اختيار يوم محدد من التقويم',
              accent: colorScheme.primary,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: now.add(const Duration(days: 1)),
                  firstDate: now.add(const Duration(days: 1)),
                  lastDate: DateTime(now.year + 1, now.month, now.day),
                );
                if (picked != null && context.mounted) {
                  Navigator.pop(context, atMorning(picked));
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
