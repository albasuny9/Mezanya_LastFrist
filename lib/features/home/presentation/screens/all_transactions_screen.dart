import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/shared_transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';

// ── Period types ────────────────────────────────────────────────────────────

enum _Period { day, week, month, custom }

// ── Screen ──────────────────────────────────────────────────────────────────

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({
    super.key,
    required this.cubit,
    required this.allTransactions,
    required this.initialMonth,
  });

  final AppCubit cubit;
  final List<TransactionEntity> allTransactions;
  final DateTime initialMonth;

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  _Period _period = _Period.month;
  String _typeTab = 'all';
  bool _sortAscending = false;

  late DateTime _anchor; // start of current period window
  DateTime? _customFrom;
  DateTime? _customTo;

  static const _beige = Color(0xFFFFFBF1);
  static const _green = Color(0xFF165b47);

  @override
  void initState() {
    super.initState();
    _anchor = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  bool _isJarTx(TransactionEntity t) => false;

  // ── Period navigation ──────────────────────────────────────────────────────

  void _prev() => setState(() {
        switch (_period) {
          case _Period.month:
            _anchor = DateTime(_anchor.year, _anchor.month - 1, 1);
          case _Period.week:
            _anchor = _anchor.subtract(const Duration(days: 7));
          case _Period.day:
            _anchor = _anchor.subtract(const Duration(days: 1));
          case _Period.custom:
            break;
        }
      });

  void _next() => setState(() {
        switch (_period) {
          case _Period.month:
            _anchor = DateTime(_anchor.year, _anchor.month + 1, 1);
          case _Period.week:
            _anchor = _anchor.add(const Duration(days: 7));
          case _Period.day:
            _anchor = _anchor.add(const Duration(days: 1));
          case _Period.custom:
            break;
        }
      });

  // ── Period label ──────────────────────────────────────────────────────────

  String _periodLabel() {
    switch (_period) {
      case _Period.month:
        return DateFormat('MMMM yyyy', 'ar').format(_anchor);
      case _Period.week:
        final end = _anchor.add(const Duration(days: 6));
        final startFmt = DateFormat('d', 'ar').format(_anchor);
        final endFmt = DateFormat('d MMMM yyyy', 'ar').format(end);
        return '$startFmt - $endFmt';
      case _Period.day:
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final d = DateTime(_anchor.year, _anchor.month, _anchor.day);
        if (d == today) return 'اليوم';
        if (d == yesterday) return 'أمس';
        return DateFormat('EEEE، d MMMM', 'ar').format(_anchor);
      case _Period.custom:
        if (_customFrom == null && _customTo == null) return 'مخصص';
        final f = _customFrom == null
            ? '...'
            : DateFormat('d MMMM yyyy', 'ar').format(_customFrom!);
        final t = _customTo == null
            ? '...'
            : DateFormat('d MMMM yyyy', 'ar').format(_customTo!);
        return '$f → $t';
    }
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<TransactionEntity> _filtered() {
    var out = widget.allTransactions.where((t) => !_isJarTx(t)).toList();

    if (_typeTab != 'all') out = out.where((t) => t.type == _typeTab).toList();

    switch (_period) {
      case _Period.day:
        final s = DateTime(_anchor.year, _anchor.month, _anchor.day);
        final e = s.add(const Duration(hours: 24));
        out = out
            .where((t) => !t.createdAt.isBefore(s) && t.createdAt.isBefore(e))
            .toList();
      case _Period.week:
        final s = DateTime(_anchor.year, _anchor.month, _anchor.day);
        final e = s.add(const Duration(days: 7));
        out = out
            .where((t) => !t.createdAt.isBefore(s) && t.createdAt.isBefore(e))
            .toList();
      case _Period.month:
        out = out
            .where((t) =>
                t.createdAt.year == _anchor.year &&
                t.createdAt.month == _anchor.month)
            .toList();
      case _Period.custom:
        if (_customFrom != null && _customTo != null) {
          final s =
              DateTime(_customFrom!.year, _customFrom!.month, _customFrom!.day);
          final e = DateTime(
              _customTo!.year, _customTo!.month, _customTo!.day, 23, 59, 59);
          out = out
              .where((t) => !t.createdAt.isBefore(s) && !t.createdAt.isAfter(e))
              .toList();
        }
    }

    if (_sortAscending) {
      out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return out;
  }

  // ── Filter bottom sheet ───────────────────────────────────────────────────

  void _openFilterSheet() {
    var tmpPeriod = _period;
    var tmpType = _typeTab;
    DateTime tmpAnchor = _anchor;
    DateTime? tmpFrom = _customFrom;
    DateTime? tmpTo = _customTo;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _beige,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          String periodLabel() {
            switch (tmpPeriod) {
              case _Period.month:
                return DateFormat('MMMM yyyy', 'ar').format(tmpAnchor);
              case _Period.week:
                final end = tmpAnchor.add(const Duration(days: 6));
                return '${DateFormat('d', 'ar').format(tmpAnchor)} - ${DateFormat('d MMM', 'ar').format(end)}';
              case _Period.day:
                return DateFormat('EEEE، d MMMM', 'ar').format(tmpAnchor);
              case _Period.custom:
                return 'مخصص';
            }
          }

          void shiftPrev() => setSheet(() {
                switch (tmpPeriod) {
                  case _Period.month:
                    tmpAnchor =
                        DateTime(tmpAnchor.year, tmpAnchor.month - 1, 1);
                  case _Period.week:
                    tmpAnchor = tmpAnchor.subtract(const Duration(days: 7));
                  case _Period.day:
                    tmpAnchor = tmpAnchor.subtract(const Duration(days: 1));
                  case _Period.custom:
                    break;
                }
              });

          void shiftNext() => setSheet(() {
                switch (tmpPeriod) {
                  case _Period.month:
                    tmpAnchor =
                        DateTime(tmpAnchor.year, tmpAnchor.month + 1, 1);
                  case _Period.week:
                    tmpAnchor = tmpAnchor.add(const Duration(days: 7));
                  case _Period.day:
                    tmpAnchor = tmpAnchor.add(const Duration(days: 1));
                  case _Period.custom:
                    break;
                }
              });

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('فلتر المعاملات',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 20),

                // ── Type filter ──────────────────────────────────────────
                const Text('نوع المعاملة',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B6358))),
                const SizedBox(height: 10),
                _SheetChipBar(
                  options: [
                    ('all', 'الكل', Color(0xFF165b47)),
                    (TransactionType.income.value, 'دخل', Color(0xFF16A34A)),
                    (TransactionType.expense.value, 'مصروف', Color(0xFFDC2626)),
                    (
                      TransactionType.transfer.value,
                      'تحويل',
                      Color(0xFF2563EB),
                    ),
                  ],
                  selected: tmpType,
                  onSelect: (v) => setSheet(() => tmpType = v),
                ),
                const SizedBox(height: 22),

                // ── Period type ──────────────────────────────────────────
                const Text('الفترة الزمنية',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B6358))),
                const SizedBox(height: 10),
                _SheetChipBar(
                  options: const [
                    ('month', 'شهر', Color(0xFF165b47)),
                    ('week', 'أسبوع', Color(0xFF165b47)),
                    ('day', 'يوم', Color(0xFF165b47)),
                    ('custom', 'مخصص', Color(0xFF7C3AED)),
                  ],
                  selected: tmpPeriod.name,
                  onSelect: (v) => setSheet(() {
                    tmpPeriod = _Period.values.firstWhere((p) => p.name == v);
                    if (tmpPeriod == _Period.week) {
                      final wd = tmpAnchor.weekday % 7;
                      tmpAnchor = tmpAnchor.subtract(Duration(days: wd));
                    }
                    if (tmpPeriod == _Period.day) {
                      tmpAnchor = DateTime(
                          tmpAnchor.year, tmpAnchor.month, tmpAnchor.day);
                    }
                    if (tmpPeriod == _Period.month) {
                      tmpAnchor = DateTime(tmpAnchor.year, tmpAnchor.month, 1);
                    }
                  }),
                ),
                const SizedBox(height: 16),

                // ── Period navigator ─────────────────────────────────────
                if (tmpPeriod != _Period.custom)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _green.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: shiftPrev,
                          icon: const Icon(Icons.chevron_right, color: _green),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              periodLabel(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _green,
                                  fontSize: 14),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: shiftNext,
                          icon: const Icon(Icons.chevron_left, color: _green),
                        ),
                      ],
                    ),
                  ),

                // ── Custom date pickers ──────────────────────────────────
                if (tmpPeriod == _Period.custom) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerBox(
                          label: 'من',
                          date: tmpFrom,
                          onTap: () async {
                            final p = await showDatePicker(
                              context: ctx,
                              initialDate: tmpFrom ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (p != null) setSheet(() => tmpFrom = p);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DatePickerBox(
                          label: 'إلى',
                          date: tmpTo,
                          onTap: () async {
                            final p = await showDatePicker(
                              context: ctx,
                              initialDate: tmpTo ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (p != null) setSheet(() => tmpTo = p);
                          },
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      setState(() {
                        _period = tmpPeriod;
                        _typeTab = tmpType;
                        _anchor = tmpAnchor;
                        _customFrom = tmpFrom;
                        _customTo = tmpTo;
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('تطبيق',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final categories = widget.cubit.state.categories;
    final filtered = _filtered();
    final totalIn = filtered
        .where((t) => t.type == TransactionType.income.value)
        .fold<double>(0, (s, t) => s + t.amount);
    final totalOut = filtered
        .where((t) => t.type == TransactionType.expense.value)
        .fold<double>(0, (s, t) => s + t.amount);

    final grouped = <String, List<TransactionEntity>>{};
    for (final t in filtered) {
      final key = DateFormat('yyyy-MM-dd').format(t.createdAt);
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => _sortAscending ? a.compareTo(b) : b.compareTo(a));

    return Scaffold(
      backgroundColor: _beige,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top period bar ─────────────────────────────────────────
            _PeriodTopBar(
              label: _periodLabel(),
              showArrows: _period != _Period.custom,
              onPrev: _prev,
              onNext: _next,
            ),

            // ── Content ────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  // Summary card
                  _SummaryCard(
                      totalIn: totalIn,
                      totalOut: totalOut,
                      count: filtered.length),
                  const SizedBox(height: 12),

                  // Sort and Filter Bar
                  Row(
                    children: [
                      // Sort Button
                      InkWell(
                        onTap: () =>
                            setState(() => _sortAscending = !_sortAscending),
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF165b47)
                                    .withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _sortAscending
                                    ? Icons.arrow_upward_rounded
                                    : Icons.arrow_downward_rounded,
                                size: 18,
                                color: const Color(0xFF165b47),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _sortAscending ? 'تصاعدي' : 'تنازلي',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF165b47),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Filter Button
                      InkWell(
                        onTap: _openFilterSheet,
                        borderRadius: BorderRadius.circular(12),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _typeTab != 'all'
                                ? const Color(0xFF165b47)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF165b47)
                                    .withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                size: 18,
                                color: _typeTab != 'all'
                                    ? Colors.white
                                    : const Color(0xFF165b47),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'تصفية',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _typeTab != 'all'
                                      ? Colors.white
                                      : const Color(0xFF165b47),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Empty state
                  if (filtered.isEmpty)
                    const _EmptyState()
                  else
                    ...sortedKeys.map((dateKey) {
                      final dayTx = grouped[dateKey]!;
                      final dayDate = DateTime.parse(dateKey);
                      final dayIncome = dayTx
                          .where((t) => t.type == TransactionType.income.value)
                          .fold<double>(0, (s, t) => s + t.amount);
                      final dayExpense = dayTx
                          .where((t) => t.type == TransactionType.expense.value)
                          .fold<double>(0, (s, t) => s + t.amount);

                      return _DayGroup(
                        date: dayDate,
                        dayIncome: dayIncome,
                        dayExpense: dayExpense,
                        transactions: dayTx,
                        categories: categories,
                        cubit: widget.cubit,
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Period Top Bar ──────────────────────────────────────────────────────────

class _PeriodTopBar extends StatelessWidget {
  const _PeriodTopBar({
    required this.label,
    required this.showArrows,
    required this.onPrev,
    required this.onNext,
  });

  final String label;
  final bool showArrows;
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
          if (showArrows)
            IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_right_rounded, size: 26),
              color: const Color(0xFF165b47),
            ),

          // Period label
          Expanded(
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
              ],
            ),
          ),

          // Next arrow
          if (showArrows)
            IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_left_rounded, size: 26),
              color: const Color(0xFF165b47),
            ),
        ],
      ),
    );
  }
}

// ── Sheet Chip Bar ──────────────────────────────────────────────────────────

class _SheetChipBar extends StatelessWidget {
  const _SheetChipBar({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<(String, String, Color)> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected == opt.$1;
        return GestureDetector(
          onTap: () => onSelect(opt.$1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? opt.$3 : opt.$3.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              opt.$2,
              style: TextStyle(
                color: isSelected ? Colors.white : opt.$3,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date Picker Box ─────────────────────────────────────────────────────────

class _DatePickerBox extends StatelessWidget {
  const _DatePickerBox({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF165b47).withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8A7F72),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              date == null
                  ? 'اختر تاريخ'
                  : DateFormat('d MMMM yyyy', 'ar').format(date!),
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF165b47)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Card ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.totalIn,
    required this.totalOut,
    required this.count,
  });

  final double totalIn, totalOut;
  final int count;

  @override
  Widget build(BuildContext context) {
    final net = totalIn - totalOut;
    final isPos = net >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B6B25), Color(0xFF0A5E19)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
              color: Color(0x301B6B25), blurRadius: 18, offset: Offset(0, 7))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _GlassTile(
                  label: 'الدخل',
                  value: '+${totalIn.toStringAsFixed(2)}',
                  valueColor: const Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GlassTile(
                  label: 'المصروف',
                  value: '-${totalOut.toStringAsFixed(2)}',
                  valueColor: const Color(0xFFF87171),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _GlassTile(
                  label: 'الصافي',
                  value: '${isPos ? '+' : ''}${net.toStringAsFixed(2)}',
                  valueColor:
                      isPos ? const Color(0xFF4ADE80) : const Color(0xFFF87171),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count معاملة',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label, value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor, fontSize: 13, fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 58, color: Color(0xFFB5A99A)),
            SizedBox(height: 12),
            Text('لا توجد معاملات مطابقة',
                style: TextStyle(
                    color: Color(0xFF8A7F72),
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ── Day Group ───────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.date,
    required this.dayIncome,
    required this.dayExpense,
    required this.transactions,
    required this.categories,
    required this.cubit,
  });

  final DateTime date;
  final double dayIncome, dayExpense;
  final List<TransactionEntity> transactions;
  final List<CategoryEntity> categories;
  final AppCubit cubit;

  String _dateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'اليوم';
    if (d == yesterday) return 'أمس';
    return DateFormat('EEEE، d MMMM', 'ar').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const Expanded(
                child: Divider(color: Color(0xFFE4DCCF), thickness: 1),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EEDF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      _dateLabel(),
                      style: const TextStyle(
                          color: Color(0xFF7D7461),
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                    if (dayIncome > 0 || dayExpense > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFB5A99A),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (dayIncome > 0)
                      Text('+${dayIncome.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    if (dayIncome > 0 && dayExpense > 0)
                      const Text('  ', style: TextStyle(fontSize: 11)),
                    if (dayExpense > 0)
                      Text('-${dayExpense.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Divider(color: Color(0xFFE4DCCF), thickness: 1),
              ),
            ],
          ),
        ),
        ...transactions.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _AllTxCard(
                transaction: t,
                cubit: cubit,
                onTap: () => openTransactionDetailsSheet(
                  context,
                  cubit: cubit,
                  transaction: t,
                ),
              ),
            )),
        const SizedBox(height: 14),
      ],
    );
  }
}

// ── Consistent fixed-height transaction card ─────────────────────────────────

class _AllTxCard extends StatelessWidget {
  const _AllTxCard({
    required this.transaction,
    required this.cubit,
    required this.onTap,
  });

  final TransactionEntity transaction;
  final AppCubit cubit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = cubit.state;
    final isIncome = transaction.type == TransactionType.income.value;
    final isExpense = transaction.type == TransactionType.expense.value;

    final accent = isIncome
        ? const Color(0xFF16A34A)
        : isExpense
            ? const Color(0xFFDC2626)
            : const Color(0xFF2563EB);

    final bgColor = isIncome
        ? const Color(0xFFE8F5E9)
        : isExpense
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFE3F2FD);

    final icon = isIncome
        ? Icons.arrow_downward_rounded
        : isExpense
            ? Icons.arrow_upward_rounded
            : Icons.swap_horiz_rounded;

    final cat = state.categories
        .where((c) => c.id == transaction.categoryId)
        .firstOrNull;

    final walletName = state.wallets
        .where((w) => w.id == transaction.walletId)
        .map((w) => w.name)
        .firstOrNull;

    final label = transaction.notes?.isNotEmpty == true
        ? transaction.notes!
        : cat?.name ??
            (isIncome ? 'دخل' : isExpense ? 'مصروف' : 'تحويل');

    final sign = isIncome ? '+' : isExpense ? '-' : '';
    final timeStr = DateFormat('HH:mm', 'ar').format(transaction.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // أيقونة
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 18),
            ),
            const SizedBox(width: 12),
            // اسم + محفظة + وقت
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (walletName != null) ...[
                        Text(
                          walletName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: accent.withValues(alpha: 0.65),
                          ),
                        ),
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 11,
                            color: accent.withValues(alpha: 0.40),
                          ),
                        ),
                      ],
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: accent.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // مبلغ
            Text(
              '$sign${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
