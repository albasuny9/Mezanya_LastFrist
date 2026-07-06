import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../widgets/recent_transaction_card.dart';

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

  bool _isJarTx(TransactionEntity t) =>
      t.transferType == TransferType.jarAllocation.value ||
      t.transferType == TransferType.jarAllocationCancel.value ||
      t.transferType == TransferType.jarAllocationSpend.value ||
      t.transferType == TransferType.allocationToJar.value ||
      t.transferType == TransferType.jarToAllocation.value;

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

  void _openDateRangeSheet() {
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
                const Text(
                  'اختر الفترة',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'حدد تاريخ البداية والنهاية',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8A7F72),
                  ),
                ),
                const SizedBox(height: 20),
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
                            initialDate: tmpTo ?? tmpFrom ?? DateTime.now(),
                            firstDate: tmpFrom ?? DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (p != null) setSheet(() => tmpTo = p);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: tmpFrom == null || tmpTo == null
                        ? null
                        : () {
                            setState(() {
                              _period = _Period.custom;
                              _customFrom = tmpFrom;
                              _customTo = tmpTo;
                            });
                            Navigator.pop(ctx);
                          },
                    child: const Text(
                      'تطبيق',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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
    final filtered = _filtered();

    final totalIncome = filtered
        .where((t) => t.type == TransactionType.income.value)
        .fold<double>(0, (s, t) => s + t.amount);
    final totalExpense = filtered
        .where((t) => t.type == TransactionType.expense.value)
        .fold<double>(0, (s, t) => s + t.amount);
    final net = totalIncome - totalExpense;

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
            _PageTitleBar(
              onFilter: _openFilterSheet,
              onSort: () => setState(() => _sortAscending = !_sortAscending),
              sortAscending: _sortAscending,
              filterActive: _typeTab != 'all' || _period == _Period.custom,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _PeriodTopBar(
                    label: _periodLabel(),
                    showArrows: _period != _Period.custom,
                    onPrev: _prev,
                    onNext: _next,
                    onRangeTap: _openDateRangeSheet,
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isNotEmpty)
                    _MonthSummaryCard(
                      income: totalIncome,
                      expense: totalExpense,
                      net: net,
                    ),
                  if (filtered.isNotEmpty) const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    const _EmptyState()
                  else
                    ...sortedKeys.map((dateKey) {
                      final dayTx = grouped[dateKey]!;
                      final dayDate = DateTime.parse(dateKey);

                      return _DayGroup(
                        date: dayDate,
                        transactions: dayTx,
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

class _PageTitleBar extends StatelessWidget {
  const _PageTitleBar({
    required this.onFilter,
    required this.onSort,
    required this.sortAscending,
    required this.filterActive,
  });

  final VoidCallback onFilter;
  final VoidCallback onSort;
  final bool sortAscending;
  final bool filterActive;

  static const _green = Color(0xFF165b47);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
      child: Row(
        children: [
          _HeaderIcon(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).pop(),
            iconSize: 20,
          ),
          Expanded(
            child: Text(
              'كل المعاملات',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _green,
              ),
            ),
          ),
          _HeaderIcon(
            icon: Icons.tune_rounded,
            onTap: onFilter,
            isActive: filterActive,
          ),
          _HeaderIcon(
            icon: sortAscending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            onTap: onSort,
            isActive: sortAscending,
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.iconSize = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;
  final double iconSize;

  static const _green = Color(0xFF165b47);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        icon,
        size: iconSize,
        color: isActive ? _green : _green.withValues(alpha: 0.82),
      ),
    );
  }
}

class _PeriodTopBar extends StatelessWidget {
  const _PeriodTopBar({
    required this.label,
    required this.showArrows,
    required this.onPrev,
    required this.onNext,
    required this.onRangeTap,
  });

  final String label;
  final bool showArrows;
  final VoidCallback onPrev, onNext, onRangeTap;

  static const _green = Color(0xFF165b47);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (showArrows)
            _PeriodNavBtn(
              icon: Icons.chevron_right_rounded,
              onTap: onPrev,
            )
          else
            const SizedBox(width: 38),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppTheme.dateTextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _green,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onRangeTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4, left: 2),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: _green.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showArrows)
            _PeriodNavBtn(
              icon: Icons.chevron_left_rounded,
              onTap: onNext,
            )
          else
            const SizedBox(width: 38),
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.income,
    required this.expense,
    required this.net,
  });

  final double income;
  final double expense;
  final double net;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCol(
              label: 'دخل',
              value: '+${income.toStringAsFixed(0)}',
              valueColor: const Color(0xFF16A34A),
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE8E0D4)),
          Expanded(
            child: _SummaryCol(
              label: 'صافي',
              value: '${net >= 0 ? '+' : ''}${net.toStringAsFixed(0)}',
              valueColor: const Color(0xFF1A1A1A),
            ),
          ),
          Container(width: 1, height: 36, color: const Color(0xFFE8E0D4)),
          Expanded(
            child: _SummaryCol(
              label: 'مصروف',
              value: '-${expense.toStringAsFixed(0)}',
              valueColor: const Color(0xFFDC2626),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCol extends StatelessWidget {
  const _SummaryCol({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8A7F72),
          ),
        ),
      ],
    );
  }
}

class _PeriodNavBtn extends StatelessWidget {
  const _PeriodNavBtn({required this.icon, required this.onTap});

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
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF165b47),
          size: 22,
          textDirection: ui.TextDirection.ltr,
        ),
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
              style: AppTheme.dateTextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF165b47),
              ),
            ),
          ],
        ),
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
    required this.transactions,
    required this.cubit,
  });

  final DateTime date;
  final List<TransactionEntity> transactions;
  final AppCubit cubit;

  String _dateLabel() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    final datePart = DateFormat('d MMMM', 'ar').format(date);
    if (d == today) return 'اليوم • $datePart';
    if (d == yesterday) return 'أمس • $datePart';
    return datePart;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              _dateLabel(),
              textAlign: TextAlign.center,
              style: AppTheme.dateTextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8A7F72),
              ),
            ),
          ),
          RecentTransactionsGroup(
            transactions: transactions,
            cubit: cubit,
          ),
        ],
      ),
    );
  }
}
