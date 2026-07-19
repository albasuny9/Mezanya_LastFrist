import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/presentation/screens/income_source_editor_screen.dart';
import '../../../transactions/presentation/screens/subscription_preset_selection_screen.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/services/budget_recurring_plan_service.dart';
import '../dialogs/budget_setup_dialogs.dart';
import '../sheets/allocation_info_sheet.dart';
import '../sheets/debt_dialog.dart';
import '../sheets/debt_info_sheet.dart';
import '../sheets/income_info_sheet.dart';
import '../sheets/jar_info_sheet.dart';
import '../sheets/lent_setup_management_sheet.dart';
import '../sheets/linked_dialog.dart';
import '../utils/budget_setup_display_helpers.dart';
import '../widgets/budget_start_day_picker_tile.dart';
import '../widgets/budget_setup_planner_section.dart';
import '../widgets/budget_setup_plan_tiles.dart';
import '../widgets/budget_setup_summary_card.dart';
import 'allocation_editor_screen.dart';

class _RetroactiveBudgetAction {
  const _RetroactiveBudgetAction({
    required this.id,
    required this.kind,
    required this.name,
    required this.amount,
    required this.isPhysical,
  });

  final String id;
  final String kind;
  final String name;
  final double amount;
  final bool isPhysical;
}

class _RetroactiveBudgetSyncResult {
  const _RetroactiveBudgetSyncResult({
    required this.setup,
    required this.actions,
  });

  final BudgetSetupEntity setup;
  final List<_RetroactiveBudgetAction> actions;
}

class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({
    super.key,
    required this.cubit,
    this.displayMonth,
  });

  final AppCubit cubit;
  final DateTime? displayMonth;

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  late BudgetSetupEntity _budget;
  late DateTime _displayMonth;
  bool _futureMonthNoticeShown = false;
  bool _summaryExpanded = false;
  // static const String _defaultSavingsJarId = 'linked-savings-default';

  // static const List<String> _weekdayNames = <String>[
  //   'الإثنين',
  //   'الثلاثاء',
  //   'الأربعاء',
  //   'الخميس',
  //   'الجمعة',
  //   'السبت',
  //   'الأحد',
  // ];

  @override
  void initState() {
    super.initState();
    _budget = widget.cubit.state.budgetSetup;
    final initialMonth = widget.displayMonth ?? DateTime.now();
    _displayMonth = DateTime(initialMonth.year, initialMonth.month, 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showFutureMonthNoticeIfNeeded();
    });
  }

  @override
  void dispose() => super.dispose();

  DateTime get _displayCycleReference => DateTime(
        _displayMonth.year,
        _displayMonth.month,
        _budget.startDay.clamp(1, 28),
      );

  DateTime get _displayCycleStart =>
      _budget.cycleStartFor(_displayCycleReference);

  DateTime get _displayCycleEnd => _budget.cycleEndFor(_displayCycleReference);

  List<DebtEntity> get _visibleDebtsForDisplayCycle =>
      _budget.debts.where((debt) {
        final recurring = budgetLinkedRecurringDebt(
          widget.cubit.state.recurringTransactions,
          debt,
        );
        return BudgetRecurringPlanService.isDueInCycle(
          debt: debt,
          recurring: recurring,
          cycleStart: _displayCycleStart,
          cycleEnd: _displayCycleEnd,
        );
      }).toList();

  double get _totalIncome => _budget.incomeSources.fold<double>(
        0,
        (sum, income) => sum + (income.isVariable ? 0 : income.amount),
      );

  double get _allocationsTotal => _budget.allocations.fold<double>(
        0,
        (sum, allocation) =>
            sum +
            allocation.funding.fold<double>(0, (s, f) => s + f.plannedAmount),
      );

  double get _linkedTotal => _budget.linkedWallets.fold<double>(
        0,
        (sum, wallet) => sum + wallet.monthlyAmount,
      );

  double get _debtsTotal {
    return _budget.debts.fold<double>(
      0,
      (sum, debt) =>
          sum +
          _debtAmountForCycle(
              _budget, debt, _displayCycleStart, _displayCycleEnd),
    );
  }

  double get _installmentsTotal =>
      _budget.debts.where((debt) => debt.isInstallment).fold<double>(
            0,
            (sum, debt) =>
                sum +
                _debtAmountForCycle(
                    _budget, debt, _displayCycleStart, _displayCycleEnd),
          );

  double get _subscriptionsTotal =>
      _budget.debts.where((debt) => debt.isSubscription).fold<double>(
            0,
            (sum, debt) =>
                sum +
                _debtAmountForCycle(
                    _budget, debt, _displayCycleStart, _displayCycleEnd),
          );

  double get _committed => _allocationsTotal + _linkedTotal + _debtsTotal;

  double get _unallocated => _totalIncome - _committed;

  /// 10% من إجمالي كل مخصص — يُستخدم كتلميح تقريبي فقط في ملخص الخطة.
  double get _allocationTenPercentHint => _budget.allocations.fold<double>(
        0,
        (sum, allocation) {
          final planned = allocation.funding.fold<double>(
            0,
            (s, f) => s + f.plannedAmount,
          );
          return sum + planned * 0.10;
        },
      );

  /// تقدير تقريبي: غير المخصص + مجموع (10% من كل مخصص). ليس رقمًا مضمونًا.
  double get _approxSavingsHint => _unallocated + _allocationTenPercentHint;

  bool get _isCurrentMonthSetup {
    final now = DateTime.now();
    return _displayMonth.year == now.year && _displayMonth.month == now.month;
  }

  bool get _isFutureMonthSetup {
    final nowMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    return _displayMonth.isAfter(nowMonth);
  }

  String get _displayMonthName {
    const monthNames = <String>[
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${monthNames[_displayMonth.month - 1]} ${_displayMonth.year}';
  }

  String get _screenHeading => _isCurrentMonthSetup
      ? 'إعداد الشهر الحالي'
      : 'خطة إعداد شهر $_displayMonthName';

  /// نطاق تاريخ الدورة: "إعداد الدورة من ١ يونيو إلى ٣٠ يونيو"
  String get _cycleRangeLabel {
    final fmt = DateFormat('d MMMM', 'ar');
    return 'إعداد الدورة من ${fmt.format(_displayCycleStart)} إلى ${fmt.format(_displayCycleEnd)}';
  }

  String get _screenSubheading => _cycleRangeLabel;

  Future<void> _showFutureMonthNoticeIfNeeded() async {
    if (!mounted || !_isFutureMonthSetup || _futureMonthNoticeShown) {
      return;
    }
    _futureMonthNoticeShown = true;
    final switchToCurrentMonth = await showFutureMonthBudgetNoticeDialog(
      context,
      displayMonthName: _displayMonthName,
    );
    if (switchToCurrentMonth && mounted) {
      setState(() {
        final now = DateTime.now();
        _displayMonth = DateTime(now.year, now.month, 1);
      });
    }
  }

  Future<void> _saveBudget(BudgetSetupEntity next) async {
    final previous = _budget;
    final normalized = next;
    // لو في دورة حالية — نحسب الدلتا ونحفظها كـ pendingDistribution
    // اليوزر هيشوفها في صفحة متابعة الميزانية أو الإشعارات ويقرر بنفسه
    final syncResult = _isCurrentMonthSetup
        ? _buildRetroactiveBudgetSync(
            previous: previous,
            next: normalized,
            state: widget.cubit.state,
          )
        : _RetroactiveBudgetSyncResult(setup: normalized, actions: const []);
    setState(() => _budget = syncResult.setup);
    await widget.cubit.updateBudgetSetup(syncResult.setup);
    // لا popup فوري — الـ pendingDistribution بيظهر تلقائياً في متابعة الميزانية
  }

  _RetroactiveBudgetSyncResult _buildRetroactiveBudgetSync({
    required BudgetSetupEntity previous,
    required BudgetSetupEntity next,
    required AppStateEntity state,
  }) {
    final cycleIncome = state.transactions
        .where((transaction) =>
            transaction.type == TransactionType.income.value &&
            !transaction.createdAt.isBefore(_displayCycleStart) &&
            !transaction.createdAt.isAfter(_displayCycleEnd) &&
            transaction.incomeSourceId != null)
        .toList();
    if (cycleIncome.isEmpty) {
      return _RetroactiveBudgetSyncResult(setup: next, actions: const []);
    }

    final incomeTotals = <String, double>{};
    final incomeWalletIds = <String, String>{};
    for (final transaction in cycleIncome) {
      final sourceId = transaction.incomeSourceId;
      if (sourceId == null || sourceId.isEmpty) continue;
      incomeTotals[sourceId] =
          (incomeTotals[sourceId] ?? 0) + transaction.amount;
      final walletId = transaction.walletId;
      if (walletId != null && walletId.isNotEmpty) {
        incomeWalletIds[sourceId] = walletId;
      }
    }

    final incomeSourcesById = {
      for (final source in next.incomeSources) source.id: source,
      for (final source in previous.incomeSources) source.id: source,
    };

    final previousAllocations = {
      for (final allocation in previous.allocations) allocation.id: allocation,
    };
    final updatedAllocations = next.allocations.map((allocation) {
      final previousAllocation = previousAllocations[allocation.id];
      final previousPlanned =
          _allocationFundingTotals(previousAllocation?.funding ?? const []);
      final nextPlanned = _allocationFundingTotals(allocation.funding);
      final delta = _retroactiveDelta(
        previousPlanned: previousPlanned,
        nextPlanned: nextPlanned,
        incomeTotals: incomeTotals,
      );
      if (delta <= 0) return allocation;
      return allocation.copyWith(
        pendingDistribution: allocation.pendingDistribution + delta,
        pendingDistributionWalletId: '',
        pendingDistributionSourceId:
            _firstTriggeredSource(previousPlanned, nextPlanned, incomeTotals),
      );
    }).toList();

    final previousJars = {
      for (final jar in previous.linkedWallets) jar.id: jar,
    };
    final retroactiveActions = <_RetroactiveBudgetAction>[];
    final updatedJars = next.linkedWallets.map((jar) {
      final previousJar = previousJars[jar.id];
      final previousPlanned =
          _jarFundingTotals(previousJar?.funding ?? const []);
      final nextPlanned = _jarFundingTotals(jar.funding);
      final delta = _retroactiveDelta(
        previousPlanned: previousPlanned.map(
          (key, value) => MapEntry(key, value.plannedAmount),
        ),
        nextPlanned: nextPlanned.map(
          (key, value) => MapEntry(key, value.plannedAmount),
        ),
        incomeTotals: incomeTotals,
      );
      if (delta <= 0) return jar;

      final triggeredSource =
          _firstTriggeredJarSource(previousPlanned, nextPlanned, incomeTotals);
      final fallbackWalletId = triggeredSource == null
          ? ''
          : (incomeWalletIds[triggeredSource] ??
              incomeSourcesById[triggeredSource]?.targetWalletId ??
              '');
      return jar.copyWith(
        pendingDistribution: jar.pendingDistribution + delta,
        pendingDistributionWalletId: fallbackWalletId,
        pendingDistributionSourceId: triggeredSource ?? '',
      );
    }).toList();

    for (final allocation in updatedAllocations) {
      final original =
          next.allocations.firstWhere((item) => item.id == allocation.id);
      final delta =
          allocation.pendingDistribution - original.pendingDistribution;
      if (delta > 0) {
        retroactiveActions.add(
          _RetroactiveBudgetAction(
            id: allocation.id,
            kind: 'allocation',
            name: allocation.name,
            amount: delta,
            isPhysical: false,
          ),
        );
      }
    }

    for (final jar in updatedJars) {
      final original =
          next.linkedWallets.firstWhere((item) => item.id == jar.id);
      final delta = jar.pendingDistribution - original.pendingDistribution;
      final hasPhysicalPending = jar.pendingDistributionSourceId.isNotEmpty &&
          jar.funding.any(
            (entry) =>
                entry.incomeSourceId == jar.pendingDistributionSourceId &&
                entry.isPhysical,
          );
      if (delta > 0) {
        retroactiveActions.add(
          _RetroactiveBudgetAction(
            id: jar.id,
            kind: 'jar',
            name: jar.name,
            amount: delta,
            isPhysical: hasPhysicalPending,
          ),
        );
      }
    }

    return _RetroactiveBudgetSyncResult(
      setup: next.copyWith(
        allocations: updatedAllocations,
        linkedWallets: updatedJars,
      ),
      actions: retroactiveActions,
    );
  }

  Map<String, double> _allocationFundingTotals(
    List<AllocationFundingEntity> funding,
  ) {
    final totals = <String, double>{};
    for (final entry in funding) {
      totals[entry.incomeSourceId] =
          (totals[entry.incomeSourceId] ?? 0) + entry.plannedAmount;
    }
    return totals;
  }

  Map<String, LinkedWalletEntityFunding> _jarFundingTotals(
    List<LinkedWalletEntityFunding> funding,
  ) {
    final totals = <String, LinkedWalletEntityFunding>{};
    for (final entry in funding) {
      final existing = totals[entry.incomeSourceId];
      totals[entry.incomeSourceId] = LinkedWalletEntityFunding(
        id: existing?.id ?? entry.id,
        incomeSourceId: entry.incomeSourceId,
        plannedAmount: (existing?.plannedAmount ?? 0) + entry.plannedAmount,
        isPhysical: (existing?.isPhysical ?? false) || entry.isPhysical,
      );
    }
    return totals;
  }

  double _retroactiveDelta({
    required Map<String, double> previousPlanned,
    required Map<String, double> nextPlanned,
    required Map<String, double> incomeTotals,
  }) {
    var delta = 0.0;
    final sourceIds = {...previousPlanned.keys, ...nextPlanned.keys};
    for (final sourceId in sourceIds) {
      final available = incomeTotals[sourceId] ?? 0;
      if (available <= 0) continue;
      final before = (available <= (previousPlanned[sourceId] ?? 0))
          ? available
          : (previousPlanned[sourceId] ?? 0);
      final after = (available <= (nextPlanned[sourceId] ?? 0))
          ? available
          : (nextPlanned[sourceId] ?? 0);
      if (after > before) {
        delta += after - before;
      }
    }
    return delta;
  }

  String? _firstTriggeredSource(
    Map<String, double> previousPlanned,
    Map<String, double> nextPlanned,
    Map<String, double> incomeTotals,
  ) {
    for (final entry in nextPlanned.entries) {
      final available = incomeTotals[entry.key] ?? 0;
      if (available <= 0) continue;
      final before = (available <= (previousPlanned[entry.key] ?? 0))
          ? available
          : (previousPlanned[entry.key] ?? 0);
      final after = available <= entry.value ? available : entry.value;
      if (after > before) return entry.key;
    }
    return null;
  }

  String? _firstTriggeredJarSource(
    Map<String, LinkedWalletEntityFunding> previousPlanned,
    Map<String, LinkedWalletEntityFunding> nextPlanned,
    Map<String, double> incomeTotals,
  ) {
    for (final entry in nextPlanned.entries) {
      final available = incomeTotals[entry.key] ?? 0;
      if (available <= 0) continue;
      final beforePlan = previousPlanned[entry.key]?.plannedAmount ?? 0;
      final before = available <= beforePlan ? available : beforePlan;
      final after = available <= entry.value.plannedAmount
          ? available
          : entry.value.plannedAmount;
      if (after > before) return entry.key;
    }
    return null;
  }

  /// لما اليوزر يغير يوم بداية الدورة — نسأله هيبدأ من النهارده ولا الدورة الجاية
  Future<void> _handleStartDayChange(int newDay) async {
    if (!mounted) return;
    final now = DateTime.now();
    final isPartialCycle = now.day > newDay;

    // لو اليوزر في منتصف الدورة الجديدة
    if (isPartialCycle) {
      final nextCycleStart = DateTime(now.year, now.month + 1, newDay);
      final currentEnd = nextCycleStart.subtract(const Duration(days: 1));

      final choice = await showBudgetStartDayTimingDialog(
        context,
        now: now,
        currentEnd: currentEnd,
        nextCycleStart: nextCycleStart,
        newDay: newDay,
      );

      if (choice == null) return; // ألغى
    }

    await _saveBudget(_budget.copyWith(startDay: newDay));
  }

  double _debtAmountForCycle(
    BudgetSetupEntity setup,
    DebtEntity debt,
    DateTime cycleStart,
    DateTime cycleEnd,
  ) {
    final recurring = budgetLinkedRecurringDebt(
      widget.cubit.state.recurringTransactions,
      debt,
    );
    return BudgetRecurringPlanService.amountDueInCycle(
      debt: debt,
      recurring: recurring,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
    );
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _openIncomeComposer() async {
    final result = await Navigator.of(context).push<IncomeSourceEditorResult>(
      MaterialPageRoute(
        builder: (_) => IncomeSourceEditorScreen(
          cubit: widget.cubit,
        ),
        fullscreenDialog: true,
      ),
    );
    final recurring = result?.recurring;
    if (recurring == null) {
      return;
    }

    final income = IncomeSourceEntity(
      id: _id('income'),
      name: recurring.name,
      amount: recurring.isVariableIncome ? 0 : recurring.amount,
      date: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.isVariableIncome ? 'manual' : recurring.executionType,
      targetWalletId: recurring.walletId,
      isVariable: recurring.isVariableIncome,
      isDefault: false,
    );

    final nextBudget = _budget.copyWith(
      incomeSources: [..._budget.incomeSources, income],
    );
    await _saveBudget(nextBudget);

    await widget.cubit.addRecurringTransaction(
      name: recurring.name,
      type: recurring.type,
      amount: recurring.amount,
      dayOfMonth: recurring.dayOfMonth,
      executionType: recurring.executionType,
      walletId: recurring.walletId,
      budgetScope: BudgetScope.withinBudget.value,
      recurrencePattern: recurring.recurrencePattern,
      icon: recurring.icon,
      iconColor: recurring.iconColor,
      weekday: recurring.weekday,
      weekdays: recurring.weekdays,
      monthOfYear: recurring.monthOfYear,
      anchorDate: recurring.anchorDate,
      scheduledTime: recurring.scheduledTime,
      reminderLeadDays: recurring.reminderLeadDays,
      incomeSourceId: income.id,
      categoryIds: recurring.categoryIds,
      isVariableIncome: recurring.isVariableIncome,
      isDebtOrSubscription: false,
      notes: recurring.notes,
    );
  }

  Future<void> _showIncomeDialog({IncomeSourceEntity? current}) async {
    if (current == null) {
      await _openIncomeComposer();
      return;
    }

    final wallets = widget.cubit.state.wallets;
    final fallbackWalletId =
        wallets.isNotEmpty ? wallets.first.id : 'wallet-cash-default';
    final linkedRecurring = budgetLinkedRecurringIncome(
      widget.cubit.state.recurringTransactions,
      current,
    );
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

    final result = await Navigator.of(context).push<IncomeSourceEditorResult>(
      MaterialPageRoute(
        builder: (_) => IncomeSourceEditorScreen(
          cubit: widget.cubit,
          initialRecurring: draftRecurring,
          allowDelete: true,
        ),
        fullscreenDialog: true,
      ),
    );

    if (result == null) {
      return;
    }

    if (result.deleteRequested) {
      final linked = widget.cubit.state.recurringTransactions
          .where((r) => r.incomeSourceId == current.id)
          .toList();
      for (final rec in linked) {
        await widget.cubit.deleteRecurringTransaction(rec.id);
      }
      final next =
          _budget.incomeSources.where((e) => e.id != current.id).toList();
      await _saveBudget(_budget.copyWith(incomeSources: next));
      return;
    }

    final recurring = result.recurring;
    if (recurring == null) {
      return;
    }

    final saved = IncomeSourceEntity(
      id: current.id,
      name: recurring.name,
      amount: recurring.isVariableIncome ? 0 : recurring.amount,
      date: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.isVariableIncome ? 'manual' : recurring.executionType,
      targetWalletId: recurring.walletId,
      isVariable: recurring.isVariableIncome,
      isDefault: current.isDefault,
    );

    final next = _budget.incomeSources
        .map((e) => e.id == current.id ? saved : e)
        .toList();
    await _saveBudget(_budget.copyWith(incomeSources: next));

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
        anchorDate: recurring.anchorDate,
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
          anchorDate: recurring.anchorDate,
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

  Future<void> _showAllocationDialog({AllocationEntity? current}) async {
    if (_budget.incomeSources.isEmpty && current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يُنصح بإضافة مصدر دخل أولاً لتفعيل التمويل'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    final result = await openAllocationEditorScreen(
      context,
      current: current,
      incomeSources: _budget.incomeSources,
      idFactory: _id,
    );
    if (result == null) {
      return;
    }
    if (result.deleteRequested && current != null) {
      final next =
          _budget.allocations.where((e) => e.id != current.id).toList();
      await _saveBudget(_budget.copyWith(allocations: next));
      return;
    }
    final allocation = result.entity;
    if (allocation == null) {
      return;
    }
    final next = current == null
        ? [..._budget.allocations, allocation]
        : _budget.allocations
            .map((e) => e.id == current.id ? allocation : e)
            .toList();
    await _saveBudget(_budget.copyWith(allocations: next));
  }

  Future<void> _showAddRecurringOrDebtComposer(
      {bool subscriptionOnly = false}) async {
    if (subscriptionOnly) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SubscriptionPresetSelectionScreen(
            cubit: widget.cubit,
          ),
        ),
      );
      if (mounted) setState(() => _budget = widget.cubit.state.budgetSetup);
      return;
    }

    // دين → فتح composer مباشرة
    await showDebtDialog(
      context,
      cubit: widget.cubit,
      budget: _budget,
      current: null,
      idFactory: _id,
      onSaveBudget: _saveBudget,
    );
  }

  Future<void> _openLentSetupManagementSheet(
      RecurringTransactionEntity record) async {
    await showLentSetupManagementSheet(
      context,
      record: record,
      onSettle: () async {
        if (!mounted) return;
        await widget.cubit.settleLentRecord(record.id);
        if (mounted) setState(() {});
      },
      onPostpone: (picked) async {
        if (!mounted) return;
        await widget.cubit.postponeLentRecord(record.id, picked);
        if (mounted) setState(() {});
      },
      onWriteOff: () async {
        if (!mounted) return;
        await widget.cubit.writeOffLentRecord(record.id);
        if (mounted) setState(() {});
      },
      onDelete: () async {
        if (!mounted) return;
        await widget.cubit.deleteRecurringTransaction(record.id);
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: _isFutureMonthSetup
                ? const Color(0xFFFFF4E8)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _isFutureMonthSetup
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
                  color: _isFutureMonthSetup
                      ? const Color(0xFFF3D4A4)
                      : const Color(0xFFDDEFEA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _isFutureMonthSetup
                      ? Icons.schedule_rounded
                      : Icons.calendar_month_rounded,
                  color: _isFutureMonthSetup
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
                      _screenHeading,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _screenSubheading,
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
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: _unallocated >= 0
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
                _unallocated.toStringAsFixed(2),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _summaryMini(
                      label: 'إجمالي الدخل',
                      value: _totalIncome,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _summaryMini(
                      label: 'إجمالي المخصص',
                      value: _committed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
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
                selectedDay: _budget.startDay,
                onDaySelected: (day) async {
                  if (day == _budget.startDay) return;
                  await _handleStartDayChange(day);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _budget.cycleMode,
                decoration: const InputDecoration(
                  labelText: 'تجديد الخطة',
                  prefixIcon: Icon(Icons.autorenew_rounded),
                ),
                items: [
                  DropdownMenuItem(
                      value: AutomationType.auto.value, child: Text('تلقائي')),
                  DropdownMenuItem(
                    value: AutomationType.confirm.value,
                    child: Text('بعد التأكيد'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _saveBudget(_budget.copyWith(cycleMode: value));
                  }
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _budget.bufferEndBehavior,
                decoration: const InputDecoration(
                  labelText: 'المبلغ غير المخصص آخر الدورة',
                  prefixIcon: Icon(Icons.monetization_on_rounded),
                ),
                items: [
                  DropdownMenuItem(
                      value: RolloverBehavior.toSavings.value,
                      child: Text('يتحول للتوفير')),
                  DropdownMenuItem(
                      value: RolloverBehavior.keep.value,
                      child: Text('يبقى للدورة الجديدة')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _saveBudget(_budget.copyWith(bufferEndBehavior: value));
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        BudgetSetupPlannerSection(
          title: 'مصادر الدخل',
          subtitle:
              'أضف الدخل الثابت أو المتغير الذي يدخل في ميزانيتك الشهرية.',
          icon: Icons.south_west_rounded,
          accent: const Color(0xFF0F9D7A),
          actionLabel: 'إضافة دخل',
          onAction: _openIncomeComposer,
          showHeaderAction: false,
          footerAction: BudgetSetupThinAddButton(
            label: 'إضافة دخل',
            onPressed: _openIncomeComposer,
            tint: const Color(0xFF0F9D7A),
          ),
          children: () {
            if (_budget.incomeSources.isEmpty) {
              return <Widget>[
                _emptyState('أضف أول دخل لتبدأ توزيع الميزانية.')
              ];
            }

            return <Widget>[
              ..._budget.incomeSources.map(
                (income) {
                  final linkedRecurring = budgetLinkedRecurringIncome(
                    widget.cubit.state.recurringTransactions,
                    income,
                  );
                  final iconName = linkedRecurring?.icon ?? 'cash';
                  final iconColorHex = linkedRecurring?.iconColor ?? '#0f9d7a';
                  return BudgetIncomePlanTile(
                    income: income,
                    iconName: iconName,
                    iconColorHex: iconColorHex,
                    onTap: () => showIncomeInfoSheet(
                      context,
                      income: income,
                      recurringTransactions:
                          widget.cubit.state.recurringTransactions,
                      wallets: widget.cubit.state.wallets,
                      onEdit: () => _showIncomeDialog(current: income),
                    ),
                  );
                },
              ),
            ];
          }(),
        ),
        const SizedBox(height: 14),
        BudgetSetupPlannerSection(
          title: 'المخصصات',
          subtitle: 'قسّم ميزانيتك على بنود واضحة قبل بداية الصرف.',
          icon: Icons.grid_view_rounded,
          accent: const Color(0xFF296BFF),
          actionLabel: 'إضافة مخصص',
          onAction: () => _showAllocationDialog(),
          showHeaderAction: false,
          footerAction: BudgetSetupThinAddButton(
            label: 'إضافة مخصص',
            onPressed: () => _showAllocationDialog(),
            tint: const Color(0xFF296BFF),
          ),
          children: _budget.allocations.isEmpty
              ? [_emptyState('أنشئ مخصصات مثل البيت أو الأكل أو المواصلات.')]
              : _budget.allocations
                  .map(
                    (allocation) => _planTile(
                      title: allocation.name,
                      amountText: allocation.funding
                          .fold<double>(0, (s, f) => s + f.plannedAmount)
                          .toStringAsFixed(2),
                      detailText: allocation.rolloverBehavior ==
                              RolloverBehavior.keep.value
                          ? 'يرحل للدورة التالية'
                          : 'يرجع للتوفير',
                      leadingWidget: BudgetSetupIconBadge(
                        iconName: allocation.icon,
                        colorHex: allocation.iconColor,
                        size: 42,
                      ),
                      tint: budgetSetupColorFromHex(allocation.iconColor),
                      onTap: () => showAllocationInfoSheet(
                        context,
                        allocation: allocation,
                        incomeSources: _budget.incomeSources,
                        onEdit: () =>
                            _showAllocationDialog(current: allocation),
                      ),
                      onDelete: null,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 14),
        BudgetSetupPlannerSection(
          title: 'الحصالات',
          subtitle: 'مبالغ ثابتة تتحول لأهدافك أو محافظك المرتبطة.',
          icon: Icons.monetization_on_rounded,
          accent: const Color(0xFFE09F1F),
          actionLabel: 'إضافة حصالة',
          onAction: () => showLinkedWalletDialog(
            context,
            budget: _budget,
            current: null,
            idFactory: _id,
            onSaveBudget: _saveBudget,
          ),
          showHeaderAction: false,
          footerAction: BudgetSetupThinAddButton(
            label: 'إضافة حصالة',
            onPressed: () => showLinkedWalletDialog(
              context,
              budget: _budget,
              current: null,
              idFactory: _id,
              onSaveBudget: _saveBudget,
            ),
            tint: const Color(0xFFE09F1F),
          ),
          children: _budget.linkedWallets.isEmpty
              ? [_emptyState('أضف حصالاتك المرتبطة مثل الطوارئ أو السفر.')]
              : _budget.linkedWallets
                  .map(
                    (wallet) => _planTile(
                      title: wallet.name,
                      amountText: wallet.monthlyAmount.toStringAsFixed(2),
                      detailText: 'يوم ${wallet.executionDay}',
                      leadingWidget: BudgetSetupIconBadge(
                        iconName: wallet.icon,
                        colorHex: wallet.iconColor,
                        size: 42,
                      ),
                      tint: budgetSetupColorFromHex(wallet.iconColor),
                      onTap: () => showJarInfoSheet(
                        context,
                        jar: wallet,
                        incomeSources: _budget.incomeSources,
                        onEdit: () => showLinkedWalletDialog(
                          context,
                          budget: _budget,
                          current: wallet,
                          idFactory: _id,
                          onSaveBudget: _saveBudget,
                        ),
                      ),
                      onDelete: null,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 14),
        BlocBuilder<AppCubit, AppStateEntity>(
          bloc: widget.cubit,
          builder: (ctx, appState) {
            final installments = _visibleDebtsForDisplayCycle
                .where((d) => d.isInstallment)
                .toList();
            final lents =
                appState.recurringTransactions.where((r) => r.isLent).toList();

            return BudgetSetupPlannerSection(
              title: 'الديون والأقساط',
              subtitle: 'أقساط شهرية وديون مربوطة بالميزانية، بالإضافة للسلف.',
              icon: Icons.receipt_long_rounded,
              accent: const Color(0xFFC65D2E),
              actionLabel: '',
              onAction: () {},
              showHeaderAction: false,
              footerAction: BudgetSetupThinAddButton(
                label: 'إضافة دين',
                onPressed: () =>
                    _showAddRecurringOrDebtComposer(subscriptionOnly: false),
                tint: const Color(0xFFC65D2E),
              ),
              children: () {
                if (installments.isEmpty && lents.isEmpty) {
                  return [
                    _emptyState('لا توجد ديون أو أقساط أو سلف في هذه الدورة.')
                  ];
                }

                final today = DateTime.now();
                final todayMid = DateTime(today.year, today.month, today.day);

                return [
                  // الأقساط والديون
                  ...installments.map((debt) {
                    final recurring = budgetLinkedRecurringDebt(
                      widget.cubit.state.recurringTransactions,
                      debt,
                    );
                    final iconColor = recurring?.iconColor ?? '#c65d2e';
                    return _planTile(
                      title: debt.name,
                      amountText: debt.amount.toStringAsFixed(2),
                      detailText: 'يوم ${debt.executionDay}',
                      leadingWidget: BudgetSetupIconBadge(
                        iconName: recurring?.icon ?? 'receipt',
                        colorHex: iconColor,
                        size: 42,
                      ),
                      tint: budgetSetupColorFromHex(iconColor),
                      onTap: () => showDebtInfoSheet(
                        context,
                        debt: debt,
                        budget: _budget,
                        recurringTransactions:
                            widget.cubit.state.recurringTransactions,
                        wallets: widget.cubit.state.wallets,
                        cubit: widget.cubit,
                        onSaveBudget: _saveBudget,
                        onEdit: () => showDebtDialog(
                          context,
                          cubit: widget.cubit,
                          budget: _budget,
                          current: debt,
                          idFactory: _id,
                          onSaveBudget: _saveBudget,
                        ),
                      ),
                      onDelete: null,
                    );
                  }),

                  // السلف
                  ...lents.map((record) {
                    final name = record.lentPersonName ?? record.name;
                    final ret = record.anchorDate != null
                        ? DateTime.tryParse(record.anchorDate!)
                        : null;
                    final overdue = ret != null &&
                        DateTime(ret.year, ret.month, ret.day)
                            .isBefore(todayMid);
                    final dateText = ret != null
                        ? 'استرداد ${ret.day}/${ret.month}/${ret.year}${overdue ? ' ⚠️' : ''}'
                        : 'بدون تاريخ استرداد';
                    return _planTile(
                      title: name,
                      amountText: record.amount.toStringAsFixed(2),
                      detailText: dateText,
                      leadingWidget: BudgetSetupIconBadge(
                          iconName: 'handshake', colorHex: '#1a7a4a', size: 42),
                      tint: overdue
                          ? const Color(0xFFC65D2E)
                          : const Color(0xFF1a7a4a),
                      onTap: () => _openLentSetupManagementSheet(record),
                      onDelete: null,
                    );
                  }),
                ];
              }(),
            );
          },
        ),
        const SizedBox(height: 14),
        BudgetSetupPlannerSection(
          title: 'الاشتراكات',
          subtitle: 'اشتراكات متكررة مثل خدمات البث والأدوات الدورية.',
          icon: Icons.subscriptions_rounded,
          accent: const Color(0xFF4A7C59),
          actionLabel: '',
          onAction: () {},
          showHeaderAction: false,
          footerAction: BudgetSetupThinAddButton(
            label: 'إضافة اشتراك',
            onPressed: () =>
                _showAddRecurringOrDebtComposer(subscriptionOnly: true),
            tint: const Color(0xFF4A7C59),
          ),
          children: () {
            final subscriptions = _visibleDebtsForDisplayCycle
                .where((d) => d.isSubscription)
                .toList();
            if (subscriptions.isEmpty) {
              return [_emptyState('لا توجد اشتراكات مستحقة في هذه الدورة.')];
            }
            return subscriptions.map((debt) {
              final recurring = budgetLinkedRecurringDebt(
                widget.cubit.state.recurringTransactions,
                debt,
              );
              final iconColor = recurring?.iconColor ?? '#4a7c59';
              return _planTile(
                title: debt.name,
                amountText: debt.amount.toStringAsFixed(2),
                detailText: budgetRecurrenceLabel(
                    recurring?.recurrencePattern ?? debt.recurrencePattern),
                leadingWidget: BudgetSetupIconBadge(
                  iconName: recurring?.icon ?? 'subscriptions',
                  colorHex: iconColor,
                  size: 42,
                ),
                tint: budgetSetupColorFromHex(iconColor),
                onTap: () => showDebtInfoSheet(
                  context,
                  debt: debt,
                  budget: _budget,
                  recurringTransactions:
                      widget.cubit.state.recurringTransactions,
                  wallets: widget.cubit.state.wallets,
                  cubit: widget.cubit,
                  onSaveBudget: _saveBudget,
                  onEdit: () => showDebtDialog(
                    context,
                    cubit: widget.cubit,
                    budget: _budget,
                    current: debt,
                    idFactory: _id,
                    onSaveBudget: _saveBudget,
                  ),
                ),
                onDelete: null,
              );
            }).toList();
          }(),
        ),
        const SizedBox(height: 18),
        BudgetSetupSummaryCard(
          totalIncome: _totalIncome,
          committed: _committed,
          allocationsTotal: _allocationsTotal,
          linkedTotal: _linkedTotal,
          installmentsTotal: _installmentsTotal,
          subscriptionsTotal: _subscriptionsTotal,
          unallocated: _unallocated,
          approxSavingsHint: _approxSavingsHint,
          isExpanded: _summaryExpanded,
          onToggleExpanded: () =>
              setState(() => _summaryExpanded = !_summaryExpanded),
        ),
      ],
    );
  }

  Widget _summaryMini({
    required String label,
    required double value,
  }) {
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

  Widget _planTile({
    required String title,
    required String amountText,
    required String detailText,
    IconData? leading,
    Widget? leadingWidget,
    required Color tint,
    required VoidCallback onTap,
    bool emphasize = false,
    Widget? extra,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: emphasize ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: tint.withValues(alpha: emphasize ? 0.30 : 0.14),
          width: emphasize ? 1.6 : 1,
        ),
        boxShadow: emphasize
            ? [
                BoxShadow(
                  color: tint.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: leadingWidget ??
                                Icon(leading ?? Icons.category,
                                    color: tint, size: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(detailText),
                              if (emphasize) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: tint.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'دخل معلق يحتاج إجراء',
                                    style: TextStyle(
                                      color: tint,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    amountText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              if (extra != null) extra,
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String text) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // DateTime? _parseClockTime(String? value) {
  //   if (value == null || value.isEmpty || !value.contains(':')) {
  //     return null;
  //   }
  //   final parts = value.split(':');
  //   if (parts.length != 2) {
  //     return null;
  //   }
  //   final hour = int.tryParse(parts[0]);
  //   final minute = int.tryParse(parts[1]);
  //   if (hour == null || minute == null) {
  //     return null;
  //   }
  //   final now = DateTime.now();
  //   return DateTime(now.year, now.month, now.day, hour, minute);
  // }

  // DateTime? _nextOccurrence(
  //     RecurringTransactionEntity recurring, DateTime now) {
  //   final time = _parseClockTime(recurring.scheduledTime) ?? now;
  //   DateTime atDate(DateTime day) =>
  //       DateTime(day.year, day.month, day.day, time.hour, time.minute);

  //   if (recurring.recurrencePattern == 'manual-variable') {
  //     return null;
  //   }
  //   if (recurring.recurrencePattern == RecurrencePattern.daily.value) {
  //     final today = atDate(now);
  //     return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  //   }
  //   if (recurring.weekdays.isNotEmpty) {
  //     for (var offset = 0; offset <= 21; offset++) {
  //       final day = now.add(Duration(days: offset));
  //       if (recurring.weekdays.contains(day.weekday)) {
  //         final candidate = atDate(day);
  //         if (candidate.isAfter(now)) {
  //           return candidate;
  //         }
  //       }
  //     }
  //   }
  //   if (recurring.recurrencePattern == RecurrencePattern.monthly.value ||
  //       recurring.recurrencePattern == RecurrencePattern.every2Months.value ||
  //       recurring.recurrencePattern == RecurrencePattern.every3Months.value ||
  //       recurring.recurrencePattern == RecurrencePattern.every6Months.value) {
  //     final interval = switch (recurring.recurrencePattern) {
  //       'every_2_months' => 2,
  //       'every_3_months' => 3,
  //       'every_6_months' => 6,
  //       _ => 1,
  //     };
  //     for (var step = 0; step < 12; step++) {
  //       final monthDate = DateTime(now.year, now.month + (step * interval));
  //       final candidate = DateTime(
  //         monthDate.year,
  //         monthDate.month,
  //         recurring.dayOfMonth.clamp(1, 28),
  //         time.hour,
  //         time.minute,
  //       );
  //       if (candidate.isAfter(now)) {
  //         return candidate;
  //       }
  //     }
  //   }
  //   if (recurring.recurrencePattern == RecurrencePattern.yearly.value) {
  //     final month = recurring.monthOfYear ?? now.month;
  //     final thisYear = DateTime(
  //       now.year,
  //       month,
  //       recurring.dayOfMonth.clamp(1, 28),
  //       time.hour,
  //       time.minute,
  //     );
  //     if (thisYear.isAfter(now)) {
  //       return thisYear;
  //     }
  //     return DateTime(
  //       now.year + 1,
  //       month,
  //       recurring.dayOfMonth.clamp(1, 28),
  //       time.hour,
  //       time.minute,
  //     );
  //   }
  //   return null;
  // }

  // Duration _leadDuration(RecurringTransactionEntity recurring) {
  //   final value = recurring.reminderLeadDays ?? 0;
  //   if (recurring.recurrencePattern == RecurrencePattern.daily.value ||
  //       recurring.recurrencePattern == RecurrencePattern.weekly.value ||
  //       recurring.recurrencePattern == RecurrencePattern.biweekly.value ||
  //       recurring.recurrencePattern == RecurrencePattern.every3Weeks.value) {
  //     return Duration(hours: value.clamp(0, 3));
  //   }
  //   return Duration(days: value.clamp(0, 3));
  // }
}
