import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import 'budget_start_day_picker_tile.dart';

class BudgetSetupHeaderCard extends StatelessWidget {
  const BudgetSetupHeaderCard({
    super.key,
    required this.isFutureMonthSetup,
    required this.heading,
    required this.subheading,
  });

  final bool isFutureMonthSetup;
  final String heading;
  final String subheading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: isFutureMonthSetup
            ? const Color(0xFFFFF4E8)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isFutureMonthSetup
              ? const Color(0xFFE6B36A)
              : colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isFutureMonthSetup
                  ? const Color(0xFFF3D4A4)
                  : const Color(0xFFDDEFEA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isFutureMonthSetup
                  ? Icons.schedule_rounded
                  : Icons.calendar_month_rounded,
              color: isFutureMonthSetup
                  ? const Color(0xFF9A5A11)
                  : const Color(0xFF0E5A47),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subheading,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetSetupUnallocatedCard extends StatelessWidget {
  const BudgetSetupUnallocatedCard({
    super.key,
    required this.unallocated,
    required this.totalIncome,
    required this.committed,
  });

  final double unallocated;
  final double totalIncome;
  final double committed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: unallocated >= 0
              ? const [Color(0xFF0E5A47), Color(0xFF197C64)]
              : const [Color(0xFF8F3E2A), Color(0xFFBE5A35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'غير المخصص',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            unallocated.toStringAsFixed(2),
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryMini(
                  label: 'إجمالي الدخل',
                  value: totalIncome,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMini(
                  label: 'إجمالي المخصص',
                  value: committed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class BudgetSetupCycleSettingsCard extends StatelessWidget {
  const BudgetSetupCycleSettingsCard({
    super.key,
    required this.startDay,
    required this.cycleMode,
    required this.bufferEndBehavior,
    required this.onStartDaySelected,
    required this.onCycleModeChanged,
    required this.onBufferEndBehaviorChanged,
  });

  final int startDay;
  final String cycleMode;
  final String bufferEndBehavior;
  final Future<void> Function(int day) onStartDaySelected;
  final ValueChanged<String> onCycleModeChanged;
  final ValueChanged<String> onBufferEndBehaviorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إعداد الدورة',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'حدد يوم بداية الدورة وطريقة تجديد الخطة ونهاية المبلغ غير المخصص.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          BudgetStartDayPickerTile(
            selectedDay: startDay,
            onDaySelected: onStartDaySelected,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: cycleMode,
            decoration: const InputDecoration(
              labelText: 'تجديد الخطة',
              prefixIcon: Icon(Icons.autorenew_rounded),
            ),
            items: [
              DropdownMenuItem(
                value: AutomationType.auto.value,
                child: const Text('تلقائي'),
              ),
              DropdownMenuItem(
                value: AutomationType.confirm.value,
                child: const Text('بعد التأكيد'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onCycleModeChanged(value);
              }
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: bufferEndBehavior,
            decoration: const InputDecoration(
              labelText: 'المبلغ غير المخصص آخر الدورة',
              prefixIcon: Icon(Icons.monetization_on_rounded),
            ),
            items: [
              DropdownMenuItem(
                value: RolloverBehavior.toSavings.value,
                child: const Text('يتحول للتوفير'),
              ),
              DropdownMenuItem(
                value: RolloverBehavior.keep.value,
                child: const Text('يبقى للدورة الجديدة'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onBufferEndBehaviorChanged(value);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryMini extends StatelessWidget {
  const _SummaryMini({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
