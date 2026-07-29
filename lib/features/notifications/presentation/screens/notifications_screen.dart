import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../logs/application/audit_facade.dart';
import '../../../recovery/domain/entities/recovery_entry.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../domain/entities/notification_entity.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _tab = 'new';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final pendingItems = _pendingNotifications(state);
        final historyItems = _historyNotifications(state);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      selected: _tab == 'new',
                      label: Text('التنبيهات (${pendingItems.length})'),
                      onSelected: (_) => setState(() => _tab = 'new'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      selected: _tab == 'history',
                      label: Text('السجل (${historyItems.length})'),
                      onSelected: (_) => setState(() => _tab = 'history'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_tab == 'new') ...[
              if (pendingItems.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('لا توجد إشعارات تحتاج إجراء الآن.'),
                  ),
                )
              else
                ...pendingItems,
            ] else ...[
              if (historyItems.isEmpty)
                const Card(
                  child: ListTile(
                    title: Text('سجل الإشعارات فارغ.'),
                  ),
                )
              else
                ...historyItems.map((item) => _historyCard(state, item)),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _pendingNotifications(AppStateEntity state) {
    final budget = state.budgetSetup;
    final month = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final monthTx = state.transactions.where((t) {
      return t.createdAt.year == month.year && t.createdAt.month == month.month;
    }).toList();
    final incomeTx =
        monthTx.where((t) => t.type == TransactionType.income.value).toList();
    final items = <Widget>[];

    for (final source in budget.incomeSources) {
      final sourceTx =
          incomeTx.where((t) => t.incomeSourceId == source.id).toList();
      final meta = _incomePendingMeta(state, source, sourceTx, month);
      if (meta == null) {
        continue;
      }
      items.add(
        _pendingCard(
          accent: meta['isDueOrLate'] == true
              ? const Color(0xFF0F9D7A)
              : const Color(0xFF4C8BF5),
          title: source.name,
          subtitle: meta['status'] as String,
          amount: source.amount,
          actions: [
            if (meta['canEarly'] == true)
              _actionButton(
                label: 'بكر',
                filled: false,
                onPressed: () => _recordIncome(source, early: true),
              ),
            if (meta['isDueOrLate'] == true)
              _actionButton(
                label: 'نزول',
                onPressed: () => _recordIncome(source),
              ),
            if (meta['isDueOrLate'] == true)
              _actionButton(
                label: 'تأجيل',
                filled: false,
                onPressed: () => _postponeIncome(source, month),
              ),
          ],
        ),
      );
    }

    for (final debt in budget.debts) {
      final recurring = _linkedRecurringDebt(state, debt);
      final paid = monthTx
          .where((t) => t.notes?.contains(debt.name) == true)
          .fold<double>(0, (s, t) => s + t.amount);
      final remaining = (debt.amount - paid).clamp(0.0, debt.amount);
      final meta = _expensePendingMeta(recurring);
      if (remaining <= 0 || meta?['pending'] != true || recurring == null) {
        continue;
      }
      items.add(
        _pendingCard(
          accent: const Color(0xFFC65D2E),
          title: debt.name,
          subtitle: meta!['status'] as String,
          amount: remaining,
          actions: [
            _actionButton(
              label: 'تأكيد الخصم',
              onPressed: () =>
                  _recordDebt(debt, recurring, meta['occurrence'] as DateTime),
            ),
            _actionButton(
              label: 'تأجيل',
              filled: false,
              onPressed: () => _snoozeRecurringExpense(
                recurring,
                meta['occurrence'] as DateTime,
              ),
            ),
          ],
        ),
      );
    }

    return items;
  }

  List<NotificationEntity> _historyNotifications(AppStateEntity state) {
    final items = state.notifications.where((item) {
      if (item.relatedLogId == null) {
        return false;
      }
      final text = '${item.title} ${item.message}';
      return text.contains('دخل') ||
          text.contains('دين') ||
          text.contains('تأجيل') ||
          text.contains('التراجع');
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  Widget _pendingCard({
    required Color accent,
    required String title,
    required String subtitle,
    required double amount,
    required List<Widget> actions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                amount.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                Expanded(child: actions[i]),
                if (i != actions.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
    bool filled = true,
  }) {
    return filled
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(38),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(38),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: Text(label),
          );
  }

  Widget _historyCard(AppStateEntity state, NotificationEntity item) {
    final relatedLogId = item.relatedLogId;
    final log = relatedLogId == null
        ? null
        : AuditFacade.findRecoveryBySourceLogId(state, relatedLogId);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(item.title),
        subtitle: Text(item.message),
        trailing: Text(DateFormat('d/M HH:mm', 'ar').format(item.createdAt)),
        onTap: () => _openHistorySheet(item, log),
      ),
    );
  }

  Future<void> _openHistorySheet(
    NotificationEntity item,
    RecoveryEntry? log,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.62,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(item.message),
            const SizedBox(height: 8),
            Text(
              'الوقت: ${DateFormat('d/M/yyyy - HH:mm', 'ar').format(item.createdAt)}',
            ),
            if (log != null && log.action == 'delete' && !log.isReverted) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.cubit.toggleLogRevert(log.sourceLogId);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: Icon(
                  log.isReverted ? Icons.redo_rounded : Icons.undo_rounded,
                ),
                label: const Text('تراجع عن الحذف'),
              ),
            ],
          ],
        ),
      ),
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

  Map<String, dynamic>? _incomePendingMeta(
    AppStateEntity state,
    IncomeSourceEntity source,
    List<TransactionEntity> sourceTx,
    DateTime month,
  ) {
    if (source.isVariable || sourceTx.isNotEmpty) {
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
    if (!canEarly && !isDueOrLate) {
      return null;
    }
    final dateLabel = '${dueDate.day}/${dueDate.month}';
    final timeLabel = recurring?.scheduledTime?.isNotEmpty == true
        ? recurring!.scheduledTime!
        : null;
    return <String, dynamic>{
      'pending': true,
      'canEarly': canEarly,
      'isDueOrLate': isDueOrLate,
      'status': isDueOrLate
          ? 'مستحق الآن • $dateLabel${timeLabel == null ? '' : ' • $timeLabel'}'
          : 'بكر • $dateLabel${timeLabel == null ? '' : ' • $timeLabel'}',
    };
  }

  RecurringTransactionEntity? _linkedRecurringDebt(
    AppStateEntity state,
    DebtEntity debt,
  ) {
    final recurring = state.recurringTransactions.where(
      (item) =>
          item.type == TransactionType.expense.value &&
          item.budgetScope == BudgetScope.withinBudget.value &&
          item.isDebtOrSubscription &&
          (((debt.recurringTransactionId ?? '').isNotEmpty &&
                  item.id == debt.recurringTransactionId) ||
              (item.name == debt.name)),
    );
    return recurring.isEmpty ? null : recurring.first;
  }

  Map<String, dynamic>? _expensePendingMeta(
      RecurringTransactionEntity? recurring) {
    if (recurring == null ||
        recurring.executionType != AutomationType.confirm.value) {
      return null;
    }
    final now = DateTime.now();
    final dueNow = _dueOccurrenceNow(recurring, now);
    final occurrence = dueNow ?? _nextRecurringOccurrence(recurring, now);
    if (occurrence == null) {
      return null;
    }
    if (_occurrenceWasHandled(recurring, occurrence)) {
      return null;
    }
    final snoozedUntil =
        recurring.snoozedUntil == null || recurring.snoozedUntil!.isEmpty
            ? null
            : DateTime.tryParse(recurring.snoozedUntil!);
    final reminderAt = _notificationMoment(recurring, occurrence);
    if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
      return <String, dynamic>{
        'pending': false,
        'status':
            'مؤجل حتى ${DateFormat('d/M HH:mm', 'ar').format(snoozedUntil)}',
        'occurrence': occurrence,
      };
    }
    if (now.isBefore(reminderAt)) {
      return null;
    }
    return <String, dynamic>{
      'pending': true,
      'status': now.isBefore(occurrence)
          ? 'مستحق قريبًا • ${DateFormat('d/M HH:mm', 'ar').format(occurrence)}'
          : 'مستحق الآن • ${DateFormat('d/M HH:mm', 'ar').format(occurrence)}',
      'occurrence': occurrence,
    };
  }

  bool _occurrenceWasHandled(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) {
    final handled = recurring.lastHandledOccurrenceAt == null
        ? null
        : DateTime.tryParse(recurring.lastHandledOccurrenceAt!);
    if (handled == null) {
      return false;
    }
    final normalized = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
      occurrence.hour,
      occurrence.minute,
    );
    return !handled.isBefore(normalized);
  }

  DateTime? _dueOccurrenceNow(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) {
    final time = _parseRecurringTime(recurring.scheduledTime) ?? now;
    DateTime atDate(DateTime day) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);

    if (recurring.recurrencePattern == RecurrencePattern.daily.value) {
      final today = atDate(now);
      return today.isAfter(now) ? null : today;
    }

    if (recurring.weekdays.isNotEmpty) {
      for (var offset = 0; offset <= 21; offset++) {
        final day = now.subtract(Duration(days: offset));
        if (recurring.weekdays.contains(day.weekday)) {
          final candidate = atDate(day);
          if (!candidate.isAfter(now)) {
            return candidate;
          }
        }
      }
      return null;
    }

    if (recurring.recurrencePattern == RecurrencePattern.yearly.value) {
      final month = recurring.monthOfYear ?? now.month;
      final candidate = DateTime(
        now.year,
        month,
        recurring.dayOfMonth.clamp(1, 28),
        time.hour,
        time.minute,
      );
      return candidate.isAfter(now) ? null : candidate;
    }

    final candidate = DateTime(
      now.year,
      now.month,
      recurring.dayOfMonth.clamp(1, 28),
      time.hour,
      time.minute,
    );
    return candidate.isAfter(now) ? null : candidate;
  }

  DateTime _incomeDueDateForMonth(IncomeSourceEntity source, DateTime month) {
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final day = source.date.clamp(1, lastDay);
    return DateTime(month.year, month.month, day);
  }

  DateTime _notificationMoment(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) {
    final lead = recurring.reminderLeadDays ?? 0;
    if (recurring.recurrencePattern == RecurrencePattern.daily.value ||
        recurring.recurrencePattern == RecurrencePattern.weekly.value ||
        recurring.recurrencePattern == RecurrencePattern.biweekly.value ||
        recurring.recurrencePattern == RecurrencePattern.every3Weeks.value) {
      return occurrence.subtract(Duration(hours: lead));
    }
    return occurrence.subtract(Duration(days: lead));
  }

  DateTime? _parseRecurringTime(String? value) {
    if (value == null || value.isEmpty || !value.contains(':')) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  DateTime? _nextRecurringOccurrence(
    RecurringTransactionEntity recurring,
    DateTime now,
  ) {
    final time = _parseRecurringTime(recurring.scheduledTime) ?? now;
    DateTime atDate(DateTime day) =>
        DateTime(day.year, day.month, day.day, time.hour, time.minute);

    if (recurring.recurrencePattern == RecurrencePattern.daily.value) {
      final today = atDate(now);
      return today.isAfter(now) ? today : today.add(const Duration(days: 1));
    }
    if (recurring.weekdays.isNotEmpty) {
      for (var offset = 0; offset <= 21; offset++) {
        final day = now.add(Duration(days: offset));
        if (recurring.weekdays.contains(day.weekday)) {
          final candidate = atDate(day);
          if (candidate.isAfter(now)) {
            return candidate;
          }
        }
      }
    }
    final candidate = DateTime(
      now.year,
      now.month,
      recurring.dayOfMonth.clamp(1, 28),
      time.hour,
      time.minute,
    );
    if (candidate.isAfter(now)) {
      return candidate;
    }
    return DateTime(
      now.year,
      now.month + 1,
      recurring.dayOfMonth.clamp(1, 28),
      time.hour,
      time.minute,
    );
  }

  Future<void> _recordIncome(IncomeSourceEntity source,
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
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      );
      if (ok != true) {
        return;
      }
      amount = double.tryParse(amountController.text.trim()) ?? 0;
      if (amount <= 0) {
        return;
      }
    }
    final now = DateTime.now();
    await widget.cubit.addTransaction(
      walletId: source.targetWalletId,
      amount: amount,
      type: TransactionType.income.value,
      incomeSourceId: source.id,
      budgetScope: BudgetScope.withinBudget.value,
      createdAt: DateTime(now.year, now.month, now.day, 12),
      notes: early
          ? 'تسجيل دخل مبكر: ${source.name}'
          : 'تأكيد نزول دخل: ${source.name}',
    );
  }

  Future<void> _postponeIncome(
      IncomeSourceEntity source, DateTime month) async {
    final dueDate = _incomeDueDateForMonth(source, month);
    final picked = await showDatePicker(
      context: context,
      initialDate: dueDate.add(const Duration(days: 1)),
      firstDate: dueDate.add(const Duration(days: 1)),
      lastDate: DateTime(month.year, month.month + 1, 28),
    );
    if (picked == null) {
      return;
    }
    final setup = widget.cubit.state.budgetSetup;
    final incomes = setup.incomeSources
        .map(
          (income) => income.id == source.id
              ? IncomeSourceEntity(
                  id: income.id,
                  name: income.name,
                  amount: income.amount,
                  date: picked.day,
                  type: income.type,
                  targetWalletId: income.targetWalletId,
                  isVariable: income.isVariable,
                  isDefault: income.isDefault,
                )
              : income,
        )
        .toList();
    await widget.cubit
        .updateBudgetSetup(setup.copyWith(incomeSources: incomes));
  }

  Future<void> _recordDebt(
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
    );
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(
        lastHandledOccurrenceAt: occurrence.toIso8601String(),
        snoozedUntil: '',
      ),
    );
  }

  Future<void> _snoozeRecurringExpense(
    RecurringTransactionEntity recurring,
    DateTime occurrence,
  ) async {
    final now = DateTime.now();
    final delayed = now.add(const Duration(hours: 1));
    final nextSnooze = delayed.isAfter(occurrence) ? occurrence : delayed;
    await widget.cubit.updateRecurringTransaction(
      recurring.copyWith(snoozedUntil: nextSnooze.toIso8601String()),
    );
  }
}
