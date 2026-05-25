import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../widgets/transaction_details_sheet.dart';
import 'recurring_transaction_composer_screen.dart';
import 'subscription_preset_selection_screen.dart';
import '../../../budget/presentation/screens/budget_setup_screen.dart';

class DebtsAndSubscriptionsScreen extends StatefulWidget {
  const DebtsAndSubscriptionsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<DebtsAndSubscriptionsScreen> createState() =>
      _DebtsAndSubscriptionsScreenState();
}

class _DebtsAndSubscriptionsScreenState
    extends State<DebtsAndSubscriptionsScreen> {
  static const Color _debtAccent = Color(0xFFC65D2E);
  static const Color _lentAccent = Color(0xFF1A7A4A);
  static const Color _subscriptionAccent = Color(0xFF2E5CC6);
  static const Color _sharedCardBackground = Color(0xFFF9F3E7);

  String _tab = 'subscriptions';
  bool _archiveExpanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;


        final subscriptionRecords = state.recurringTransactions
            .where((r) =>
                r.type == 'expense' && r.expensePlanKind == 'subscription')
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        // ── السلفات: فصل النشط عن الأرشيف
        final allLentPersons = state.recurringTransactions
            .where((r) => r.isLent)
            .toList()
          ..sort((a, b) => (a.lentPersonName ?? a.name).compareTo(b.lentPersonName ?? b.name));
        final activeLentPersons = allLentPersons
            .where((r) => !r.isLentArchived)
            .toList();
        final archivedLentPersons = allLentPersons
            .where((r) => r.isLentArchived)
            .toList();
        final borrowedRecords = state.recurringTransactions
            .where((r) => !r.isLent && r.expensePlanKind == 'installment')
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('الديون والاشتراكات'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _typeSwitcher(),
              const SizedBox(height: 14),
              if (_tab == 'subscriptions') ...[
                _actionButton(
                  label: 'إضافة اشتراك جديد',
                  icon: Icons.subscriptions_rounded,
                  color: _subscriptionAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscriptionPresetSelectionScreen(
                          cubit: widget.cubit,
                        ),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (subscriptionRecords.isEmpty)
                  _emptyCard('لا توجد اشتراكات مسجلة حالياً.')
                else
                  ...subscriptionRecords
                      .map((r) => _recurringCard(state, r)),
              ] else ...[
                // ── زرار الإضافة ─────────────────────────────────────────
                _actionButton(
                  label: 'دين أو قسط',
                  icon: Icons.account_balance_outlined,
                  color: _debtAccent,
                  onTap: () => _openRecurringComposer(
                    mode: 'expense',
                    initialExpensePlanKind: 'installment',
                    debtOnlyMode: true,
                  ),
                ),
                const SizedBox(height: 20),

                // ── سكشن: ديون عليّ ──────────────────────────────────────
                _sectionHeader(
                  label: 'ديون وأقساط عليّ',
                  color: _debtAccent,
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 10),
                if (borrowedRecords.isEmpty)
                  _emptyCard('لا توجد ديون أو أقساط مسجلة حالياً.')
                else
                  ...borrowedRecords.map((r) => _recurringCard(state, r)),

                const SizedBox(height: 20),

                // ── سكشن: سلّفت للناس ────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _sectionHeader(
                        label: 'سلّفت للناس',
                        color: _lentAccent,
                        icon: Icons.handshake_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (activeLentPersons.isEmpty)
                  _emptyCard('ما سلّفتش حد حالياً.')
                else
                  ...activeLentPersons.map((r) => _lentPersonCard(state, r)),

                // ── قسم الأرشيف ────────────────────────────────────────────
                if (archivedLentPersons.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => setState(() => _archiveExpanded = !_archiveExpanded),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'الأرشيف (${archivedLentPersons.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _archiveExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_archiveExpanded) ...[
                    const SizedBox(height: 8),
                    ...archivedLentPersons.map((r) => _lentPersonCard(state, r, isArchived: true)),
                  ],
                ],
              ],

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _openBudgetSetupScreen(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('تعديل الميزانية الشهرية'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionHeader({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 15,
          color: color,
        ),
      ),
    ]);
  }


  void _openBudgetSetupScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('تعديل خطة الميزانية'),
          ),
          body: BudgetSetupScreen(
            cubit: widget.cubit,
            displayMonth: DateTime(DateTime.now().year, DateTime.now().month, 1),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeSwitcher() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        children: [
          _switchTile(
            'subscriptions',
            'الاشتراكات',
            Icons.subscriptions_rounded,
          ),
          const SizedBox(width: 8),
          _switchTile('debts', 'الديون', Icons.account_balance_outlined),
        ],
      ),
    );
  }

  Widget _switchTile(String value, String label, IconData icon) {
    final selected = _tab == value;
    final accent = value == 'subscriptions' ? _subscriptionAccent : _debtAccent;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = value),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.surface : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? accent : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? accent : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── بطاقة الشخص (السلف) ──────────────────────────────────────────────────
  Widget _lentPersonCard(
    AppStateEntity state,
    RecurringTransactionEntity person, {
    bool isArchived = false,
  }) {
    final accent = _parseColor(person.iconColor);
    final personName = person.lentPersonName ?? person.name;
    final outstanding = person.outstandingLentAmount;
    final totalEntries = person.lentEntries.length;
    final pendingCount = person.lentEntries.where((e) => e['isSettled'] != true).length;
    final walletName = _walletName(state, person.walletId);

    DateTime? earliestDue;
    for (final e in person.lentEntries.where((e) => e['isSettled'] != true)) {
      final d = e['expectedReturnDate'] != null
          ? DateTime.tryParse(e['expectedReturnDate'] as String)
          : null;
      if (d != null && (earliestDue == null || d.isBefore(earliestDue))) {
        earliestDue = d;
      }
    }
    final isOverdue = earliestDue != null && earliestDue.isBefore(DateTime.now());
    final dueLbl = earliestDue != null
        ? '${earliestDue.day}/${earliestDue.month}/${earliestDue.year}'
        : '—';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openLentPersonSheet(state, person),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isArchived
                ? Colors.grey.withValues(alpha: 0.05)
                : const Color(0xFFF0FAF4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isArchived
                  ? Colors.grey.withValues(alpha: 0.2)
                  : accent.withValues(alpha: isOverdue ? 0.55 : 0.22),
              width: isOverdue ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (isArchived ? Colors.grey : accent)
                    .withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isArchived ? Icons.archive_outlined : Icons.person_rounded,
                  color: isArchived ? Colors.grey : accent,
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
                    personName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isArchived ? Colors.grey.shade600 : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'محفظة: $walletName · $pendingCount/$totalEntries سلف',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  outstanding.toStringAsFixed(2),
                  style: TextStyle(
                    color: isArchived ? Colors.grey : accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (!isArchived) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOverdue
                          ? const Color(0xFFFFEDED)
                          : const Color(0xFFE8F5ED),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isOverdue ? '⚠ $dueLbl' : dueLbl,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isOverdue
                            ? const Color(0xFFC0392B)
                            : accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _openLentPersonSheet(
    AppStateEntity state,
    RecurringTransactionEntity person,
  ) async {
    final theme = Theme.of(context);
    final accent = _parseColor(person.iconColor);
    final personName = person.lentPersonName ?? person.name;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setS) {
          final currentState = widget.cubit.state;
          final currentPerson = currentState.recurringTransactions
                  .where((r) => r.id == person.id)
                  .cast<RecurringTransactionEntity?>()
                  .firstWhere((_) => true, orElse: () => null) ??
              person;

          final allEntries = currentPerson.lentEntries.toList();

          final historyTxs = currentState.transactions
              .where((t) =>
                  ((t.notes?.contains('سلفة لـ $personName') ?? false) ||
                      (t.notes?.contains('استرداد سلفة من $personName') ??
                          false)))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * 0.9,
            child: Column(
              children: [
                // ── Hero Header ──────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.7)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              personName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'إجمالي غير مسترد: ${currentPerson.outstandingLentAmount.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecurringTransactionComposerScreen(
                                cubit: widget.cubit,
                                initialType: 'expense',
                                initialRecurring: currentPerson,
                                initialLentMode: true,
                              ),
                              fullscreenDialog: true,
                            ),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Expanding Card for Pending Entries ──────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LentEntriesExpandingCard(
                    theme: theme,
                    accent: accent,
                    person: currentPerson,
                    allEntries: allEntries,
                    onEntryAction: () => setS(() {}),
                    cubit: widget.cubit,
                    sheetCtx: sheetCtx,
                  ),
                ),

                const SizedBox(height: 20),

                // ── History Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 18, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      const Text(
                        'سجل المعاملات',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // ── History List ────────────────────────────────────────
                Expanded(
                  child: historyTxs.isEmpty
                      ? const Center(child: Text('لا توجد معاملات مسجلة'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          itemCount: historyTxs.length,
                          itemBuilder: (ctx, i) {
                            final tx = historyTxs[i];
                            final isIncome = tx.type == 'income';
                            return ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: (isIncome ? Colors.green : Colors.red)
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle),
                                child: Icon(
                                    isIncome
                                        ? Icons.south_west_rounded
                                        : Icons.north_east_rounded,
                                    size: 16,
                                    color: isIncome ? Colors.green : Colors.red),
                              ),
                              title: Text(
                                  isIncome ? 'استرداد مبلغ' : 'إخراج سلفة',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  DateFormat('d MMMM yyyy', 'ar')
                                      .format(tx.createdAt),
                                  style: const TextStyle(fontSize: 11)),
                              trailing: Text(
                                  '${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color:
                                          isIncome ? Colors.green : Colors.red)),
                            );
                          },
                        ),
                ),

                // ── أزرار الشخص ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(sheetCtx);
                            await widget.cubit.archiveLentPerson(person.id,
                                archive: !person.isLentArchived);
                          },
                          icon: Icon(
                              person.isLentArchived
                                  ? Icons.unarchive_outlined
                                  : Icons.archive_outlined,
                              size: 18),
                          label: Text(
                              person.isLentArchived ? 'إلغاء الأرشفة' : 'أرشفة الشخص',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            side: BorderSide(
                                color: theme.colorScheme.outlineVariant,
                                width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        onPressed: () async {
                          final confirm = await _confirmDialog(
                            title: 'حذف السجل',
                            content: 'هل تريد حذف سجل $personName نهائياً؟',
                          );
                          if (confirm) {
                            await widget.cubit
                                .deleteRecurringTransaction(person.id);
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // (تم حذف شاشة الاختيار بطلب من المستخدم لفتح الفورم مباشرة)

  Future<bool> _confirmDialog({required String title, required String content}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _lentAccent),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── فورم إضافة سلفة (جديد أو لشخص موجود) ────────────────────────────────
  // (تم حذف _openLentForm المخصص بطلب من المستخدم)



  Widget _recurringCard(
    AppStateEntity state,
    RecurringTransactionEntity record,
  ) {
    final accent = _parseColor(record.iconColor);
    final amountLabel =
        record.isVariableIncome ? 'متغير' : record.amount.toStringAsFixed(2);
    final wallet = _walletName(state, record.walletId);
    final execution = _executionLabel(record.executionType);
    final scope =
        record.budgetScope == 'within-budget' ? 'داخل الميزانية' : 'عام';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openDetailsSheet(state, record),
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _sharedCardBackground,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: AppIconPickerDialog.iconWidgetForName(
                    record.icon,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          amountLabel,
                          style: const TextStyle(
                            color: Color(0xFF254034),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _recurrenceLabel(record),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _miniTag(execution),
                        _miniTag(scope),
                        if (wallet != '-') _miniTag(wallet),
                        if (record.type == 'expense')
                          _miniTag(_expensePlanKindLabel(record)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_left_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _openDetailsSheet(
    AppStateEntity state,
    RecurringTransactionEntity record,
  ) async {
    final accent = _parseColor(record.iconColor);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setS) {
          final theme = Theme.of(sheetContext);
          final currentState = widget.cubit.state;
          final currentRecord = currentState.recurringTransactions
                  .where((r) => r.id == record.id)
                  .cast<RecurringTransactionEntity?>()
                  .firstWhere((_) => true, orElse: () => null) ??
              record;

          final isDebt = currentRecord.expensePlanKind == 'installment';

          final historyTxs = currentState.transactions
                  .where((t) =>
                      ((t.notes?.contains('سداد دين: ${currentRecord.name}') ??
                              false) ||
                          (t.notes?.contains(
                                  'تأكيد استحقاق اشتراك: ${currentRecord.name}') ??
                              false) ||
                          (t.notes?.contains('خصم تلقائي دين: ${currentRecord.name}') ??
                              false)))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.9,
            child: Column(
              children: [
                // ── Hero Header ──────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.7)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: AppIconPickerDialog.iconWidgetForName(
                            currentRecord.icon,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentRecord.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_typeLabel(currentRecord)} · ${_executionLabel(currentRecord.executionType)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currentRecord.isVariableIncome
                                ? 'متغير'
                                : currentRecord.amount.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            'ج.م',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // ── Interactive Fulfillment Card (for Debts) ──────────
                      if (isDebt) ...[
                        _DebtInstallmentInteractiveCard(
                          record: currentRecord,
                          state: currentState,
                          accent: accent,
                          onPaid: () => setS(() {}),
                          cubit: widget.cubit,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Interactive Card (for Subscriptions) ──────────────
                      if (!isDebt && currentRecord.expensePlanKind == 'subscription') ...[
                        _SubscriptionInteractiveCard(
                          record: currentRecord,
                          state: currentState,
                          accent: accent,
                          onPaid: () => setS(() {}),
                          cubit: widget.cubit,
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Details Table ──────────────────────────────────────
                      _sectionTitle(context, 'تفاصيل المعاملة',
                          Icons.info_outline_rounded),
                      const SizedBox(height: 10),
                      _DetailsTable(rows: _detailsRows(currentState, currentRecord)),
                      const SizedBox(height: 24),

                      // ── سجل المعاملات ─────────────────────────────────────────
                      _sectionTitle(context, 'سجل المعاملات', Icons.history_rounded),
                      const SizedBox(height: 10),
                      if (historyTxs.isEmpty)
                        _emptyCard('لا توجد معاملات مسجلة لهذا البند.')
                      else
                        ...historyTxs.map((t) => _transactionTile(sheetContext, theme, t)),
                      const SizedBox(height: 28),
                    ],
                  ),
                ),

                // ── Action Buttons ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _openRecurringComposer(
                              mode: currentRecord.type,
                              editing: currentRecord,
                              subscriptionOnlyMode:
                                  currentRecord.expensePlanKind ==
                                      'subscription',
                              debtOnlyMode: currentRecord.expensePlanKind ==
                                  'installment',
                            );
                          },
                          icon: const Icon(Icons.edit_rounded, size: 20),
                          label: const Text('تعديل البيانات',
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        onPressed: () async {
                          final confirm = await _confirmDialog(
                            title: 'حذف المعاملة',
                            content: 'هل أنت متأكد من حذف ${currentRecord.name}؟',
                          );
                          if (confirm) {
                            await widget.cubit
                                .deleteRecurringTransaction(currentRecord.id);
                            if (sheetContext.mounted) Navigator.pop(sheetContext);
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: Colors.red),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon,
            size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Map<String, String> _detailsRows(
    AppStateEntity state,
    RecurringTransactionEntity record,
  ) {
    return {
      'اسم المعاملة': record.name,
      'النوع': _typeLabel(record),
      'القيمة': record.isVariableIncome
          ? 'دخل متغير'
          : record.amount.toStringAsFixed(2),
      'المحفظة': _walletName(state, record.walletId),
      'النطاق':
          record.budgetScope == 'within-budget' ? 'داخل الميزانية' : 'عام',
      'التكرار': _recurrenceLabel(record),
      'التنفيذ': _executionLabel(record.executionType),
      if (record.reminderLeadDays != null)
        'التنبيه قبل': _reminderLabel(record),
      if (record.incomeSourceId != null)
        'مصدر الدخل': _incomeName(state, record.incomeSourceId!),
      if (record.allocationId != null)
        'المخصص': _allocationName(state, record.allocationId!),
      if (record.targetJarId != null)
        'الحصالة': _jarName(state, record.targetJarId!),
      if (record.categoryIds.isNotEmpty)
        'الفئات':
            record.categoryIds.map((id) => _categoryName(state, id)).join('، '),
      if (record.type == 'expense') 'التصنيف': _expensePlanKindLabel(record),
      if (record.expensePlanKind == 'installment' &&
          record.debtPrincipalTotal != null)
        'إجمالي الأصل': record.debtPrincipalTotal!.toStringAsFixed(2),
      if (record.notes?.trim().isNotEmpty == true)
        'الملاحظات': record.notes!.trim(),
    };
  }

  String _recurrenceLabel(RecurringTransactionEntity record) {
    final timeSuffix = (record.scheduledTime ?? '').isEmpty
        ? ''
        : ' · ${record.scheduledTime}';
    final weekdayLabel = record.weekdays.isNotEmpty
        ? record.weekdays.map(_weekdayName).join('، ')
        : _weekdayName(record.weekday);
    return switch (record.recurrencePattern) {
      'daily' => 'يومي$timeSuffix',
      'weekly' => 'أسبوعي ($weekdayLabel)$timeSuffix',
      'biweekly' => 'كل أسبوعين ($weekdayLabel)$timeSuffix',
      'every_3_weeks' => 'كل 3 أسابيع ($weekdayLabel)$timeSuffix',
      'every_2_months' => 'كل شهرين يوم ${record.dayOfMonth}$timeSuffix',
      'every_3_months' => 'كل 3 شهور يوم ${record.dayOfMonth}$timeSuffix',
      'every_6_months' => 'كل 6 شهور يوم ${record.dayOfMonth}$timeSuffix',
      'yearly' =>
        'سنوي ${record.dayOfMonth}/${record.monthOfYear ?? 1}$timeSuffix',
      'manual-variable' => 'يدوي / مرة واحدة',
      _ => 'شهري يوم ${record.dayOfMonth}$timeSuffix',
    };
  }

  String _typeLabel(RecurringTransactionEntity record) {
    if (record.type == 'income') return 'دخل';
    return 'مصروف';
  }

  String _expensePlanKindLabel(RecurringTransactionEntity record) {
    if (record.expensePlanKind == 'installment') return 'قسط / دين';
    if (record.expensePlanKind == 'subscription') return 'اشتراك';
    if (record.expensePlanKind == 'lent') return 'سلفة';
    return 'مصروف متكرر';
  }

  String _executionLabel(String type) => type == 'auto' ? 'تلقائي' : 'يدوي';

  String _reminderLabel(RecurringTransactionEntity record) {
    final days = record.reminderLeadDays ?? 0;
    if (days == 0) {
      return record.recurrencePattern == 'daily' ||
              record.recurrencePattern == 'weekly' ||
              record.recurrencePattern == 'biweekly' ||
              record.recurrencePattern == 'every_3_weeks'
          ? 'في نفس الوقت'
          : 'في نفس اليوم';
    }
    if (record.recurrencePattern == 'daily' ||
        record.recurrencePattern == 'weekly' ||
        record.recurrencePattern == 'biweekly' ||
        record.recurrencePattern == 'every_3_weeks') {
      return 'قبلها بـ $days ساعة';
    }
    return 'قبلها بـ $days يوم';
  }

  String _walletName(AppStateEntity state, String id) {
    try {
      return state.wallets.firstWhere((w) => w.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _incomeName(AppStateEntity state, String id) {
    try {
      return state.budgetSetup.incomeSources.firstWhere((i) => i.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _allocationName(AppStateEntity state, String id) {
    try {
      return state.budgetSetup.allocations.firstWhere((a) => a.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _jarName(AppStateEntity state, String id) {
    try {
      return state.budgetSetup.linkedWallets.firstWhere((j) => j.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _categoryName(AppStateEntity state, String id) {
    try {
      return state.categories.firstWhere((c) => c.id == id).name;
    } catch (_) {
      return '-';
    }
  }

  String _weekdayName(int? dayIndex) {
    if (dayIndex == null) return '';
    return [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد'
    ][(dayIndex - 1).clamp(0, 6)];
  }

  Color _parseColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Future<void> _openRecurringComposer({
    required String mode,
    RecurringTransactionEntity? editing,
    String? initialExpensePlanKind,
    bool subscriptionOnlyMode = false,
    bool debtOnlyMode = false,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: mode,
          initialRecurring: editing,
          initialWithinBudget: true,
          initialExpensePlanKind:
              editing?.expensePlanKind ?? initialExpensePlanKind,
          allowDelete: editing != null,
          subscriptionOnlyMode: subscriptionOnlyMode,
          debtOnlyMode: debtOnlyMode,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _transactionTile(
    BuildContext sheetContext,
    ThemeData theme,
    TransactionEntity item,
  ) {
    final isIncome = item.type == 'income';
    final isExpense = item.type == 'expense';
    final amtColor = isIncome
        ? const Color(0xFF0F9D7A)
        : (isExpense ? theme.colorScheme.error : theme.colorScheme.primary);
    final icon = isIncome
        ? Icons.add_rounded
        : (isExpense ? Icons.remove_rounded : Icons.swap_horiz_rounded);
    final defaultTitle = isIncome ? 'دخل' : (isExpense ? 'مصروف' : 'تحويل');
    final prefix = isIncome ? '+' : (isExpense ? '-' : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: amtColor.withValues(alpha: 0.12),
                  child: Icon(icon, color: amtColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.notes?.isNotEmpty == true
                            ? item.notes!
                            : defaultTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('d MMMM · h:mm a', 'ar')
                            .format(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$prefix${item.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: amtColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LentEntriesExpandingCard extends StatefulWidget {
  const _LentEntriesExpandingCard({
    required this.theme,
    required this.accent,
    required this.person,
    required this.allEntries,
    required this.onEntryAction,
    required this.cubit,
    required this.sheetCtx,
  });

  final ThemeData theme;
  final Color accent;
  final RecurringTransactionEntity person;
  final List<dynamic> allEntries;
  final VoidCallback onEntryAction;
  final AppCubit cubit;
  final BuildContext sheetCtx;

  @override
  State<_LentEntriesExpandingCard> createState() => _LentEntriesExpandingCardState();
}

class _LentEntriesExpandingCardState extends State<_LentEntriesExpandingCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final accent = widget.accent;
    final pendingCount = widget.allEntries.where((e) => e['isSettled'] != true).length;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('السلفات الفردية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                        Text(
                          '$pendingCount معلق · ${widget.allEntries.length} إجمالي',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),

          // ── Entries List ────────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildEntriesList(theme, accent),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(ThemeData theme, Color accent) {
    final entries = widget.allEntries.reversed.toList();
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text('لا توجد سلفات مسجلة لهذا الشخص.', style: TextStyle(color: Colors.grey)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...entries.map((entry) {
            final isSettled = entry['isSettled'] == true;
            final amount = (entry['amount'] as num?)?.toDouble() ?? 0;
            final lentDateStr = entry['lentDate'] as String?;
            final returnStr = entry['expectedReturnDate'] as String?;
            final lentDate = lentDateStr != null ? DateTime.tryParse(lentDateStr) : null;
            final returnDate = returnStr != null ? DateTime.tryParse(returnStr) : null;
            final isOverdue = !isSettled && returnDate != null && returnDate.isBefore(DateTime.now());
            final entryId = entry['id'] as String;

            final cardColor = isSettled
                ? Colors.grey.withValues(alpha: 0.05)
                : (isOverdue ? const Color(0xFFFFF5F5) : const Color(0xFFF0FAF4));
            final borderColor = isSettled
                ? Colors.grey.withValues(alpha: 0.2)
                : (isOverdue ? Colors.red.withValues(alpha: 0.2) : accent.withValues(alpha: 0.2));

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Status badge + Amount ──────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSettled
                            ? Colors.grey.withValues(alpha: 0.1)
                            : (isOverdue ? Colors.red.withValues(alpha: 0.1) : accent.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isSettled ? '✓ مسترد' : (isOverdue ? '⚠ متأخر' : 'معلق'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isSettled ? Colors.grey : (isOverdue ? Colors.red : accent),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${amount.toStringAsFixed(2)} ج.م',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ]),
                  const SizedBox(height: 8),

                  // ── Dates ──────────────────────────────────────────────
                  if (lentDate != null)
                    Text(
                      'تاريخ السلفة: ${lentDate.day}/${lentDate.month}/${lentDate.year}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  if (returnDate != null)
                    Text(
                      'الاسترداد المتوقع: ${returnDate.day}/${returnDate.month}/${returnDate.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue ? Colors.red : Colors.grey,
                        fontWeight: isOverdue ? FontWeight.w700 : null,
                      ),
                    ),

                  // ── Action Buttons (pending only) ──────────────────────
                  if (!isSettled) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      _actionBtn(
                        label: 'استرداد',
                        icon: Icons.check_circle_outline,
                        color: accent,
                        onTap: () async {
                          await widget.cubit.settleLentEntry(widget.person.id, entryId);
                          widget.onEntryAction();
                        },
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        label: 'تأجيل',
                        icon: Icons.update_rounded,
                        color: Colors.blueGrey,
                        onTap: () async {
                          final d = await showDatePicker(
                            context: widget.sheetCtx,
                            initialDate: DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                          );
                          if (d != null) {
                            await widget.cubit.postponeLentEntry(widget.person.id, entryId, d);
                            widget.onEntryAction();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _actionBtn(
                        label: 'تنازل',
                        icon: Icons.heart_broken_outlined,
                        color: Colors.redAccent,
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: widget.sheetCtx,
                            builder: (ctx) => AlertDialog(
                              title: const Text('تنازل عن السلفة'),
                              content: const Text('هل أنت متأكد من التنازل عن هذا المبلغ؟ سيتم اعتباره مصروفاً نهائياً.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('تنازل'),
                                ),
                              ],
                            ),
                          ) ?? false;
                          if (confirm) {
                            await widget.cubit.writeOffLentEntry(widget.person.id, entryId);
                            widget.onEntryAction();
                          }
                        },
                      ),
                    ]),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _DebtInstallmentInteractiveCard extends StatefulWidget {
  const _DebtInstallmentInteractiveCard({
    required this.record,
    required this.state,
    required this.accent,
    required this.onPaid,
    required this.cubit,
  });

  final RecurringTransactionEntity record;
  final AppStateEntity state;
  final Color accent;
  final VoidCallback onPaid;
  final AppCubit cubit;

  @override
  State<_DebtInstallmentInteractiveCard> createState() =>
      _DebtInstallmentInteractiveCardState();
}

class _DebtInstallmentInteractiveCardState
    extends State<_DebtInstallmentInteractiveCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;
    final state = widget.state;

    // Calculate progress
    final totalPrincipal = record.debtPrincipalTotal ?? 0;
    final installmentAmt = record.amount;
    final totalInstallments = record.installmentCount ?? 0;

    // Find transactions related to this debt
    final payments = state.transactions
        .where((t) =>
            t.notes?.contains('سداد دين: ${record.name}') == true ||
            t.notes?.contains('سداد قسط: ${record.name}') == true)
        .toList();

    final paidAmount = payments.fold(0.0, (sum, t) => sum + t.amount);
    final paidCount = (paidAmount / (installmentAmt > 0 ? installmentAmt : 1)).floor();
    final remainingAmount = (totalPrincipal - paidAmount).clamp(0.0, totalPrincipal);

    // Check if paid this month
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final paidThisMonth = payments.any((t) => t.createdAt.isAfter(thisMonthStart));

    final progress = totalPrincipal > 0 ? (paidAmount / totalPrincipal).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.account_balance_wallet_rounded,
                            color: widget.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'موقف السداد',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            Text(
                              'متبقي ${remainingAmount.toStringAsFixed(0)} ج.م',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'التقدم: $paidCount / $totalInstallments قسط',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: widget.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: widget.accent,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: paidThisMonth
                          ? Colors.green.withValues(alpha: 0.08)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: paidThisMonth
                            ? Colors.green.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: paidThisMonth
                                ? Colors.green.withValues(alpha: 0.15)
                                : theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            paidThisMonth
                                ? Icons.check_rounded
                                : Icons.calendar_today_rounded,
                            color: paidThisMonth
                                ? Colors.green
                                : theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paidThisMonth ? 'تم سداد قسط هذا الشهر' : 'قسط هذا الشهر',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: paidThisMonth ? Colors.green.shade800 : null,
                                ),
                              ),
                              Text(
                                paidThisMonth
                                    ? 'تم السداد بنجاح'
                                    : 'مستحق بقيمة ${installmentAmt.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!paidThisMonth)
                          FilledButton(
                            onPressed: () async {
                              await widget.cubit.addTransaction(
                                walletId: record.walletId,
                                amount: installmentAmt,
                                type: 'expense',
                                budgetScope: 'within-budget',
                                createdAt: DateTime.now(),
                                notes: 'سداد قسط: ${record.name}',
                                details: 'سداد قسط من صفحة الديون: ${record.name}',
                              );
                              widget.onPaid();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.accent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('سداد',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Subscription Interactive Card
// ─────────────────────────────────────────────────────────────────────────────

class _SubscriptionInteractiveCard extends StatefulWidget {
  const _SubscriptionInteractiveCard({
    required this.record,
    required this.state,
    required this.accent,
    required this.onPaid,
    required this.cubit,
  });

  final RecurringTransactionEntity record;
  final AppStateEntity state;
  final Color accent;
  final VoidCallback onPaid;
  final AppCubit cubit;

  @override
  State<_SubscriptionInteractiveCard> createState() =>
      _SubscriptionInteractiveCardState();
}

class _SubscriptionInteractiveCardState
    extends State<_SubscriptionInteractiveCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;
    final state = widget.state;

    // دفعات الاشتراك ده من سجل المعاملات
    final payments = state.transactions
        .where((t) =>
            t.notes?.contains('دفع اشتراك: ${record.name}') == true ||
            t.notes?.contains('سداد اشتراك: ${record.name}') == true ||
            t.notes?.contains('سداد قسط: ${record.name}') == true)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final totalPaid = payments.fold(0.0, (s, t) => s + t.amount);
    final paymentsCount = payments.length;

    // هل دُفع هذا الشهر؟
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final paidThisMonth = payments.any((t) => t.createdAt.isAfter(thisMonthStart));

    final subscriptionAmt = record.amount;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.subscriptions_rounded,
                            color: widget.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'دفعات هذا الاشتراك',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14),
                            ),
                            Text(
                              '$paymentsCount دفعة · إجمالي ${totalPaid.toStringAsFixed(0)} ج.م',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  // ── حالة دفع الشهر الحالي ─────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: paidThisMonth
                          ? Colors.green.withValues(alpha: 0.08)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: paidThisMonth
                            ? Colors.green.withValues(alpha: 0.3)
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: paidThisMonth
                                ? Colors.green.withValues(alpha: 0.15)
                                : theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            paidThisMonth
                                ? Icons.check_rounded
                                : Icons.calendar_today_rounded,
                            color: paidThisMonth
                                ? Colors.green
                                : theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                paidThisMonth
                                    ? 'تم الدفع هذا الشهر'
                                    : 'اشتراك هذا الشهر',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: paidThisMonth
                                      ? Colors.green.shade800
                                      : null,
                                ),
                              ),
                              Text(
                                paidThisMonth
                                    ? 'تم الدفع بنجاح'
                                    : 'مستحق بقيمة ${subscriptionAmt.toStringAsFixed(2)} ج.م',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!paidThisMonth)
                          FilledButton(
                            onPressed: () async {
                              await widget.cubit.addTransaction(
                                walletId: record.walletId,
                                amount: subscriptionAmt,
                                type: 'expense',
                                budgetScope: record.budgetScope,
                                createdAt: DateTime.now(),
                                notes: 'دفع اشتراك: ${record.name}',
                                details: 'دفع اشتراك من صفحة الاشتراكات: ${record.name}',
                              );
                              widget.onPaid();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.accent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('دفع',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                          ),
                      ],
                    ),
                  ),
                  // ── سجل الدفعات السابقة ────────────────────────────────
                  if (payments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...payments.take(5).map((tx) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: widget.accent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check_rounded, size: 14, color: widget.accent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        Text(
                          '${tx.amount.toStringAsFixed(2)} ج.م',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: widget.accent),
                        ),
                      ]),
                    )),
                    if (payments.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+${payments.length - 5} دفعة سابقة',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _DetailsTable extends StatelessWidget {
  final Map<String, String> rows;

  const _DetailsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        children: rows.entries.map((entry) {
          final isLast = entry.key == rows.entries.last.key;
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.3),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
