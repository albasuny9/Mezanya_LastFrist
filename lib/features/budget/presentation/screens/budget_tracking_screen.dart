// ignore_for_file: no_wildcard_variable_uses

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';
import '../../../transactions/presentation/screens/recurring_transaction_composer_screen.dart';
import '../../../transactions/presentation/widgets/recurring_postpone_dialog.dart';
import '../../../transactions/presentation/widgets/shared_transaction_card.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../../wallets/presentation/widgets/jar_details_sheet.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/services/budget_recurring_plan_service.dart';
import '../../domain/utils/budget_date_format.dart';
import '../constants/budget_colors.dart';
import '../constants/budget_layout.dart';
import 'budget_setup_screen.dart';
import 'cycle_analysis_screen.dart';
import '../widgets/budget_static_info_card.dart';
import '../widgets/budget_section_title.dart';
import '../widgets/budget_section_empty_card.dart';
import '../widgets/budget_compact_action_button.dart';
import '../widgets/budget_icon_badge.dart';
import '../widgets/budget_hero_summary_card.dart';
import '../widgets/budget_past_month_summary_card.dart';
import '../widgets/budget_setup_prompt_card.dart';
import '../widgets/budget_entity_tile.dart';
import '../widgets/budget_tracking_detail_hero_shell.dart';
import '../widgets/budget_month_bar.dart';
import '../widgets/budget_inline_section_card.dart';
import '../widgets/budget_cycle_summary_card.dart';
import '../widgets/budget_lent_pending_card.dart';
import '../widgets/budget_installment_payments_card.dart';
import '../widgets/budget_draggable_tx_sheet.dart';

class BudgetTrackingScreen extends StatefulWidget {
  const BudgetTrackingScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  /// [_cycleStart] = أول يوم في الدورة المعروضة حالياً
  late DateTime _cycleStart;
  bool _isIncomeExpanded = false;
  bool _isLentExpanded = false;
  bool _processingAutomaticDebts = false;

  /// occurrences اتشغلت في هذه الـ session — يمنع التكرار بسبب rebuild
  final Set<String> _handledOccurrenceKeys = {};

  String? _dismissedAutoIncomeMonthKey;
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    final budget = widget.cubit.state.budgetSetup;
    _cycleStart = budget.cycleStartFor(DateTime.now());
    // تشغيل المعاملات التلقائية مرة واحدة عند فتح الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = widget.cubit.state;
      final cycleTx = state.transactions
          .where((t) =>
              !t.createdAt.isBefore(_cycleStart) &&
              !t.createdAt.isAfter(_cycleEnd))
          .toList();
      _processAutomaticDebts(state, state.budgetSetup, cycleTx);
    });
  }

  // ── الدورة الحالية ────────────────────────────────────────────────────────

  DateTime get _cycleEnd {
    final budget = widget.cubit.state.budgetSetup;
    return budget.cycleEndFor(_cycleStart);
  }

  /// للتوافق مع الكود القديم الذي يستخدم _month
  DateTime get _month => _cycleStart;

  void _goToPreviousCycle(BudgetSetupEntity budget) {
    setState(() {
      _cycleStart = DateTime(
        _cycleStart.year,
        _cycleStart.month - 1,
        budget.startDay.clamp(1, 28),
      );
    });
  }

  void _goToNextCycle(BudgetSetupEntity budget) {
    setState(() {
      _cycleStart = DateTime(
        _cycleStart.year,
        _cycleStart.month + 1,
        budget.startDay.clamp(1, 28),
      );
    });
  }

  bool _isCurrentCycle(BudgetSetupEntity budget) {
    final expected = budget.cycleStartFor(DateTime.now());
    return _cycleStart.year == expected.year &&
        _cycleStart.month == expected.month &&
        _cycleStart.day == expected.day;
  }

  bool _isFutureCycle(BudgetSetupEntity budget) {
    return _cycleStart.isAfter(budget.cycleStartFor(DateTime.now()));
  }

  bool _isPastCycle(BudgetSetupEntity budget) {
    return _cycleStart.isBefore(budget.cycleStartFor(DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final budget = _budgetForMonth(state);
        final futureMonth = _isFutureMonth();
        final pastMonth = _isPastMonth();
        final hasBudgetPlan = _hasBudgetPlan(budget);
        final showSetupPromptOnly = futureMonth || !hasBudgetPlan;
        final budgetJars = budget.linkedWallets.where((jar) {
          if (jar.id == 'linked-savings-default') return true;
          return jar.funding
              .any((f) => f.incomeSourceId.isNotEmpty && f.plannedAmount > 0);
        }).toList();
        final monthTx = _monthTransactions(state.transactions);
        final incomeTx = monthTx
            .where((t) =>
                t.type == TransactionType.income.value &&
                // الإيداعات اليدوية للحصالات (depositWithJarLabel) هي
                // تمويل داخلي للحصالة وليست دخلاً ضمن الميزانية الشهرية
                t.transferType != TransferType.depositWithJarLabel.value)
            .toList();
        final expenseTx = monthTx
            .where((t) => t.type == TransactionType.expense.value)
            .toList();
        final incomeSectionChildren =
            _incomeInlineCards(state, budget, incomeTx, monthTx);
        final totalIncomeActual =
            incomeTx.fold<double>(0, (s, t) => s + t.amount);
        final totalExpenseActual =
            expenseTx.fold<double>(0, (s, t) => s + t.amount);
        final remainingIncome = totalIncomeActual - totalExpenseActual;
        // final totalDebts = budget.debts.fold<double>(0, (s, d) => s + d.amount);
        final isCurrentMonthView = _isCurrentCycle(budget);
        final hasPendingIncome =
            isCurrentMonthView && _hasPendingIncome(budget, incomeTx);
        final monthKey = budget.cycleKeyFor(_cycleStart);
        final shouldAutoExpandIncome =
            hasPendingIncome && _dismissedAutoIncomeMonthKey != monthKey;
        final isIncomeExpanded = _isIncomeExpanded || shouldAutoExpandIncome;

        // ── computed for BudgetMonthBar ────────────────────────────────
        final cycleEndForBar = _cycleEnd;
        final startLabel = budgetFormatShortDate(_cycleStart);
        final endLabel = budgetFormatShortDate(cycleEndForBar);
        final currentYear = DateTime.now().year;
        final showYear = _cycleStart.year != currentYear ||
            cycleEndForBar.year != currentYear;
        final yearText = showYear ? ' ${cycleEndForBar.year}' : '';
        final rangeLabel = '$startLabel — $endLabel$yearText';

        // ── computed for BudgetCycleSummaryCard ─────────────────────────
        final plannedIncome = budget.incomeSources
            .where((i) => !i.isVariable)
            .fold<double>(0, (s, i) => s + i.amount);
        final plannedAllocations = budget.allocations.fold<double>(
          0,
          (s, a) =>
              s + a.funding.fold<double>(0, (ss, f) => ss + f.plannedAmount),
        );
        final plannedJars =
            budget.linkedWallets.fold<double>(0, (s, j) => s + j.monthlyAmount);
        final plannedDebts = budget.debts.fold<double>(0, (s, d) {
          final rec = _linkedRecurringDebt(state, d);
          return s +
              BudgetRecurringPlanService.amountDueInCycle(
                debt: d,
                recurring: rec,
                cycleStart: _cycleStart,
                cycleEnd: _cycleEnd,
              );
        });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BudgetMonthBar(
              rangeLabel: rangeLabel,
              isCurrent: _isCurrentCycle(budget),
              isPast: _isPastCycle(budget),
              isFuture: _isFutureCycle(budget),
              onPrevious: () => _goToPreviousCycle(budget),
              onNext: () => _goToNextCycle(budget),
            ),
            const SizedBox(height: 12),
            BudgetHeroSummaryCard(
              totalIncomeActual: totalIncomeActual,
              totalExpenseActual: totalExpenseActual,
              remainingIncome: remainingIncome,
              plannedIncome: budget.totalIncome,
            ),
            if (pastMonth) ...[
              const SizedBox(height: 14),
              BudgetPastMonthSummaryCard(
                totalIncomeActual: totalIncomeActual,
                totalExpenseActual: totalExpenseActual,
                remainingIncome: remainingIncome,
              ),
            ],
            if (showSetupPromptOnly) ...[
              const SizedBox(height: 18),
              BudgetSetupPromptCard(
                futureMonth: futureMonth,
                isPastMonth: pastMonth,
                onSetup: _openBudgetSetupScreen,
              ),
            ] else ...[
              const SizedBox(height: 18),
              const BudgetSectionTitle(title: 'الدخل'),
              const SizedBox(height: 12),
              BudgetInlineSectionCard(
                title: 'الدخل الكلي',
                subtitle: incomeSectionChildren.length == 1 &&
                        incomeSectionChildren.first is BudgetStaticInfoCard
                    ? 'لا توجد مصادر دخل مضافة في هذه الدورة بعد'
                    : 'كل مصادر الدخل المخطط لها لهذا الشهر',
                amount: totalIncomeActual,
                isExpanded: isIncomeExpanded,
                incomeTotalLayout: true,
                onTap: () {
                  setState(() {
                    if (isIncomeExpanded) {
                      _isIncomeExpanded = false;
                      if (hasPendingIncome) {
                        _dismissedAutoIncomeMonthKey = monthKey;
                      }
                    } else {
                      _isIncomeExpanded = true;
                      _dismissedAutoIncomeMonthKey = null;
                    }
                  });
                },
                expandedChildren: incomeSectionChildren,
              ),
              const SizedBox(height: 18),
              const BudgetSectionTitle(title: 'المخصصات'),
              const SizedBox(height: 12),
              ...budget.allocations.isEmpty
                  ? <Widget>[
                      BudgetSectionEmptyCard(
                        text: 'لا يوجد مخصص في هذه الدورة.',
                        onTap: futureMonth || !pastMonth
                            ? _openBudgetSetupScreen
                            : null,
                      ),
                    ]
                  : budget.allocations.map((allocation) =>
                      _allocationSummaryTile(state, allocation, monthTx)),
              const SizedBox(height: 18),
              const BudgetSectionTitle(title: 'الحصالات'),
              const SizedBox(height: 12),
              ...budgetJars.isEmpty
                  ? const <Widget>[
                      BudgetStaticInfoCard(
                          text: 'لا توجد حصالات ممولة في هذا الشهر.')
                    ]
                  : budgetJars.map((jar) => _jarSummaryTile(jar)),
              const SizedBox(height: 18),
              const BudgetSectionTitle(title: 'الديون والأقساط'),
              const SizedBox(height: 12),
              ..._installmentCards(state, budget, monthTx),
              ..._lentCards(state, monthTx),
              const SizedBox(height: 18),
              const BudgetSectionTitle(title: 'الاشتراكات'),
              const SizedBox(height: 12),
              ..._subscriptionCards(state, budget, monthTx),
              const SizedBox(height: 18),
              const BudgetSectionTitle(title: 'ملخص الدورة'),
              const SizedBox(height: 12),
              BudgetCycleSummaryCard(
                totalIncomeActual: totalIncomeActual,
                totalExpenseActual: totalExpenseActual,
                remainingIncome: remainingIncome,
                plannedIncome: plannedIncome,
                plannedAllocations: plannedAllocations,
                plannedJars: plannedJars,
                plannedDebts: plannedDebts,
                unallocatedAmount: budget.unallocatedAmount,
                onViewAnalysis: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CycleAnalysisScreen(
                      cubit: widget.cubit,
                      cycleStart: _cycleStart,
                      cycleEnd: _cycleEnd,
                      totalIncomeActual: totalIncomeActual,
                      totalExpenseActual: totalExpenseActual,
                      remainingIncome: remainingIncome,
                      plannedIncome: plannedIncome,
                      plannedAllocations: plannedAllocations,
                      plannedJars: plannedJars,
                      plannedDebts: plannedDebts,
                    ),
                  ),
                ),
              ),
              if (!pastMonth) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _openBudgetSetupScreen,
                  icon: Icon(futureMonth
                      ? Icons.add_task_outlined
                      : Icons.edit_outlined),
                  label: Text(futureMonth
                      ? 'إعداد الميزانية الشهرية'
                      : 'تعديل الميزانية الشهرية'),
                ),
              ],
            ],
          ],
        );
      },
    );
  }


  List<TransactionEntity> _monthTransactions(List<TransactionEntity> tx) {
    final end = _cycleEnd;
    return tx
        .where((t) =>
            !t.createdAt.isBefore(_cycleStart) &&
            !t.createdAt.isAfter(end) &&
            !_isJarReserveTx(t))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  BudgetSetupEntity _budgetForMonth(AppStateEntity state) {
    final budget = state.budgetSetup;

    // الدورة الحالية: دايمًا نستخدم budgetSetup الحالي لضمان ظهور آخر التحديثات
    if (_isCurrentCycle(budget)) return state.budgetSetup;

    final cycleKey = budget.cycleKeyFor(_cycleStart);

    // جرب الـ snapshot الجديد بمفتاح الدورة
    final cycleSnapshot = state.monthlyBudgetSnapshots[cycleKey];
    if (cycleSnapshot != null && cycleSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(cycleSnapshot);
    }

    // fallback: مفتاح الشهر القديم للتوافق مع البيانات السابقة
    final oldKey =
        '${_cycleStart.year}-${_cycleStart.month.toString().padLeft(2, '0')}';
    final oldSnapshot = state.monthlyBudgetSnapshots[oldKey];
    if (oldSnapshot != null && oldSnapshot.isNotEmpty) {
      return BudgetSetupEntity.fromMap(oldSnapshot);
    }

    final end = _cycleEnd;
    for (final log in state.logs) {
      if (log.timestamp.isAfter(end)) continue;
      try {
        final map = jsonDecode(log.afterState) as Map<String, dynamic>;
        return AppStateEntity.fromMap(map).budgetSetup;
      } catch (_) {
        continue;
      }
    }
    return state.budgetSetup;
  }

  bool _isFutureMonth() => _isFutureCycle(widget.cubit.state.budgetSetup);

  bool _isPastMonth() => _isPastCycle(widget.cubit.state.budgetSetup);

  bool _hasBudgetPlan(BudgetSetupEntity budget) {
    final hasUserConfiguredJar = budget.linkedWallets.any(
      (jar) =>
          jar.id != 'linked-savings-default' ||
          jar.monthlyAmount > 0 ||
          jar.balance > 0 ||
          jar.funding.isNotEmpty,
    );
    return budget.incomeSources.isNotEmpty ||
        budget.allocations.isNotEmpty ||
        budget.debts.isNotEmpty ||
        hasUserConfiguredJar ||
        budget.totalIncome > 0 ||
        budget.totalAllocated > 0 ||
        budget.unallocatedAmount > 0;
  }

  void _openBudgetSetupScreen() {
    final futureMonth = _isFutureMonth();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(
              futureMonth ? 'إعداد خطة الشهر القادم' : 'تعديل خطة الميزانية',
            ),
          ),
          body: BudgetSetupScreen(
            cubit: widget.cubit,
            displayMonth: _month,
          ),
        ),
      ),
    );
  }




  String _monthWordLabel(DateTime date) {
    return budgetFormatMediumDate(date);
  }

  String _recurrenceLabel(String pattern) {
    if (pattern == RecurrencePattern.daily.value) return 'يومي';
    if (pattern == RecurrencePattern.weekly.value) return 'أسبوعي';
    if (pattern == RecurrencePattern.biweekly.value) return 'كل أسبوعين';
    if (pattern == RecurrencePattern.every3Weeks.value) return 'كل 3 أسابيع';
    if (pattern == RecurrencePattern.monthly.value) return 'شهري';
    if (pattern == RecurrencePattern.every2Months.value) return 'كل شهرين';
    if (pattern == RecurrencePattern.every3Months.value) return 'كل 3 شهور';
    if (pattern == RecurrencePattern.every6Months.value) return 'كل 6 شهور';
    if (pattern == RecurrencePattern.yearly.value) return 'سنوي';
    return pattern;
  }


  Color _usageProgressColor(double ratio) {
    final value = ratio.clamp(0.0, 1.0).toDouble();
    if (value <= 0.4) {
      return Color.lerp(
            kBudgetIncomeGreenMed,
            kBudgetWarningYellow,
            value / 0.4,
          ) ??
          kBudgetIncomeGreenMed;
    }
    if (value <= 0.7) {
      return Color.lerp(
            kBudgetWarningYellow,
            kBudgetWarningOrange,
            (value - 0.4) / 0.3,
          ) ??
          kBudgetWarningYellow;
    }
    return Color.lerp(
          kBudgetWarningOrange,
          kBudgetDangerRed,
          (value - 0.7) / 0.3,
        ) ??
        kBudgetDangerRed;
  }

  // Widget _trackingSheetGrabHandle(ThemeData theme) {
  //   return Center(
  //     child: Container(
  //       width: 40,
  //       height: 4,
  //       margin: const EdgeInsets.only(bottom: 14),
  //       decoration: BoxDecoration(
  //         color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
  //         borderRadius: BorderRadius.circular(kBudgetRadiusPill),
  //       ),
  //     ),
  //   );
  // }

  // Widget _trackingSheetTransactionsHeader(ThemeData theme) {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Divider(
  //         height: 32,
  //         thickness: 1,
  //         color: theme.colorScheme.outlineVariant,
  //       ),
  //       Text(
  //         'معاملات الشهر',
  //         style: theme.textTheme.titleSmall?.copyWith(
  //           fontWeight: FontWeight.w900,
  //         ),
  //       ),
  //       const SizedBox(height: 10),
  //     ],
  //   );
  // }


  Widget _trackingMonthTransactionTile(
    BuildContext sheetContext,
    ThemeData theme,
    TransactionEntity item,
  ) {
    return SharedTransactionCard(
      transaction: item,
      appState: widget.cubit.state,
      grouped: true,
      onTap: () {
        Navigator.pop(sheetContext);
        final parentContext = context;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          openTransactionDetailsSheet(
            parentContext,
            cubit: widget.cubit,
            transaction: item,
          );
        });
      },
    );
  }
  // Widget _trackingSheetTxList(
  //   BuildContext sheetContext,
  //   ThemeData theme,
  //   List<TransactionEntity> transactions,
  //   String emptyMessage,
  // ) {
  //   return Column(
  //     children: [
  //       ...transactions.map(
  //         (item) => _trackingMonthTransactionTile(sheetContext, theme, item),
  //       ),
  //       if (transactions.isEmpty)
  //         Padding(
  //           padding: const EdgeInsets.symmetric(vertical: 12),
  //           child: Text(
  //             emptyMessage,
  //             style: TextStyle(
  //               color: theme.colorScheme.onSurfaceVariant,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //         ),
  //     ],
  //   );
  // }



  bool _hasPendingIncome(
    BudgetSetupEntity budget,
    List<TransactionEntity> incomeTx,
  ) {
    final state = widget.cubit.state;
    for (final source in budget.incomeSources) {
      final sourceTx =
          incomeTx.where((t) => t.incomeSourceId == source.id).toList();
      final pendingMeta = _incomePendingMeta(state, source, sourceTx);
      if (pendingMeta?['pending'] == true) {
        return true;
      }
    }
    return false;
  }

  // bool _hasPendingDebt(
  //   AppStateEntity state,
  //   BudgetSetupEntity budget,
  //   List<TransactionEntity> monthTx,
  // ) {
  //   for (final debt in budget.debts) {
  //     final recurring = _linkedRecurringDebt(state, debt);
  //     final tx = monthTx.where((t) => t.notes?.contains(debt.name) == true);
  //     final paid = tx.fold<double>(0, (s, t) => s + t.amount);
  //     final remaining = (debt.amount - paid).clamp(0.0, debt.amount);
  //     final pendingMeta = _expensePendingMeta(recurring);
  //     if (pendingMeta?['pending'] == true && remaining > 0) {
  //       return true;
  //     }
  //   }
  //   return false;
  // }

  bool _isCurrentMonthView() => _isCurrentCycle(widget.cubit.state.budgetSetup);

  RecurringTransactionEntity? _linkedRecurringIncome(
    AppStateEntity state,
    IncomeSourceEntity source,
  ) {
    final linked = state.recurringTransactions.where(
      (item) =>
          item.type == TransactionType.income.value &&
          item.budgetScope == BudgetScope.withinBudget.value &&
          (item.incomeSourceId == source.id ||
              ((item.incomeSourceId ?? '').isEmpty &&
                  item.name == source.name &&
                  item.walletId == source.targetWalletId)),
    );
    if (linked.isEmpty) {
      return null;
    }
    return linked.first;
  }

  Map<String, dynamic>? _incomePendingMeta(
    AppStateEntity state,
    IncomeSourceEntity source,
    List<TransactionEntity> sourceTx,
  ) {
    if (source.isVariable || sourceTx.isNotEmpty || !_isCurrentMonthView()) {
      return null;
    }
    final recurring = _linkedRecurringIncome(state, source);
    final dueDate = _incomeDueDateForMonth(source, _month);
    final reminderLeadDays = (recurring?.reminderLeadDays ?? 0).clamp(0, 3);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = dueDate.subtract(Duration(days: reminderLeadDays));
    final canEarly = reminderLeadDays > 0 &&
        !today.isBefore(reminderDate) &&
        today.isBefore(dueDate);
    final isDueOrLate = !today.isBefore(dueDate);
    if (!canEarly && !isDueOrLate) return null;

    // ── snooze check ──────────────────────────────────────────────────────
    if (source.isSnoozed) {
      final until = source.snoozedUntilDate!;
      return <String, dynamic>{
        'pending': false,
        'snoozed': true,
        'canEarly': false,
        'isDueOrLate': isDueOrLate,
        'status': 'مؤجل حتى ${DateFormat('d/M - HH:mm', 'ar').format(until)}',
        'dateLabel': '${dueDate.day}/${dueDate.month}',
        'timeLabel': null,
      };
    }

    final dateLabel = '${dueDate.day}/${dueDate.month}';
    final timeLabel = recurring?.scheduledTime?.isNotEmpty == true
        ? recurring!.scheduledTime!
        : null;
    final status = isDueOrLate
        ? 'مستحق الآن • $dateLabel${timeLabel == null ? '' : ' • $timeLabel'}'
        : 'بكر • $dateLabel${timeLabel == null ? '' : ' • $timeLabel'}';
    return <String, dynamic>{
      'pending': true,
      'snoozed': false,
      'canEarly': canEarly,
      'isDueOrLate': isDueOrLate,
      'status': status,
      'dateLabel': dateLabel,
      'timeLabel': timeLabel,
    };
  }


  double _incomeDisplayPool(IncomeSourceEntity source, double received) {
    if (source.isVariable) return 0;
    return received > 0 ? received : source.amount;
  }

  double _spentAttributedToIncomeSource(
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
    String incomeSourceId,
  ) {
    final counted = <String>{};
    var total = 0.0;

    for (final alloc in budget.allocations) {
      final fromThis = alloc.funding
          .where((f) => f.incomeSourceId == incomeSourceId)
          .fold<double>(0, (s, f) => s + f.plannedAmount);
      if (fromThis <= 0) continue;
      final plannedTotal =
          alloc.funding.fold<double>(0, (s, f) => s + f.plannedAmount);
      if (plannedTotal <= 0) continue;
      final share = fromThis / plannedTotal;
      for (final t in monthTx.where((x) =>
          x.type == TransactionType.expense.value &&
          x.allocationId == alloc.id)) {
        counted.add(t.id);
        total += t.amount * share;
      }
    }

    for (final debt in budget.debts) {
      if (debt.fundingSource != incomeSourceId) continue;
      for (final t in monthTx.where((x) =>
          x.type == TransactionType.expense.value &&
          x.notes?.contains(debt.name) == true)) {
        if (!counted.contains(t.id)) {
          counted.add(t.id);
          total += t.amount;
        }
      }
    }

    return total;
  }

  double? _incomeRemainingProgress(
    IncomeSourceEntity source,
    double received,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) {
    if (source.isVariable) return null;
    final pool = _incomeDisplayPool(source, received);
    if (pool <= 0) return null;
    final spent = _spentAttributedToIncomeSource(budget, monthTx, source.id);
    final ratio = ((pool - spent) / pool).clamp(0.0, 1.0);
    return ratio;
  }

  List<TransactionEntity> _monthTransactionsForIncomeSource(
    List<TransactionEntity> sourceIncomeTx,
  ) {
    final incomeOnly = [...sourceIncomeTx];
    incomeOnly.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return incomeOnly;
  }

  List<Widget> _incomeInlineCards(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> incomeTx,
    List<TransactionEntity> monthTx,
  ) {
    final children = <Widget>[
      ...budget.incomeSources.map((source) {
        final sourceTx =
            incomeTx.where((t) => t.incomeSourceId == source.id).toList();
        final received = sourceTx.fold<double>(0, (s, t) => s + t.amount);
        final recurring = _linkedRecurringIncome(state, source);
        final pendingMeta = _incomePendingMeta(state, source, sourceTx);
        final isSnoozed = pendingMeta?['snoozed'] == true;
        final displayedAmount = received <= 0 ? source.amount : received;
        final pool = _incomeDisplayPool(source, received);
        final spent =
            _spentAttributedToIncomeSource(budget, monthTx, source.id);
        final afterSpend = (pool - spent).clamp(0.0, pool);
        final remProgress =
            _incomeRemainingProgress(source, received, budget, monthTx);
        final sourceAccent = BudgetIconBadge.colorFromHex(recurring?.iconColor ?? '#165b47');
        final incomeProgressColor = remProgress == null
            ? sourceAccent
            : _usageProgressColor(1 - remProgress);

        // ── snooze chip ──────────────────────────────────────────────────
        Widget? snoozeChip;
        if (isSnoozed) {
          snoozeChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kBudgetPendingAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(kBudgetRadiusL),
              border: Border.all(
                color: kBudgetPendingAmber.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 13, color: kBudgetPendingAmber),
                const SizedBox(width: 4),
                Text(
                  pendingMeta!['status'] as String,
                  style: const TextStyle(
                    fontSize: 11,
                    color: kBudgetPendingAmber,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        return BudgetEntityTile(
          title: source.name,
          leading: BudgetIconBadge(
            recurring?.icon ?? 'cash',
            recurring?.iconColor ?? '#165b47',
            // حجم أصغر لو مأجل
            size: isSnoozed ? 44 : 54,
            solid: true,
          ),
          amountText: displayedAmount.truncate().toString(),
          metaText: source.isVariable
              ? 'غير ثابت'
              : _monthWordLabel(_incomeDueDateForMonth(source, _month)),
          trailingTopText: recurring?.scheduledTime?.isNotEmpty == true
              ? recurring!.scheduledTime!
              : null,
          supportingText: source.isVariable ? 'دخل غير ثابت' : null,
          supportingCustom: isSnoozed
              ? snoozeChip
              : source.isVariable
                  ? null
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'الباقي',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color.lerp(sourceAccent, Colors.black, 0.35),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          afterSpend.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 11,
                            color: Color.lerp(sourceAccent, Colors.black, 0.35),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
          tint: isSnoozed ? kBudgetPendingAmber : sourceAccent,
          amountColor: Color.lerp(
              isSnoozed ? kBudgetPendingAmber : sourceAccent,
              Colors.black,
              0.35),
          strongTint: !isSnoozed,
          compactMeta: source.isVariable || isSnoozed,
          progress: isSnoozed ? null : remProgress,
          progressColor: incomeProgressColor,
          onTap: () =>
              _openIncomeDetailsSheet(source, sourceTx, budget, monthTx),
          actions: (pendingMeta == null || isSnoozed)
              ? isSnoozed
                  ? <Widget>[
                      BudgetCompactActionButton(
                        label: 'إلغاء التأجيل',
                        filled: false,
                        onPressed: () async {
                          final setup = widget.cubit.state.budgetSetup;
                          final updated = setup.incomeSources.map((i) {
                            if (i.id != source.id) return i;
                            return i.copyWith(snoozedUntil: '');
                          }).toList();
                          await widget.cubit.updateBudgetSetup(
                            setup.copyWith(incomeSources: updated),
                          );
                        },
                      ),
                    ]
                  : const <Widget>[]
              : <Widget>[
                  if (pendingMeta['canEarly'] == true)
                    BudgetCompactActionButton(
                      label: 'بكر',
                      filled: false,
                      onPressed: () =>
                          _recordIncomeFromTracking(source, early: true),
                    ),
                  if (pendingMeta['isDueOrLate'] == true)
                    BudgetCompactActionButton(
                      label: 'نزول',
                      onPressed: () => _recordIncomeFromTracking(source),
                    ),
                  if (pendingMeta['isDueOrLate'] == true)
                    BudgetCompactActionButton(
                      label: 'تأجيل',
                      filled: false,
                      onPressed: () => _postponeIncome(source),
                    ),
                ],
        );
      }),
      ...incomeTx.where((t) => t.incomeSourceId == null).map(
            (t) => BudgetEntityTile(
              title: t.notes?.isNotEmpty == true ? t.notes! : 'دخل إضافي',
              leading: BudgetIconBadge('cash', '#165b47', size: 54, solid: true),
              amountText: t.amount.toStringAsFixed(2),
              metaText: budgetFormatMediumDate(t.createdAt),
              trailingTopText: DateFormat('HH:mm', 'ar').format(t.createdAt),
              tint: kBudgetIncomeGreen,
              strongTint: true,
              amountColor: kBudgetIncomeGreen,
              onTap: () => _openTxSheet(title: 'دخل إضافي', tx: [t]),
            ),
          ),
    ];
    if (children.isEmpty) {
      children.add(const BudgetStaticInfoCard(
          text: 'لا يوجد دخل مسجل أو مخطط في هذه الدورة.'));
    }
    return children;
  }

  Widget _allocationSummaryTile(AppStateEntity state,
      AllocationEntity allocation, List<TransactionEntity> monthTx) {
    final planned =
        allocation.funding.fold<double>(0, (s, f) => s + f.plannedAmount);
    final funded = allocation.funding.fold<double>(0, (sum, f) {
      final incomeReceived = monthTx
          .where((t) =>
              t.type == TransactionType.income.value &&
              t.incomeSourceId == f.incomeSourceId)
          .fold<double>(0, (s, t) => s + t.amount);
      return sum +
          (incomeReceived <= f.plannedAmount
              ? incomeReceived
              : f.plannedAmount);
    });
    final spent = monthTx
        .where((t) =>
            t.type == TransactionType.expense.value &&
            t.allocationId == allocation.id)
        .fold<double>(0, (s, t) => s + t.amount);
    final remaining = funded - spent;
    final ratio = funded <= 0 ? 0.0 : (remaining / funded).clamp(0.0, 1.0);
    final color = _usageProgressColor(1 - ratio);
    final hasPending = allocation.pendingDistribution > 0;

    Widget? pendingChip;
    if (hasPending) {
      pendingChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kBudgetPendingAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(kBudgetRadiusL),
          border: Border.all(
            color: kBudgetPendingAmber.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 13, color: kBudgetPendingAmber),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'ينتظر تأكيد تحويل ${allocation.pendingDistribution.toStringAsFixed(0)} ج.م',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: kBudgetPendingAmber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return BudgetEntityTile(
      title: allocation.name,
      leading: BudgetIconBadge(
        allocation.icon,
        allocation.iconColor,
        size: hasPending ? 44 : 54,
        solid: true,
      ),
      amountText: hasPending
          ? allocation.pendingDistribution.toStringAsFixed(2)
          : remaining.toStringAsFixed(2),
      metaText: 'المخطط ${planned.toStringAsFixed(2)}',
      supportingText: hasPending ? null : 'المتاح ${funded.toStringAsFixed(2)}',
      supportingCustom: pendingChip,
      compactMeta: hasPending,
      progress: hasPending ? null : ratio,
      progressColor: hasPending ? null : color,
      tint: hasPending
          ? kBudgetPendingAmber
          : BudgetIconBadge.colorFromHex(allocation.iconColor),
      amountColor:
          Color.lerp(BudgetIconBadge.colorFromHex(allocation.iconColor), Colors.black, 0.35),
      strongTint: true,
      onTap: () => _openAllocationSheet(state, allocation, monthTx),
      actions: hasPending
          ? [
              BudgetCompactActionButton(
                label: 'تأكيد التحويل',
                onPressed: () async {
                  await widget.cubit
                      .confirmAllocationDistribution(allocation.id);
                },
              ),
              BudgetCompactActionButton(
                label: 'تأجيل',
                filled: false,
                onPressed: () async {
                  await widget.cubit
                      .postponeAllocationDistribution(allocation.id);
                },
              ),
            ]
          : [],
    );
  }

  Widget _jarSummaryTile(LinkedWalletEntity jar) {
    final hasPending = jar.pendingDistribution > 0;
    final budgetAllocated = jar.funding.isNotEmpty
        ? jar.funding.fold<double>(0, (s, f) => s + f.plannedAmount)
        : jar.monthlyAmount;
    final jarAccent = BudgetIconBadge.colorFromHex(jar.iconColor);

    Widget? pendingChip;
    if (hasPending) {
      pendingChip = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kBudgetPendingAmber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(kBudgetRadiusL),
          border: Border.all(
            color: kBudgetPendingAmber.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded,
                size: 13, color: kBudgetPendingAmber),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'ينتظر تأكيد تحويل ${jar.pendingDistribution.toStringAsFixed(0)} ج.م',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: kBudgetPendingAmber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return BudgetEntityTile(
      title: jar.name,
      leading: BudgetIconBadge(
        jar.icon,
        jar.iconColor,
        size: hasPending ? 44 : 54,
        solid: true,
      ),
      amountText: jar.balance.toStringAsFixed(2),
      metaText: 'مخصص من الميزانية ${budgetAllocated.toStringAsFixed(2)}',
      supportingText: hasPending ? null : 'الرصيد الحالي',
      supportingCustom: pendingChip,
      compactMeta: hasPending,
      tint: hasPending ? kBudgetPendingAmber : jarAccent,
      amountColor: Color.lerp(
        hasPending ? kBudgetPendingAmber : jarAccent,
        Colors.black,
        0.35,
      ),
      strongTint: !hasPending,
      onTap: () => _openJarDetailsSheet(jar),
      actions: hasPending
          ? [
              BudgetCompactActionButton(
                label: 'تأكيد التحويل',
                onPressed: () async {
                  await widget.cubit.confirmJarDistribution(jar.id);
                },
              ),
              BudgetCompactActionButton(
                label: 'تأجيل',
                filled: false,
                onPressed: () async {
                  await widget.cubit.postponeJarDistribution(jar.id);
                },
              ),
            ]
          : [],
    );
  }

  Future<void> _openJarDetailsSheet(LinkedWalletEntity jar) {
    return showJarDetailsSheet(
      context: context,
      cubit: widget.cubit,
      jarId: jar.id,
      onEditJar: (_) => _openBudgetSetupScreen(),
    );
  }

  List<Widget> _installmentCards(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) {
    final installments = budget.debts.where((d) => d.isInstallment).toList();
    if (installments.isEmpty) {
      return [const BudgetStaticInfoCard(text: 'لا توجد ديون أو أقساط مسجلة.')];
    }
    final widgets = <Widget>[];
    for (final debt in installments) {
      final recurring = _linkedRecurringDebt(state, debt);
      final allDebtTx = _allDebtPayments(state, debt);
      final paid = allDebtTx.fold<double>(0, (s, t) => s + t.amount);
      final principal = debt.principalTotal ?? debt.amount;
      final remaining = (principal - paid).clamp(0.0, principal);
      final paidRatio =
          principal <= 0 ? 0.0 : (paid / principal).clamp(0.0, 1.0);
      final pct = (paidRatio * 100).round().clamp(0, 100);
      final monthPaid = monthTx
          .where((t) => _transactionCountsTowardDebt(t, debt))
          .fold<double>(0, (s, t) => s + t.amount);
      final pendingMeta = _expensePendingMeta(recurring);
      final isSnoozed = pendingMeta?['snoozed'] == true;
      final isPending =
          pendingMeta?['pending'] == true && monthPaid < debt.amount;
      final remainingInstallments =
          debt.amount > 0 ? ((remaining - monthPaid) / debt.amount).ceil() : 0;
      widgets.add(BudgetEntityTile(
        title: debt.name,
        leading: BudgetIconBadge(
          recurring?.icon ?? 'receipt',
          recurring?.iconColor ?? '#c65d2e',
          size: 54,
        ),
        amountText: remaining.toStringAsFixed(2),
        metaText:
            '$pct% مسدد · القسط ${debt.amount.toStringAsFixed(2)} · ${remainingInstallments > 0 ? '$remainingInstallments قسط متبقي' : 'مكتمل'}',
        supportingText: 'الأصل ${principal.toStringAsFixed(2)}',
        progress: paidRatio,
        progressColor: Colors.green,
        tint: isPending ? kBudgetDangerOrange : null,
        onTap: () => _openDebtDetailsSheet(debt, allDebtTx, remaining),
        actions: recurring == null
            ? <Widget>[]
            : isSnoozed
                ? <Widget>[
                    BudgetCompactActionButton(
                      label: 'إلغاء التأجيل',
                      filled: false,
                      onPressed: () => _clearDebtPostpone(recurring),
                    ),
                  ]
                : isPending
                    ? <Widget>[
                        BudgetCompactActionButton(
                          label: 'تسديد الآن',
                          onPressed: () {
                            _confirmDebtPayment(state, budget, debt, recurring);
                          },
                        ),
                        BudgetCompactActionButton(
                          label: 'تأجيل',
                          filled: false,
                          onPressed: () => _postponeDebt(recurring),
                        ),
                      ]
                    : <Widget>[],
      ));
    }
    return widgets;
  }

  List<Widget> _lentCards(
    AppStateEntity state,
    List<TransactionEntity> monthTx,
  ) {
    final allLent = state.recurringTransactions.where((r) => r.isLent).toList();
    if (allLent.isEmpty) return [];

    final cycleEnd = _cycleEnd;

    // الأشخاص اللي حصل ليهم نشاط (سلفة أو استرداد) في الدورة دي
    final cycleLentPersons = allLent.where((r) {
      final name = r.lentPersonName ?? r.name;
      return state.transactions.any((t) =>
          ((t.notes?.contains('سلفة لـ $name') ?? false) ||
              (t.notes?.contains('استرداد سلفة من $name') ?? false)) &&
          !t.createdAt.isBefore(_cycleStart) &&
          !t.createdAt.isAfter(cycleEnd));
    }).toList();

    if (cycleLentPersons.isEmpty) return [];

    // إجمالي اللي اتسلف في الدورة دي (Outflow)
    double cycleTotalOut = 0;
    for (final person in cycleLentPersons) {
      final name = person.lentPersonName ?? person.name;
      final txs = state.transactions.where((t) =>
          t.type == TransactionType.expense.value &&
          (t.notes?.contains('سلفة لـ $name') ?? false) &&
          !t.createdAt.isBefore(_cycleStart) &&
          !t.createdAt.isAfter(cycleEnd));
      cycleTotalOut += txs.fold(0.0, (s, t) => s + t.amount);
    }

    final hasOverdueGlobal = cycleLentPersons.any((r) =>
        r.hasOutstandingLent &&
        r.lentEntries.any((e) {
          if (e['isSettled'] == true) return false;
          final retStr = e['expectedReturnDate'] as String?;
          if (retStr == null) return false;
          final d = DateTime.tryParse(retStr);
          return d != null && d.isBefore(DateTime.now());
        }));

    final childTiles = cycleLentPersons.map((record) {
      final personName = record.lentPersonName ?? record.name;

      // نشاط الشخص ده في الدورة دي
      final personCycleTxs = state.transactions
          .where((t) =>
              ((t.notes?.contains('سلفة لـ $personName') ?? false) ||
                  (t.notes?.contains('استرداد سلفة من $personName') ??
                      false)) &&
              !t.createdAt.isBefore(_cycleStart) &&
              !t.createdAt.isAfter(cycleEnd))
          .toList();

      final out = personCycleTxs
          .where((t) => t.type == TransactionType.expense.value)
          .fold(0.0, (s, t) => s + t.amount);
      final inc = personCycleTxs
          .where((t) => t.type == TransactionType.income.value)
          .fold(0.0, (s, t) => s + t.amount);

      final isOverdue = record.hasOutstandingLent &&
          record.lentEntries.any((e) {
            if (e['isSettled'] == true) return false;
            final retStr = e['expectedReturnDate'] as String?;
            if (retStr == null) return false;
            final d = DateTime.tryParse(retStr);
            return d != null && d.isBefore(DateTime.now());
          });

      String activityLabel = '';
      if (out > 0 && inc > 0) {
        activityLabel =
            'سلفة ${out.toStringAsFixed(0)} • استرداد ${inc.toStringAsFixed(0)}';
      } else if (out > 0) {
        activityLabel = 'سلفة ${out.toStringAsFixed(0)}';
      } else if (inc > 0) {
        activityLabel = 'استرداد ${inc.toStringAsFixed(0)}';
      }

      final balanceLabel =
          'المتبقي: ${record.outstandingLentAmount.toStringAsFixed(0)}';
      final statusLabel = isOverdue ? ' · متأخر ⚠️' : '';

      return BudgetEntityTile(
        title: personName,
        leading: BudgetIconBadge(
          record.icon.isEmpty ? 'handshake' : record.icon,
          record.iconColor.isEmpty ? '#1a7a4a' : record.iconColor,
          size: 48,
        ),
        amountText: out > 0 ? out.toStringAsFixed(2) : inc.toStringAsFixed(2),
        metaText: '$activityLabel\n$balanceLabel$statusLabel',
        tint: isOverdue
            ? kBudgetDangerOrange
            : (out > 0 ? null : kBudgetLentGreen),
        onTap: () => _openBudgetLentDetailsSheet(record, state),
        embeddedInIncomeCard: true,
        actions: const [],
      );
    }).toList();

    final theme = Theme.of(context);
    return [
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(kBudgetRadiusCard),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(kBudgetRadiusCard),
            onTap: () => setState(() => _isLentExpanded = !_isLentExpanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      BudgetIconBadge('handshake', '#1a7a4a', size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'سلف للناس',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${cycleLentPersons.length} نشاط سلف'
                              '${hasOverdueGlobal ? ' · يوجد متأخرات ⚠️' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: hasOverdueGlobal
                                    ? kBudgetDangerOrange
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            cycleTotalOut.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: kBudgetIncomeGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            _isLentExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_isLentExpanded) ...[
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 8),
                    ...childTiles,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  Future<void> _openBudgetLentDetailsSheet(
    RecurringTransactionEntity person,
    AppStateEntity state,
  ) async {
    const accent = kBudgetLentGreen;
    final personName = person.lentPersonName ?? person.name;
    final theme = Theme.of(context);

    // كل معاملات الشخص ده (سلف + استردادات)
    final allPersonTxs = state.transactions
        .where(
          (t) =>
              (t.notes?.contains('سلفة لـ $personName') ?? false) ||
              (t.notes?.contains('استرداد سلفة من $personName') ?? false),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => BudgetDraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: allPersonTxs,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات مسجلة لهذا الشخص في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          // ── Hero Shell: بيانات الشخص + زر الإعداد ──────────────────
          BudgetTrackingDetailHeroShell(
            accent: accent,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _openLentSettingsFromBudget(person, widget.cubit.state);
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BudgetIconBadge(
                    person.icon.isEmpty ? 'handshake' : person.icon,
                    person.iconColor.isEmpty ? '#1a7a4a' : person.iconColor,
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          personName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        StreamBuilder<AppStateEntity>(
                          stream: widget.cubit.stream,
                          initialData: widget.cubit.state,
                          builder: (_, snap) {
                            final s = snap.data ?? widget.cubit.state;
                            final cur = s.recurringTransactions
                                    .where((r) => r.id == person.id)
                                    .cast<RecurringTransactionEntity?>()
                                    .firstWhere((_) => true,
                                        orElse: () => null) ??
                                person;
                            final pending = cur.lentEntries
                                .where((e) => e['isSettled'] != true)
                                .length;
                            return Text(
                              'إجمالي غير مسترد: ${cur.outstandingLentAmount.toStringAsFixed(2)} ج.م · $pending معلق',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder<AppStateEntity>(
                    stream: widget.cubit.stream,
                    initialData: widget.cubit.state,
                    builder: (_, snap) {
                      final s = snap.data ?? widget.cubit.state;
                      final cur = s.recurringTransactions
                              .where((r) => r.id == person.id)
                              .cast<RecurringTransactionEntity?>()
                              .firstWhere((_) => true, orElse: () => null) ??
                          person;
                      return Text(
                        cur.outstandingLentAmount.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── كارت السلفات المعلقة القابل للتوسيع ─────────────────
              StreamBuilder<AppStateEntity>(
                stream: widget.cubit.stream,
                initialData: widget.cubit.state,
                builder: (_, snap) {
                  final s = snap.data ?? widget.cubit.state;
                  final cur = s.recurringTransactions
                          .where((r) => r.id == person.id)
                          .cast<RecurringTransactionEntity?>()
                          .firstWhere((_) => true, orElse: () => null) ??
                      person;
                  return BudgetLentPendingCard(
                    theme: theme,
                    accent: accent,
                    person: cur,
                    cubit: widget.cubit,
                    sheetCtx: sheetContext,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// فتح إعدادات السلف: إضافة سلفة جديدة لنفس الشخص
  Future<void> _openLentSettingsFromBudget(
    RecurringTransactionEntity person,
    AppStateEntity state,
  ) async {
    // نفتح شيت إضافة سلفة جديدة لنفس الشخص
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String walletId = person.walletId.isNotEmpty
        ? person.walletId
        : (state.wallets.isNotEmpty ? state.wallets.first.id : '');
    DateTime lentDate = DateTime.now();
    DateTime returnDate = DateTime.now().add(const Duration(days: 30));
    const accent = kBudgetLentGreen;
    final personName = person.lentPersonName ?? person.name;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(kBudgetRadiusPill),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kBudgetLentDialogGradientDark, kBudgetLentDialogGradientLight],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(kBudgetRadiusXL),
                  ),
                  child: Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                          child: Icon(Icons.person_rounded,
                              color: Colors.white, size: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('سلفة جديدة لـ $personName',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16)),
                          const Text('المبلغ يُخصم من المحفظة فوراً',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                        ])),
                  ]),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                if (state.wallets.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(kBudgetRadiusM),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: walletId.isEmpty ? null : walletId,
                        isExpanded: true,
                        hint: const Text('اختر المحفظة'),
                        items: state.wallets
                            .map((w) => DropdownMenuItem(
                                value: w.id, child: Text(w.name)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setS(() => walletId = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(kBudgetRadiusM),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: lentDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => lentDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(kBudgetRadiusM),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_month_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                          'تاريخ السلفة: ${lentDate.day}/${lentDate.month}/${lentDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(kBudgetRadiusM),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: returnDate,
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (d != null) setS(() => returnDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(kBudgetRadiusM),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_month_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                          'تاريخ الاسترداد المتوقع: ${returnDate.day}/${returnDate.month}/${returnDate.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      final amount =
                          double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amount <= 0 || walletId.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('أدخل المبلغ والمحفظة')),
                        );
                        return;
                      }
                      Navigator.pop(ctx);
                      await widget.cubit.addLentRecord(
                        personName: personName,
                        amount: amount,
                        walletId: walletId,
                        lentDate: lentDate,
                        expectedReturnDate: returnDate,
                        existingPersonId: person.id,
                        notes: notesCtrl.text.trim().isEmpty
                            ? null
                            : notesCtrl.text.trim(),
                      );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('تسجيل السلفة',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
  }

  List<Widget> _subscriptionCards(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) {
    final subscriptions = budget.debts.where((d) => d.isSubscription).toList();
    if (subscriptions.isEmpty) {
      return [const BudgetStaticInfoCard(text: 'لا توجد اشتراكات مسجلة.')];
    }
    final widgets = <Widget>[];
    for (final debt in subscriptions) {
      final recurring = _linkedRecurringDebt(state, debt);
      final cycleDates = BudgetRecurringPlanService.occurrenceDatesInCycle(
        debt: debt,
        recurring: recurring,
        cycleStart: _cycleStart,
        cycleEnd: _cycleEnd,
      );
      final isDueThisCycle = cycleDates.isNotEmpty;
      if (!isDueThisCycle) continue;

      final amountPerOccurrence =
          BudgetRecurringPlanService.amountPerOccurrence(
        debt: debt,
        recurring: recurring,
      );
      final cycleDue = amountPerOccurrence * cycleDates.length;
      final cyclePaid = monthTx
          .where((t) => _transactionCountsTowardDebt(t, debt))
          .fold<double>(0, (s, t) => s + t.amount);

      int paidCount = amountPerOccurrence > 0
          ? (cyclePaid / amountPerOccurrence).floor()
          : 0;
      if (paidCount > cycleDates.length) paidCount = cycleDates.length;

      final pendingDates = cycleDates.skip(paidCount).toList();
      final isFullyPaid = pendingDates.isEmpty;
      final nextDate = isFullyPaid ? null : pendingDates.first;

      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      final pendingMeta = _expensePendingMeta(recurring);
      final isSnoozed = pendingMeta?['snoozed'] == true;

      bool isDueOrLate = false;
      if (nextDate != null) {
        final nextMidnight =
            DateTime(nextDate.year, nextDate.month, nextDate.day);
        isDueOrLate = !todayMidnight.isBefore(nextMidnight);
      }
      final shouldShowDecision =
          pendingMeta?['pending'] == true && !isFullyPaid;

      String metaText;
      final amountLabel = amountPerOccurrence <= 0
          ? 'مجاني'
          : amountPerOccurrence.toStringAsFixed(2);
      if (isFullyPaid) {
        metaText = 'تم السداد ✓';
      } else {
        final nextStr = '${nextDate!.day}/${nextDate.month}';
        if (cycleDates.length > 1) {
          metaText = 'استحقاق يوم $nextStr · $amountLabel لكل مرة';
        } else {
          metaText = 'استحقاق يوم $nextStr · $amountLabel';
        }
      }

      widgets.add(BudgetEntityTile(
        title: debt.name,
        leading: BudgetIconBadge(
          recurring?.icon ?? 'subscriptions',
          recurring?.iconColor ?? '#4a7c59',
          size: 54,
        ),
        amountText: cycleDue <= 0 ? 'مجاني' : cycleDue.toStringAsFixed(2),
        metaText: metaText,
        supportingText: _recurrenceLabel(
            recurring?.recurrencePattern ?? debt.recurrencePattern),
        progress: cycleDue <= 0
            ? null
            : (cyclePaid / cycleDue).clamp(0.0, 1.0).toDouble(),
        progressColor: Colors.teal,
        tint: (isDueOrLate || shouldShowDecision)
            ? kBudgetDangerOrange
            : null,
        onTap: () => _openSubscriptionDetailsSheet(
          debt: debt,
          recurring: recurring,
          cycleDates: cycleDates,
          cyclePaid: cyclePaid,
          amountPerOccurrence: amountPerOccurrence,
          monthTx: monthTx,
        ),
        actions: recurring == null
            ? const <Widget>[]
            : isSnoozed
                ? <Widget>[
                    BudgetCompactActionButton(
                      label: 'إلغاء التأجيل',
                      filled: false,
                      onPressed: () => _clearDebtPostpone(recurring),
                    ),
                  ]
                : shouldShowDecision
                    ? <Widget>[
                        BudgetCompactActionButton(
                          label: 'تسديد الآن',
                          onPressed: () => _confirmDebtPayment(
                              state, budget, debt, recurring),
                        ),
                        BudgetCompactActionButton(
                          label: 'تأجيل',
                          filled: false,
                          onPressed: () => _postponeDebt(recurring),
                        ),
                      ]
                    : const <Widget>[],
      ));
    }
    if (widgets.isEmpty) {
      return [
        const BudgetStaticInfoCard(text: 'لا توجد اشتراكات مستحقة هذه الدورة.')
      ];
    }
    return widgets;
  }

  Future<void> _openSubscriptionDetailsSheet({
    required DebtEntity debt,
    required RecurringTransactionEntity? recurring,
    required List<DateTime> cycleDates,
    required double cyclePaid,
    required double amountPerOccurrence,
    required List<TransactionEntity> monthTx,
  }) async {
    final theme = Theme.of(context);
    final accent = BudgetIconBadge.colorFromHex(recurring?.iconColor ?? '#4a7c59');

    final tx = monthTx
        .where((t) => _transactionCountsTowardDebt(t, debt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    int paidCount =
        amountPerOccurrence > 0 ? (cyclePaid / amountPerOccurrence).floor() : 0;
    if (paidCount > cycleDates.length) paidCount = cycleDates.length;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => BudgetDraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: tx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات دفع لهذا الاشتراك.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          BudgetTrackingDetailHeroShell(
            accent: accent,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BudgetIconBadge(
                    recurring?.icon ?? 'subscriptions',
                    recurring?.iconColor ?? '#4a7c59',
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'استحقاقات الشهر (${cycleDates.length})',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...List.generate(cycleDates.length, (index) {
                final date = cycleDates[index];
                final isPaid = index < paidCount;
                final dateStr = '${date.day}/${date.month}';

                final today = DateTime.now();
                final todayMidnight =
                    DateTime(today.year, today.month, today.day);
                final occurrenceMidnight =
                    DateTime(date.year, date.month, date.day);
                final isDueOrLate = !todayMidnight.isBefore(occurrenceMidnight);

                final statusText =
                    isPaid ? 'مسدد ✓' : (isDueOrLate ? 'مستحق الآن' : 'قادم');
                final statusColor = isPaid
                    ? Colors.green
                    : (isDueOrLate
                        ? kBudgetDangerOrange
                        : theme.colorScheme.onSurfaceVariant);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'استحقاق $dateStr',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        amountPerOccurrence.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openAllocationSheet(
    AppStateEntity state,
    AllocationEntity allocation,
    List<TransactionEntity> monthTx,
  ) async {
    final theme = Theme.of(context);
    final accent = BudgetIconBadge.colorFromHex(allocation.iconColor);
    final planned = allocation.funding.fold<double>(
      0,
      (s, f) => s + f.plannedAmount,
    );
    final funded = allocation.funding.fold<double>(0, (sum, f) {
      final incomeReceived = monthTx
          .where((t) =>
              t.type == TransactionType.income.value &&
              t.incomeSourceId == f.incomeSourceId)
          .fold<double>(0, (s, t) => s + t.amount);
      return sum +
          (incomeReceived <= f.plannedAmount
              ? incomeReceived
              : f.plannedAmount);
    });
    final spent = monthTx
        .where((t) =>
            t.type == TransactionType.expense.value &&
            t.allocationId == allocation.id)
        .fold<double>(0, (s, t) => s + t.amount);
    final remaining = funded - spent;
    final ratio = funded <= 0 ? 0.0 : (remaining / funded).clamp(0.0, 1.0);
    final progressColor = _usageProgressColor(1 - ratio);
    final tx = state.transactions
        .where((t) => !_isJarReserveTx(t) && t.allocationId == allocation.id)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => BudgetDraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: tx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات لهذا المخصص في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          BudgetTrackingDetailHeroShell(
            accent: accent,
            strongTint: true,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _editAllocation(allocation);
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BudgetIconBadge(
                    allocation.icon,
                    allocation.iconColor,
                    size: 56,
                    solid: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          allocation.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'المخطط ${planned.toStringAsFixed(2)} · المتاح ${funded.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    remaining.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'المصروف حتى الآن: ${spent.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(kBudgetRadiusPill),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8,
                  color: progressColor,
                  backgroundColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAllocation(AllocationEntity _) async {
    final state = widget.cubit.state;
    final budget = _budgetForMonth(state);
    final result = await openAllocationEditorScreen(
      context,
      current: _,
      incomeSources: budget.incomeSources,
      idFactory: _id,
    );
    if (result == null) return;
    if (result.deleteRequested) {
      final next = budget.allocations.where((e) => e.id != _.id).toList();
      await widget.cubit.updateBudgetSetup(
        budget.copyWith(allocations: next),
      );
      return;
    }

    final updated = result.entity;
    if (updated == null) return;
    final next =
        budget.allocations.map((e) => e.id == _.id ? updated : e).toList();
    await widget.cubit.updateBudgetSetup(
      budget.copyWith(allocations: next),
    );
  }

  Future<void> _openIncomeDetailsSheet(
    IncomeSourceEntity source,
    List<TransactionEntity> sourceIncomeTx,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) async {
    final theme = Theme.of(context);
    const accent = kBudgetDefaultAccent;
    final dueDate = _incomeDueDateForMonth(source, _month);
    final received = sourceIncomeTx.fold<double>(0, (s, t) => s + t.amount);
    final displayedAmount = received <= 0 ? source.amount : received;
    final pool = _incomeDisplayPool(source, received);
    final spent = _spentAttributedToIncomeSource(budget, monthTx, source.id);
    final afterSpend = (pool - spent).clamp(0.0, pool);
    final remProgress =
        _incomeRemainingProgress(source, received, budget, monthTx);
    final pendingMeta =
        _incomePendingMeta(widget.cubit.state, source, sourceIncomeTx);
    final canEarly = pendingMeta?['canEarly'] == true;
    final isDueOrLate = pendingMeta?['isDueOrLate'] == true;
    final recurring = _linkedRecurringIncome(widget.cubit.state, source);
    final cycleTx = _monthTransactionsForIncomeSource(sourceIncomeTx);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => BudgetDraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: cycleTx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات دخل مسجلة لهذا المصدر في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          BudgetTrackingDetailHeroShell(
            accent: accent,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _editIncomeDirect(source);
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BudgetIconBadge(
                    recurring?.icon ?? 'cash',
                    recurring?.iconColor ?? '#0f9d7a',
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          source.isVariable
                              ? 'دخل غير ثابت'
                              : _monthWordLabel(dueDate),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (recurring?.scheduledTime?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              recurring!.scheduledTime!,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayedAmount.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              if (!source.isVariable) ...[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'الباقي',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      afterSpend.toStringAsFixed(2),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                if (remProgress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(kBudgetRadiusPill),
                    child: LinearProgressIndicator(
                      value: remProgress,
                      minHeight: 8,
                      color: accent,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ],
              if ((canEarly || isDueOrLate) && !source.isVariable) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (canEarly)
                      Expanded(
                        child: BudgetCompactActionButton(
                          label: 'بكر',
                          filled: false,
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Future.microtask(() {
                              if (!mounted) return;
                              _recordIncomeFromTracking(source, early: true);
                            });
                          },
                        ),
                      ),
                    if (canEarly && isDueOrLate) const SizedBox(width: 8),
                    if (isDueOrLate)
                      Expanded(
                        child: BudgetCompactActionButton(
                          label: 'نزول',
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Future.microtask(() {
                              if (!mounted) return;
                              _recordIncomeFromTracking(source);
                            });
                          },
                        ),
                      ),
                    if (isDueOrLate) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: BudgetCompactActionButton(
                          label: 'تأجيل',
                          filled: false,
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Future.microtask(() {
                              if (!mounted) return;
                              _postponeIncome(source);
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDebtDetailsSheet(
    DebtEntity debt,
    List<TransactionEntity> tx,
    double remaining,
  ) async {
    final theme = Theme.of(context);
    const accent = kBudgetDangerOrange;
    final state = widget.cubit.state;
    final budget = state.budgetSetup;
    final recurring = _linkedRecurringDebt(state, debt);
    final now = DateTime.now();
    final dueDate = debt.isSubscription && recurring != null
        ? (RecurringScheduleEngine.dueOccurrenceNow(recurring, now) ??
            RecurringScheduleEngine.nextOccurrence(recurring, now) ??
            DateTime(
              _month.year,
              _month.month,
              debt.executionDay.clamp(1, 28),
            ))
        : DateTime(
            _month.year,
            _month.month,
            debt.executionDay.clamp(1, 28),
          );
    final paid = tx.fold<double>(0, (s, t) => s + t.amount);
    final principal = debt.principalTotal ?? debt.amount;
    final dueThisCycle = BudgetRecurringPlanService.amountDueInCycle(
      debt: debt,
      recurring: recurring,
      cycleStart: _cycleStart,
      cycleEnd: _cycleEnd,
    );
    final paidRatio = debt.isSubscription
        ? (dueThisCycle <= 0 ? null : (paid / dueThisCycle).clamp(0.0, 1.0))
        : (principal <= 0 ? null : (paid / principal).clamp(0.0, 1.0));

    // حسابات دفعات القسط في هذه الدورة
    final monthTx = state.transactions
        .where((t) => _transactionCountsTowardDebt(t, debt))
        .where((t) =>
            !t.createdAt.isBefore(_cycleStart) &&
            !t.createdAt.isAfter(_cycleEnd))
        .toList();
    final monthPaid = monthTx.fold<double>(0, (s, t) => s + t.amount);
    final installmentAmt = debt.amount;
    final currentPaid = monthPaid >= installmentAmt;
    final isSinglePaymentInstallment =
        debt.installmentCount == 1 || principal <= installmentAmt;
    final nextPaid =
        isSinglePaymentInstallment || monthPaid >= installmentAmt * 2;

    final sortedTx = [...tx]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final pctLabel =
        paidRatio == null ? '0' : (paidRatio * 100).round().toString();
    final headerLabel = debt.isSubscription
        ? 'استحقاق ${_monthWordLabel(dueDate)} · ${_recurrenceLabel(recurring?.recurrencePattern ?? debt.recurrencePattern)}'
        : 'استحقاق ${_monthWordLabel(dueDate)} · الأصل ${principal.toStringAsFixed(2)}';
    final progressLabel = debt.isSubscription
        ? 'تم سداد $pctLabel٪ · المدفوع ${paid.toStringAsFixed(2)} من قيمة الدورة ${dueThisCycle.toStringAsFixed(2)}'
        : 'تم سداد $pctLabel٪ · المتبقي ${remaining.toStringAsFixed(2)} من أصل ${principal.toStringAsFixed(2)}';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => BudgetDraggableFilterableTxSheet(
        theme: theme,
        accent: accent,
        transactions: sortedTx,
        initialMonth: _month,
        emptyMessage: 'لا توجد معاملات سداد مسجلة لهذا الدين في المدة المحددة.',
        sheetContext: sheetContext,
        tileBuilder: (item) =>
            _trackingMonthTransactionTile(sheetContext, theme, item),
        topSectionAfterGrab: [
          BudgetTrackingDetailHeroShell(
            accent: accent,
            onEdit: () {
              Navigator.pop(sheetContext);
              Future.microtask(() {
                if (!mounted) return;
                _editDebtDirect(debt);
              });
            },
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  BudgetIconBadge(
                    recurring?.icon ?? 'receipt',
                    recurring?.iconColor ?? '#c65d2e',
                    size: 56,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          debt.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          headerLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    remaining.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                progressLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (paidRatio != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(kBudgetRadiusPill),
                  child: LinearProgressIndicator(
                    value: paidRatio,
                    minHeight: 8,
                    color: Colors.green,
                    backgroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.10),
                  ),
                ),
              ],
              // ── قسم الدفعات القابل للتوسع ────────────────────────────
              if (debt.isInstallment && recurring != null) ...[
                const SizedBox(height: 14),
                BudgetInstallmentPaymentsCard(
                  theme: theme,
                  debt: debt,
                  recurring: recurring,
                  installmentAmt: installmentAmt,
                  currentPaid: currentPaid,
                  nextPaid: nextPaid,
                  showNextPayment: !isSinglePaymentInstallment,
                  dueDate: dueDate,
                  onPayCurrent: () async {
                    Navigator.pop(sheetContext);
                    await _confirmDebtPayment(state, budget, debt, recurring);
                  },
                  onPayNext: () async {
                    Navigator.pop(sheetContext);
                    await _confirmDebtPayment(state, budget, debt, recurring);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editIncomeDirect(IncomeSourceEntity current) async {
    final state = widget.cubit.state;
    final wallets = state.wallets;
    final fallbackWalletId =
        wallets.isNotEmpty ? wallets.first.id : 'wallet-cash-default';
    final linkedRecurring = _linkedRecurringIncome(state, current);
    final draftRecurring = linkedRecurring ??
        RecurringTransactionEntity(
          id: '',
          name: current.name,
          type: TransactionType.income.value,
          amount: current.isVariable ? 0 : current.amount,
          dayOfMonth: current.date.clamp(1, 28),
          executionType: current.isVariable ? 'manual' : current.type,
          walletId: current.targetWalletId.isEmpty
              ? fallbackWalletId
              : current.targetWalletId,
          budgetScope: BudgetScope.withinBudget.value,
          recurrencePattern: RecurrencePattern.monthly.value,
          icon: 'cash',
          iconColor: '#0f9d7a',
          incomeSourceId: current.id,
          isVariableIncome: current.isVariable,
          isDebtOrSubscription: false,
        );

    final result =
        await Navigator.of(context).push<RecurringTransactionComposerResult>(
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: TransactionType.income.value,
          initialWithinBudget: true,
          initialRecurring: draftRecurring,
          returnOnSave: true,
          allowDelete: true,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == null) {
      return;
    }

    final setup = widget.cubit.state.budgetSetup;
    if (result.deleteRequested) {
      final linked = widget.cubit.state.recurringTransactions
          .where((r) => r.incomeSourceId == current.id)
          .toList();
      for (final recurring in linked) {
        await widget.cubit.deleteRecurringTransaction(recurring.id);
      }
      if (linked.isEmpty && linkedRecurring != null) {
        await widget.cubit.deleteRecurringTransaction(linkedRecurring.id);
      }
      final incomes =
          setup.incomeSources.where((e) => e.id != current.id).toList();
      await widget.cubit
          .updateBudgetSetup(setup.copyWith(incomeSources: incomes));
      return;
    }

    final recurring = result.recurring;
    if (recurring == null) {
      return;
    }

    final updated = IncomeSourceEntity(
      id: current.id,
      name: recurring.name,
      amount: recurring.isVariableIncome ? 0 : recurring.amount,
      date: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.isVariableIncome ? 'manual' : recurring.executionType,
      targetWalletId: recurring.walletId,
      isVariable: recurring.isVariableIncome,
      isDefault: current.isDefault,
    );
    final incomes = setup.incomeSources
        .map((e) => e.id == current.id ? updated : e)
        .toList();
    await widget.cubit
        .updateBudgetSetup(setup.copyWith(incomeSources: incomes));

    if (linkedRecurring == null) {
      await widget.cubit.addRecurringTransaction(
        name: recurring.name,
        type: recurring.type,
        amount: recurring.amount,
        dayOfMonth: recurring.dayOfMonth,
        executionType: recurring.executionType,
        walletId: recurring.walletId,
        budgetScope: recurring.budgetScope,
        recurrencePattern: recurring.recurrencePattern,
        icon: recurring.icon,
        iconColor: recurring.iconColor,
        weekday: recurring.weekday,
        weekdays: recurring.weekdays,
        monthOfYear: recurring.monthOfYear,
        scheduledTime: recurring.scheduledTime,
        reminderLeadDays: recurring.reminderLeadDays,
        incomeSourceId: current.id,
        categoryIds: recurring.categoryIds,
        isVariableIncome: recurring.isVariableIncome,
        isDebtOrSubscription: false,
        notes: recurring.notes,
      );
    } else {
      await widget.cubit.updateRecurringTransaction(
        linkedRecurring.copyWith(
          name: recurring.name,
          amount: recurring.amount,
          dayOfMonth: recurring.dayOfMonth,
          executionType: recurring.executionType,
          walletId: recurring.walletId,
          budgetScope: recurring.budgetScope,
          recurrencePattern: recurring.recurrencePattern,
          icon: recurring.icon,
          iconColor: recurring.iconColor,
          weekday: recurring.weekday,
          weekdays: recurring.weekdays,
          monthOfYear: recurring.monthOfYear,
          scheduledTime: recurring.scheduledTime,
          reminderLeadDays: recurring.reminderLeadDays,
          incomeSourceId: current.id,
          categoryIds: recurring.categoryIds,
          isVariableIncome: recurring.isVariableIncome,
          isDebtOrSubscription: false,
          notes: recurring.notes,
        ),
      );
    }
  }

  Future<void> _editDebtDirect(DebtEntity current) async {
    final state = widget.cubit.state;
    final linkedRecurring = _linkedRecurringDebt(state, current);
    final fallbackWalletId = state.wallets.isNotEmpty
        ? state.wallets.first.id
        : 'wallet-cash-default';
    final draftRecurring = (linkedRecurring ??
            RecurringTransactionEntity(
              id: current.recurringTransactionId ?? '',
              name: current.name,
              type: TransactionType.expense.value,
              amount: current.amount,
              dayOfMonth: current.executionDay.clamp(1, 28),
              executionType: current.type,
              walletId: fallbackWalletId,
              budgetScope: BudgetScope.withinBudget.value,
              recurrencePattern: current.recurrencePattern,
              icon: 'receipt',
              iconColor: '#c65d2e',
              monthOfYear: current.monthOfYear,
              isDebtOrSubscription: true,
              expensePlanKind: current.isSubscription
                  ? ExpensePlanKind.subscription.value
                  : ExpensePlanKind.installment.value,
              debtPrincipalTotal: current.principalTotal ??
                  (current.isInstallment && current.amount > 0
                      ? current.amount
                      : null),
            ))
        .copyWith(
      recurrencePattern: current.recurrencePattern !=
              RecurrencePattern.monthly.value
          ? current.recurrencePattern
          : (linkedRecurring?.recurrencePattern ?? current.recurrencePattern),
      monthOfYear: current.monthOfYear ?? linkedRecurring?.monthOfYear,
      expensePlanKind: linkedRecurring?.expensePlanKind ??
          (current.isSubscription
              ? ExpensePlanKind.subscription.value
              : ExpensePlanKind.installment.value),
      debtPrincipalTotal: linkedRecurring?.debtPrincipalTotal ??
          current.principalTotal ??
          (current.isInstallment && current.amount > 0 ? current.amount : null),
    );
    final result =
        await Navigator.of(context).push<RecurringTransactionComposerResult>(
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: TransactionType.expense.value,
          initialWithinBudget: true,
          initialRecurring: draftRecurring,
          returnOnSave: true,
          allowDelete: true,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == null) {
      return;
    }

    final setup = widget.cubit.state.budgetSetup;
    if (result.deleteRequested) {
      if ((current.recurringTransactionId ?? '').isNotEmpty) {
        await widget.cubit
            .deleteRecurringTransaction(current.recurringTransactionId!);
      } else if (linkedRecurring != null) {
        await widget.cubit.deleteRecurringTransaction(linkedRecurring.id);
      }
      final next = setup.debts.where((d) => d.id != current.id).toList();
      await widget.cubit.updateBudgetSetup(setup.copyWith(debts: next));
      return;
    }

    final recurring = result.recurring;
    if (recurring == null) {
      return;
    }

    final recurringId =
        linkedRecurring?.id ?? current.recurringTransactionId ?? _id('rec');
    final isSubscription =
        recurring.expensePlanKind == ExpensePlanKind.subscription.value;
    final principal = recurring.debtPrincipalTotal;
    final updated = DebtEntity(
      id: current.id,
      name: recurring.name,
      amount: recurring.amount,
      executionDay: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.executionType,
      fundingSource: current.fundingSource,
      recurringTransactionId: recurringId,
      kind: isSubscription
          ? ExpensePlanKind.subscription.value
          : ExpensePlanKind.installment.value,
      principalTotal: isSubscription
          ? null
          : (principal != null && principal > 0 ? principal : null),
      installmentCount: isSubscription ? null : recurring.installmentCount,
      downPayment: isSubscription ? null : recurring.installmentDownPayment,
      recurrencePattern: recurring.recurrencePattern,
      monthOfYear: recurring.monthOfYear,
    );
    final next =
        setup.debts.map((d) => d.id == current.id ? updated : d).toList();
    await widget.cubit.updateBudgetSetup(setup.copyWith(debts: next));

    final recurringToSave = recurring.copyWith(
      id: recurringId,
      type: TransactionType.expense.value,
      budgetScope: BudgetScope.withinBudget.value,
      isDebtOrSubscription: true,
      allocationId: null,
      targetJarId: null,
    );
    if (linkedRecurring == null) {
      await widget.cubit.addRecurringTransaction(
        id: recurringId,
        name: recurringToSave.name,
        type: recurringToSave.type,
        amount: recurringToSave.amount,
        dayOfMonth: recurringToSave.dayOfMonth,
        executionType: recurringToSave.executionType,
        walletId: recurringToSave.walletId,
        budgetScope: recurringToSave.budgetScope,
        recurrencePattern: recurringToSave.recurrencePattern,
        icon: recurringToSave.icon,
        iconColor: recurringToSave.iconColor,
        weekday: recurringToSave.weekday,
        weekdays: recurringToSave.weekdays,
        monthOfYear: recurringToSave.monthOfYear,
        anchorDate: recurringToSave.anchorDate,
        scheduledTime: recurringToSave.scheduledTime,
        reminderLeadDays: recurringToSave.reminderLeadDays,
        isDebtOrSubscription: true,
        expensePlanKind: recurringToSave.expensePlanKind,
        debtPrincipalTotal: recurringToSave.debtPrincipalTotal,
        installmentCount: recurringToSave.installmentCount,
        installmentDownPayment: recurringToSave.installmentDownPayment,
        notes: recurringToSave.notes,
      );
    } else {
      await widget.cubit.updateRecurringTransaction(recurringToSave);
    }
  }

  RecurringTransactionEntity? _linkedRecurringDebt(
    AppStateEntity state,
    DebtEntity debt,
  ) =>
      BudgetRecurringPlanService.linkedRecurring(
        state.recurringTransactions,
        debt,
      );

  bool _transactionCountsTowardDebt(
    TransactionEntity t,
    DebtEntity debt,
  ) {
    if (t.type != TransactionType.expense.value) return false;
    final n = t.notes ?? '';
    return n.contains(debt.name);
  }

  List<TransactionEntity> _allDebtPayments(
    AppStateEntity state,
    DebtEntity debt,
  ) {
    final list = state.transactions
        .where((t) => _transactionCountsTowardDebt(t, debt))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  DateTime? _nextRecurringOccurrence(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) =>
      RecurringScheduleEngine.nextOccurrence(recurring, now);

  Map<String, dynamic>? _expensePendingMeta(
      RecurringTransactionEntity? recurring) {
    if (recurring == null) {
      return null;
    }
    final now = DateTime.now();
    final fallbackOccurrence = _dueOccurrenceNow(recurring, now) ??
        _nextRecurringOccurrence(recurring, now);
    final snoozedUntil = recurring.snoozedUntil == null
        ? null
        : DateTime.tryParse(recurring.snoozedUntil!);
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
      return <String, dynamic>{
        'status':
            'مؤجل حتى ${DateFormat('d MMMM - h:mm a', 'ar').format(snoozedUntil)}',
        'occurrence': fallbackOccurrence,
        'pending': false,
        'snoozed': true,
      };
    }
    final prompt = RecurringScheduleEngine.expensePrompt(recurring, now);
    if (prompt != null) {
      return <String, dynamic>{
        'status': switch (prompt.state) {
          RecurringExpensePromptState.upcoming =>
            'مستحق قريبًا ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
          RecurringExpensePromptState.due =>
            'مستحق الآن ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
          RecurringExpensePromptState.overdue => prompt.catchUpFromAuto
              ? 'دورة فائتة تحتاج قرارًا ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}'
              : 'استحقاق متأخر ${DateFormat('d MMMM - h:mm a', 'ar').format(prompt.occurrence)}',
        },
        'occurrence': prompt.occurrence,
        'pending': true,
        'snoozed': false,
      };
    }

    final occurrence = fallbackOccurrence;
    if (occurrence == null) return null;
    return <String, dynamic>{
      'status':
          'الاستحقاق القادم ${DateFormat('d/M - h:mm a', 'ar').format(occurrence)}',
      'occurrence': occurrence,
      'pending': false,
      'snoozed': false,
    };
  }

  bool _occurrenceWasHandled(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) =>
      RecurringScheduleEngine.wasOccurrenceHandled(recurring, occurrence);

  DateTime? _dueOccurrenceNow(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) =>
      RecurringScheduleEngine.dueOccurrenceNow(recurring, now);

  Future<void> _processAutomaticDebts(
    AppStateEntity state,
    BudgetSetupEntity budget,
    List<TransactionEntity> monthTx,
  ) async {
    if (_processingAutomaticDebts || !_isCurrentMonthView() || !mounted) {
      return;
    }
    _processingAutomaticDebts = true;
    try {
      final now = DateTime.now();
      for (final debt in budget.debts) {
        final recurring = _linkedRecurringDebt(state, debt);
        if (recurring == null ||
            recurring.executionType != AutomationType.auto.value) {
          continue;
        }
        final snoozedUntil =
            recurring.snoozedUntil == null || recurring.snoozedUntil!.isEmpty
                ? null
                : DateTime.tryParse(recurring.snoozedUntil!);
        if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
          continue;
        }
        final occurrence = _dueOccurrenceNow(recurring, now);
        if (occurrence == null ||
            _occurrenceWasHandled(recurring, occurrence)) {
          continue;
        }
        // منع التكرار بسبب rebuild خلال نفس الـ session
        final occKey = '${recurring.id}__${occurrence.toIso8601String()}';
        if (_handledOccurrenceKeys.contains(occKey)) continue;
        _handledOccurrenceKeys.add(occKey);
        if (!RecurringScheduleEngine.isSameCalendarDay(occurrence, now)) {
          continue;
        }
        if (debt.isInstallment) {
          final paid = monthTx
              .where((t) => _transactionCountsTowardDebt(t, debt))
              .fold<double>(0, (sum, t) => sum + t.amount);
          final remaining = (debt.amount - paid).clamp(0.0, debt.amount);
          if (remaining <= 0) {
            await widget.cubit.updateRecurringTransaction(
              recurring.copyWith(
                lastHandledOccurrenceAt: occurrence.toIso8601String(),
                snoozedUntil: '',
              ),
            );
            continue;
          }
        }
        // تحقق إن المعاملة دي مش اتسجلت فعلاً في الدورة الحالية
        final alreadyPaidThisCycle = monthTx
            .where((t) =>
                t.type == TransactionType.expense.value &&
                t.walletId == recurring.walletId &&
                t.notes?.contains(debt.name) == true &&
                RecurringScheduleEngine.isSameCalendarDay(t.createdAt, now))
            .isNotEmpty;
        if (alreadyPaidThisCycle) {
          _handledOccurrenceKeys.add(occKey);
          continue;
        }

        await widget.cubit.addTransaction(
          walletId: recurring.walletId,
          amount: recurring.amount,
          type: TransactionType.expense.value,
          budgetScope: BudgetScope.withinBudget.value,
          createdAt: now,
          notes: 'خصم تلقائي دين: ${debt.name}',
        );
        await widget.cubit.updateRecurringTransaction(
          recurring.copyWith(
            lastHandledOccurrenceAt: occurrence.toIso8601String(),
            snoozedUntil: '',
          ),
        );
      }
    } finally {
      _processingAutomaticDebts = false;
    }
  }

  DateTime _incomeDueDateForMonth(IncomeSourceEntity source, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = source.date.clamp(1, lastDay);
    return DateTime(month.year, month.month, day);
  }

  Future<void> _recordIncomeFromTracking(IncomeSourceEntity source,
      {bool early = false}) async {
    double amount = source.amount;
    if (source.isVariable || amount <= 0) {
      final amountController = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تسجيل دخل ${source.name}'),
          content: TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد')),
          ],
        ),
      );
      if (ok != true) return;
      amount = double.tryParse(amountController.text.trim()) ?? 0;
      if (amount <= 0) return;
    }
    final now = DateTime.now();
    await widget.cubit.addTransaction(
      walletId: source.targetWalletId,
      amount: amount,
      type: TransactionType.income.value,
      incomeSourceId: source.id,
      budgetScope: BudgetScope.withinBudget.value,
      createdAt: DateTime(now.year, now.month, now.day, 12),
      details: early
          ? 'تسجيل دخل مبكر: ${source.name} بقيمة ${amount.toStringAsFixed(2)}'
          : 'تأكيد نزول دخل: ${source.name} بقيمة ${amount.toStringAsFixed(2)}',
    );
  }

  // Removed local _showPostponeDialog in favor of RecurringPostponeDialog

  Future<void> _postponeIncome(IncomeSourceEntity source) async {
    final dueDate = _incomeDueDateForMonth(source, _month);
    final result = await RecurringPostponeDialog.show(
      context,
      name: source.name,
      amount: source.amount,
      kindLabel: 'راتب / دخل',
      occurrence: dueDate,
      allowSkip: false,
    );

    if (result == null || result is! DateTime) return;

    final setup = widget.cubit.state.budgetSetup;
    final updatedIncomes = setup.incomeSources.map((i) {
      if (i.id != source.id) return i;
      return i.copyWith(snoozedUntil: result.toIso8601String());
    }).toList();

    await widget.cubit.updateBudgetSetup(
      setup.copyWith(incomeSources: updatedIncomes),
      detailsOverride:
          'تأجيل دخل: ${source.name} حتى ${DateFormat('d MMMM yyyy - HH:mm', 'ar').format(result)}',
    );
  }

  Future<void> _postponeDebt(RecurringTransactionEntity recurring) async {
    final now = DateTime.now();
    final occurrence = _dueOccurrenceNow(recurring, now) ??
        _nextRecurringOccurrence(recurring, now) ??
        now;
    final result = await RecurringPostponeDialog.show(
      context,
      name: recurring.name,
      amount: recurring.amount,
      kindLabel: recurring.expensePlanKind == ExpensePlanKind.subscription.value
          ? 'اشتراك'
          : 'دفعة دين',
      occurrence: occurrence,
      allowSkip: true,
    );

    if (result == null) return;

    if (result == PostponeChoice.skip) {
      await widget.cubit.updateRecurringTransaction(
        recurring.copyWith(
          lastHandledOccurrenceAt: occurrence.toIso8601String(),
          snoozedUntil: '',
        ),
        detailsOverride:
            'تخطي هذه المرة: ${recurring.name} بقيمة ${recurring.amount.toStringAsFixed(2)}',
      );
      return;
    }

    if (result is DateTime) {
      await widget.cubit.updateRecurringTransaction(
        recurring.copyWith(snoozedUntil: result.toIso8601String()),
        detailsOverride:
            'تأجيل معاملة متكررة: ${recurring.name} بقيمة ${recurring.amount.toStringAsFixed(2)} حتى ${DateFormat('d MMMM yyyy - HH:mm', 'ar').format(result)}',
      );
    }
  }

  Future<void> _clearDebtPostpone(RecurringTransactionEntity recurring) async {
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(snoozedUntil: ''),
    );
  }

  Future<void> _recordDebtFromTracking(
    DebtEntity debt,
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) async {
    await widget.cubit.addTransaction(
      walletId: recurring.walletId,
      amount: debt.amount,
      type: TransactionType.expense.value,
      budgetScope: BudgetScope.withinBudget.value,
      createdAt: DateTime.now(),
      notes: 'سداد دين: ${debt.name}',
      details: 'سداد دين: ${debt.name} بقيمة ${debt.amount.toStringAsFixed(2)}',
    );
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(
        lastHandledOccurrenceAt: occurrence.toIso8601String(),
        snoozedUntil: '',
      ),
    );
  }

  Future<void> _confirmDebtPayment(
    AppStateEntity state,
    BudgetSetupEntity budget,
    DebtEntity debt,
    RecurringTransactionEntity recurring,
  ) async {
    final now = DateTime.now();
    final occurrence = _dueOccurrenceNow(recurring, now) ??
        _nextRecurringOccurrence(recurring, now);
    if (occurrence == null) return;

    await _recordDebtFromTracking(debt, recurring, occurrence);
  }

  Future<void> _openTxSheet(
      {required String title, required List<TransactionEntity> tx}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SharedTransactionDayGroups(
              transactions: tx,
              appState: widget.cubit.state,
              onTap: (item) => openTransactionDetailsSheet(
                context,
                cubit: widget.cubit,
                transaction: item,
              ),
            ),
            if (tx.isEmpty) const ListTile(title: Text('لا توجد معاملات.')),
          ],
        ),
      ),
    );
  }


  bool _isJarReserveTx(TransactionEntity t) {
    return t.transferType == TransferType.allocationToJar.value;
  }
}
