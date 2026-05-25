import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../widgets/transaction_details_sheet.dart';
import 'recurring_transaction_composer_screen.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key, required this.cubit});

  final AppCubit cubit;

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  static const Color _incomeAccent = Color(0xFF2F6F5E);
  static const Color _expenseAccent = Color(0xFFC65D2E);
  static const Color _sharedCardBackground = Color(0xFFF9F3E7);

  String _tab = 'expense';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppStateEntity>(
      stream: widget.cubit.stream,
      initialData: widget.cubit.state,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.cubit.state;
        final records = state.recurringTransactions.where(_matchesTab).toList()
          ..sort((a, b) {
            final nameCompare = a.name.compareTo(b.name);
            if (nameCompare != 0) return nameCompare;
            return a.dayOfMonth.compareTo(b.dayOfMonth);
          });
        final inBudget = records
            .where((item) => item.budgetScope == 'within-budget')
            .toList();
        final outBudget = records
            .where((item) => item.budgetScope != 'within-budget')
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _typeSwitcher(),
            const SizedBox(height: 14),
            _addButtons(),
            const SizedBox(height: 16),
            _scopeSection(
              state: state,
              title: 'داخل الميزانية',
              subtitle: _scopeSubtitle(withinBudget: true),
              records: inBudget,
              emptyLabel: _emptyScopeLabel(withinBudget: true),
              accent: _currentAccent,
            ),
            const SizedBox(height: 14),
            _scopeSection(
              state: state,
              title: 'عام',
              subtitle: _scopeSubtitle(withinBudget: false),
              records: outBudget,
              emptyLabel: _emptyScopeLabel(withinBudget: false),
              accent: _currentAccent,
            ),
          ],
        );
      },
    );
  }

  bool _matchesTab(RecurringTransactionEntity item) {
    if (_tab == 'income') {
      return item.type == 'income';
    }
    return item.type == 'expense' &&
        item.expensePlanKind != 'subscription' &&
        item.expensePlanKind != 'installment';
  }

  Color get _currentAccent {
    if (_tab == 'income') return _incomeAccent;
    return _expenseAccent;
  }



  String _scopeSubtitle({required bool withinBudget}) {
    if (_tab == 'income') {
      return withinBudget
          ? 'الدخل المتكرر الذي يدخل في خطة الميزانية ومصادر دخلها.'
          : 'الدخل المتكرر العام خارج تخطيط الميزانية الشهرية.';
    }
    return withinBudget
        ? 'المصروفات المتكررة المرتبطة بخطة الميزانية.'
        : 'مصروفات متكررة عامة خارج حسابات الميزانية الشهرية.';
  }

  String _emptyScopeLabel({required bool withinBudget}) {
    if (_tab == 'income') {
      return withinBudget
          ? 'لا توجد معاملات دخل متكررة داخل الميزانية.'
          : 'لا توجد معاملات دخل متكررة عامة.';
    }
    return withinBudget
        ? 'لا توجد مصروفات متكررة داخل الميزانية.'
        : 'لا توجد مصروفات متكررة عامة.';
  }

  void _handleAddPressed() {
    _openRecurringComposer(mode: _tab);
  }

  Widget _addButtons() {
    final isExpense = _tab == 'expense';
    final color = isExpense ? _expenseAccent : _incomeAccent;
    final icon = isExpense ? Icons.north_east_rounded : Icons.south_west_rounded;
    final label = isExpense ? 'إضافة مصروف متكرر' : 'إضافة دخل متكرر';

    return GestureDetector(
      onTap: _handleAddPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
          _switchTile('expense', 'المصروف', Icons.north_east_rounded),
          const SizedBox(width: 8),
          _switchTile('income', 'الدخل', Icons.south_west_rounded),
        ],
      ),
    );
  }

  Widget _switchTile(String value, String label, IconData icon) {
    final selected = _tab == value;
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
                color: selected ? _currentAccent : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? _currentAccent : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scopeSection({
    required AppStateEntity state,
    required String title,
    required String subtitle,
    required List<RecurringTransactionEntity> records,
    required String emptyLabel,
    required Color accent,
  }) {
    final theme = Theme.of(context);
    final total = records
        .where((item) => !item.isVariableIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.layers_rounded, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                total.toStringAsFixed(2),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 8),
          if (records.isEmpty)
            _emptyCard(emptyLabel)
          else
            ...records.map((record) => _recurringCard(state, record)),
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
    final relatedTransactions = _relatedTransactions(state, record);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.84,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _sharedCardBackground,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.7),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Center(
                      child: AppIconPickerDialog.iconWidgetForName(
                        record.icon,
                        color: accent,
                        size: 31,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_typeLabel(record)} · ${_executionLabel(record.executionType)}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    record.isVariableIncome
                        ? 'متغير'
                        : record.amount.toStringAsFixed(2),
                    style: const TextStyle(
                      color: Color(0xFF254034),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _DetailsTable(rows: _detailsRows(state, record)),
            const SizedBox(height: 14),
            _relatedTransactionsSection(relatedTransactions),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openRecurringComposer(
                        mode: record.type,
                        editing: record,
                        subscriptionOnlyMode:
                            record.expensePlanKind == 'subscription',
                        debtOnlyMode:
                            record.expensePlanKind == 'installment',
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('تعديل'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await widget.cubit.deleteRecurringTransaction(record.id);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('حذف'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _relatedTransactionsSection(List<TransactionEntity> transactions) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المعاملات المرتبطة',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            transactions.isEmpty
                ? 'لا توجد معاملات مسجلة لهذه العملية المتكررة حتى الآن.'
                : 'آخر المعاملات المسجلة المرتبطة بهذه العملية.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (transactions.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...transactions.map(_relatedTransactionTile),
          ],
        ],
      ),
    );
  }

  Widget _relatedTransactionTile(TransactionEntity transaction) {
    final date = '${transaction.createdAt.day.toString().padLeft(2, '0')}/'
        '${transaction.createdAt.month.toString().padLeft(2, '0')}/'
        '${transaction.createdAt.year}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor:
            Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.28,
                ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(
          transaction.amount.toStringAsFixed(2),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          transaction.notes?.trim().isNotEmpty == true
              ? '${transaction.notes}\n$date'
              : date,
        ),
        isThreeLine: transaction.notes?.trim().isNotEmpty == true,
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: () => openTransactionDetailsSheet(
          context,
          cubit: widget.cubit,
          transaction: transaction,
        ),
      ),
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
        'مصدر الدخل': _incomeName(state, record.incomeSourceId),
      if (record.allocationId != null)
        'المخصص': _allocationName(state, record.allocationId),
      if (record.targetJarId != null)
        'الحصالة': _jarName(state, record.targetJarId),
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
      'manual-variable' => 'يدوي متغير',
      _ => 'شهري يوم ${record.dayOfMonth}$timeSuffix',
    };
  }

  String _weekdayName(int? day) {
    return switch (day) {
      1 => 'الإثنين',
      2 => 'الثلاثاء',
      3 => 'الأربعاء',
      4 => 'الخميس',
      5 => 'الجمعة',
      6 => 'السبت',
      7 => 'الأحد',
      _ => 'غير محدد',
    };
  }

  String _executionLabel(String value) {
    return switch (value) {
      'auto' => 'تلقائي',
      'confirm' => 'يحتاج تأكيد',
      'manual' => 'يدوي',
      _ => value,
    };
  }

  String _typeLabel(RecurringTransactionEntity record) {
    if (record.type == 'income') {
      return 'دخل';
    }
    if (record.expensePlanKind == 'subscription') {
      return 'اشتراك';
    }
    if (record.expensePlanKind == 'installment') {
      return 'قسط';
    }
    return 'مصروف';
  }

  String _reminderLabel(RecurringTransactionEntity record) {
    final value = record.reminderLeadDays ?? 0;
    if (value == 0) return 'في نفس الموعد';
    final isHours = record.recurrencePattern == 'daily' ||
        record.recurrencePattern == 'weekly' ||
        record.recurrencePattern == 'biweekly' ||
        record.recurrencePattern == 'every_3_weeks';
    return isHours ? '$value ساعة' : '$value يوم';
  }

  String _walletName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final wallets = state.wallets.where((item) => item.id == id).toList();
    return wallets.isEmpty ? id : wallets.first.name;
  }

  String _incomeName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items =
        state.budgetSetup.incomeSources.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _allocationName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items =
        state.budgetSetup.allocations.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _jarName(AppStateEntity state, String? id) {
    if (id == null || id.isEmpty) return '-';
    final items =
        state.budgetSetup.linkedWallets.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _categoryName(AppStateEntity state, String id) {
    final items = state.categories.where((item) => item.id == id).toList();
    return items.isEmpty ? id : items.first.name;
  }

  String _expensePlanKindLabel(RecurringTransactionEntity record) {
    final kind = record.expensePlanKind;
    if (kind == 'installment') {
      return 'قسط';
    }
    if (kind == 'subscription') {
      return 'اشتراك';
    }
    return 'مصروف';
  }

  Color _parseColor(String hex) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (value ?? 0x2F6F5E));
  }

  List<TransactionEntity> _relatedTransactions(
    AppStateEntity state,
    RecurringTransactionEntity record,
  ) {
    final items = state.transactions.where((transaction) {
      if (transaction.type != record.type) {
        return false;
      }
      if (record.type == 'income') {
        if ((record.incomeSourceId ?? '').isNotEmpty) {
          return transaction.incomeSourceId == record.incomeSourceId;
        }
        return transaction.walletId == record.walletId;
      }
      if (transaction.walletId != record.walletId) {
        return false;
      }
      if ((record.allocationId ?? '').isNotEmpty) {
        return transaction.allocationId == record.allocationId;
      }
      if ((record.targetJarId ?? '').isNotEmpty) {
        return transaction.toWalletId == record.targetJarId ||
            transaction.walletId == record.targetJarId;
      }
      if (record.categoryIds.isNotEmpty &&
          transaction.categoryId != null &&
          record.categoryIds.contains(transaction.categoryId)) {
        return true;
      }
      final notes = (transaction.notes ?? '').toLowerCase();
      final recurringName = record.name.trim().toLowerCase();
      if (notes.contains(recurringName)) {
        return true;
      }
      return (transaction.amount - record.amount).abs() < 0.01;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(12).toList();
  }

  Future<void> _openRecurringComposer({
    required String mode,
    RecurringTransactionEntity? editing,
    String? initialExpensePlanKind,
    bool subscriptionOnlyMode = false,
    bool debtOnlyMode = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => RecurringTransactionComposerScreen(
          cubit: widget.cubit,
          initialType: mode,
          initialRecurring: editing,
          initialWithinBudget: editing?.budgetScope == 'within-budget',
          initialExpensePlanKind:
              editing?.expensePlanKind ?? initialExpensePlanKind,
          allowDelete: editing != null,
          subscriptionOnlyMode: subscriptionOnlyMode,
          debtOnlyMode: debtOnlyMode,
        ),
      ),
    );
  }

}

class _DetailsTable extends StatelessWidget {
  const _DetailsTable({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: rows.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.start,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  entry.key,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
