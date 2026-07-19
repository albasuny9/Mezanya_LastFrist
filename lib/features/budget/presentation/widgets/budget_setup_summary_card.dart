import 'package:flutter/material.dart';

class BudgetSetupSummaryCard extends StatelessWidget {
  const BudgetSetupSummaryCard({
    super.key,
    required this.totalIncome,
    required this.committed,
    required this.allocationsTotal,
    required this.linkedTotal,
    required this.installmentsTotal,
    required this.subscriptionsTotal,
    required this.unallocated,
    required this.approxSavingsHint,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final double totalIncome;
  final double committed;
  final double allocationsTotal;
  final double linkedTotal;
  final double installmentsTotal;
  final double subscriptionsTotal;
  final double unallocated;
  final double approxSavingsHint;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF0E5A47);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E5A47), Color(0xFF197C64)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.summarize_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ملخص الخطة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PlanDistributionBar(
            totalIncome: totalIncome,
            committed: committed,
            allocationsTotal: allocationsTotal,
            linkedTotal: linkedTotal,
            installmentsTotal: installmentsTotal,
            subscriptionsTotal: subscriptionsTotal,
            unallocated: unallocated,
          ),
          const SizedBox(height: 14),
          Divider(
            height: 20,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'متوقع التوفير',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '10٪',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            approxSavingsHint.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          _ExpandableSummaryTable(
            totalIncome: totalIncome,
            committed: committed,
            allocationsTotal: allocationsTotal,
            linkedTotal: linkedTotal,
            installmentsTotal: installmentsTotal,
            subscriptionsTotal: subscriptionsTotal,
            unallocated: unallocated,
            isExpanded: isExpanded,
            onToggleExpanded: onToggleExpanded,
          ),
        ],
      ),
    );
  }
}

class _PlanDistributionBar extends StatelessWidget {
  const _PlanDistributionBar({
    required this.totalIncome,
    required this.committed,
    required this.allocationsTotal,
    required this.linkedTotal,
    required this.installmentsTotal,
    required this.subscriptionsTotal,
    required this.unallocated,
  });

  final double totalIncome;
  final double committed;
  final double allocationsTotal;
  final double linkedTotal;
  final double installmentsTotal;
  final double subscriptionsTotal;
  final double unallocated;

  @override
  Widget build(BuildContext context) {
    final freeSpace = unallocated > 0 ? unallocated : 0.0;
    final overage = unallocated < 0 ? -unallocated : 0.0;
    final scale = totalIncome > committed ? totalIncome : committed;

    final segments = <(double, Color, String)>[
      if (allocationsTotal > 0)
        (allocationsTotal, Colors.white.withValues(alpha: 0.92), 'المخصصات'),
      if (linkedTotal > 0) (linkedTotal, const Color(0xFFFCD34D), 'الحصالات'),
      if (installmentsTotal > 0)
        (installmentsTotal, const Color(0xFFF87171), 'الأقساط'),
      if (subscriptionsTotal > 0)
        (subscriptionsTotal, const Color(0xFFC4B5FD), 'الاشتراكات'),
      if (freeSpace > 0)
        (freeSpace, Colors.white.withValues(alpha: 0.18), 'غير مخصص'),
      if (overage > 0) (overage, const Color(0xFFDC2626), 'تجاوز الميزانية'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 14,
            color: Colors.white.withValues(alpha: 0.14),
            child: scale <= 0 || segments.isEmpty
                ? null
                : Row(
                    children: segments
                        .map(
                          (seg) => Expanded(
                            flex: ((seg.$1 / scale) * 1000)
                                .round()
                                .clamp(1, 1000),
                            child: Container(color: seg.$2),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        if (segments.isEmpty)
          Text(
            'لسه مفيش دخل أو مخصصات مضافة.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: segments
                .map(
                  (seg) => _PlanLegendChip(
                    color: seg.$2,
                    label: seg.$3,
                    value: seg.$1,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _PlanLegendChip extends StatelessWidget {
  const _PlanLegendChip({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label  ${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ExpandableSummaryTable extends StatelessWidget {
  const _ExpandableSummaryTable({
    required this.totalIncome,
    required this.committed,
    required this.allocationsTotal,
    required this.linkedTotal,
    required this.installmentsTotal,
    required this.subscriptionsTotal,
    required this.unallocated,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  final double totalIncome;
  final double committed;
  final double allocationsTotal;
  final double linkedTotal;
  final double installmentsTotal;
  final double subscriptionsTotal;
  final double unallocated;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onToggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'عرض التفاصيل بالأرقام',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: !isExpanded
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'إجمالي الدخل',
                        value: totalIncome,
                        light: true,
                      ),
                      _SummaryRow(
                        label: 'إجمالي المخصص',
                        value: committed,
                        light: true,
                      ),
                      _SummaryRow(
                        label: 'المخصصات',
                        value: allocationsTotal,
                        light: true,
                      ),
                      _SummaryRow(
                        label: 'الحصالات',
                        value: linkedTotal,
                        light: true,
                      ),
                      _SummaryRow(
                        label: 'الديون والأقساط',
                        value: installmentsTotal,
                        light: true,
                      ),
                      _SummaryRow(
                        label: 'الاشتراكات',
                        value: subscriptionsTotal,
                        light: true,
                      ),
                      _SummaryRow(
                        label: 'غير المخصص',
                        value: unallocated,
                        light: true,
                        emphasize: unallocated < 0,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.light,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool light;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: light
                    ? Colors.white.withValues(alpha: 0.92)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(
              color: emphasize
                  ? const Color(0xFFFFD180)
                  : (light
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
