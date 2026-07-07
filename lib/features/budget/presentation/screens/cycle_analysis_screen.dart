import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';

class CycleAnalysisScreen extends StatelessWidget {
  const CycleAnalysisScreen({
    super.key,
    required this.transactions,
    required this.categories,
    required this.cycleStart,
    required this.cycleEnd,
    required this.totalIncomeActual,
    required this.totalExpenseActual,
    required this.remainingIncome,
    required this.plannedIncome,
    required this.plannedAllocations,
    required this.plannedJars,
    required this.plannedDebts,
  });

  final List<TransactionEntity> transactions;
  final List<CategoryEntity> categories;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final double totalIncomeActual;
  final double totalExpenseActual;
  final double remainingIncome;
  final double plannedIncome;
  final double plannedAllocations;
  final double plannedJars;
  final double plannedDebts;

  // ── helpers ──────────────────────────────────────────────────────────────
  double get _spendRatio => totalIncomeActual <= 0
      ? 0
      : (totalExpenseActual / totalIncomeActual).clamp(0.0, 1.0);

  double get _savingsRatio => totalIncomeActual <= 0
      ? 0
      : (remainingIncome / totalIncomeActual).clamp(0.0, 1.0);

  double get _planCoverageRatio {
    final planned = plannedAllocations + plannedJars + plannedDebts;
    return planned <= 0 ? 1.0 : (totalIncomeActual / planned).clamp(0.0, 2.0);
  }

  String get _cycleLabel {
    final f = DateFormat('d MMM', 'ar');
    return '${f.format(cycleStart)} — ${f.format(cycleEnd)}';
  }

  String _generateParagraph() {
    final spendPct = (_spendRatio * 100).round();
    final savePct = (_savingsRatio * 100).round();
    final coveragePct = (_planCoverageRatio * 100).round();

    final buf = StringBuffer();

    // Opening
    if (totalIncomeActual <= 0) {
      buf.write(
          'لم يُسجَّل دخل فعلي في هذه الدورة حتى الآن، لذا يعتمد التحليل على الخطة المخططة مسبقاً. ');
    } else {
      buf.write(
          'حتى الآن في دورة $_cycleLabel، وصل الدخل الفعلي إلى ${totalIncomeActual.toStringAsFixed(0)} وهو ');
      if (totalIncomeActual >= plannedIncome) {
        buf.write(
            'ما يساوي أو يتجاوز الدخل المخطط — وهذا مؤشر جيد على الاستقرار. ');
      } else {
        final gap = (plannedIncome - totalIncomeActual).toStringAsFixed(0);
        buf.write(
            'أقل من المخطط بفارق $gap — قد تحتاج لمتابعة مصادر الدخل المتبقية. ');
      }
    }

    // Spending
    if (spendPct == 0) {
      buf.write('لم تُسجَّل مصاريف فعلية بعد. ');
    } else if (spendPct <= 50) {
      buf.write(
          'المصاريف الفعلية حتى الآن $spendPct٪ من الدخل، وهو معدل منخفض يدل على ترشّد جيد في الإنفاق. ');
    } else if (spendPct <= 80) {
      buf.write(
          'المصاريف وصلت إلى $spendPct٪ من الدخل — الوضع معقول لكن يستحق المتابعة حتى نهاية الدورة. ');
    } else if (spendPct <= 100) {
      buf.write(
          'المصاريف بلغت $spendPct٪ من الدخل — مرحلة تحذير، يُنصح بمراجعة المصاريف غير الضرورية. ');
    } else {
      buf.write(
          'المصاريف تجاوزت الدخل الفعلي بنسبة ${spendPct - 100}٪ — وضع يستلزم تدخلاً فورياً لضبط الإنفاق. ');
    }

    // Savings
    if (savePct > 0) {
      buf.write(
          'المبلغ المتبقي للتوفير المحتمل هو ${remainingIncome.toStringAsFixed(0)} أي $savePct٪ من الدخل. ');
    } else if (savePct == 0) {
      buf.write('لا يوجد فائض واضح للتوفير حتى الآن في هذه الدورة. ');
    } else {
      buf.write(
          'يوجد عجز مالي حالي قدره ${remainingIncome.abs().toStringAsFixed(0)}. ');
    }

    // Plan coverage
    final planned = plannedAllocations + plannedJars + plannedDebts;
    if (planned > 0) {
      if (coveragePct >= 100) {
        buf.write(
            'الدخل الفعلي يغطي الالتزامات المخططة بنسبة $coveragePct٪ — الخطة محمية حتى الآن.');
      } else {
        buf.write(
            'الدخل الفعلي يغطي $coveragePct٪ فقط من الالتزامات المخططة — بعض الالتزامات قد لا تُنفَّذ كاملاً هذه الدورة إن لم يكتمل الدخل.');
      }
    }

    return buf.toString();
  }

  // ── category breakdown ─────────────────────────────────────────────────
  Map<String, double> _categoryBreakdown() {
    final txs = transactions
        .where((t) =>
            t.type == TransactionType.expense.value &&
            !t.createdAt.isBefore(cycleStart) &&
            !t.createdAt.isAfter(cycleEnd))
        .toList();

    final Map<String, double> result = {};
    for (final tx in txs) {
      final cat = tx.categoryId ?? 'غير مصنف';
      // resolve name
      final catName = categories
              .where((c) => c.id == cat)
              .map((c) => c.name)
              .cast<String?>()
              .firstWhere((_) => true, orElse: () => null) ??
          'غير مصنف';
      result[catName] = (result[catName] ?? 0) + tx.amount;
    }

    // sort desc
    final sorted = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(6));
  }

  // ── daily trend ────────────────────────────────────────────────────────
  List<_DayPoint> _dailyTrend() {
    final txs = transactions
        .where((t) =>
            !t.createdAt.isBefore(cycleStart) && !t.createdAt.isAfter(cycleEnd))
        .toList();

    final Map<int, double> incomeByDay = {};
    final Map<int, double> expenseByDay = {};

    for (final tx in txs) {
      final dayIndex = tx.createdAt.difference(cycleStart).inDays;
      if (tx.type == TransactionType.income.value) {
        incomeByDay[dayIndex] = (incomeByDay[dayIndex] ?? 0) + tx.amount;
      } else if (tx.type == TransactionType.expense.value) {
        expenseByDay[dayIndex] = (expenseByDay[dayIndex] ?? 0) + tx.amount;
      }
    }

    final totalDays = cycleEnd.difference(cycleStart).inDays + 1;
    final step = (totalDays / 10).ceil();
    final result = <_DayPoint>[];
    for (var i = 0; i < totalDays; i += step) {
      double inc = 0, exp = 0;
      for (var j = i; j < math.min(i + step, totalDays); j++) {
        inc += incomeByDay[j] ?? 0;
        exp += expenseByDay[j] ?? 0;
      }
      final day = cycleStart.add(Duration(days: i));
      result.add(_DayPoint(
        label: DateFormat('d/M', 'ar').format(day),
        income: inc,
        expense: exp,
      ));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final paragraph = _generateParagraph();
    final catBreakdown = _categoryBreakdown();
    final dailyPoints = _dailyTrend();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تحليل الدورة',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: Color(0xFF2C2416))),
            Text(_cycleLabel,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A6E5F),
                    fontWeight: FontWeight.w600)),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2C2416)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── KPI row ──────────────────────────────────────────────────────
          Row(
            children: [
              _KpiCard(
                label: 'الدخل الفعلي',
                value: totalIncomeActual.toStringAsFixed(0),
                color: const Color(0xFF4A7C59),
                icon: Icons.south_west_rounded,
              ),
              const SizedBox(width: 10),
              _KpiCard(
                label: 'المصروف',
                value: totalExpenseActual.toStringAsFixed(0),
                color: const Color(0xFFC65D2E),
                icon: Icons.north_east_rounded,
              ),
              const SizedBox(width: 10),
              _KpiCard(
                label: 'المتبقي',
                value: remainingIncome.toStringAsFixed(0),
                color: remainingIncome >= 0
                    ? const Color(0xFF2A5F8F)
                    : const Color(0xFF8E4A37),
                icon: Icons.account_balance_wallet_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Analysis paragraph ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF6EE),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDDD5C4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A7C59).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: Color(0xFF4A7C59), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text('قراءة الدورة',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF2C2416))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  paragraph,
                  style: const TextStyle(
                    color: Color(0xFF4A3F30),
                    height: 1.75,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Spend donut chart ─────────────────────────────────────────
          _SectionTitle(title: 'توزيع الإنفاق'),
          const SizedBox(height: 10),
          _DonutCard(
            spendRatio: _spendRatio,
            savingsRatio: _savingsRatio.clamp(0.0, 1.0),
            totalIncome: totalIncomeActual,
            totalExpense: totalExpenseActual,
            remaining: remainingIncome,
          ),
          const SizedBox(height: 16),

          // ── Daily bar chart ───────────────────────────────────────────
          if (dailyPoints.isNotEmpty) ...[
            _SectionTitle(title: 'النشاط اليومي خلال الدورة'),
            const SizedBox(height: 10),
            _BarChartCard(points: dailyPoints),
            const SizedBox(height: 16),
          ],

          // ── Category breakdown ────────────────────────────────────────
          if (catBreakdown.isNotEmpty) ...[
            _SectionTitle(title: 'تصنيف المصاريف'),
            const SizedBox(height: 10),
            _CategoryBreakdownCard(
              breakdown: catBreakdown,
              total: totalExpenseActual,
            ),
            const SizedBox(height: 16),
          ],

          // ── Plan vs actual table ──────────────────────────────────────
          _SectionTitle(title: 'الخطة مقابل التنفيذ'),
          const SizedBox(height: 10),
          _PlanVsActualCard(
            plannedIncome: plannedIncome,
            actualIncome: totalIncomeActual,
            plannedAllocations: plannedAllocations,
            plannedJars: plannedJars,
            plannedDebts: plannedDebts,
            actualExpense: totalExpenseActual,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 16, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7A6E5F),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
                color: const Color(0xFF4A7C59),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF2C2416))),
      ],
    );
  }
}

// ── Donut chart ─────────────────────────────────────────────────────────────
class _DonutCard extends StatelessWidget {
  const _DonutCard({
    required this.spendRatio,
    required this.savingsRatio,
    required this.totalIncome,
    required this.totalExpense,
    required this.remaining,
  });
  final double spendRatio;
  final double savingsRatio;
  final double totalIncome;
  final double totalExpense;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD5C4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DonutPainter(
                spendRatio: spendRatio,
                savingsRatio: savingsRatio.clamp(0.0, 1.0 - spendRatio),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DonutLegend(
                    color: const Color(0xFFC65D2E),
                    label: 'مصروف',
                    value: totalExpense.toStringAsFixed(0)),
                const SizedBox(height: 8),
                _DonutLegend(
                    color: const Color(0xFF4A7C59),
                    label: 'متبقي',
                    value:
                        remaining.clamp(0, double.infinity).toStringAsFixed(0)),
                const SizedBox(height: 8),
                _DonutLegend(
                    color: const Color(0xFFDDD5C4),
                    label: 'دخل كلي',
                    value: totalIncome.toStringAsFixed(0)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutLegend extends StatelessWidget {
  const _DonutLegend(
      {required this.color, required this.label, required this.value});
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A6E5F),
                    fontWeight: FontWeight.w600))),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Color(0xFF2C2416))),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.spendRatio, required this.savingsRatio});
  final double spendRatio;
  final double savingsRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 18.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      Paint()
        ..color = const Color(0xFFE8E0D0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Savings (green)
    if (savingsRatio > 0.01) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * savingsRatio,
        false,
        Paint()
          ..color = const Color(0xFF4A7C59)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Spend (amber) — drawn on top
    if (spendRatio > 0.01) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + 2 * math.pi * savingsRatio,
        2 * math.pi * spendRatio,
        false,
        Paint()
          ..color = const Color(0xFFC65D2E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Center text
    final pct = '${(spendRatio * 100).round()}٪';
    final textPainter = TextPainter(
      text: TextSpan(
        text: pct,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF2C2416)),
      ),
      textDirection: ui.TextDirection.rtl,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.spendRatio != spendRatio || old.savingsRatio != savingsRatio;
}

// ── Bar chart ───────────────────────────────────────────────────────────────
class _BarChartCard extends StatelessWidget {
  const _BarChartCard({required this.points});
  final List<_DayPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxVal = points.fold<double>(
        0, (m, p) => math.max(m, math.max(p.income, p.expense)));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD5C4)),
      ),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _BarLegend(color: const Color(0xFF4A7C59), label: 'دخل'),
              const SizedBox(width: 14),
              _BarLegend(color: const Color(0xFFC65D2E), label: 'مصروف'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: points.map((p) {
                final incH = maxVal <= 0 ? 0.0 : (p.income / maxVal) * 100;
                final expH = maxVal <= 0 ? 0.0 : (p.expense / maxVal) * 100;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _Bar(height: incH, color: const Color(0xFF4A7C59)),
                            const SizedBox(width: 2),
                            _Bar(height: expH, color: const Color(0xFFC65D2E)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(p.label,
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF7A6E5F),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: height.clamp(2.0, 100.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

class _BarLegend extends StatelessWidget {
  const _BarLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7A6E5F),
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Category breakdown ───────────────────────────────────────────────────────
class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.breakdown, required this.total});
  final Map<String, double> breakdown;
  final double total;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFC65D2E),
      const Color(0xFF4A7C59),
      const Color(0xFF2A5F8F),
      const Color(0xFF8B6B3D),
      const Color(0xFF6B5B9A),
      const Color(0xFF3D8B6B),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD5C4)),
      ),
      child: Column(
        children: breakdown.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final name = entry.value.key;
          final amount = entry.value.value;
          final ratio = total <= 0 ? 0.0 : (amount / total).clamp(0.0, 1.0);
          final color = colors[idx % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF2C2416))),
                    ),
                    Text(amount.toStringAsFixed(0),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF2C2416))),
                    const SizedBox(width: 6),
                    Text('${(ratio * 100).round()}٪',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Plan vs Actual ───────────────────────────────────────────────────────────
class _PlanVsActualCard extends StatelessWidget {
  const _PlanVsActualCard({
    required this.plannedIncome,
    required this.actualIncome,
    required this.plannedAllocations,
    required this.plannedJars,
    required this.plannedDebts,
    required this.actualExpense,
  });
  final double plannedIncome;
  final double actualIncome;
  final double plannedAllocations;
  final double plannedJars;
  final double plannedDebts;
  final double actualExpense;

  Widget _row(String label, double planned, double actual) {
    final diff = actual - planned;
    final isOver = diff > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF2C2416)))),
              Text(
                  '${actual.toStringAsFixed(0)} / ${planned.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A6E5F),
                      fontWeight: FontWeight.w600)),
              if (diff.abs() > 1) ...[
                const SizedBox(width: 6),
                Text(
                  '${isOver ? '+' : ''}${diff.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isOver
                          ? const Color(0xFFC65D2E)
                          : const Color(0xFF4A7C59)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 7, color: const Color(0xFFE8E0D0)),
                FractionallySizedBox(
                  widthFactor:
                      planned <= 0 ? 0 : (actual / planned).clamp(0.0, 1.0),
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color:
                          (actual / math.max(planned, 1)).clamp(0.0, 1.1) > 1.0
                              ? const Color(0xFFC65D2E)
                              : const Color(0xFF4A7C59),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plannedTotal = plannedAllocations + plannedJars + plannedDebts;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF6EE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD5C4)),
      ),
      child: Column(
        children: [
          _row('الدخل', plannedIncome, actualIncome),
          const Divider(color: Color(0xFFDDD5C4)),
          _row('المخصصات', plannedAllocations, actualExpense),
          _row('الإجمالي المخطط', plannedTotal, actualExpense),
        ],
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────────────────
class _DayPoint {
  const _DayPoint(
      {required this.label, required this.income, required this.expense});
  final String label;
  final double income;
  final double expense;
}
