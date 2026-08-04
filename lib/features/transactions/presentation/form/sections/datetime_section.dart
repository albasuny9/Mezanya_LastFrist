import 'package:flutter/material.dart';

/// Date + time row. Hidden in recurring mode (recurring uses schedule-based
/// fields in RecurringSettingsSection instead).
class DateTimeSection extends StatelessWidget {
  const DateTimeSection({
    super.key,
    required this.date,
    required this.time,
    required this.onDateChanged,
    required this.onTimeChanged,
    this.onBeforeOpen,
  });

  final DateTime date;
  final TimeOfDay time;
  final void Function(DateTime) onDateChanged;
  final void Function(TimeOfDay) onTimeChanged;
  /// Called immediately before a date or time picker is opened, and again
  /// after it closes. Use to dismiss the keyboard / clear field focus.
  final VoidCallback? onBeforeOpen;

  static const _accent = Color(0xFF2F6F5E);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _pill(
          context: context,
          icon: Icons.calendar_today_rounded,
          label: 'التاريخ',
          value: _dateLabel,
          onTap: () async {
            onBeforeOpen?.call();
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2023),
              lastDate: DateTime(2100),
            );
            onBeforeOpen?.call(); // ensure focus stays dismissed after close
            if (picked != null) onDateChanged(picked);
          },
          flex: 1,
        ),
        const SizedBox(width: 8),
        _pill(
          context: context,
          icon: Icons.schedule_rounded,
          label: 'الوقت',
          value: _timeLabel,
          onTap: () async {
            onBeforeOpen?.call();
            final picked =
                await showTimePicker(context: context, initialTime: time);
            onBeforeOpen?.call(); // ensure focus stays dismissed after close
            if (picked != null) onTimeChanged(picked);
          },
          flex: 1,
        ),
      ],
    );
  }

  String get _dateLabel {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String get _timeLabel {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'ص' : 'م';
    return '$h:$m $period';
  }

  Widget _pill({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required int flex,
  }) {
    final theme = Theme.of(context);
    final border = Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
    return Expanded(
      flex: flex,
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: border,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 17, color: _accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
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
