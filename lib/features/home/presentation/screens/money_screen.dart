import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../../../../core/constants/transaction_types.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../widgets/recent_transaction_card.dart';
import 'all_transactions_screen.dart';
import 'transaction_charts_screen.dart';

class MoneyScreen extends StatelessWidget {
  const MoneyScreen({super.key, required this.cubit});
  final AppCubit cubit;

  static const _green = Color(0xFF165b47);

  static bool _isJarTx(TransactionEntity t) =>
      t.transferType == TransferType.jarAllocation.value ||
      t.transferType == TransferType.jarAllocationCancel.value ||
      t.transferType == TransferType.jarAllocationSpend.value ||
      t.transferType == TransferType.allocationToJar.value ||
      t.transferType == TransferType.jarToAllocation.value ||
      t.transferType == TransferType.jarToJar.value;

  static List<TransactionEntity> _visibleTransactions(
    List<TransactionEntity> allTx,
  ) {
    return allTx.where((t) => !_isJarTx(t)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static List<TransactionEntity> _lastSevenDaysTransactions(
    List<TransactionEntity> visibleTx,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    return visibleTx.where((t) {
      final day = DateTime(t.createdAt.year, t.createdAt.month, t.createdAt.day);
      return !day.isBefore(start) && !day.isAfter(today);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: cubit.stream,
      initialData: cubit.state,
      builder: (context, snap) {
        final state = snap.data ?? cubit.state;
        final allTx = state.transactions;
        final wallets = state.wallets;
        final visibleTx = _visibleTransactions(allTx);
        final recentTx = visibleTx.take(4).toList();
        final weekTx = _lastSevenDaysTransactions(visibleTx);
        final totalBalance = wallets.fold<double>(0, (s, w) => s + w.balance);
        final netIncome = weekTx
            .where((t) => t.type == TransactionType.income.value)
            .fold<double>(0, (s, t) => s + t.amount);
        final netExpense = weekTx
            .where((t) => t.type == TransactionType.expense.value)
            .fold<double>(0, (s, t) => s + t.amount);
        final netSaving = netIncome - netExpense;

        return ListView(
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
          children: [
            _HeroCard(
              totalBalance: totalBalance,
              netIncome: netIncome,
              netExpense: netExpense,
              netSaving: netSaving,
              currencyCode: state.currencyCode,
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'آخر المعاملات',
              accentColor: _green,
              child: recentTx.isEmpty
                  ? const _EmptyHint(text: 'لا توجد معاملات بعد.')
                  : Column(
                      children: [
                        RecentTransactionsGroup(
                          transactions: recentTx,
                          cubit: cubit,
                          showDateWithTime: true,
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AllTransactionsScreen(
                                cubit: cubit,
                                allTransactions: allTx,
                                initialMonth: DateTime.now(),
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: _green.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: _green.withValues(alpha: 0.18)),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('كل المعاملات',
                                      style: TextStyle(
                                          color: _green,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 6),
                                  Icon(Icons.chevron_left_rounded,
                                      color: _green,
                                      size: 18,
                                      textDirection: ui.TextDirection.ltr),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'التحليل',
              accentColor: _green,
              onMore: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TransactionChartsScreen(
                  cubit: cubit,
                  allTransactions: allTx,
                  initialMonth: DateTime.now(),
                ),
              )),
              child: weekTx.isEmpty
                  ? const _EmptyHint(
                      text: 'لا توجد حركة دخل أو مصروف في آخر ٧ أيام.',
                    )
                  : _AnalysisPreview(
                      weekTx: weekTx,
                      netIncome: netIncome,
                      netExpense: netExpense,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalBalance,
    required this.netIncome,
    required this.netExpense,
    required this.netSaving,
    required this.currencyCode,
  });

  final double totalBalance, netIncome, netExpense, netSaving;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final isPositive = netSaving >= 0;
    final gradColors = isPositive
        ? [const Color(0xFF1E6B4B), const Color(0xFF104C35)]
        : [const Color(0xFF9B2C2C), const Color(0xFF6F1D1D)];
    final shadowC =
        isPositive ? const Color(0x241E6B4B) : const Color(0x249B2C2C);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: shadowC,
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إجمالي المحافظ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    totalBalance.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    currencyCode,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'الدخل',
                    value: netIncome.toStringAsFixed(2),
                    icon: Icons.arrow_downward_rounded,
                    iconBg: const Color(0x334ADE80),
                    iconColor: const Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroStat(
                    label: 'المصروف',
                    value: netExpense.toStringAsFixed(2),
                    icon: Icons.arrow_upward_rounded,
                    iconBg: const Color(0x33F87171),
                    iconColor: const Color(0xFFF87171),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _HeroStat(
                    label: 'التوفير',
                    value:
                        '${isPositive ? '+' : ''}${netSaving.toStringAsFixed(2)}',
                    icon: Icons.monetization_on_rounded,
                    iconBg: isPositive
                        ? const Color(0x3360D4A0)
                        : const Color(0x33F87171),
                    iconColor: isPositive
                        ? const Color(0xFF4ADE80)
                        : const Color(0xFFF87171),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  final String label, value;
  final IconData icon;
  final Color iconBg, iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 14),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card wrapper ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    required this.accentColor,
    this.onMore,
  });

  final String title;
  final Widget child;
  final VoidCallback? onMore;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A1A1A))),
                    ],
                  ),
                ),
                if (onMore != null)
                  GestureDetector(
                    onTap: onMore,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(Icons.chevron_left_rounded,
                          color: accentColor,
                          size: 20,
                          textDirection: ui.TextDirection.ltr),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF165b47).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFF8A7F72), fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ── Analysis Preview ───────────────────────────────────────────────────────

class _AnalysisPreview extends StatelessWidget {
  const _AnalysisPreview({
    required this.weekTx,
    required this.netIncome,
    required this.netExpense,
  });

  final List<TransactionEntity> weekTx;
  final double netIncome;
  final double netExpense;

  static const _incomeColor = Color(0xFF16A34A);
  static const _expenseColor = Color(0xFFDC2626);

  List<DateTime> _chartDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    return List.generate(7, (i) => start.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final netSaving = netIncome - netExpense;
    final totalFlow = netIncome + netExpense;
    final hasFlow = totalFlow > 0;
    final incomeShare = hasFlow ? netIncome / totalFlow : 0.0;
    final expenseShare = hasFlow ? netExpense / totalFlow : 0.0;

    final days = _chartDays();
    final dailyIncome = days.map((d) {
      return weekTx
          .where((t) =>
              t.type == TransactionType.income.value &&
              t.createdAt.year == d.year &&
              t.createdAt.month == d.month &&
              t.createdAt.day == d.day)
          .fold<double>(0, (s, t) => s + t.amount);
    }).toList();
    final dailyExpense = days.map((d) {
      return weekTx
          .where((t) =>
              t.type == TransactionType.expense.value &&
              t.createdAt.year == d.year &&
              t.createdAt.month == d.month &&
              t.createdAt.day == d.day)
          .fold<double>(0, (s, t) => s + t.amount);
    }).toList();

    final chartMax = [
      ...dailyIncome,
      ...dailyExpense,
      1.0,
    ].reduce(math.max);

    final hasChartData =
        dailyIncome.any((v) => v > 0) || dailyExpense.any((v) => v > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Income / expense summary ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _incomeColor.withValues(alpha: 0.08),
                _expenseColor.withValues(alpha: 0.06),
              ],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE8E0D4)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _FlowStatTile(
                      label: 'الدخل',
                      amount: netIncome,
                      color: _incomeColor,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    color: const Color(0xFFE4DCCF),
                  ),
                  Expanded(
                    child: _FlowStatTile(
                      label: 'المصروف',
                      amount: netExpense,
                      color: _expenseColor,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                ],
              ),
              if (hasFlow) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 10,
                    child: Row(
                      children: [
                        if (incomeShare > 0)
                          Expanded(
                            flex: (incomeShare * 100).round().clamp(1, 100),
                            child: Container(color: _incomeColor),
                          ),
                        if (expenseShare > 0)
                          Expanded(
                            flex: (expenseShare * 100).round().clamp(1, 100),
                            child: Container(color: _expenseColor),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(incomeShare * 100).round()}% دخل',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _incomeColor,
                      ),
                    ),
                    Text(
                      '${(expenseShare * 100).round()}% مصروف',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _expenseColor,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (netIncome > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: (netSaving >= 0 ? _incomeColor : _expenseColor)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (netSaving >= 0 ? _incomeColor : _expenseColor)
                    .withValues(alpha: 0.18),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  netSaving >= 0
                      ? Icons.savings_outlined
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: netSaving >= 0 ? _incomeColor : _expenseColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    netSaving >= 0
                        ? 'وفّرت ${netSaving.toStringAsFixed(0)} من دخلك'
                        : 'أنفقت أكثر من دخلك بـ ${(-netSaving).toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: netSaving >= 0 ? _incomeColor : _expenseColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ── Legend ───────────────────────────────────────────────────
        Row(
          children: [
            const _LegendDot(color: _incomeColor, label: 'دخل'),
            const SizedBox(width: 16),
            const _LegendDot(color: _expenseColor, label: 'مصروف'),
            const Spacer(),
            Text(
              'آخر ٧ أيام',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF8A7F72).withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── Dual bar chart ─────────────────────────────────────────────
        if (hasChartData)
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(days.length, (i) {
                final inc = dailyIncome[i];
                final exp = dailyExpense[i];
                final incH = (inc / chartMax) * 88;
                final expH = (exp / chartMax) * 88;
                final dayLabel = DateFormat('EEE', 'ar').format(days[i]);
                final isToday = days[i].year == DateTime.now().year &&
                    days[i].month == DateTime.now().month &&
                    days[i].day == DateTime.now().day;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 88,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _ChartBar(
                                  height: incH,
                                  color: _incomeColor,
                                  isHighlighted: isToday,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: _ChartBar(
                                  height: expH,
                                  color: _expenseColor,
                                  isHighlighted: isToday,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight:
                                isToday ? FontWeight.w900 : FontWeight.w600,
                            color: isToday
                                ? const Color(0xFF165b47)
                                : const Color(0xFF8A7F72),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          )
        else
          const _EmptyHint(text: 'لا توجد حركة دخل أو مصروف في الأيام الأخيرة.'),
      ],
    );
  }
}

class _FlowStatTile extends StatelessWidget {
  const _FlowStatTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  final String label;
  final double amount;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          amount.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }
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
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B6358),
          ),
        ),
      ],
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({
    required this.height,
    required this.color,
    required this.isHighlighted,
  });

  final double height;
  final Color color;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final h = height.clamp(0.0, 88.0);
    return Align(
      alignment: Alignment.bottomCenter,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        height: h > 0 ? h : 3,
        width: double.infinity,
        decoration: BoxDecoration(
          color: h > 0
              ? (isHighlighted ? color : color.withValues(alpha: 0.55))
              : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(5),
        ),
      ),
    );
  }
}
