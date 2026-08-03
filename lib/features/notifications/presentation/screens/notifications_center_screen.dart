import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../budget/domain/services/budget_cycle_service.dart';
import '../../../budget/domain/services/budget_recurring_plan_service.dart';
import '../../../logs/application/audit_facade.dart';
import '../../../recovery/domain/entities/recovery_entry.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/domain/services/recurring_schedule_engine.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/notification_history_helper.dart';
import '../../domain/notification_history_filters.dart';
import '../../domain/notification_action_copy.dart';
import '../widgets/notification_center_widgets.dart';
import '../widgets/distribution_postpone_sheet.dart';
import '../widgets/notification_history_details_sheet.dart';
import '../../../transactions/presentation/widgets/recurring_postpone_dialog.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  String _selectedTab = 'new';
  final Set<String> _processingIds = {};
  NotificationHistoryCategory _historyCategory =
      NotificationHistoryCategory.all;
  NotificationHistoryDuration _historyDuration =
      NotificationHistoryDuration.days30;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final pendingCards = _pendingNotificationCards(state);
        final historyItems = _historyNotifications(state);
        final filteredHistory = _filteredHistoryItems(historyItems);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            NotificationsTabSelector(
              selectedTab: _selectedTab,
              pendingCount: pendingCards.length,
              historyCount: historyItems.length,
              onTabChanged: (value) => setState(() => _selectedTab = value),
            ),
            if (_selectedTab == 'new') ...[
              const SizedBox(height: 12),
              if (pendingCards.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('لا توجد إشعارات تحتاج إجراء الآن.'),
                  ),
                )
              else
                ...pendingCards,
            ] else ...[
              NotificationHistoryFilterBar(
                categoryLabel: _historyCategory.label,
                durationLabel: _historyDuration.label,
                categoryOptions: NotificationHistoryCategory.values
                    .map((item) => item.label)
                    .toList(),
                durationOptions: NotificationHistoryDuration.values
                    .map((item) => item.label)
                    .toList(),
                onCategorySelected: (label) {
                  final next = NotificationHistoryCategory.values.firstWhere(
                    (item) => item.label == label,
                    orElse: () => NotificationHistoryCategory.all,
                  );
                  setState(() => _historyCategory = next);
                },
                onDurationSelected: (label) {
                  final next = NotificationHistoryDuration.values.firstWhere(
                    (item) => item.label == label,
                    orElse: () => NotificationHistoryDuration.days30,
                  );
                  setState(() => _historyDuration = next);
                },
              ),
              if (filteredHistory.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('لا توجد إشعارات في هذا النطاق.'),
                  ),
                )
              else
                ..._buildGroupedHistoryTiles(state, filteredHistory),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _pendingNotificationCards(AppStateEntity state) {
    final cards = <Widget>[];
    final budget = state.budgetSetup;
    final now = DateTime.now();
    final month = DateTime(DateTime.now().year, DateTime.now().month, 1);
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

    for (final source in budget.incomeSources) {
      final sourceTransactions = incomeTransactions
          .where((transaction) => transaction.incomeSourceId == source.id)
          .toList();
      final pendingMeta = _incomePendingMeta(
        state,
        source,
        sourceTransactions,
        month,
      );
      if (pendingMeta == null) continue;

      cards.add(
        PendingNotificationCard(
          accent: pendingMeta.isDueOrLate
              ? const Color(0xFF0F9D7A)
              : const Color(0xFF4C8BF5),
          title: source.name,
          amount: source.amount,
          icon: _pendingIconBox(
            Icons.south_west_rounded,
            pendingMeta.isDueOrLate
                ? const Color(0xFF0F9D7A)
                : const Color(0xFF4C8BF5),
          ),
          confirmLabel: pendingMeta.isDueOrLate ? 'نزول' : 'بكر',
          confirmEnabled: !_processingIds.contains(
            pendingMeta.isDueOrLate ? 'due_${source.id}' : 'early_${source.id}',
          ),
          showPostpone: pendingMeta.isDueOrLate,
          onConfirm: pendingMeta.isDueOrLate
              ? () async {
                  if (_processingIds.contains('due_${source.id}')) return;
                  setState(() => _processingIds.add('due_${source.id}'));
                  try {
                    await _recordIncome(source);
                  } finally {
                    if (mounted) {
                      setState(() => _processingIds.remove('due_${source.id}'));
                    }
                  }
                }
              : () async {
                  if (_processingIds.contains('early_${source.id}')) return;
                  setState(() => _processingIds.add('early_${source.id}'));
                  try {
                    await _recordIncome(source, early: true);
                  } finally {
                    if (mounted) {
                      setState(
                          () => _processingIds.remove('early_${source.id}'));
                    }
                  }
                },
          onPostpone: () => _postponeIncome(source, month),
        ),
      );
    }

    for (final debt in budget.debts) {
      final recurring = _linkedRecurringDebt(state, debt);
      final pendingMeta = _expensePendingMeta(recurring);
      if (pendingMeta == null || !pendingMeta.pending) {
        continue;
      }
      final paidAmount = cycleTransactions
          .where(
              (transaction) => transaction.notes?.contains(debt.name) == true)
          .fold<double>(0, (sum, transaction) => sum + transaction.amount);
      final decisionAmount = BudgetRecurringPlanService.pendingDecisionAmount(
        debt: debt,
        recurring: recurring,
        cyclePaid: paidAmount,
      );
      if (decisionAmount <= 0) {
        continue;
      }

      cards.add(
        PendingNotificationCard(
          accent: const Color(0xFFC65D2E),
          title: debt.name,
          amount: decisionAmount,
          icon: _pendingIconBox(
              Icons.credit_card_rounded, const Color(0xFFC65D2E)),
          confirmLabel: 'سدد',
          onConfirm: recurring == null
              ? () {}
              : () => _recordDebt(
                    debt,
                    recurring,
                    pendingMeta.occurrence,
                  ),
          onPostpone: recurring == null
              ? () {}
              : () => _openRecurringPostponeDialog(
                    debt: debt,
                    recurring: recurring,
                    occurrence: pendingMeta.occurrence,
                    amount: decisionAmount,
                  ),
        ),
      );
    }

    for (final jar in budget.linkedWallets) {
      if (!jar.isPendingDistributionVisible) continue;
      final accent = notificationAccentFromHex(jar.iconColor);
      cards.add(
        PendingNotificationCard(
          accent: accent,
          title: 'تخصيص لحصالة ${jar.name}',
          amount: jar.pendingDistribution,
          icon: _pendingEntityIcon(jar.icon, accent),
          confirmLabel: 'تأكيد',
          confirmEnabled: !_processingIds.contains('jar_${jar.id}'),
          onConfirm: _processingIds.contains('jar_${jar.id}')
              ? () {}
              : () async {
                  setState(() => _processingIds.add('jar_${jar.id}'));
                  try {
                    await _confirmJarDistribution(jar);
                  } finally {
                    if (mounted) {
                      setState(() => _processingIds.remove('jar_${jar.id}'));
                    }
                  }
                },
          onPostpone: () => _openJarDistributionPostpone(jar),
        ),
      );
    }

    for (final alloc in budget.allocations) {
      if (!alloc.isPendingDistributionVisible) continue;
      final accent = notificationAccentFromHex(alloc.iconColor);
      cards.add(
        PendingNotificationCard(
          accent: accent,
          title: 'تخصيص ل${alloc.name}',
          amount: alloc.pendingDistribution,
          icon: _pendingEntityIcon(alloc.icon, accent),
          confirmLabel: 'تأكيد',
          confirmEnabled: !_processingIds.contains('alloc_${alloc.id}'),
          onConfirm: _processingIds.contains('alloc_${alloc.id}')
              ? () {}
              : () async {
                  setState(() => _processingIds.add('alloc_${alloc.id}'));
                  try {
                    await _confirmAllocationDistribution(alloc);
                  } finally {
                    if (mounted) {
                      setState(
                          () => _processingIds.remove('alloc_${alloc.id}'));
                    }
                  }
                },
          onPostpone: () => _openAllocationDistributionPostpone(alloc),
        ),
      );
    }

    return cards;
  }

  List<NotificationEntity> _filteredHistoryItems(
    List<NotificationEntity> items,
  ) {
    final start = _historyDuration.startDate;
    return items.where((item) {
      if (item.createdAt.isBefore(start)) return false;
      return notificationMatchesHistoryCategory(item, _historyCategory);
    }).toList();
  }

  List<Widget> _buildGroupedHistoryTiles(
    AppStateEntity state,
    List<NotificationEntity> items,
  ) {
    final widgets = <Widget>[];
    String? currentGroup;

    for (final item in items) {
      final group = notificationHistoryDateGroupLabel(item.createdAt);
      if (group != currentGroup) {
        currentGroup = group;
        widgets.add(NotificationHistoryDateHeader(label: group));
      }
      widgets.add(_buildHistoryTile(state, item));
    }

    return widgets;
  }

  List<NotificationEntity> _historyNotifications(AppStateEntity state) {
    final items = state.notifications.where((item) {
      if (!isNotificationHistoryEntry(item)) return false;

      final relatedLogId = item.relatedLogId;
      final isReverted = relatedLogId != null &&
          (AuditFacade.findRecoveryBySourceLogId(state, relatedLogId)
                  ?.isReverted ??
              false);
      return !isReverted;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Widget _buildHistoryTile(AppStateEntity state, NotificationEntity item) {
    final relatedLogId = item.relatedLogId;
    final log = relatedLogId == null
        ? null
        : AuditFacade.findRecoveryBySourceLogId(state, relatedLogId);
    final accent = _historyAccent(state, item, log);

    return NotificationHistoryCard(
      title: _historyTitle(item),
      timeLabel: DateFormat('h:mm a', 'ar').format(item.createdAt),
      amountValue: _historyAmountValue(item, log),
      accent: accent,
      icon: _historyIconWidget(state, item, log, accent),
      onOpen: () => _openHistorySheet(state, item, log),
    );
  }

  Future<void> _openHistorySheet(
    AppStateEntity state,
    NotificationEntity item,
    RecoveryEntry? log,
  ) async {
    final transaction = transactionForHistoryLog(state, log);
    if (transaction != null) {
      await openTransactionDetailsSheet(
        context,
        cubit: widget.cubit,
        transaction: transaction,
      );
      return;
    }

    await openNotificationHistoryDetailsSheet(
      context,
      cubit: widget.cubit,
      item: item,
      log: log,
      accent: _historyAccent(state, item, log),
      icon: _historyIcon(item),
    );
  }

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
    return linked.isEmpty ? null : linked.first;
  }

  _IncomePendingMeta? _incomePendingMeta(
    AppStateEntity state,
    IncomeSourceEntity source,
    List<TransactionEntity> sourceTransactions,
    DateTime month,
  ) {
    if (source.isVariable || sourceTransactions.isNotEmpty) {
      return null;
    }

    final recurring = _linkedRecurringIncome(state, source);
    final dueDate = _incomeDueDateForMonth(source, month);
    final reminderLeadDays = (recurring?.reminderLeadDays ?? 0).clamp(0, 3);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = dueDate.subtract(Duration(days: reminderLeadDays));
    final canEarly = reminderLeadDays > 0 &&
        !today.isBefore(reminderDate) &&
        today.isBefore(dueDate);
    final isDueOrLate = !today.isBefore(dueDate);
    if (!canEarly && !isDueOrLate) return null;
    final snoozedUntil =
        recurring?.snoozedUntil == null || recurring!.snoozedUntil!.isEmpty
            ? null
            : DateTime.tryParse(recurring.snoozedUntil!);
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) return null;

    final dateLabel = DateFormat('d MMMM', 'ar').format(dueDate);
    final timeLabel = recurring?.scheduledTime?.isNotEmpty == true
        ? recurring!.scheduledTime!
        : null;

    return _IncomePendingMeta(
      canEarly: canEarly,
      isDueOrLate: isDueOrLate,
      status: isDueOrLate
          ? 'مستحق الآن · $dateLabel${timeLabel == null ? '' : ' · $timeLabel'}'
          : 'بكر · $dateLabel${timeLabel == null ? '' : ' · $timeLabel'}',
    );
  }

  RecurringTransactionEntity? _linkedRecurringDebt(
    AppStateEntity state,
    DebtEntity debt,
  ) =>
      BudgetRecurringPlanService.linkedRecurring(
        state.recurringTransactions,
        debt,
      );

  _ExpensePendingMeta? _expensePendingMeta(
    RecurringTransactionEntity? recurring,
  ) {
    if (recurring == null) {
      return null;
    }
    final now = DateTime.now();
    final prompt = RecurringScheduleEngine.expensePrompt(recurring, now);
    if (prompt == null) return null;
    return _ExpensePendingMeta(
      pending: true,
      status: switch (prompt.state) {
        RecurringExpensePromptState.upcoming =>
          'مستحق قريبًا · ${DateFormat('d MMMM - HH:mm', 'ar').format(prompt.occurrence)}',
        RecurringExpensePromptState.due =>
          'مستحق الآن · ${DateFormat('d MMMM - HH:mm', 'ar').format(prompt.occurrence)}',
        RecurringExpensePromptState.overdue => prompt.catchUpFromAuto
            ? 'دورة فائتة تحتاج قرارًا · ${DateFormat('d MMMM - HH:mm', 'ar').format(prompt.occurrence)}'
            : 'استحقاق متأخر · ${DateFormat('d MMMM - HH:mm', 'ar').format(prompt.occurrence)}',
      },
      occurrence: prompt.occurrence,
    );
  }

  DateTime _incomeDueDateForMonth(IncomeSourceEntity source, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = source.date.clamp(1, lastDay);
    return DateTime(month.year, month.month, day);
  }

  Future<void> _recordIncome(
    IncomeSourceEntity source, {
    bool early = false,
  }) async {
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
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      amount = double.tryParse(amountController.text.trim()) ?? 0;
      if (amount <= 0) return;
    }

    final now = DateTime.now();
    final historyTitle = incomeConfirmTitle(name: source.name, early: early);
    final historyMessage = incomeConfirmMessage(
      name: source.name,
      amount: amount,
      early: early,
    );
    final recurring = BudgetCycleService.linkedRecurringIncome(
      widget.cubit.state,
      source,
    );
    if (recurring != null) {
      final occurrence = early
          ? (RecurringScheduleEngine.nextOccurrence(recurring, now) ?? now)
          : (RecurringScheduleEngine.unhandledDueOccurrence(recurring, now) ??
              RecurringScheduleEngine.dueOccurrenceNow(recurring, now) ??
              now);
      await widget.cubit.recordRecurringIncomeOccurrence(
        recurring: recurring,
        amount: amount,
        occurrence: occurrence,
        transactionNotes: source.name,
        logDetails: historyMessage,
        titleOverride: historyTitle,
      );
      return;
    }

    await widget.cubit.addTransaction(
      walletId: source.targetWalletId,
      amount: amount,
      type: TransactionType.income.value,
      incomeSourceId: source.id,
      budgetScope: BudgetScope.withinBudget.value,
      createdAt: DateTime(now.year, now.month, now.day, 12),
      details: historyMessage,
      notificationTitleOverride: historyTitle,
      recordInNotificationHistory: true,
    );
  }

  Future<void> _postponeIncome(
    IncomeSourceEntity source,
    DateTime month,
  ) async {
    final dueDate = _incomeDueDateForMonth(source, month);
    final result = await RecurringPostponeDialog.show(
      context,
      name: source.name,
      amount: source.amount,
      kindLabel: 'دفعة دخل متكررة',
      occurrence: dueDate,
      allowSkip: false,
    );

    if (result == null || result is! DateTime) {
      return;
    }

    final picked = result;
    final setup = widget.cubit.state.budgetSetup;
    final incomes = setup.incomeSources
        .map(
          (income) => income.id == source.id
              ? income.copyWith(date: picked.day)
              : income,
        )
        .toList();

    final historyTitle = incomePostponeTitle(name: source.name);
    final historyMessage = incomePostponeMessage(
      name: source.name,
      amount: source.amount,
      until: picked,
    );
    final recurring = BudgetCycleService.linkedRecurringIncome(
      widget.cubit.state,
      source,
    );
    if (recurring != null) {
      await widget.cubit.recordRecurringPostpone(
        recurring: recurring,
        snoozedUntil: picked,
        logDetails: historyMessage,
        titleOverride: historyTitle,
      );
      return;
    }

    await widget.cubit.updateBudgetSetup(
      setup.copyWith(incomeSources: incomes),
      detailsOverride: historyMessage,
      titleOverride: historyTitle,
      recordInNotificationHistory: true,
    );
  }

  Future<void> _recordDebt(
    DebtEntity debt,
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) async {
    final historyTitle = debtPayTitle(name: debt.name);
    final historyMessage = debtPayMessage(name: debt.name, amount: debt.amount);
    await widget.cubit.recordRecurringExpenseOccurrence(
      recurring: recurring,
      amount: debt.amount,
      occurrence: occurrence,
      transactionNotes: historyMessage,
      logDetails: historyMessage,
      titleOverride: historyTitle,
    );
  }

  Future<void> _skipRecurringExpenseOccurrence(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
    String name,
    double amount,
  ) async {
    await widget.cubit.recordRecurringSkip(
      recurring: recurring,
      occurrence: occurrence,
      logDetails: debtSkipMessage(name: name, amount: amount),
      titleOverride: debtSkipTitle(name: name),
    );
  }

  Future<void> _postponeRecurringExpenseUntil({
    required RecurringTransactionEntity recurring,
    required String name,
    required double amount,
    required DateTime until,
  }) async {
    await widget.cubit.recordRecurringPostpone(
      recurring: recurring,
      snoozedUntil: until,
      logDetails: debtPostponeMessage(
        name: name,
        amount: amount,
        until: until,
      ),
      titleOverride: debtPostponeTitle(name: name),
    );
  }

  Future<void> _confirmJarDistribution(LinkedWalletEntity jar) async {
    await widget.cubit.confirmJarDistribution(jar.id);
  }

  Future<void> _postponeJarDistribution(LinkedWalletEntity jar) async {
    await widget.cubit.postponeJarDistribution(jar.id);
  }

  Future<void> _confirmAllocationDistribution(AllocationEntity alloc) async {
    await widget.cubit.confirmAllocationDistribution(alloc.id);
  }

  Future<void> _postponeAllocationDistribution(AllocationEntity alloc) async {
    await widget.cubit.postponeAllocationDistribution(alloc.id);
  }

  Widget _pendingIconBox(IconData icon, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: accent, size: 22),
    );
  }

  Widget _pendingEntityIcon(String iconName, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: AppIconPickerDialog.iconWidgetForName(
        iconName,
        color: accent,
        size: 22,
      ),
    );
  }

  DateTime _distributionSnoozeUntil(int days) {
    final target = DateTime.now().add(Duration(days: days));
    return DateTime(target.year, target.month, target.day, 9);
  }

  Future<void> _openAllocationDistributionPostpone(
    AllocationEntity alloc,
  ) async {
    final choice = await showDistributionPostponeSheet(context);
    if (choice == null) return;

    switch (choice) {
      case DistributionPostponeChoice.oneDay:
        await widget.cubit.snoozeAllocationDistribution(
          alloc.id,
          _distributionSnoozeUntil(1),
        );
      case DistributionPostponeChoice.threeDays:
        await widget.cubit.snoozeAllocationDistribution(
          alloc.id,
          _distributionSnoozeUntil(3),
        );
      case DistributionPostponeChoice.skip:
        await _postponeAllocationDistribution(alloc);
    }
  }

  Future<void> _openJarDistributionPostpone(LinkedWalletEntity jar) async {
    final choice = await showDistributionPostponeSheet(context);
    if (choice == null) return;

    switch (choice) {
      case DistributionPostponeChoice.oneDay:
        await widget.cubit.snoozeJarDistribution(
          jar.id,
          _distributionSnoozeUntil(1),
        );
      case DistributionPostponeChoice.threeDays:
        await widget.cubit.snoozeJarDistribution(
          jar.id,
          _distributionSnoozeUntil(3),
        );
      case DistributionPostponeChoice.skip:
        await _postponeJarDistribution(jar);
    }
  }

  Future<void> _openRecurringPostponeDialog({
    required DebtEntity debt,
    required RecurringTransactionEntity recurring,
    required DateTime occurrence,
    required double amount,
  }) async {
    final result = await RecurringPostponeDialog.show(
      context,
      name: debt.name,
      amount: amount,
      kindLabel: debt.isSubscription ? 'اشتراك' : 'دفعة دين',
      occurrence: occurrence,
      allowSkip: true,
    );

    if (result == null) return;

    if (result == PostponeChoice.skip) {
      await _skipRecurringExpenseOccurrence(
        recurring,
        occurrence,
        debt.name,
        amount,
      );
      return;
    }

    if (result is DateTime) {
      await _postponeRecurringExpenseUntil(
        recurring: recurring,
        name: debt.name,
        amount: amount,
        until: result,
      );
    }
  }

  String _historyTitle(NotificationEntity item) {
    return notificationHistoryTitle(
      title: item.title,
      message: item.message,
    );
  }

  String _historyAmount(NotificationEntity item, RecoveryEntry? log) {
    return notificationHistoryAmount(
      message: item.message,
      logDetails: log?.details,
    );
  }

  String _historyAmountValue(NotificationEntity item, RecoveryEntry? log) {
    final formatted = _historyAmount(item, log);
    if (formatted.isEmpty) return '';
    return formatted.replaceAll('جنيه', '').trim();
  }

  Widget _historyIconWidget(
    AppStateEntity state,
    NotificationEntity item,
    RecoveryEntry? log,
    Color accent,
  ) {
    final entityId = log?.entityId ?? '';
    if (item.type == 'allocation' && entityId.isNotEmpty) {
      for (final alloc in state.budgetSetup.allocations) {
        if (alloc.id == entityId) {
          return _pendingEntityIcon(alloc.icon, accent);
        }
      }
    }
    if (item.type == 'jar' && entityId.isNotEmpty) {
      for (final jar in state.budgetSetup.linkedWallets) {
        if (jar.id == entityId) {
          return _pendingEntityIcon(jar.icon, accent);
        }
      }
    }

    return _pendingIconBox(_historyIcon(item), accent);
  }

  Color _historyAccent(
    AppStateEntity state,
    NotificationEntity item,
    RecoveryEntry? log,
  ) {
    final entityId = log?.entityId ?? '';
    if (item.type == 'allocation' && entityId.isNotEmpty) {
      for (final alloc in state.budgetSetup.allocations) {
        if (alloc.id == entityId) {
          return notificationAccentFromHex(alloc.iconColor);
        }
      }
    }
    if (item.type == 'jar' && entityId.isNotEmpty) {
      for (final jar in state.budgetSetup.linkedWallets) {
        if (jar.id == entityId) {
          return notificationAccentFromHex(jar.iconColor);
        }
      }
    }

    final text = '${item.title} ${item.message}';
    if (text.contains('حصالة')) {
      return const Color(0xFF7C5CBF);
    }
    if (text.contains('مخصص') || text.contains('تخصيص')) {
      return const Color(0xFF165B47);
    }
    if (text.contains('راتب') || text.contains('دخل')) {
      return const Color(0xFF0F9D7A);
    }
    if (text.contains('تأجيل')) {
      return const Color(0xFFD4A017);
    }
    if (text.contains('دين') ||
        text.contains('اشتراك') ||
        text.contains('سداد')) {
      return const Color(0xFFC65D2E);
    }
    return const Color(0xFF2F6F5E);
  }

  IconData _historyIcon(NotificationEntity item) {
    final text = '${item.title} ${item.message}';
    if (text.contains('تخصيص') || text.contains('حصالة')) {
      return Icons.savings_outlined;
    }
    if (text.contains('راتب') || text.contains('دخل')) {
      return Icons.south_west_rounded;
    }
    if (text.contains('دين') || text.contains('اشتراك')) {
      return Icons.credit_card_rounded;
    }
    if (text.contains('تأجيل')) {
      return Icons.schedule_rounded;
    }
    return Icons.notifications_active_rounded;
  }
}

class _IncomePendingMeta {
  const _IncomePendingMeta({
    required this.canEarly,
    required this.isDueOrLate,
    required this.status,
  });

  final bool canEarly;
  final bool isDueOrLate;
  final String status;
}

class _ExpensePendingMeta {
  const _ExpensePendingMeta({
    required this.pending,
    required this.status,
    required this.occurrence,
  });

  final bool pending;
  final String status;
  final DateTime occurrence;
}
