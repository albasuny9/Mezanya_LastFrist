import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../../../../core/constants/transaction_types.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/shared_transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import 'all_transactions_screen.dart';
import 'transaction_charts_screen.dart';

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key, required this.cubit});
  final AppCubit cubit;

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const _green = Color(0xFF165b47);

  bool _isJarTx(TransactionEntity t) =>
      t.transferType == TransferType.jarAllocation.value ||
      t.transferType == TransferType.jarAllocationCancel.value ||
      t.transferType == TransferType.jarAllocationSpend.value ||
      t.transferType == TransferType.jarToJar.value;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snap) {
        final state = snap.data ?? widget.cubit.state;
        final wallets = state.wallets;
        final allTx = state.transactions;
        final monthTx = allTx
            .where((t) =>
                t.createdAt.year == _month.year &&
                t.createdAt.month == _month.month &&
                !_isJarTx(t))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        final totalBalance = wallets.fold<double>(0, (s, w) => s + w.balance);
        final netIncome = monthTx
            .where((t) => t.type == TransactionType.income.value)
            .fold<double>(0, (s, t) => s + t.amount);
        final netExpense = monthTx
            .where((t) => t.type == TransactionType.expense.value)
            .fold<double>(0, (s, t) => s + t.amount);
        final netSaving = netIncome - netExpense;
        // Empty month → full green; spending with no income → red
        final savingRate = netIncome > 0
            ? (netSaving / netIncome).clamp(-1.0, 1.0)
            : (netExpense > 0 ? -1.0 : 1.0);

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Month selector bar (above card) ────────────────────────
            _MonthBar(
              month: _month,
              onPrev: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1)),
              onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1, 1)),
            ),
            const SizedBox(height: 10),

            // ── Hero card ──────────────────────────────────────────────
            _HeroCard(
              totalBalance: totalBalance,
              netIncome: netIncome,
              netExpense: netExpense,
              netSaving: netSaving,
              savingRate: savingRate,
              currencyCode: state.currencyCode,
            ),
            const SizedBox(height: 14),

            // ── Quick stats row ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _QuickStatsRow(
                monthTx: monthTx,
                categories: state.categories,
              ),
            ),
            const SizedBox(height: 14),

            // ── Transactions section ───────────────────────────────────
            _SectionCard(
              title: 'المعاملات',
              subtitle: 'آخر الحركات في هذا الشهر',
              accentColor: _green,
              onMore: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AllTransactionsScreen(
                  cubit: widget.cubit,
                  allTransactions: allTx,
                  initialMonth: _month,
                ),
              )),
              child: monthTx.isEmpty
                  ? const _EmptyHint(text: 'لا توجد معاملات لهذا الشهر.')
                  : Column(
                      children: [
                        ...monthTx
                            .take(5)
                            .map((t) => _CompactTxCard(
                                  transaction: t,
                                  state: state,
                                  onTap: () => openTransactionDetailsSheet(
                                      context,
                                      cubit: widget.cubit,
                                      transaction: t),
                                )),
                        const SizedBox(height: 4),
                        // كارت المزيد
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AllTransactionsScreen(
                                cubit: widget.cubit,
                                allTransactions: allTx,
                                initialMonth: _month,
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
                                  Icon(Icons.arrow_back_ios_new_rounded,
                                      color: _green, size: 12),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),

            // ── Chart preview section ──────────────────────────────────
            _SectionCard(
              title: 'الرسم البياني',
              subtitle: 'ملخص مالي سريع',
              accentColor: _green,
              onMore: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => TransactionChartsScreen(
                  cubit: widget.cubit,
                  allTransactions: allTx,
                  initialMonth: _month,
                ),
              )),
              child: monthTx.isEmpty
                  ? const _EmptyHint(text: 'لا توجد بيانات لهذا الشهر.')
                  : _MiniChartPreview(
                      monthTx: monthTx,
                      netIncome: netIncome,
                      netExpense: netExpense,
                      categories: state.categories,
                    ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// ── Month Bar (above hero card) ─────────────────────────────────────────────

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev, onNext;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('MMMM yyyy', 'ar').format(month);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _NavBtn(icon: Icons.chevron_right_rounded, onTap: onPrev),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF165b47),
                ),
              ),
            ),
          ),
          _NavBtn(icon: Icons.chevron_left_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF165b47).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF165b47), size: 22),
      ),
    );
  }
}

// ── Hero Card ──────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.totalBalance,
    required this.netIncome,
    required this.netExpense,
    required this.netSaving,
    required this.savingRate,
    required this.currencyCode,
  });

  final double totalBalance, netIncome, netExpense, netSaving, savingRate;
  final String currencyCode;

  /// Returns gradient colors based on saving health
  static List<Color> _gradientColors(double rate) {
    if (rate >= 0.35) {
      // Healthy — deep green
      return [const Color(0xFF1e7a30), const Color(0xFF0b5c1a)];
    } else if (rate >= 0.15) {
      // Decent — medium green
      return [const Color(0xFF2E8B57), const Color(0xFF1B6640)];
    } else if (rate >= 0.03) {
      // Getting tight — amber/yellow
      return [const Color(0xFFB8820C), const Color(0xFF8B6508)];
    } else if (rate >= -0.05) {
      // Almost empty — orange
      return [const Color(0xFFBF5E14), const Color(0xFF9C4410)];
    } else {
      // Over budget — red
      return [const Color(0xFFC0392B), const Color(0xFF96261E)];
    }
  }

  static Color _shadowColor(double rate) {
    if (rate >= 0.35) return const Color(0x381e7a30);
    if (rate >= 0.15) return const Color(0x352E8B57);
    if (rate >= 0.03) return const Color(0x38B8820C);
    if (rate >= -0.05) return const Color(0x38BF5E14);
    return const Color(0x38C0392B);
  }

  static Color _barColor(double rate) {
    if (rate >= 0.15) return const Color(0xFF4ADE80);
    if (rate >= 0.03) return const Color(0xFFFFD060);
    if (rate >= -0.05) return const Color(0xFFFFAA40);
    return const Color(0xFFF87171);
  }

  @override
  Widget build(BuildContext context) {
    final isPositive = netSaving >= 0;
    final savingPct = (savingRate * 100).toStringAsFixed(0);
    final gradColors = _gradientColors(savingRate);
    final shadowC = _shadowColor(savingRate);
    final barC = _barColor(savingRate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: shadowC,
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Balance label + amount ──────────────────────────────────
            Text(
              'إجمالي المحافظ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
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
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
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
            const SizedBox(height: 20),

            // ── Three stats: income / expense / saving ──────────────────
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
            const SizedBox(height: 18),

            // ── Saving rate bar ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'نسبة التوفير',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: barC.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$savingPct%',
                    style: TextStyle(
                      color: barC,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: savingRate.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation(barC),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(height: 8),
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

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({required this.monthTx, required this.categories});
  final List<TransactionEntity> monthTx;
  final List<CategoryEntity> categories;

  @override
  Widget build(BuildContext context) {
    final expenseTx =
        monthTx.where((t) => t.type == TransactionType.expense.value).toList();
    monthTx.where((t) => t.type == TransactionType.income.value).toList();
    final avgExpense = expenseTx.isEmpty
        ? 0.0
        : expenseTx.fold<double>(0, (s, t) => s + t.amount) / expenseTx.length;

    // Top spending category
    final catMap = <String, double>{};
    for (final t in expenseTx) {
      if (t.categoryId != null) {
        catMap[t.categoryId!] = (catMap[t.categoryId!] ?? 0) + t.amount;
      }
    }
    String? topCatName;
    if (catMap.isNotEmpty) {
      final topId =
          catMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      topCatName =
          categories.where((c) => c.id == topId).map((c) => c.name).firstOrNull;
    }

    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.receipt_long_rounded,
            label: 'عدد المعاملات',
            value: '${monthTx.length}',
            color: const Color(0xFF165b47),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            icon: Icons.trending_down_rounded,
            label: 'متوسط المصروف',
            value: avgExpense.toStringAsFixed(0),
            color: const Color(0xFFDC2626),
          ),
        ),
        if (topCatName != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              icon: Icons.star_rounded,
              label: 'أكثر إنفاق',
              value: topCatName,
              color: const Color(0xFFD97706),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A7F72),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Card ───────────────────────────────────────────────────────────

// ── Compact colored transaction card ─────────────────────────────────────────

class _CompactTxCard extends StatelessWidget {
  const _CompactTxCard({
    required this.transaction,
    required this.state,
    required this.onTap,
  });

  final TransactionEntity transaction;
  final AppStateEntity state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income.value;
    final isExpense = transaction.type == TransactionType.expense.value;

    final bgColor = isIncome
        ? const Color(0xFFE8F5E9)   // مخضر فاتح
        : isExpense
            ? const Color(0xFFFFEBEE) // محمر فاتح
            : const Color(0xFFE3F2FD); // أزرق فاتح للتحويلات

    final accentColor = isIncome
        ? const Color(0xFF16A34A)
        : isExpense
            ? const Color(0xFFDC2626)
            : const Color(0xFF2563EB);

    final icon = isIncome
        ? Icons.arrow_downward_rounded
        : isExpense
            ? Icons.arrow_upward_rounded
            : Icons.swap_horiz_rounded;

    // الاسم: الملاحظات > اسم الفئة > نوع المعاملة
    final cat = state.categories
        .where((c) => c.id == transaction.categoryId)
        .firstOrNull;
    final label = transaction.notes?.isNotEmpty == true
        ? transaction.notes!
        : cat?.name ??
            (isIncome ? 'دخل' : isExpense ? 'مصروف' : 'تحويل');

    final dateStr = DateFormat('d MMM', 'ar').format(transaction.createdAt);
    final sign = isIncome ? '+' : isExpense ? '-' : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // أيقونة دائرية
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 17),
            ),
            const SizedBox(width: 12),
            // اسم + تاريخ
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: accentColor.withValues(alpha: 0.70),
                    ),
                  ),
                ],
              ),
            ),
            // المبلغ
            Text(
              '$sign${transaction.amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section card wrapper ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onMore,
    required this.accentColor,
  });

  final String title, subtitle;
  final Widget child;
  final VoidCallback onMore;
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
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A7F72),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onMore,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('المزيد',
                            style: TextStyle(
                                color: accentColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_back_ios_new_rounded,
                            color: accentColor, size: 12),
                      ],
                    ),
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

// ── Mini Chart Preview ─────────────────────────────────────────────────────

class _MiniChartPreview extends StatelessWidget {
  const _MiniChartPreview({
    required this.monthTx,
    required this.netIncome,
    required this.netExpense,
    required this.categories,
  });

  final List<TransactionEntity> monthTx;
  final double netIncome, netExpense;
  final List<CategoryEntity> categories;

  @override
  Widget build(BuildContext context) {
    final max = math.max(netIncome, netExpense).clamp(1.0, double.infinity);
    final net = netIncome - netExpense;
    final isPositive = net >= 0;

    // Daily cumulative expense sparkline (last 30 days)
    final now = DateTime.now();
    final days = List.generate(14, (i) => now.subtract(Duration(days: 13 - i)));
    final dailyExpense = days.map((d) {
      return monthTx
          .where((t) =>
              t.type == TransactionType.expense.value &&
              t.createdAt.day == d.day &&
              t.createdAt.month == d.month)
          .fold<double>(0, (s, t) => s + t.amount);
    }).toList();
    final maxDaily = dailyExpense.reduce(math.max).clamp(1.0, double.infinity);

    // Top categories
    final catMap = <String, double>{};
    for (final t in monthTx.where((t) => t.type == TransactionType.expense.value)) {
      if (t.categoryId != null) {
        catMap[t.categoryId!] = (catMap[t.categoryId!] ?? 0) + t.amount;
      }
    }
    final top3 = (catMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();
    final totalExp = netExpense.clamp(1.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Income vs Expense bars ──────────────────────────────────
        _gradientBar(
          label: 'الدخل',
          ratio: netIncome / max,
          color: const Color(0xFF16A34A),
          value: netIncome.toStringAsFixed(0),
        ),
        const SizedBox(height: 10),
        _gradientBar(
          label: 'المصروف',
          ratio: netExpense / max,
          color: const Color(0xFFDC2626),
          value: netExpense.toStringAsFixed(0),
        ),
        const SizedBox(height: 12),

        // ── Net pill ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color:
                (isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626))
                    .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (isPositive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626))
                  .withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: isPositive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPositive ? 'وفّرت هذا الشهر' : 'مصروفك أكبر من دخلك',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${isPositive ? '+' : ''}${net.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isPositive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // ── Daily sparkline ─────────────────────────────────────────
        if (dailyExpense.any((d) => d > 0)) ...[
          const SizedBox(height: 14),
          const Text('المصروف اليومي',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A7F72),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: dailyExpense.asMap().entries.map((e) {
                final ratio = e.value / maxDaily;
                final isToday = days[e.key].day == now.day &&
                    days[e.key].month == now.month;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: ratio * 36 + (ratio > 0 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFDC2626)
                                    .withValues(alpha: 0.40),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // ── Top categories ──────────────────────────────────────────
        if (top3.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('أعلى فئات المصروف',
              style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8A7F72),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...top3.asMap().entries.map((e) {
            final cat =
                categories.where((c) => c.id == e.value.key).firstOrNull;
            final ratio = e.value.value / totalExp;
            final barColors = [
              const Color(0xFFDC2626),
              const Color(0xFFF97316),
              const Color(0xFFF59E0B),
            ];
            final c = barColors[e.key % barColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  SizedBox(
                    width: 68,
                    child: Text(
                      cat?.name ?? 'أخرى',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: ratio,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${(ratio * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: c),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _gradientBar(
      {required String label,
      required double ratio,
      required Color color,
      required String value}) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.65),
                        color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    );
  }
}


