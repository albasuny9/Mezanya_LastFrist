import 'package:flutter/material.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'package:intl/intl.dart';

import '../../../../core/constants/transaction_types.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/services/budget_recurring_plan_service.dart';
import '../../../budget/presentation/screens/budget_tracking_screen.dart';
import '../../../home/presentation/screens/money_screen.dart';
import '../../../notifications/presentation/screens/notifications_center_screen.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';
import '../../../transactions/presentation/screens/add_transaction_screen.dart';
import '../../../wallets/presentation/screens/wallets_screen.dart';
import '../widgets/main_shell_app_bar.dart';
import '../widgets/main_shell_bottom_navigation.dart';
import '../widgets/more_tab_content.dart';
import '../widgets/section_page_scaffold.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({
    super.key,
    required this.cubit,
  });

  final AppCubit cubit;

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  static const int _addTabIndex = 2;

  int _currentIndex = 0;
  bool _isAddSheetOpen = false;
  late final Future<String> _todayLabelFuture = _buildTodayLabel();

  final List<MainShellDestination> _destinations = const [
    MainShellDestination(
      label: 'الفلوس',
      icon: Icons.bar_chart_rounded,
      activeIcon: Icons.bar_chart,
    ),
    MainShellDestination(
      label: 'المحافظ',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
    ),
    MainShellDestination(
      label: 'إضافة',
      icon: Icons.add_circle_outline_rounded,
      activeIcon: Icons.add_circle_rounded,
    ),
    MainShellDestination(
      label: 'الميزانية',
      icon: Icons.pie_chart_outline_rounded,
      activeIcon: Icons.pie_chart_rounded,
    ),
    MainShellDestination(
      label: 'المزيد',
      icon: Icons.more_horiz_rounded,
      activeIcon: Icons.more_horiz_rounded,
    ),
  ];

  Future<String> _buildTodayLabel() async {
    await initializeDateFormatting('ar');
    return DateFormat('EEEE d MMMM yyyy', 'ar').format(DateTime.now());
  }

  bool get _showsAppBar => _currentIndex != _addTabIndex;

  List<Widget> get _pages => [
        MoneyScreen(cubit: widget.cubit),
        WalletsScreen(cubit: widget.cubit),
        const SizedBox.shrink(),
        BudgetTrackingScreen(cubit: widget.cubit),
        MoreTabContent(cubit: widget.cubit),
      ];

  @override
  Widget build(BuildContext context) {
    final pendingNotifications = _pendingNotificationCount(widget.cubit.state);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _showsAppBar
          ? MainShellAppBar(
              todayLabelFuture: _todayLabelFuture,
              pendingNotifications: pendingNotifications,
              onOpenNotifications: _openNotifications,
            )
          : null,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
      ),
      bottomNavigationBar: MainShellBottomNavigation(
        selectedIndex: _currentIndex,
        destinations: _destinations,
        onSelected: _handleDestinationSelected,
      ),
    );
  }

  void _handleDestinationSelected(int index) {
    if (index == _addTabIndex) {
      _openAddSheet();
      return;
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _openAddSheet() async {
    if (_isAddSheetOpen) {
      return;
    }

    setState(() => _isAddSheetOpen = true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      barrierColor: const Color(0xFF2D2A22).withValues(alpha: 0.28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddTransactionScreen(cubit: widget.cubit),
      ),
    );

    if (mounted) {
      setState(() => _isAddSheetOpen = false);
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SectionPageScaffold(
          title: 'الإشعارات',
          child: NotificationsCenterScreen(cubit: widget.cubit),
        ),
      ),
    );
  }

  int _pendingNotificationCount(AppStateEntity state) {
    final month = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final budget = state.budgetSetup;
    final now = DateTime.now();
    final cycleStart = budget.cycleStartFor(now);
    final cycleEnd = budget.cycleEndFor(now);
    final monthTransactions = state.transactions.where((transaction) {
      return transaction.createdAt.year == month.year &&
          transaction.createdAt.month == month.month;
    }).toList();
    final cycleTransactions = state.transactions.where((transaction) {
      return !transaction.createdAt.isBefore(cycleStart) &&
          !transaction.createdAt.isAfter(cycleEnd);
    }).toList();
    final incomeTransactions = monthTransactions
        .where(
            (transaction) => transaction.type == TransactionType.income.value)
        .toList();
    var count = 0;

    for (final income in budget.incomeSources) {
      if (income.isVariable ||
          incomeTransactions.any(
            (transaction) => transaction.incomeSourceId == income.id,
          )) {
        continue;
      }

      final recurringTransactions = state.recurringTransactions.where(
        (item) =>
            item.type == TransactionType.income.value &&
            item.budgetScope == BudgetScope.withinBudget.value &&
            item.incomeSourceId == income.id,
      );
      final recurring =
          recurringTransactions.isEmpty ? null : recurringTransactions.first;
      final dueDate =
          DateTime(month.year, month.month, income.date.clamp(1, 28));
      final reminderLeadDays = (recurring?.reminderLeadDays ?? 0).clamp(0, 3);
      final today = DateTime(now.year, now.month, now.day);
      final reminderDate = dueDate.subtract(Duration(days: reminderLeadDays));
      final canRecordEarly = reminderLeadDays > 0 &&
          !today.isBefore(reminderDate) &&
          today.isBefore(dueDate);
      final isDueOrLate = !today.isBefore(dueDate);

      if (canRecordEarly || isDueOrLate) {
        count++;
      }
    }

    for (final debt in budget.debts) {
      final recurring = BudgetRecurringPlanService.linkedRecurring(
        state.recurringTransactions,
        debt,
      );
      if (recurring == null ||
          recurring.executionType != AutomationType.confirm.value) {
        continue;
      }
      final paidAmount = cycleTransactions
          .where(
              (transaction) => transaction.notes?.contains(debt.name) == true)
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);
      final prompt = RecurringScheduleEngine.expensePrompt(recurring, now);
      final remaining = BudgetRecurringPlanService.pendingDecisionAmount(
        debt: debt,
        recurring: recurring,
        cyclePaid: paidAmount,
      );

      if (remaining > 0 && prompt != null) {
        count++;
      }
    }

    return count;
  }
}
