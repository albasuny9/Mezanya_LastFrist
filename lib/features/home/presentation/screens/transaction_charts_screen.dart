import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class TransactionChartsScreen extends StatefulWidget {
  const TransactionChartsScreen({
    super.key,
    required this.cubit,
    required this.allTransactions,
    required this.initialMonth,
  });

  final AppCubit cubit;
  final List<TransactionEntity> allTransactions;
  final DateTime initialMonth;

  @override
  State<TransactionChartsScreen> createState() =>
      _TransactionChartsScreenState();
}

class _TransactionChartsScreenState extends State<TransactionChartsScreen> {
  late DateTime _month;

  static const _beige = Color(0xFFFFFBF1);

  bool _isJarTx(TransactionEntity t) =>
      t.transferType == TransferType.jarAllocation.value ||
      t.transferType == TransferType.jarAllocationCancel.value ||
      t.transferType == TransferType.jarAllocationSpend.value;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  List<TransactionEntity> get _monthTx => widget.allTransactions
      .where((t) =>
          !_isJarTx(t) &&
          t.createdAt.year == _month.year &&
          t.createdAt.month == _month.month)
      .toList();

  List<TransactionEntity> get _allClean =>
      widget.allTransactions.where((t) => !_isJarTx(t)).toList();

  String get _monthLabel => DateFormat('MMMM yyyy', 'ar').format(_month);

  @override
  Widget build(BuildContext context) {
    final categories = widget.cubit.state.categories;
    final monthTx = _monthTx;
    final allTx = _allClean;

    final netIncome = monthTx
        .where((t) => t.type == TransactionType.income.value)
        .fold<double>(0, (s, t) => s + t.amount);
    final netExpense = monthTx
        .where((t) => t.type == TransactionType.expense.value)
        .fold<double>(0, (s, t) => s + t.amount);
    final netSaving = netIncome - netExpense;

    double savingRate = 0.0;
    if (netIncome > 0 && netIncome.isFinite && netSaving.isFinite) {
      savingRate = (netSaving / netIncome).clamp(0.0, 1.0);
    }

    return Scaffold(
      backgroundColor: _beige,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top period bar ──────────────────────────────────────────
            _ChartsPeriodBar(
              label: _monthLabel,
              onPrev: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1)),
              onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1)),
            ),

            // ── Scrollable charts ───────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // ── Summary KPIs ──────────────────────────────────────
                  _KpiRow(
                    netIncome: netIncome,
                    netExpense: netExpense,
                    netSaving: netSaving,
                    txCount: monthTx.length,
                  ),
                  const SizedBox(height: 14),

                  // ── Saving rate gauge ─────────────────────────────────
                  _ChartCard(
                    title: 'نسبة التوفير',
                    subtitle: 'من الدخل الكلي هذا الشهر',
                    child: _SavingRateGauge(
                        savingRate: savingRate, saving: netSaving),
                  ),
                  const SizedBox(height: 14),

                  // ── Daily income vs expense bars ──────────────────────
                  _ChartCard(
                    title: 'التدفق اليومي',
                    subtitle: 'دخل ومصروف يوم بيوم',
                    child: _DailyBarsChart(monthTx: monthTx, month: _month),
                  ),
                  const SizedBox(height: 14),

                  // ── Category breakdown ────────────────────────────────
                  _ChartCard(
                    title: 'توزيع المصروف',
                    subtitle: 'حسب الفئة',
                    child: _CategoryBreakdown(
                        monthTx: monthTx, categories: categories),
                  ),
                  const SizedBox(height: 14),

                  // ── Monthly trend (last 6 months) ─────────────────────
                  _ChartCard(
                    title: 'الاتجاه الشهري',
                    subtitle: 'آخر 6 شهور — دخل ومصروف',
                    child:
                        _MonthlyTrendChart(allTx: allTx, currentMonth: _month),
                  ),
                  const SizedBox(height: 14),

                  // ── Day of week pattern ───────────────────────────────
                  _ChartCard(
                    title: 'أيام الإنفاق',
                    subtitle: 'المصروف حسب أيام الأسبوع',
                    child: _DayOfWeekChart(monthTx: monthTx),
                  ),
                  const SizedBox(height: 14),

                  // ── Income sources breakdown ──────────────────────────
                  _ChartCard(
                    title: 'مصادر الدخل',
                    subtitle: 'تفاصيل الإيرادات',
                    child: _IncomeBreakdown(
                        monthTx: monthTx, categories: categories),
                  ),
                  const SizedBox(height: 14),

                  // ── Top spending days ─────────────────────────────────
                  _ChartCard(
                    title: 'أعلى أيام إنفاقاً',
                    subtitle: 'أكثر 5 أيام مصروفاً',
                    child: _TopSpendingDays(monthTx: monthTx),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Charts Period Bar ────────────────────────────────────────────────────────

class _ChartsPeriodBar extends StatelessWidget {
  const _ChartsPeriodBar({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFFBF1),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: const Color(0xFF165b47),
          ),

          // Prev arrow
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_right_rounded, size: 26),
            color: const Color(0xFF165b47),
          ),

          // Month label
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF165b47),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'تحليلات مالية',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A7F6E),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Next arrow
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_left_rounded, size: 26),
            color: const Color(0xFF165b47),
          ),

          // Placeholder to balance back button
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.netIncome,
    required this.netExpense,
    required this.netSaving,
    required this.txCount,
  });

  final double netIncome, netExpense, netSaving;
  final int txCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            label: 'الدخل',
            value: netIncome.toStringAsFixed(0),
            color: const Color(0xFF16A34A),
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: 'المصروف',
            value: netExpense.toStringAsFixed(0),
            color: const Color(0xFFDC2626),
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: 'التوفير',
            value: netSaving.toStringAsFixed(0),
            color: netSaving >= 0
                ? const Color(0xFF165b47)
                : const Color(0xFFDC2626),
            icon: Icons.savings_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _KpiCard(
            label: 'المعاملات',
            value: '$txCount',
            color: const Color(0xFF2563EB),
            icon: Icons.receipt_long_rounded,
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label, value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF8A7F72),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Chart Card wrapper ─────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title, subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: const Color(0xFF165b47).withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF165b47).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A7F72),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ── Saving Rate Gauge ──────────────────────────────────────────────────────

class _SavingRateGauge extends StatelessWidget {
  const _SavingRateGauge({required this.savingRate, required this.saving});
  final double savingRate, saving;

  @override
  Widget build(BuildContext context) {
    final isPos = saving >= 0;
    final pct = (savingRate * 100).toStringAsFixed(1);
    final color = isPos ? const Color(0xFF165b47) : const Color(0xFFDC2626);

    return Column(
      children: [
        SizedBox(
          height: 100,
          child: CustomPaint(
            painter: _GaugePainter(value: savingRate, color: color),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$pct%',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: color)),
                    Text(
                      'توفير',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8A7F72),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: const Color(0xFF165b47), label: 'نسبة التوفير'),
            const SizedBox(width: 16),
            _LegendDot(color: const Color(0xFFDC2626), label: 'نسبة المصروف'),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('صافي التوفير',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text(
                '${isPos ? '+' : ''}${saving.toStringAsFixed(2)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || !value.isFinite) return;

    final center = Offset(size.width / 2, size.height * 0.9);
    final radius = size.width * 0.42;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    final bgPaint = Paint()
      ..color = const Color(0xFF165b47).withValues(alpha: 0.10)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false, bgPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle * value.clamp(0.0, 1.0), false, fgPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.value != value;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8A7F72),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Daily Bars Chart ───────────────────────────────────────────────────────

class _DailyBarsChart extends StatelessWidget {
  const _DailyBarsChart({required this.monthTx, required this.month});
  final List<TransactionEntity> monthTx;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final dailyIn = <int, double>{};
    final dailyOut = <int, double>{};
    for (final t in monthTx) {
      if (t.type == TransactionType.income.value) {
        dailyIn[t.createdAt.day] = (dailyIn[t.createdAt.day] ?? 0) + t.amount;
      } else if (t.type == TransactionType.expense.value) {
        dailyOut[t.createdAt.day] = (dailyOut[t.createdAt.day] ?? 0) + t.amount;
      }
    }

    if (dailyIn.isEmpty && dailyOut.isEmpty) {
      return const _EmptyChart(text: 'لا توجد بيانات');
    }

    final allVals = [...dailyIn.values, ...dailyOut.values]
        .where((v) => v.isFinite)
        .toList();
    final maxVal = allVals.isEmpty
        ? 1.0
        : allVals.reduce(math.max).clamp(1.0, double.infinity);

    // Show every 5 days
    final displayDays = <int>[];
    for (int d = 1; d <= daysInMonth; d++) {
      if (d == 1 || d % 5 == 0 || d == daysInMonth) displayDays.add(d);
    }

    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(daysInMonth, (i) {
          final day = i + 1;
          final inc = (dailyIn[day] ?? 0) / maxVal;
          final exp = (dailyOut[day] ?? 0) / maxVal;
          final showLabel = displayDays.contains(day);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Fill space to maintain correct height ratio
                        if (1.0 - inc - exp > 0.01)
                          Spacer(
                            flex: (((1.0 - inc - exp).clamp(0.0, 1.0)) * 100)
                                .toInt()
                                .clamp(1, 100),
                          ),
                        if (inc > 0)
                          Flexible(
                            flex: (inc * 100).toInt().clamp(1, 100),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF16A34A),
                                borderRadius: BorderRadius.vertical(
                                  top: const Radius.circular(3),
                                  bottom: Radius.circular(exp > 0 ? 0 : 3),
                                ),
                              ),
                            ),
                          ),
                        if (exp > 0)
                          Flexible(
                            flex: (exp * 100).toInt().clamp(1, 100),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626)
                                    .withValues(alpha: 0.80),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(inc > 0 ? 0 : 3),
                                  bottom: const Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (showLabel)
                    Text('$day',
                        style: const TextStyle(
                            fontSize: 8, color: Color(0xFF8A7F72)))
                  else
                    const SizedBox(height: 10),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Category Breakdown ─────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.monthTx, required this.categories});
  final List<TransactionEntity> monthTx;
  final List<CategoryEntity> categories;

  @override
  Widget build(BuildContext context) {
    final catMap = <String, double>{};
    for (final t
        in monthTx.where((t) => t.type == TransactionType.expense.value)) {
      final key = t.categoryId ?? '__none__';
      catMap[key] = (catMap[key] ?? 0) + t.amount;
    }

    if (catMap.isEmpty) {
      return const _EmptyChart(text: 'لا توجد مصروفات مصنفة');
    }

    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = catMap.values.fold<double>(0, (s, v) => s + v);

    final colors = [
      const Color(0xFFDC2626),
      const Color(0xFFD97706),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFF0891B2),
      const Color(0xFF059669),
      const Color(0xFFDB2777),
    ];

    return Column(
      children: sorted.take(7).toList().asMap().entries.map((entry) {
        final idx = entry.key;
        final e = entry.value;
        final cat = e.key == '__none__'
            ? null
            : categories.where((c) => c.id == e.key).firstOrNull;
        final ratio = e.value / total;
        final color = colors[idx % colors.length];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat?.name ?? 'غير مصنف',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    e.value.toStringAsFixed(2),
                    style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(ratio * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        color: Color(0xFF8A7F72),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Monthly Trend Chart (last 6 months) ────────────────────────────────────

class _MonthlyTrendChart extends StatelessWidget {
  const _MonthlyTrendChart({required this.allTx, required this.currentMonth});
  final List<TransactionEntity> allTx;
  final DateTime currentMonth;

  @override
  Widget build(BuildContext context) {
    final months = List.generate(6, (i) {
      final m = DateTime(currentMonth.year, currentMonth.month - 5 + i, 1);
      return m;
    });

    final data = months.map((m) {
      final tx = allTx.where(
          (t) => t.createdAt.year == m.year && t.createdAt.month == m.month);
      final inc = tx
          .where((t) => t.type == TransactionType.income.value)
          .fold<double>(0, (s, t) => s + t.amount);
      final exp = tx
          .where((t) => t.type == TransactionType.expense.value)
          .fold<double>(0, (s, t) => s + t.amount);
      return (m, inc, exp);
    }).toList();

    final allValues = data.expand((d) => [d.$2, d.$3]).where((v) => v.isFinite);
    final maxVal = allValues.isEmpty
        ? 1.0
        : allValues.reduce(math.max).clamp(1.0, double.infinity);

    if (maxVal <= 1 || !maxVal.isFinite) {
      return const _EmptyChart(text: 'لا توجد بيانات كافية');
    }

    return Column(
      children: [
        Row(
          children: [
            _LegendDot(color: const Color(0xFF16A34A), label: 'الدخل'),
            const SizedBox(width: 16),
            _LegendDot(color: const Color(0xFFDC2626), label: 'المصروف'),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: data.map((d) {
              final incRatio = (d.$2 / maxVal).clamp(0.0, 1.0);
              final expRatio = (d.$3 / maxVal).clamp(0.0, 1.0);
              final label = DateFormat('MMM', 'ar').format(d.$1);

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Income bar
                            Expanded(
                              child: FractionallySizedBox(
                                heightFactor: incRatio,
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(5)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            // Expense bar
                            Expanded(
                              child: FractionallySizedBox(
                                heightFactor: expRatio,
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.80),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(5)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8A7F72),
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        // Summary table
        ...data.map((d) {
          final net = d.$2 - d.$3;
          final isPos = net >= 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    DateFormat('MMM yy', 'ar').format(d.$1),
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A7F72),
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Text(d.$2.toStringAsFixed(0),
                          style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      const Text(' / ',
                          style: TextStyle(
                              color: Color(0xFF8A7F72), fontSize: 11)),
                      Text(d.$3.toStringAsFixed(0),
                          style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Text(
                  '${isPos ? '+' : ''}${net.toStringAsFixed(0)}',
                  style: TextStyle(
                    color: isPos
                        ? const Color(0xFF165b47)
                        : const Color(0xFFDC2626),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Day of Week Chart ──────────────────────────────────────────────────────

class _DayOfWeekChart extends StatelessWidget {
  const _DayOfWeekChart({required this.monthTx});
  final List<TransactionEntity> monthTx;

  @override
  Widget build(BuildContext context) {
    final days = [
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت'
    ];
    final dayTotals = List.generate(7, (i) {
      return monthTx
          .where((t) =>
              t.type == TransactionType.expense.value &&
              t.createdAt.weekday % 7 == i)
          .fold<double>(0, (s, t) => s + t.amount);
    });

    final maxVal = dayTotals.fold<double>(1.0, (m, v) => v > m ? v : m);

    if (maxVal <= 1) return const _EmptyChart(text: 'لا توجد بيانات');

    return Column(
      children: List.generate(7, (i) {
        final ratio = dayTotals[i] / maxVal;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 55,
                child: Text(days[i],
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 14,
                    backgroundColor:
                        const Color(0xFF2563EB).withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation(
                      Color.lerp(
                            const Color(0xFF93C5FD),
                            const Color(0xFF1D4ED8),
                            ratio,
                          ) ??
                          const Color(0xFF2563EB),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 55,
                child: Text(
                  dayTotals[i].toStringAsFixed(0),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Income Breakdown ───────────────────────────────────────────────────────

class _IncomeBreakdown extends StatelessWidget {
  const _IncomeBreakdown({required this.monthTx, required this.categories});
  final List<TransactionEntity> monthTx;
  final List<CategoryEntity> categories;

  @override
  Widget build(BuildContext context) {
    final incomeTx =
        monthTx.where((t) => t.type == TransactionType.income.value).toList();
    if (incomeTx.isEmpty) {
      return const _EmptyChart(text: 'لا توجد إيرادات هذا الشهر');
    }

    final total = incomeTx.fold<double>(0, (s, t) => s + t.amount);
    final catMap = <String, double>{};
    for (final t in incomeTx) {
      final key = t.categoryId ?? '__none__';
      catMap[key] = (catMap[key] ?? 0) + t.amount;
    }
    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      const Color(0xFF16A34A),
      const Color(0xFF059669),
      const Color(0xFF0D9488),
      const Color(0xFF0284C7),
      const Color(0xFF7C3AED),
    ];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي الدخل',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              Text('+${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...sorted.take(5).toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final e = entry.value;
          final cat = e.key == '__none__'
              ? null
              : categories.where((c) => c.id == e.key).firstOrNull;
          final ratio = e.value / total;
          final color = colors[idx % colors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(cat?.name ?? 'أخرى',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                          Text(
                            '+${e.value.toStringAsFixed(2)}',
                            style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(ratio * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: Color(0xFF8A7F72),
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 7,
                          backgroundColor: color.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(color),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ── Top Spending Days ──────────────────────────────────────────────────────

class _TopSpendingDays extends StatelessWidget {
  const _TopSpendingDays({required this.monthTx});
  final List<TransactionEntity> monthTx;

  @override
  Widget build(BuildContext context) {
    final expTx =
        monthTx.where((t) => t.type == TransactionType.expense.value).toList();
    if (expTx.isEmpty) return const _EmptyChart(text: 'لا توجد مصروفات');

    final dayMap = <String, double>{};
    for (final t in expTx) {
      final key = DateFormat('yyyy-MM-dd').format(t.createdAt);
      dayMap[key] = (dayMap[key] ?? 0) + t.amount;
    }

    final sorted = dayMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sorted.take(5).toList();
    final maxVal = top5.first.value.clamp(1.0, double.infinity);

    return Column(
      children: top5.asMap().entries.map((entry) {
        final idx = entry.key;
        final e = entry.value;
        final date = DateTime.parse(e.key);
        final ratio = e.value / maxVal;
        final colors = [
          const Color(0xFFDC2626),
          const Color(0xFFD97706),
          const Color(0xFF2563EB),
          const Color(0xFF7C3AED),
          const Color(0xFF0891B2),
        ];
        final color = colors[idx];
        final medal = ['🥇', '🥈', '🥉', '4', '5'][idx];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(medal,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: Text(
                  DateFormat('d MMM', 'ar').format(date),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 14,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                e.value.toStringAsFixed(0),
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Empty Chart ────────────────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  const _EmptyChart({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF165b47).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF8A7F72), fontWeight: FontWeight.w500)),
      ),
    );
  }
}
