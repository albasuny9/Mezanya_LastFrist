import 'package:flutter/material.dart';

import '../transaction_form_controller.dart';

/// قسم الجدولة الخالص — نمط التكرار وتفاصيله (يوم/أسبوع/وقت)، طريقة
/// التنفيذ، والتذكير. مُستخرَج من `RecurringSettingsSection` (كانت تخلط
/// الجدولة مع حقول الهوية: الاسم والأيقونة) ليصبح قابلاً لإعادة الاستخدام
/// في أي شاشة تحتاج جدولة تكرار فقط — مثل `IncomeSourceEditorScreen`.
///
/// لا تغيير في المنطق أو السلوك عن النسخة الأصلية داخل
/// `RecurringSettingsSection` — نقل حرفي.
class SchedulingSection extends StatelessWidget {
  const SchedulingSection({
    super.key,
    required this.ctrl,
    required this.onChanged,
  });

  final TransactionFormController ctrl;

  /// يُستدعى بعد أي تعديل على [ctrl] لإجبار الشاشة الأم على إعادة البناء.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!ctrl.showRecurrenceDetails) {
      return _surfaceSection(
        theme: theme,
        child: const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline_rounded),
          title: Text('دخل متغير'),
          subtitle:
              Text('سيتم تسجيله يدويًا فقط بدون تاريخ أو تكرار ثابت'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: ctrl.recurrencePattern,
          decoration: const InputDecoration(
            labelText: 'نوع التكرار',
            prefixIcon: Icon(Icons.repeat_rounded),
          ),
          items: const [
            DropdownMenuItem(value: 'daily', child: Text('يومي')),
            DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
            DropdownMenuItem(value: 'biweekly', child: Text('كل أسبوعين')),
            DropdownMenuItem(
                value: 'every3weeks', child: Text('كل 3 أسابيع')),
            DropdownMenuItem(value: 'monthly', child: Text('شهري')),
            DropdownMenuItem(value: 'every2months', child: Text('كل شهرين')),
            DropdownMenuItem(
                value: 'every3months', child: Text('كل 3 شهور')),
            DropdownMenuItem(
                value: 'every6months', child: Text('كل 6 شهور')),
            DropdownMenuItem(value: 'yearly', child: Text('سنوي')),
          ],
          onChanged: (v) {
            if (v != null) {
              ctrl.recurrencePattern = v;
              onChanged();
            }
          },
        ),
        const SizedBox(height: 12),
        _recurrenceDetails(context, theme),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: ctrl.executionType,
          decoration: const InputDecoration(
            labelText: 'طريقة التنفيذ',
            prefixIcon: Icon(Icons.bolt_rounded),
          ),
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('تلقائي')),
            DropdownMenuItem(value: 'confirm', child: Text('يحتاج تأكيد')),
          ],
          onChanged: (v) {
            if (v != null) {
              ctrl.executionType = v;
              onChanged();
            }
          },
        ),
        if (ctrl.executionType == 'confirm') ...[
          const SizedBox(height: 12),
          _reminderDropdown(theme),
        ],
      ],
    );
  }

  Widget _recurrenceDetails(BuildContext context, ThemeData theme) {
    if (ctrl.recurrencePattern == 'daily') {
      return _timeTile(context, theme);
    }
    if (ctrl.isWeekPattern) {
      return Column(children: [
        _weekdayPicker(theme),
        const SizedBox(height: 12),
        _timeTile(context, theme),
      ]);
    }
    if (ctrl.isMonthPattern) {
      return Column(children: [
        _DayPickerTile(
          label: 'اليوم الشهري',
          selectedDay: ctrl.monthlyDay,
          onDaySelected: (day) {
            ctrl.monthlyDay = day;
            onChanged();
          },
        ),
        const SizedBox(height: 12),
        _timeTile(context, theme),
      ]);
    }
    if (ctrl.recurrencePattern == 'yearly') {
      return Column(children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: ctrl.yearlyMonth,
              decoration: const InputDecoration(
                labelText: 'الشهر',
                prefixIcon: Icon(Icons.date_range_rounded),
              ),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(
                    value: i + 1, child: Text(_monthLabel(i + 1))),
              ),
              onChanged: (v) {
                if (v != null) {
                  ctrl.yearlyMonth = v;
                  onChanged();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DayPickerTile(
              label: 'اليوم',
              selectedDay: ctrl.yearlyDay,
              onDaySelected: (day) {
                ctrl.yearlyDay = day;
                onChanged();
              },
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _timeTile(context, theme),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _weekdayPicker(ThemeData theme) {
    return _surfaceSection(
      theme: theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أيام التكرار',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final weekday = index + 1;
              return FilterChip(
                selected: ctrl.selectedWeekdays.contains(weekday),
                label: Text(_weekdayLabel(weekday)),
                onSelected: (selected) {
                  if (selected) {
                    ctrl.selectedWeekdays.add(weekday);
                  } else {
                    ctrl.selectedWeekdays.remove(weekday);
                  }
                  onChanged();
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _timeTile(BuildContext context, ThemeData theme) {
    final label = TransactionFormController.formatTime(ctrl.scheduledTime);
    return _surfaceSection(
      theme: theme,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_rounded),
        title: const Text('الوقت'),
        subtitle: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final picked = await showTimePicker(
              context: context, initialTime: ctrl.scheduledTime);
          if (picked != null) {
            ctrl.scheduledTime = picked;
            onChanged();
          }
        },
      ),
    );
  }

  Widget _reminderDropdown(ThemeData theme) {
    return DropdownButtonFormField<int>(
      value: ctrl.reminderLeadDays,
      decoration: const InputDecoration(
        labelText: 'وقت الإشعار',
        prefixIcon: Icon(Icons.notifications_active_rounded),
      ),
      items: (ctrl.recurrencePattern == 'daily' || ctrl.isWeekPattern)
          ? const [
              DropdownMenuItem(value: 0, child: Text('في الوقت المحدد')),
              DropdownMenuItem(value: 1, child: Text('قبلها بساعة')),
              DropdownMenuItem(value: 2, child: Text('قبلها بساعتين')),
              DropdownMenuItem(value: 3, child: Text('قبلها بـ 3 ساعات')),
            ]
          : const [
              DropdownMenuItem(value: 0, child: Text('في نفس اليوم')),
              DropdownMenuItem(value: 1, child: Text('مبكر بيوم')),
              DropdownMenuItem(value: 2, child: Text('مبكر بيومين')),
              DropdownMenuItem(value: 3, child: Text('مبكر بـ 3 أيام')),
            ],
      onChanged: (v) {
        if (v != null) {
          ctrl.reminderLeadDays = v;
          onChanged();
        }
      },
    );
  }

  Widget _surfaceSection(
      {required ThemeData theme, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
  }

  static String _weekdayLabel(int weekday) {
    const labels = [
      'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
      'الجمعة', 'السبت', 'الأحد',
    ];
    return labels[(weekday - 1).clamp(0, 6)];
  }

  static String _monthLabel(int month) {
    const labels = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return labels[month - 1];
  }
}

// ── Day-of-month picker tile ───────────────────────────────────────────────
class _DayPickerTile extends StatelessWidget {
  const _DayPickerTile({
    this.label,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final String? label;
  final int selectedDay;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: () => _showDaySheet(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 20, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'اليوم $selectedDay من كل شهر',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(Icons.unfold_more_rounded,
                    size: 20, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDaySheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'اختر اليوم الشهري',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: 28,
              itemBuilder: (_, index) {
                final day = index + 1;
                final isSelected = day == selectedDay;
                return GestureDetector(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onDaySelected(day);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant
                                .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
