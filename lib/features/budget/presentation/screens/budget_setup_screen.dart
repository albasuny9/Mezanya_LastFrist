import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/presentation/screens/recurring_transaction_composer_screen.dart';
import '../../../transactions/presentation/screens/subscription_preset_selection_screen.dart';
import '../../../wallets/presentation/screens/jar_editor_screen.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../../domain/services/budget_recurring_plan_service.dart';

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

Future<AllocationEditorResult?> openAllocationEditorScreen(
  BuildContext context, {
  AllocationEntity? current,
  required List<IncomeSourceEntity> incomeSources,
  required String Function(String prefix) idFactory,
}) {
  return Navigator.of(context).push<AllocationEditorResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AllocationEditorScreen(
        current: current,
        incomeSources: incomeSources,
        idFactory: idFactory,
      ),
    ),
  );
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
        final recurring = _linkedRecurringDebt(debt);
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

  String get _screenSubheading => _isCurrentMonthSetup
      ? 'هذه الصفحة خاصة بتخطيط ميزانية الشهر الحالي.'
      : 'أنت الآن تعد خطة شهر قادم مسبقًا قبل بداية تنفيذه.';

  Future<void> _showFutureMonthNoticeIfNeeded() async {
    if (!mounted || !_isFutureMonthSetup || _futureMonthNoticeShown) {
      return;
    }
    _futureMonthNoticeShown = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('خطة شهر قادم: $_displayMonthName'),
        content: const Text(
          'هذه الصفحة خاصة بإعداد شهر قادم وليست للشهر الحالي. يمكنك المتابعة أو التحويل مباشرة إلى إعداد الشهر الحالي.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                final now = DateTime.now();
                _displayMonth = DateTime(now.year, now.month, 1);
              });
            },
            child: const Text('خطة الشهر الحالي'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('أوكي'),
          ),
        ],
      ),
    );
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

  Future<void> _showRetroactiveBudgetDialog(
    List<_RetroactiveBudgetAction> actions,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تطبيق عناصر أضيفت بعد نزول الدخل'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'في عناصر اتضافت أو زادت بعد تسجيل الدخل في الدورة الحالية. نقدر نعلّقها الآن للمراجعة أو نطبقها فورًا.',
            ),
            const SizedBox(height: 12),
            ...actions.take(4).map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• ${action.name}: ${action.amount.toStringAsFixed(2)}'
                      '${action.isPhysical ? ' (خصم فعلي)' : ' (تخصيص افتراضي)'}',
                    ),
                  ),
                ),
            if (actions.length > 4)
              Text('وباقي ${actions.length - 4} عنصر/عناصر أخرى.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('تأجيل'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد الآن'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final action in actions) {
      if (action.kind == 'jar') {
        await widget.cubit.confirmJarDistribution(action.id);
      } else {
        await widget.cubit.confirmAllocationDistribution(action.id);
      }
    }
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

      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('يوم بداية الدورة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'أنت حاليًا في منتصف الدورة المحددة.\n\n'
                '• الدورة الحالية: ${now.day}/${now.month} — ${currentEnd.day}/${currentEnd.month}\n'
                '• الدورة الكاملة القادمة تبدأ يوم $newDay/${nextCycleStart.month}',
              ),
              const SizedBox(height: 12),
              const Text(
                'هتبدأ الإعداد ده من النهارده ولا هتطبقه من الدورة الجاية؟',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('next'),
              child: const Text('من الدورة الجاية'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('now'),
              child: const Text('من النهارده'),
            ),
          ],
        ),
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
    final recurring = _linkedRecurringDebtFromSetup(setup, debt);
    return BudgetRecurringPlanService.amountDueInCycle(
      debt: debt,
      recurring: recurring,
      cycleStart: cycleStart,
      cycleEnd: cycleEnd,
    );
  }

  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  Future<bool> _confirmDeletion({
    required String title,
    required String message,
    String confirmLabel = 'حذف',
  }) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _openIncomeComposer() async {
    final result =
        await Navigator.of(context).push<RecurringTransactionComposerResult>(
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: TransactionType.income.value,
          initialWithinBudget: true,
          returnOnSave: true,
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
    final linkedRecurring = _linkedRecurringIncome(current);
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

  Future<void> _openAllocationInfoSheet(AllocationEntity allocation) async {
    final planned = allocation.funding.fold<double>(
      0,
      (s, f) => s + f.plannedAmount,
    );
    final categoryCount = allocation.categories.length;
    final rolloverLabel = allocation.rolloverBehavior == RolloverBehavior.keep.value
        ? 'يرحل للدورة التالية'
        : 'يرجع للتوفير';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.55;
        return SizedBox(
          height: height.clamp(380.0, 520.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'تفاصيل المخصص',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        _detailsBlocks(
                          blocks: [
                            _DetailsBlock.wide('اسم المخصص', allocation.name),
                            _DetailsBlock.narrow(
                              'إجمالي المخطط',
                              planned.toStringAsFixed(2),
                            ),
                            _DetailsBlock.narrow('سلوك المتبقي', rolloverLabel),
                            _DetailsBlock.wide(
                              'مصادر التمويل',
                              _fundingBreakdownText(
                                allocation.funding
                                    .map((f) =>
                                        (f.incomeSourceId, f.plannedAmount))
                                    .toList(),
                              ),
                            ),
                            _DetailsBlock.narrow(
                                'عدد الفئات', '$categoryCount'),
                            _DetailsBlock.wide(
                              'الأيقونة واللون',
                              '${allocation.icon} • ${allocation.iconColor}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showAllocationDialog(current: allocation);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل المخصص'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLinkedDialog({LinkedWalletEntity? current}) async {
    if (_budget.incomeSources.isEmpty && current == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يُنصح بإضافة مصدر دخل أولاً لتفعيل التمويل'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    final result = await Navigator.of(context).push<JarEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => JarEditorScreen(
          current: current,
          incomeSources: _budget.incomeSources,
          idFactory: _id,
        ),
      ),
    );
    if (result == null) {
      return;
    }
    if (result.deleteRequested && current != null) {
      final next =
          _budget.linkedWallets.where((e) => e.id != current.id).toList();
      await _saveBudget(_budget.copyWith(linkedWallets: next));
      return;
    }
    final entity = result.entity;
    if (entity == null) {
      return;
    }
    final next = current == null
        ? [..._budget.linkedWallets, entity]
        : _budget.linkedWallets
            .map((e) => e.id == current.id ? entity : e)
            .toList();
    await _saveBudget(_budget.copyWith(linkedWallets: next));
  }

  Future<void> _openJarInfoSheet(LinkedWalletEntity jar) async {
    final fundingText = _fundingBreakdownText(
      jar.funding.map((f) => (f.incomeSourceId, f.plannedAmount)).toList(),
    );
    final automationLabel = _incomeTypeLabel(jar.automationType);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.55;
        return SizedBox(
          height: height.clamp(380.0, 520.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'تفاصيل الحصالة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        _detailsBlocks(
                          blocks: [
                            _DetailsBlock.wide('اسم الحصالة', jar.name),
                            _DetailsBlock.narrow(
                              'الرصيد الحالي',
                              jar.balance.toStringAsFixed(2),
                            ),
                            _DetailsBlock.narrow(
                              'المخصص الشهري',
                              jar.monthlyAmount.toStringAsFixed(2),
                            ),
                            _DetailsBlock.narrow(
                                'يوم التحويل', '${jar.executionDay}'),
                            _DetailsBlock.narrow(
                                'نوع التنفيذ', automationLabel),
                            _DetailsBlock.wide('مصادر التمويل', fundingText),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showLinkedDialog(current: jar);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل الحصالة'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDebtDialog({DebtEntity? current}) async {
    final linkedRecurring =
        current == null ? null : _linkedRecurringDebt(current);
    final draftRecurring = (linkedRecurring ??
            RecurringTransactionEntity(
              id: current?.recurringTransactionId ?? '',
              name: current?.name ?? '',
              type: TransactionType.expense.value,
              amount: current?.amount ?? 0,
              dayOfMonth: (current?.executionDay ?? 1).clamp(1, 28),
              executionType: current?.type ?? AutomationType.confirm.value,
              walletId: widget.cubit.state.wallets.isNotEmpty
                  ? widget.cubit.state.wallets.first.id
                  : '',
              budgetScope: BudgetScope.withinBudget.value,
              recurrencePattern:
                  current?.recurrencePattern ?? RecurrencePattern.monthly.value,
              icon: 'receipt',
              iconColor: '#c65d2e',
              monthOfYear: current?.monthOfYear,
              incomeSourceId: null,
              isDebtOrSubscription: true,
              expensePlanKind: current?.isSubscription == true
                  ? ExpensePlanKind.subscription.value
                  : ExpensePlanKind.installment.value,
              debtPrincipalTotal: current?.principalTotal ??
                  (current?.isInstallment == true ? current!.amount : null),
            ))
        .copyWith(
      recurrencePattern: current?.recurrencePattern != null &&
              current!.recurrencePattern != RecurrencePattern.monthly.value
          ? current.recurrencePattern
          : (linkedRecurring?.recurrencePattern ??
              RecurrencePattern.monthly.value),
      monthOfYear: current?.monthOfYear ?? linkedRecurring?.monthOfYear,
      expensePlanKind: linkedRecurring?.expensePlanKind ??
          (current?.isSubscription == true
              ? ExpensePlanKind.subscription.value
              : ExpensePlanKind.installment.value),
      debtPrincipalTotal: linkedRecurring?.debtPrincipalTotal ??
          current?.principalTotal ??
          (current?.isInstallment == true ? current!.amount : null),
    );

    final result =
        await Navigator.of(context).push<RecurringTransactionComposerResult>(
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: TransactionType.expense.value,
          initialWithinBudget: true,
          initialRecurring: draftRecurring,
          initialExpensePlanKind: draftRecurring.expensePlanKind ??
              ExpensePlanKind.installment.value,
          debtOnlyMode: true,
          returnOnSave: true,
        ),
        fullscreenDialog: true,
      ),
    );
    final recurring = result?.recurring;
    if (recurring == null) {
      return;
    }

    final recurringId =
        linkedRecurring?.id ?? current?.recurringTransactionId ?? _id('rec');
    final isSubscription =
        recurring.expensePlanKind == ExpensePlanKind.subscription.value;
    final principal = recurring.debtPrincipalTotal;
    final debt = DebtEntity(
      id: current?.id ?? _id('debt'),
      name: recurring.name,
      amount: recurring.amount,
      executionDay: recurring.dayOfMonth.clamp(1, 31),
      type: recurring.executionType,
      fundingSource: current?.fundingSource ??
          (_budget.incomeSources.isNotEmpty
              ? _budget.incomeSources.first.id
              : ''),
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

    final nextDebts = current == null
        ? [..._budget.debts, debt]
        : _budget.debts
            .map((item) => item.id == current.id ? debt : item)
            .toList();
    await _saveBudget(_budget.copyWith(debts: nextDebts));

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
    await _showDebtDialog();
  }

  Future<void> _openLentSetupManagementSheet(
      RecurringTransactionEntity record) async {
    final personName = record.lentPersonName ?? record.name;
    final returnDate = record.anchorDate != null
        ? DateTime.tryParse(record.anchorDate!)
        : null;
    final isOverdue = returnDate != null &&
        DateTime(returnDate.year, returnDate.month, returnDate.day).isBefore(
            DateTime(
                DateTime.now().year, DateTime.now().month, DateTime.now().day));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSt) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1a7a4a).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.handshake_rounded,
                            color: Color(0xFF1a7a4a)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              personName,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '${record.amount.toStringAsFixed(2)}'
                              '${returnDate != null ? ' • ${returnDate.day}/${returnDate.month}/${returnDate.year}' : ''}'
                              '${isOverdue ? ' ⚠️ متأخر' : ''}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isOverdue
                                    ? const Color(0xFFC65D2E)
                                    : Theme.of(ctx)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetCtx).pop();
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: const Text('تأكيد الاسترداد'),
                            content: Text(
                                'هل استردّيت السلفة من $personName؟\nسيتم إضافة المبلغ لمحفظتك.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('إلغاء')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('تم الاسترداد')),
                            ],
                          ),
                        );
                        if (confirmed == true && mounted) {
                          await widget.cubit.settleLentRecord(record.id);
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('تم الاسترداد'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: const Color(0xFF1a7a4a),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(sheetCtx).pop();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: returnDate ??
                                  DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 5)),
                              helpText: 'اختر تاريخ الاسترداد الجديد',
                            );
                            if (picked != null && mounted) {
                              await widget.cubit
                                  .postponeLentRecord(record.id, picked);
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.schedule_rounded),
                          label: const Text('تأجيل'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.of(sheetCtx).pop();
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('تنازل عن السلفة'),
                                content: Text(
                                    'هل متأكد إنك هتتنازل عن ${record.amount.toStringAsFixed(2)} من $personName؟\n\nلن يُضاف المبلغ لمحفظتك.'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dCtx, false),
                                      child: const Text('إلغاء')),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF7B4FBF)),
                                    child: const Text('تنازل'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true && mounted) {
                              await widget.cubit.writeOffLentRecord(record.id);
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded,
                              color: Color(0xFF7B4FBF)),
                          label: const Text('تنازل',
                              style: TextStyle(color: Color(0xFF7B4FBF))),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            side: const BorderSide(
                                color: Color(0xFF7B4FBF), width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetCtx).pop();
                        final confirmed = await _confirmDeletion(
                          title: 'حذف السلفة',
                          message:
                              'سيتم حذف سلفة "$personName" نهائيًا بدون تسجيل. هل تريد المتابعة؟',
                        );
                        if (confirmed && mounted) {
                          await widget.cubit
                              .deleteRecurringTransaction(record.id);
                          setState(() {});
                        }
                      },
                      icon: Icon(Icons.delete_outline_rounded,
                          color: Theme.of(ctx).colorScheme.error),
                      label: Text('حذف',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: BorderSide(
                            color: Theme.of(ctx)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openDebtInfoSheet(DebtEntity debt) async {
    final recurring = _linkedRecurringDebt(debt);
    final walletName = () {
      final id = recurring?.walletId ?? '';
      if (id.isEmpty) return 'غير محدد';
      for (final w in widget.cubit.state.wallets) {
        if (w.id == id) return w.name;
      }
      return id;
    }();
    final fundingName = () {
      final id = debt.fundingSource;
      for (final income in _budget.incomeSources) {
        if (income.id == id) return income.name;
      }
      return id.isEmpty ? 'غير محدد' : id;
    }();
    final recurrenceLabel = _recurrenceLabel(
        recurring?.recurrencePattern ?? RecurrencePattern.monthly.value);
    final monthlyDay =
        (recurring?.dayOfMonth ?? debt.executionDay).clamp(1, 28).toString();
    final timeLabel = (recurring?.scheduledTime?.isNotEmpty == true)
        ? _formatClockTime(recurring!.scheduledTime!)
        : 'غير محدد';
    final reminderLabel = _reminderLabel(
      recurrencePattern:
          recurring?.recurrencePattern ?? RecurrencePattern.monthly.value,
      executionType: recurring?.executionType ?? debt.type,
      reminderLeadDays: recurring?.reminderLeadDays ?? 0,
    );

    final isSubscription = debt.isSubscription;
    final sheetTitle = isSubscription ? 'تفاصيل الاشتراك' : 'تفاصيل الدين';
    final nameLabel = isSubscription ? 'اسم الاشتراك' : 'اسم الدين';
    final amountLabel = isSubscription ? 'قيمة الاشتراك' : 'قيمة القسط';
    final editLabel = isSubscription ? 'تعديل الاشتراك' : 'تعديل الدين';
    final deleteTitle = isSubscription ? 'حذف الاشتراك' : 'حذف الدين';
    final deleteMessage = isSubscription
        ? 'سيتم حذف "${debt.name}" من قائمة الاشتراكات. هل تريد المتابعة؟'
        : 'سيتم حذف "${debt.name}" من خطة الميزانية. هل تريد المتابعة؟';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        final height = MediaQuery.of(sheetCtx).size.height * 0.6;
        return SizedBox(
          height: height.clamp(420.0, 580.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    sheetTitle,
                    style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(sheetCtx).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(sheetCtx)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        _detailsBlocks(
                          blocks: [
                            _DetailsBlock.wide(nameLabel, debt.name),
                            _DetailsBlock.narrow(
                              amountLabel,
                              debt.amount.toStringAsFixed(2),
                            ),
                            if (recurring?.debtPrincipalTotal != null)
                              _DetailsBlock.narrow(
                                'إجمالي الدين',
                                recurring!.debtPrincipalTotal!
                                    .toStringAsFixed(2),
                              ),
                            _DetailsBlock.narrow(
                              'يوم الاستحقاق',
                              '${debt.executionDay}',
                            ),
                            _DetailsBlock.narrow('مصدر التمويل', fundingName),
                            _DetailsBlock.narrow('محفظة السداد', walletName),
                            _DetailsBlock.narrow(
                              'طريقة التنفيذ',
                              _incomeTypeLabel(
                                  recurring?.executionType ?? debt.type),
                            ),
                            _DetailsBlock.narrow(
                                'نوع التكرار', recurrenceLabel),
                            _DetailsBlock.narrow('اليوم الشهري', monthlyDay),
                            _DetailsBlock.narrow('الوقت', timeLabel),
                            _DetailsBlock.narrow('وقت الإشعار', reminderLabel),
                            _DetailsBlock.wide(
                              'الملاحظات',
                              recurring?.notes?.isNotEmpty == true
                                  ? recurring!.notes!
                                  : '—',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      _showDebtDialog(current: debt);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(editLabel),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final approved = await _confirmDeletion(
                        title: deleteTitle,
                        message: deleteMessage,
                      );
                      if (!approved) return;
                      final rec = _linkedRecurringDebt(debt);
                      if (rec != null) {
                        await widget.cubit.deleteRecurringTransaction(rec.id);
                      }
                      await _saveBudget(
                        _budget.copyWith(
                          debts: _budget.debts
                              .where((e) => e.id != debt.id)
                              .toList(),
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(sheetCtx).colorScheme.error,
                    ),
                    label: Text(
                      deleteTitle,
                      style: TextStyle(
                          color: Theme.of(sheetCtx).colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(
                          color: Theme.of(sheetCtx)
                              .colorScheme
                              .error
                              .withValues(alpha: 0.4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
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
              _StartDayPickerTile(
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
                  prefixIcon: Icon(Icons.savings_rounded),
                ),
                items: [
                  DropdownMenuItem(
                      value: RolloverBehavior.toSavings.value, child: Text('يتحول للتوفير')),
                  DropdownMenuItem(
                      value: RolloverBehavior.keep.value, child: Text('يبقى للدورة الجديدة')),
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
        _plannerSection(
          title: 'مصادر الدخل',
          subtitle:
              'أضف الدخل الثابت أو المتغير الذي يدخل في ميزانيتك الشهرية.',
          icon: Icons.south_west_rounded,
          accent: const Color(0xFF0F9D7A),
          actionLabel: 'إضافة دخل',
          onAction: _openIncomeComposer,
          showHeaderAction: false,
          footerAction: _thinAddButton(
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
                  final linkedRecurring = _linkedRecurringIncome(income);
                  final iconName = linkedRecurring?.icon ?? 'cash';
                  final iconColorHex = linkedRecurring?.iconColor ?? '#0f9d7a';
                  return _incomePlanTile(
                    income: income,
                    iconName: iconName,
                    iconColorHex: iconColorHex,
                    onTap: () => _openIncomeInfoSheet(income),
                  );
                },
              ),
            ];
          }(),
        ),
        const SizedBox(height: 14),
        _plannerSection(
          title: 'المخصصات',
          subtitle: 'قسّم ميزانيتك على بنود واضحة قبل بداية الصرف.',
          icon: Icons.grid_view_rounded,
          accent: const Color(0xFF296BFF),
          actionLabel: 'إضافة مخصص',
          onAction: () => _showAllocationDialog(),
          showHeaderAction: false,
          footerAction: _thinAddButton(
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
                      detailText: allocation.rolloverBehavior == RolloverBehavior.keep.value
                          ? 'يرحل للدورة التالية'
                          : 'يرجع للتوفير',
                      leadingWidget: _iconBadge(
                        iconName: allocation.icon,
                        colorHex: allocation.iconColor,
                        size: 42,
                      ),
                      tint: _colorFromHex(allocation.iconColor),
                      onTap: () => _openAllocationInfoSheet(allocation),
                      onDelete: null,
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 14),
        _plannerSection(
          title: 'الحصالات',
          subtitle: 'مبالغ ثابتة تتحول لأهدافك أو محافظك المرتبطة.',
          icon: Icons.savings_rounded,
          accent: const Color(0xFFE09F1F),
          actionLabel: 'إضافة حصالة',
          onAction: () => _showLinkedDialog(),
          showHeaderAction: false,
          footerAction: _thinAddButton(
            label: 'إضافة حصالة',
            onPressed: () => _showLinkedDialog(),
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
                      leadingWidget: _iconBadge(
                        iconName: wallet.icon,
                        colorHex: wallet.iconColor,
                        size: 42,
                      ),
                      tint: _colorFromHex(wallet.iconColor),
                      onTap: () => _openJarInfoSheet(wallet),
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

            return _plannerSection(
              title: 'الديون والأقساط',
              subtitle: 'أقساط شهرية وديون مربوطة بالميزانية، بالإضافة للسلف.',
              icon: Icons.receipt_long_rounded,
              accent: const Color(0xFFC65D2E),
              actionLabel: '',
              onAction: () {},
              showHeaderAction: false,
              footerAction: _thinAddButton(
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
                    final recurring = _linkedRecurringDebt(debt);
                    final iconColor = recurring?.iconColor ?? '#c65d2e';
                    return _planTile(
                      title: debt.name,
                      amountText: debt.amount.toStringAsFixed(2),
                      detailText: 'يوم ${debt.executionDay}',
                      leadingWidget: _iconBadge(
                        iconName: recurring?.icon ?? 'receipt',
                        colorHex: iconColor,
                        size: 42,
                      ),
                      tint: _colorFromHex(iconColor),
                      onTap: () => _openDebtInfoSheet(debt),
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
                      leadingWidget: _iconBadge(
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
        _plannerSection(
          title: 'الاشتراكات',
          subtitle: 'اشتراكات متكررة مثل خدمات البث والأدوات الدورية.',
          icon: Icons.subscriptions_rounded,
          accent: const Color(0xFF4A7C59),
          actionLabel: '',
          onAction: () {},
          showHeaderAction: false,
          footerAction: _thinAddButton(
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
              final recurring = _linkedRecurringDebt(debt);
              final iconColor = recurring?.iconColor ?? '#4a7c59';
              return _planTile(
                title: debt.name,
                amountText: debt.amount.toStringAsFixed(2),
                detailText: _recurrenceLabel(
                    recurring?.recurrencePattern ?? debt.recurrencePattern),
                leadingWidget: _iconBadge(
                  iconName: recurring?.icon ?? 'subscriptions',
                  colorHex: iconColor,
                  size: 42,
                ),
                tint: _colorFromHex(iconColor),
                onTap: () => _openDebtInfoSheet(debt),
                onDelete: null,
              );
            }).toList();
          }(),
        ),
        const SizedBox(height: 18),
        _planSummaryCard(),
      ],
    );
  }

  Widget _planSummaryCard() {
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
          const SizedBox(height: 14),
          _summaryRow(
            label: 'إجمالي الدخل',
            value: _totalIncome,
            light: true,
          ),
          _summaryRow(
            label: 'إجمالي المخصص',
            value: _committed,
            light: true,
          ),
          _summaryRow(
            label: 'المخصصات',
            value: _allocationsTotal,
            light: true,
          ),
          _summaryRow(
            label: 'الحصالات',
            value: _linkedTotal,
            light: true,
          ),
          _summaryRow(
            label: 'الديون والأقساط',
            value: _installmentsTotal,
            light: true,
          ),
          _summaryRow(
            label: 'الاشتراكات',
            value: _subscriptionsTotal,
            light: true,
          ),
          _summaryRow(
            label: 'غير المخصص',
            value: _unallocated,
            light: true,
            emphasize: _unallocated < 0,
          ),
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
            _approxSavingsHint.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'تقدير أولي — يتحدث مع نشاطك وصرفك خلال الشهر.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required String label,
    required double value,
    required bool light,
    bool emphasize = false,
    bool valueBold = false,
  }) {
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
              fontWeight: valueBold ? FontWeight.w900 : FontWeight.w800,
              fontSize: valueBold ? 15 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _plannerSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required String actionLabel,
    required VoidCallback onAction,
    required List<Widget> children,
    bool showHeaderAction = true,
    Widget? footerAction,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showHeaderAction) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ),
            const SizedBox(height: 14),
          ],
          ...children,
          if (footerAction != null) ...[
            const SizedBox(height: 10),
            footerAction,
          ],
        ],
      ),
    );
  }

  Widget _thinAddButton({
    required String label,
    required VoidCallback onPressed,
    required Color tint,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.add_rounded, color: tint, size: 18),
        label: Text(
          label,
          style: TextStyle(
            color: tint,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(42),
          side: BorderSide(color: tint.withValues(alpha: 0.45)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _incomePlanTile({
    required IncomeSourceEntity income,
    required String iconName,
    required String iconColorHex,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final tint = _colorFromHex(iconColorHex);
    final meta = income.isVariable
        ? 'دخل متغير • يدوي'
        : 'يوم ${income.date} • ${_incomeTypeLabel(income.type)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: tint.withValues(alpha: 0.14),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _iconBadge(
                iconName: iconName,
                colorHex: iconColorHex,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      income.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: FittedBox(
                            alignment: AlignmentDirectional.centerStart,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              income.isVariable
                                  ? 'متغير'
                                  : income.amount.toStringAsFixed(2),
                              maxLines: 1,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF165B47),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              income.isVariable
                                  ? 'غير ثابت'
                                  : 'يوم ${income.date}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openIncomeInfoSheet(IncomeSourceEntity income) async {
    final theme = Theme.of(context);
    final state = widget.cubit.state;
    final recurring = _linkedRecurringIncome(income);

    String resolveWalletName() {
      final wallets = state.wallets;
      for (final w in wallets) {
        if (w.id == income.targetWalletId) return w.name;
      }
      return income.targetWalletId.isEmpty ? 'غير محدد' : income.targetWalletId;
    }

    final incomeTypeLabel = income.isVariable ? 'متغير' : 'ثابت';
    final executionLabel = recurring == null
        ? _incomeTypeLabel(income.type)
        : _incomeTypeLabel(recurring.executionType);
    final recurrenceLabel = _recurrenceLabel(
        recurring?.recurrencePattern ?? RecurrencePattern.monthly.value);
    final monthlyDay = (recurring?.dayOfMonth ?? income.date).clamp(1, 28);
    final timeLabel = (recurring?.scheduledTime?.isNotEmpty == true)
        ? _formatClockTime(recurring!.scheduledTime!)
        : null;
    final executionDayLine = income.isVariable
        ? 'يدوي'
        : timeLabel != null
            ? 'يوم $monthlyDay • $timeLabel'
            : 'يوم $monthlyDay';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.48;
        return SizedBox(
          height: height.clamp(340.0, 460.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    'تفاصيل الدخل',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        _detailsBlocks(
                          blocks: [
                            _DetailsBlock.wide('اسم الدخل', income.name),
                            _DetailsBlock.narrow('نوع الدخل', incomeTypeLabel),
                            _DetailsBlock.narrow(
                              'قيمة الدخل',
                              income.isVariable
                                  ? 'متغير'
                                  : income.amount.toStringAsFixed(2),
                            ),
                            _DetailsBlock.narrow(
                              'محفظة الإيداع',
                              resolveWalletName(),
                            ),
                            _DetailsBlock.narrow(
                                'نوع التكرار', recurrenceLabel),
                            _DetailsBlock.wide('يوم التنفيذ', executionDayLine),
                            _DetailsBlock.narrow(
                                'طريقة التنفيذ', executionLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showIncomeDialog(current: income);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل الدخل'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailsBlocks({required List<_DetailsBlock> blocks}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const spacing = 10.0;

        // Force a 2-column layout (even on phones) to reduce scrolling.
        double itemWidth() {
          return ((w - spacing) / 2).clamp(140.0, w);
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final block in blocks)
              SizedBox(
                width: itemWidth(),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        block.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.15,
                          fontSize: 12.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _fundingBreakdownText(List<(String, double)> funding) {
    final cleaned = funding.where((f) => f.$1.isNotEmpty && f.$2 > 0).toList();
    if (cleaned.isEmpty) {
      return 'لا يوجد';
    }
    final nameById = <String, String>{
      for (final inc in _budget.incomeSources) inc.id: inc.name,
    };
    return cleaned.map((f) {
      final name = nameById[f.$1] ?? f.$1;
      final amount = f.$2.toStringAsFixed(0);
      return '$name $amount';
    }).join('\n');
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
    if (pattern == RecurrencePattern.manualVariable.value) return 'يدوي';
    return pattern;
  }

  String _formatClockTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return value;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return value;
    final h = hour.clamp(0, 23);
    final m = minute.clamp(0, 59);
    final suffix = h >= 12 ? 'مساء' : 'صباحًا';
    final displayH = (h % 12 == 0) ? 12 : (h % 12);
    final mm = m.toString().padLeft(2, '0');
    return '$displayH:$mm $suffix';
  }

  String _reminderLabel({
    required String recurrencePattern,
    required String executionType,
    required int reminderLeadDays,
  }) {
    if (executionType != AutomationType.confirm.value) {
      return 'لا يوجد';
    }
    final value = reminderLeadDays.clamp(0, 3);
    final isHourly = recurrencePattern == RecurrencePattern.daily.value ||
        recurrencePattern == RecurrencePattern.weekly.value ||
        recurrencePattern == RecurrencePattern.biweekly.value ||
        recurrencePattern == RecurrencePattern.every3Weeks.value;
    if (isHourly) {
      return value == 0 ? 'في الوقت المحدد' : 'قبلها بـ $value ساعة';
    }
    return value == 0 ? 'في نفس اليوم' : 'مبكر بـ $value يوم';
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

  String _incomeTypeLabel(String type) {
    if (type == AutomationType.auto.value) return 'تلقائي';
    if (type == AutomationType.confirm.value) return 'تأكيد';
    if (type == 'manual') return 'يدوي';
    return type;
  }

  Widget _iconBadge({
    required String iconName,
    required String colorHex,
    double size = 48,
  }) {
    final color = _colorFromHex(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Center(
        child: AppIconPickerDialog.iconWidgetForName(
          iconName,
          color: color,
          size: size * 0.48,
        ),
      ),
    );
  }

  Color _colorFromHex(String value) {
    final hex = value.replaceAll('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    final intColor = int.tryParse(normalized, radix: 16) ?? 0xFF165B47;
    return Color(intColor);
  }

  RecurringTransactionEntity? _linkedRecurringIncome(
      IncomeSourceEntity source) {
    final linked = widget.cubit.state.recurringTransactions.where(
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

  RecurringTransactionEntity? _linkedRecurringDebt(DebtEntity debt) {
    return BudgetRecurringPlanService.linkedRecurring(
      widget.cubit.state.recurringTransactions,
      debt,
    );
  }

  RecurringTransactionEntity? _linkedRecurringDebtFromSetup(
    BudgetSetupEntity setup,
    DebtEntity debt,
  ) {
    return _linkedRecurringDebt(debt);
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

class AllocationEditorResult {
  const AllocationEditorResult({
    this.entity,
    this.deleteRequested = false,
  });

  final AllocationEntity? entity;
  final bool deleteRequested;
}

class _AllocationEditorScreen extends StatefulWidget {
  const _AllocationEditorScreen({
    required this.current,
    required this.incomeSources,
    required this.idFactory,
  });

  final AllocationEntity? current;
  final List<IncomeSourceEntity> incomeSources;
  final String Function(String prefix) idFactory;

  @override
  State<_AllocationEditorScreen> createState() =>
      _AllocationEditorScreenState();
}

class _AllocationEditorScreenState extends State<_AllocationEditorScreen> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;
  late String _rolloverBehavior;
  late List<AllocationFundingEntity> _funding;

  bool get _canDelete => widget.current != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.current?.name ?? '');
    _selectedIcon = widget.current?.icon ?? 'category';
    _selectedColor = widget.current?.iconColor ?? '#165b47';
    _rolloverBehavior = widget.current?.rolloverBehavior ?? RolloverBehavior.toSavings.value;
    _funding = List<AllocationFundingEntity>.from(
      widget.current?.funding ??
          [
            // AllocationFundingEntity(
            //   id: widget.idFactory('fund'),
            //   incomeSourceId: widget.incomeSources.first.id,
            //   plannedAmount: 0,
            // ),
          ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? incomeSourceId;
  double get _totalPlanned => _funding.fold<double>(
        0,
        (sum, item) => sum + item.plannedAmount,
      );

  Future<void> _pickIcon() async {
    final picked = await AppIconPickerDialog.show(
      context,
      initialIconName: _selectedIcon,
      initialColorHex: _selectedColor,
      title: 'اختيار أيقونة المخصص',
      name: _nameController.text,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _selectedIcon = picked.iconName;
      _selectedColor = picked.colorHex;
    });
  }

  void _addFundingSource() {
    setState(() {
      _funding = [
        ..._funding,
        AllocationFundingEntity(
          id: widget.idFactory('fund'),
          incomeSourceId: incomeSourceId ?? '',
          plannedAmount: 0,
        ),
      ];
    });
  }

  void _updateFundingSource(String id,
      {String? incomeSourceId, double? amount}) {
    setState(() {
      _funding = _funding
          .map(
            (item) => item.id == id
                ? AllocationFundingEntity(
                    id: item.id,
                    incomeSourceId: incomeSourceId ?? item.incomeSourceId,
                    plannedAmount: amount ?? item.plannedAmount,
                  )
                : item,
          )
          .toList();
    });
  }

  Future<void> _removeFundingSource(String id) async {
    if (_funding.length == 1) {
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مصدر التمويل'),
        content: const Text(
            'سيتم حذف مصدر التمويل من هذا المخصص. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) {
      return;
    }
    setState(() {
      _funding = _funding.where((item) => item.id != id).toList();
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final cleaned = _funding
        .where(
            (item) => item.incomeSourceId.isNotEmpty && item.plannedAmount > 0)
        .toList();
    if (name.isEmpty) {
      _showMessage('اكتب اسمًا واضحًا للمخصص أولًا.');
      return;
    }
    if (cleaned.isEmpty) {
      _showMessage('أضف مصدر تمويل واحدًا على الأقل بقيمة أكبر من صفر.');
      return;
    }
    Navigator.of(context).pop(
      AllocationEditorResult(
        entity: AllocationEntity(
          id: widget.current?.id ?? widget.idFactory('alloc'),
          name: name,
          icon: _selectedIcon,
          iconColor: _selectedColor,
          rolloverBehavior: _rolloverBehavior,
          funding: cleaned,
          categories: widget.current?.categories ?? const [],
        ),
      ),
    );
  }

  Future<void> _delete() async {
    if (!_canDelete) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المخصص'),
        content: const Text(
            'سيتم حذف هذا المخصص من خطة الميزانية. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    Navigator.of(context)
        .pop(const AllocationEditorResult(deleteRequested: true));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _colorFromHex(_selectedColor);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.current == null ? 'إضافة مخصص' : 'تعديل المخصص'),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: accent,
            ),
            child: Text(
              widget.current == null ? 'إضافة المخصص' : 'حفظ التعديلات',
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.95),
                  accent.withValues(alpha: 0.72),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: AppIconPickerDialog.iconWidgetForName(
                      _selectedIcon,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.trim().isEmpty
                            ? 'مخصص جديد'
                            : _nameController.text.trim(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _rolloverBehavior == RolloverBehavior.keep.value
                            ? 'المتبقي يرحل إلى الشهر التالي'
                            : 'المتبقي يتحول إلى التوفير',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'إجمالي التمويل ${_totalPlanned.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _EditorSection(
            title: 'البيانات الأساسية',
            subtitle: 'سمِّ المخصص واختر له أيقونة واضحة يسهل تمييزها.',
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المخصص',
                    hintText: 'مثل: البيت أو المواصلات أو المصروف اليومي',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickIcon,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.35,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            colorScheme.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: AppIconPickerDialog.iconWidgetForName(
                              _selectedIcon,
                              color: accent,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'اختيار الأيقونة واللون',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'غيّر شكل المخصص ليظهر بوضوح في شاشة المتابعة.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EditorSection(
            title: 'المتبقي آخر الدورة',
            subtitle: 'اختر كيف تريد التعامل مع الرصيد المتبقي من هذا المخصص.',
            child: Column(
              children: [
                _ChoiceTile(
                  title: 'يرحل إلى الشهر التالي',
                  subtitle:
                      'يبقى المبلغ المتبقي داخل نفس المخصص في الدورة الجديدة.',
                  selected: _rolloverBehavior == RolloverBehavior.keep.value,
                  onTap: () => setState(() => _rolloverBehavior = RolloverBehavior.keep.value),
                ),
                const SizedBox(height: 10),
                _ChoiceTile(
                  title: 'يتحول إلى التوفير',
                  subtitle: 'ينتقل المتبقي تلقائيًا إلى التوفير بدل ترحيله.',
                  selected: _rolloverBehavior == RolloverBehavior.toSavings.value,
                  onTap: () => setState(() => _rolloverBehavior = RolloverBehavior.toSavings.value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EditorSection(
            title: 'مصادر التمويل',
            subtitle: 'وزّع قيمة هذا المخصص على دخل واحد أو أكثر.',
            trailing: TextButton.icon(
              onPressed: _addFundingSource,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة مصدر'),
            ),
            child: Column(
              children: _funding
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FundingCard(
                        item: item,
                        incomeSources: widget.incomeSources,
                        canDelete: _funding.length > 1,
                        onChanged: ({String? incomeSourceId, double? amount}) {
                          _updateFundingSource(
                            item.id,
                            incomeSourceId: incomeSourceId,
                            amount: amount,
                          );
                        },
                        onDelete: () => _removeFundingSource(item.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_canDelete) ...[
            const SizedBox(height: 14),
            _EditorSection(
              title: 'إدارة المخصص',
              subtitle:
                  'يمكنك حذف المخصص من هنا بدل جعل الحذف سهل الوصول بالخطأ.',
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف المخصص'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0E5A47).withValues(alpha: 0.10)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.26),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF0E5A47)
                : colorScheme.outlineVariant.withValues(alpha: 0.55),
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF0E5A47)
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _FundingCard extends StatelessWidget {
  const _FundingCard({
    required this.item,
    required this.incomeSources,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
  });

  final AllocationFundingEntity item;
  final List<IncomeSourceEntity> incomeSources;
  final bool canDelete;
  final void Function({String? incomeSourceId, double? amount}) onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isValid = incomeSources.any(
      (e) => e.id == item.incomeSourceId,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: isValid ? item.incomeSourceId : null,
            decoration: const InputDecoration(
              labelText: 'مصدر الدخل',
            ),
            items: incomeSources
                .map(
                  (income) => DropdownMenuItem(
                    value: income.id,
                    child: Text(income.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              onChanged(incomeSourceId: value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.plannedAmount == 0
                ? ''
                : item.plannedAmount.toStringAsFixed(0),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'المبلغ المخصص',
              hintText: 'اكتب القيمة التي تريد تخصيصها',
            ),
            onChanged: (value) =>
                onChanged(amount: double.tryParse(value) ?? 0),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: canDelete ? onDelete : null,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('حذف هذا المصدر'),
            ),
          ),
        ],
      ),
    );
  }
}

Color _colorFromHex(String value) {
  final hex = value.replaceAll('#', '');
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  final intColor = int.tryParse(normalized, radix: 16) ?? 0xFF165B47;
  return Color(intColor);
}

enum _DetailsBlockSize { narrow, wide }

class _DetailsBlock {
  const _DetailsBlock(this.size, this.label, this.value);
  final _DetailsBlockSize size;
  final String label;
  final String value;

  static _DetailsBlock narrow(String label, String value) =>
      _DetailsBlock(_DetailsBlockSize.narrow, label, value);
  static _DetailsBlock wide(String label, String value) =>
      _DetailsBlock(_DetailsBlockSize.wide, label, value);
}

// ─────────────────────────────────────────────────────────────────────────────
// Start Day Grid Picker
// ─────────────────────────────────────────────────────────────────────────────

class _StartDayPickerTile extends StatelessWidget {
  const _StartDayPickerTile({
    required this.selectedDay,
    required this.onDaySelected,
  });

  final int selectedDay;
  final Future<void> Function(int) onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: () => _showDaySheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.event_rounded,
                size: 22, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بداية الدورة',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'اليوم $selectedDay من كل شهر',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.unfold_more_rounded,
                size: 20, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  void _showDaySheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختر يوم بداية الدورة',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'سيتم تطبيق التغيير على الدورة الحالية أو القادمة',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: 28,
                itemBuilder: (_, index) {
                  final day = index + 1;
                  final isSelected = day == selectedDay;
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onDaySelected(day);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$day',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isSelected
                                ? colorScheme.onPrimary
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
