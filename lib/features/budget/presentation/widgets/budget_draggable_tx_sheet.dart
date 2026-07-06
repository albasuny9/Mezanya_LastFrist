// ignore_for_file: no_wildcard_variable_uses

// BudgetDraggableFilterableTxSheet
//
// Purpose: A draggable bottom sheet presenting a filterable, sortable list of
// transactions for a specific budget entity (income source, allocation, debt,
// subscription, or lent person). Includes kind filter and date range filter.
//
// Responsibility: Self-contained UI — manages its own filter and sort state
// locally. All transactions and tile rendering are provided by the caller.
// No business logic, no Cubit mutations.
//
// Dependencies: Flutter Material, TransactionEntity, intl.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_DraggableFilterableTxSheet) to reduce file size and isolate this reusable
// sheet component.
//
// Must never: Modify transaction data, call Cubit methods, perform financial
// calculations, or change the filtering/sorting logic.

import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/utils/budget_date_format.dart';
import '../constants/budget_colors.dart';
import '../constants/budget_layout.dart';

// Filter by transaction kind (type).
enum BudgetTxKindFilter { all, expense, income, transfer }

// Filter by date period.
enum BudgetTxDateFilter { day, week, month, year, custom, all }

class BudgetDraggableFilterableTxSheet extends StatefulWidget {
  const BudgetDraggableFilterableTxSheet({
    super.key,
    required this.theme,
    required this.accent,
    required this.topSectionAfterGrab,
    required this.transactions,
    required this.initialMonth,
    required this.emptyMessage,
    required this.sheetContext,
    required this.tileBuilder,
  });

  final ThemeData theme;
  final Color accent;
  final List<Widget> topSectionAfterGrab;
  final List<TransactionEntity> transactions;
  final DateTime initialMonth;
  final String emptyMessage;
  final BuildContext sheetContext;
  final Widget Function(TransactionEntity item) tileBuilder;

  @override
  State<BudgetDraggableFilterableTxSheet> createState() =>
      _BudgetDraggableFilterableTxSheetState();
}

class _BudgetDraggableFilterableTxSheetState
    extends State<BudgetDraggableFilterableTxSheet> {
  bool _newestFirst = true;
  BudgetTxKindFilter _kind = BudgetTxKindFilter.all;
  BudgetTxDateFilter _dateFilter = BudgetTxDateFilter.month;
  DateTime? _selectedDay;
  DateTime? _selectedWeekStart;
  DateTimeRange? _customRange;

  static bool _isTransfer(TransactionEntity t) {
    return t.type != TransactionType.expense.value &&
        t.type != TransactionType.income.value;
  }

  List<TransactionEntity> get _visible {
    var list = List<TransactionEntity>.from(widget.transactions);
    switch (_kind) {
      case BudgetTxKindFilter.all:
        break;
      case BudgetTxKindFilter.expense:
        list = list
            .where((t) => t.type == TransactionType.expense.value)
            .toList();
        break;
      case BudgetTxKindFilter.income:
        list = list
            .where((t) => t.type == TransactionType.income.value)
            .toList();
        break;
      case BudgetTxKindFilter.transfer:
        list = list.where(_isTransfer).toList();
        break;
    }
    list = list.where(_matchesDateFilter).toList();
    list.sort((a, b) => _newestFirst
        ? b.createdAt.compareTo(a.createdAt)
        : a.createdAt.compareTo(b.createdAt));
    return list;
  }

  bool _matchesDateFilter(TransactionEntity transaction) {
    final date = transaction.createdAt;
    switch (_dateFilter) {
      case BudgetTxDateFilter.all:
        return true;
      case BudgetTxDateFilter.month:
        return date.year == widget.initialMonth.year &&
            date.month == widget.initialMonth.month;
      case BudgetTxDateFilter.year:
        return date.year == widget.initialMonth.year;
      case BudgetTxDateFilter.day:
        final day = _selectedDay ?? widget.initialMonth;
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      case BudgetTxDateFilter.week:
        final start = _selectedWeekStart ?? widget.initialMonth;
        final normalizedStart =
            DateTime(start.year, start.month, start.day);
        final normalizedEnd = normalizedStart
            .add(const Duration(days: 6, hours: 23, minutes: 59));
        return !date.isBefore(normalizedStart) &&
            !date.isAfter(normalizedEnd);
      case BudgetTxDateFilter.custom:
        final range = _customRange;
        if (range == null) {
          return true;
        }
        final start = DateTime(
          range.start.year,
          range.start.month,
          range.start.day,
        );
        final end = DateTime(
          range.end.year,
          range.end.month,
          range.end.day,
          23,
          59,
          59,
        );
        return !date.isBefore(start) && !date.isAfter(end);
    }
  }

  String get _dateFilterLabel {
    switch (_dateFilter) {
      case BudgetTxDateFilter.day:
        final day = _selectedDay ?? widget.initialMonth;
        return 'يوم ${budgetFormatFullDate(day)}';
      case BudgetTxDateFilter.week:
        final start = _selectedWeekStart ?? widget.initialMonth;
        final end = start.add(const Duration(days: 6));
        return 'أسبوع ${budgetFormatShortNumericDate(start)} - ${budgetFormatShortNumericDate(end)}';
      case BudgetTxDateFilter.month:
        return budgetFormatMonthYear(widget.initialMonth);
      case BudgetTxDateFilter.year:
        return 'سنة ${widget.initialMonth.year}';
      case BudgetTxDateFilter.custom:
        if (_customRange == null) return 'مدى مخصص';
        return '${budgetFormatFullDate(_customRange!.start)} - ${budgetFormatFullDate(_customRange!.end)}';
      case BudgetTxDateFilter.all:
        return 'كل المعاملات';
    }
  }

  String get _kindFilterLabel {
    switch (_kind) {
      case BudgetTxKindFilter.expense:
        return 'مصروفات فقط';
      case BudgetTxKindFilter.income:
        return 'دخل فقط';
      case BudgetTxKindFilter.transfer:
        return 'تحويلات فقط';
      case BudgetTxKindFilter.all:
        return 'كل الأنواع';
    }
  }

  String get _sortLabel => _newestFirst ? 'الأحدث أولًا' : 'الأقدم أولًا';

  List<Widget> _dayGroups(List<TransactionEntity> transactions) {
    final grouped = <DateTime, List<TransactionEntity>>{};
    for (final transaction in transactions) {
      final day = DateTime(
        transaction.createdAt.year,
        transaction.createdAt.month,
        transaction.createdAt.day,
      );
      grouped.putIfAbsent(day, () => <TransactionEntity>[]).add(transaction);
    }

    return [
      for (final entry in grouped.entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _dayLabel(entry.key),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kBudgetMutedText,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: kBudgetSheetSurface,
                  borderRadius: BorderRadius.circular(kBudgetRadiusM),
                  border: Border.all(color: kBudgetSheetBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: kBudgetSheetBorder,
                          indent: 16,
                          endIndent: 16,
                        ),
                      widget.tileBuilder(entry.value[i]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(date.year, date.month, date.day);
    final datePart = budgetFormatMediumDate(date);
    if (day == today) return 'اليوم • $datePart';
    if (day == yesterday) return 'أمس • $datePart';
    return datePart;
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        Widget sectionTitle(String title, IconData icon) {
          return Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(kBudgetRadiusXS),
                ),
                child: Icon(icon, color: widget.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: widget.theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          );
        }

        Widget optionTile({
          required String title,
          String? subtitle,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(kBudgetRadiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? widget.accent.withValues(alpha: 0.10)
                      : widget.theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(kBudgetRadiusMd),
                  border: Border.all(
                    color: selected
                        ? widget.accent.withValues(alpha: 0.34)
                        : widget.theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.theme.colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: selected
                          ? widget.accent
                          : widget.theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تصفية المعاملات',
                    style: widget.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'اختر نوع المعاملات والفترة المناسبة، ويمكنك تغيير الترتيب من الشاشة الرئيسية مباشرة.',
                    style: widget.theme.textTheme.bodySmall?.copyWith(
                      color: widget.theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  sectionTitle('نوع المعاملة', Icons.tune_rounded),
                  const SizedBox(height: 10),
                  optionTile(
                    title: 'كل المعاملات',
                    selected: _kind == BudgetTxKindFilter.all,
                    onTap: () {
                      setState(() => _kind = BudgetTxKindFilter.all);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'مصروفات فقط',
                    selected: _kind == BudgetTxKindFilter.expense,
                    onTap: () {
                      setState(() => _kind = BudgetTxKindFilter.expense);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'دخل فقط',
                    selected: _kind == BudgetTxKindFilter.income,
                    onTap: () {
                      setState(() => _kind = BudgetTxKindFilter.income);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'تحويلات فقط',
                    selected: _kind == BudgetTxKindFilter.transfer,
                    onTap: () {
                      setState(() => _kind = BudgetTxKindFilter.transfer);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 18),
                  sectionTitle('الفترة', Icons.date_range_rounded),
                  const SizedBox(height: 10),
                  optionTile(
                    title: 'الشهر المعروض',
                    subtitle: budgetFormatMonthYear(widget.initialMonth),
                    selected: _dateFilter == BudgetTxDateFilter.month,
                    onTap: () {
                      setState(
                          () => _dateFilter = BudgetTxDateFilter.month);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'السنة المعروضة',
                    subtitle: '${widget.initialMonth.year}',
                    selected: _dateFilter == BudgetTxDateFilter.year,
                    onTap: () {
                      setState(
                          () => _dateFilter = BudgetTxDateFilter.year);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'يوم محدد',
                    subtitle: _selectedDay == null
                        ? 'اختر يومًا بعينه'
                        : budgetFormatFullDate(_selectedDay!),
                    selected: _dateFilter == BudgetTxDateFilter.day,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDay ?? widget.initialMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setState(() {
                        _selectedDay = picked;
                        _dateFilter = BudgetTxDateFilter.day;
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'أسبوع',
                    subtitle: _selectedWeekStart == null
                        ? 'اختر بداية الأسبوع'
                        : '${budgetFormatShortNumericDate(_selectedWeekStart!)} - ${budgetFormatShortNumericDate(_selectedWeekStart!.add(const Duration(days: 6)))}',
                    selected: _dateFilter == BudgetTxDateFilter.week,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            _selectedWeekStart ?? widget.initialMonth,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null) return;
                      setState(() {
                        _selectedWeekStart = picked;
                        _dateFilter = BudgetTxDateFilter.week;
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'من تاريخ إلى تاريخ',
                    subtitle: _customRange == null
                        ? 'حدد مدى زمني مخصص'
                        : '${budgetFormatFullDate(_customRange!.start)} - ${budgetFormatFullDate(_customRange!.end)}',
                    selected: _dateFilter == BudgetTxDateFilter.custom,
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDateRange: _customRange,
                      );
                      if (picked == null) return;
                      setState(() {
                        _customRange = picked;
                        _dateFilter = BudgetTxDateFilter.custom;
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  optionTile(
                    title: 'كل الفترات',
                    selected: _dateFilter == BudgetTxDateFilter.all,
                    onTap: () {
                      setState(() => _dateFilter = BudgetTxDateFilter.all);
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final theme = widget.theme;

    return SizedBox(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.76,
        minChildSize: 0.38,
        maxChildSize: 1.0,
        snap: true,
        snapSizes: const [0.76, 1.0],
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(kBudgetRadiusL)),
            child: Material(
              color: theme.colorScheme.surface,
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(kBudgetRadiusPill),
                      ),
                    ),
                  ),
                  ...widget.topSectionAfterGrab,
                  Divider(
                    height: 32,
                    thickness: 1,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المعاملات',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _dateFilterLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _kindFilterLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: widget.accent,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              widget.accent.withValues(alpha: 0.10),
                          foregroundColor: widget.accent,
                        ),
                        onPressed: () {
                          setState(() => _newestFirst = !_newestFirst);
                        },
                        icon: Icon(
                          _newestFirst
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 20,
                        ),
                        tooltip: _sortLabel,
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              widget.accent.withValues(alpha: 0.10),
                          foregroundColor: widget.accent,
                        ),
                        onPressed: _openFilterSheet,
                        icon: const Icon(Icons.filter_list_rounded, size: 22),
                        tooltip: 'تصفية',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._dayGroups(visible),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        widget.emptyMessage,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
