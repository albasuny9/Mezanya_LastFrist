import 'package:flutter/material.dart';

import '../../../../core/constants/transaction_types.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/transaction_entity.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    required this.cubit,
    this.initialTransaction,
    this.recurringMode = false,
    this.recurringType,
    this.initialRecurring,
  });

  final AppCubit cubit;
  final TransactionEntity? initialTransaction;
  final bool recurringMode;
  final String? recurringType;
  final RecurringTransactionEntity? initialRecurring;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  String _type = TransactionType.expense.value;
  String _budgetScope = BudgetScope.outsideBudget.value;
  String _incomeBudgetScope = BudgetScope.outsideBudget.value;
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _recurringNameController = TextEditingController();
  final _newCategoryController = TextEditingController();
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String _walletId = '';
  String _budgetTargetId = '';
  String _incomeSourceId = 'wallet-only';
  String _incomeJarId = '';
  String _recurrencePattern = RecurrencePattern.monthly.value;
  int _recurrenceWeekday = DateTime.now().weekday;
  String _recurringIconName = 'category';
  String _recurringIconColor = '#165b47';
  bool _isSaving = false;
  String? _selectedCategoryId;
  String? _selectedIncomeCategoryId;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_refreshAmountPreview);
    final state = widget.cubit.state;
    _walletId = state.wallets.isNotEmpty ? state.wallets.first.id : '';
    _incomeSourceId = 'wallet-only';
    _incomeJarId = '';
    if (widget.recurringMode) {
      _type = widget.recurringType ?? TransactionType.expense.value;
      final r = widget.initialRecurring;
      if (r != null) {
        _type = r.type;
        _walletId = r.walletId;
        _amountController.text = r.amount.toStringAsFixed(2);
        _notesController.text = r.notes ?? '';
        _recurringNameController.text = r.name;
        _recurrencePattern = r.recurrencePattern;
        _recurrenceWeekday = r.weekday ?? _recurrenceWeekday;
        _recurringIconName = r.icon;
        _recurringIconColor = r.iconColor;
        _budgetScope = r.budgetScope;
        _incomeBudgetScope = r.budgetScope;
        _incomeSourceId = r.incomeSourceId ?? _incomeSourceId;
        _incomeJarId = r.targetJarId ?? '';
        if (r.allocationId != null) {
          _budgetTargetId = 'alloc:${r.allocationId!}';
        } else if (r.targetJarId != null) {
          _budgetTargetId = 'jar:${r.targetJarId!}';
        }
        _date = DateTime(_date.year, _date.month, r.dayOfMonth);
      }
    }
    final t = widget.initialTransaction;
    if (t != null) {
      _type = t.type;
      _date = t.createdAt;
      _time = TimeOfDay(hour: t.createdAt.hour, minute: t.createdAt.minute);
      _walletId = t.walletId ?? _walletId;
      _amountController.text = t.amount.toStringAsFixed(2);
      _notesController.text = t.notes ?? '';
      _incomeSourceId = t.incomeSourceId ?? _incomeSourceId;
      if (t.type == TransactionType.expense.value) {
        _budgetScope = t.budgetScope ?? BudgetScope.outsideBudget.value;
        if (t.allocationId != null) {
          _budgetTargetId = 'alloc:${t.allocationId!}';
        } else if (t.toWalletId != null) {
          _budgetTargetId = 'jar:${t.toWalletId!}';
        } else {
          _budgetTargetId = '';
        }
      }
      if (t.type == TransactionType.income.value) {
        _incomeBudgetScope = t.budgetScope == BudgetScope.withinBudget.value
            ? BudgetScope.withinBudget.value
            : BudgetScope.outsideBudget.value;
        _incomeJarId = t.toWalletId ?? '';
      }
      // تحميل الفئة المحددة
      _selectedCategoryId = t.categoryId;
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_refreshAmountPreview);
    _amountController.dispose();
    _notesController.dispose();
    _recurringNameController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }

  void _refreshAmountPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  double _walletReservedAmount(String walletId) {
    // الحجز الآن محسوب من walletSources في الحصالات (virtual labels) مش من transactions
    var reserved = 0.0;
    for (final jar in widget.cubit.state.budgetSetup.linkedWallets) {
      final sources = jar.walletSources.isNotEmpty
          ? jar.walletSources
          : jar.walletBalances.entries
              .map((e) => JarWalletSource(walletId: e.key, amount: e.value))
              .toList();
      for (final src in sources) {
        if (src.walletId == walletId) reserved += src.amount;
      }
    }
    return reserved < 0 ? 0 : reserved;
  }

  Future<bool> _confirmExpenseImpact({
    required WalletEntity wallet,
    required double amount,
  }) async {
    var effectiveBalance = wallet.balance;
    if (widget.initialTransaction?.walletId == wallet.id) {
      if (widget.initialTransaction?.type == TransactionType.expense.value) {
        effectiveBalance += widget.initialTransaction!.amount;
      } else if (widget.initialTransaction?.type ==
          TransactionType.income.value) {
        effectiveBalance -= widget.initialTransaction!.amount;
      }
    }

    final reserved = _walletReservedAmount(wallet.id);
    final availableNet = effectiveBalance - reserved;
    final usesReservedFunds = amount > availableNet;
    final goesNegative = (effectiveBalance - amount) < 0;
    if (!usesReservedFunds && !goesNegative) {
      return true;
    }

    final messages = <String>[
      if (usesReservedFunds)
        'هذه المعاملة ستسحب من مبلغ محجوز للحصالات. الصافي المتاح الآن ${availableNet.toStringAsFixed(2)}.',
      if (goesNegative)
        'هذه المعاملة ستجعل رصيد المحفظة بالسالب. الرصيد بعد التنفيذ ${(effectiveBalance - amount).toStringAsFixed(2)}.',
    ];

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد تنفيذ المعاملة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              wallet.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...messages.map(
              (message) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(message),
              ),
            ),
            Text(
              'يمكنك متابعة العملية الآن ثم تعديل ربطها بالحصالة أو المخصص لاحقًا.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تنفيذ'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  bool get _canSubmit {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (_isSaving || amount <= 0 || (_walletId.isEmpty)) {
      return false;
    }
    if (_type == TransactionType.expense.value &&
        _budgetScope == BudgetScope.withinBudget.value &&
        _budgetTargetId.isEmpty) {
      return false;
    }
    if (_type == TransactionType.income.value &&
        _incomeBudgetScope == BudgetScope.withinBudget.value &&
        _incomeSourceId == 'wallet-only' &&
        _incomeJarId.isEmpty) {
      return false;
    }
    if (widget.recurringMode && _recurringNameController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SMART WALLET DEFAULT
  // ─────────────────────────────────────────────────────────────────────────

  /// لما اليوزر يختار مخصص، المحفظة تتحدد تلقائياً من مصدر الدخل المرتبط
  void _autoSetWalletFromAllocation(String budgetTargetId) {
    final s = widget.cubit.state;
    final budget = s.budgetSetup;

    String? incomeSourceId;
    if (budgetTargetId.startsWith('alloc:')) {
      final allocId = budgetTargetId.replaceFirst('alloc:', '');
      final alloc = budget.allocations
          .where((a) => a.id == allocId)
          .toList();
      if (alloc.isEmpty || alloc.first.funding.isEmpty) return;
      incomeSourceId = alloc.first.funding.first.incomeSourceId;
    } else if (budgetTargetId.startsWith('jar:')) {
      final jarId = budgetTargetId.replaceFirst('jar:', '');
      final jar = budget.linkedWallets
          .where((j) => j.id == jarId)
          .toList();
      if (jar.isEmpty || jar.first.funding.isEmpty) return;
      incomeSourceId = jar.first.funding.first.incomeSourceId;
    }
    if (incomeSourceId == null) return;
    final src = budget.incomeSources.where((s) => s.id == incomeSourceId).toList();
    if (src.isEmpty) return;
    final walletExists = s.wallets.any((w) => w.id == src.first.targetWalletId);
    if (walletExists) setState(() => _walletId = src.first.targetWalletId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = widget.cubit.state;
    final wallets = state.wallets;
    final budget = state.budgetSetup;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final selectedWallet = wallets.where((w) => w.id == _walletId).toList();
    final selectedWalletName = _walletId == 'no-wallet'
        ? 'بدون محفظة (افتراضي)'
        : selectedWallet.isEmpty
            ? 'اختر المحفظة'
            : selectedWallet.first.name;

    // ── allocation label ──
    final selectedAllocation = budget.allocations
        .where((a) => _budgetTargetId == 'alloc:${a.id}')
        .toList();
    final selectedJar = budget.linkedWallets
        .where((j) => _budgetTargetId == 'jar:${j.id}')
        .toList();
    final selectedAllocationName = _budgetTargetId == 'unallocated'
        ? 'غير المخصص'
        : selectedJar.isNotEmpty
            ? 'حصالة: ${selectedJar.first.name}'
            : selectedAllocation.isEmpty
                ? 'خارج الميزانية'
                : selectedAllocation.first.name;

    // ── income jar label ──
    final selectedIncomeJar =
        budget.linkedWallets.where((j) => j.id == _incomeJarId).toList();
    final selectedIncomeJarName = selectedIncomeJar.isEmpty
        ? 'اختر الحصالة'
        : selectedIncomeJar.first.name;
    final selectedIncomeSource = budget.incomeSources
        .where((item) => item.id == _incomeSourceId)
        .toList();
    final incomeTargetLabel = _incomeJarId.isNotEmpty
        ? 'حصالتي: $selectedIncomeJarName'
        : selectedIncomeSource.isNotEmpty
            ? 'مصدر دخل: ${selectedIncomeSource.first.name}'
            : 'إيداع لمحفظة $selectedWalletName فقط';

    // ── categories ──
    final allocationCategories = selectedAllocation.isEmpty
        ? <CategoryEntity>[]
        : selectedAllocation.first.categories;
    final jarCategories =
        selectedJar.isEmpty ? <CategoryEntity>[] : selectedJar.first.categories;
    final generalExpenseCategories = state.categories
        .where((c) => c.scope == 'expense' && c.incomeSourceId == null)
        .toList();

    // Show general categories when outside-budget OR jar selected
    final visibleCategories = _budgetScope == BudgetScope.withinBudget.value &&
            _budgetTargetId.startsWith('alloc:')
        ? allocationCategories
        : (_budgetScope == BudgetScope.withinBudget.value &&
                _budgetTargetId.startsWith('jar:'))
            ? jarCategories
            : generalExpenseCategories;

    // ── allocation dropdown items ──
    final allocationItems = [
      if (budget.unallocatedAmount > 0)
        const DropdownMenuItem(value: 'unallocated', child: Text('غير المخصص')),
      ...budget.allocations.map(
          (a) => DropdownMenuItem(value: 'alloc:${a.id}', child: Text(a.name))),
      ...budget.linkedWallets.map((j) => DropdownMenuItem(
          value: 'jar:${j.id}', child: Text('حصالة: ${j.name}'))),
    ];
    final allocationIds = allocationItems.map((item) => item.value!).toSet();

    if (_budgetTargetId.isNotEmpty &&
        !allocationIds.contains(_budgetTargetId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _budgetTargetId = '');
      });
    }

    void unfocusScope(BuildContext context) {
      FocusScope.of(context).unfocus();
    }

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: GestureDetector(
        onTap: () => unfocusScope(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── Type toggle ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: _typeSegmentedToggle(theme),
              ),
              // ── Scrollable body ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    // ── Recurring fields ──
                    if (widget.recurringMode) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _recurringNameController,
                        decoration: const InputDecoration(
                            labelText: 'اسم المعاملة المتكررة'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _recurrencePattern,
                        decoration: const InputDecoration(labelText: 'التكرار'),
                        items: [
                          DropdownMenuItem(
                              value: RecurrencePattern.weekly.value,
                              child: Text('مرة كل أسبوع')),
                          DropdownMenuItem(
                              value: RecurrencePattern.biweekly.value,
                              child: Text('مرة كل أسبوعين')),
                          DropdownMenuItem(
                              value: RecurrencePattern.monthly.value,
                              child: Text('مرة كل شهر')),
                          DropdownMenuItem(
                              value: RecurrencePattern.every2Months.value,
                              child: Text('مرة كل شهرين')),
                          DropdownMenuItem(
                              value: RecurrencePattern.every3Months.value,
                              child: Text('مرة كل 3 شهور')),
                          DropdownMenuItem(
                              value: RecurrencePattern.every6Months.value,
                              child: Text('مرة كل 6 شهور')),
                          DropdownMenuItem(
                              value: RecurrencePattern.yearly.value,
                              child: Text('مرة كل سنة')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _recurrencePattern = v);
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await AppIconPickerDialog.show(
                              context,
                              initialIconName: _recurringIconName,
                              initialColorHex: _recurringIconColor,
                              title: 'اختيار أيقونة المعاملة المتكررة',
                              name: _recurringNameController.text,
                            );
                            if (picked == null) return;
                            setState(() {
                              _recurringIconName = picked.iconName;
                              _recurringIconColor = picked.colorHex;
                            });
                          },
                          icon: const Icon(Icons.palette_outlined),
                          label: const Text('اختيار الأيقونة واللون'),
                        ),
                      ),
                    ],

                    // ── Amount ──
                    _AmountField(controller: _amountController),
                    const SizedBox(height: 10),

                    // ── EXPENSE: المخصص (قبل المحفظة) ──
                    if (_type == TransactionType.expense.value) ...[
                      _RowCard(
                        label: 'المخصص',
                        value: _budgetTargetId.isEmpty
                            ? 'خارج الميزانية'
                            : selectedAllocationName,
                        icon: Icons.pie_chart_outline_rounded,
                        onTap: () {
                          _openAllocationPicker(allocationItems, budget);
                          if (_budgetTargetId.isNotEmpty) {
                            _autoSetWalletFromAllocation(_budgetTargetId);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Wallet picker ──
                    _RowCard(
                      label: 'المحفظة',
                      value: selectedWalletName,
                      icon: Icons.account_balance_wallet_outlined,
                      onTap: () => _openWalletPicker(wallets),
                    ),
                    const SizedBox(height: 8),

                    // ── EXPENSE: الفئات (بعد المحفظة دائماً) ──
                    if (_type == TransactionType.expense.value) ...[
                      _CategoriesSection(
                        categories: visibleCategories,
                        selectedId: _selectedCategoryId,
                        onSelectChange: (id) =>
                            setState(() => _selectedCategoryId = id),
                        onAdd: () => _openAddCategoryDialog(
                          budgetScope: _budgetScope,
                          allocationId: _budgetTargetId.startsWith('alloc:')
                              ? _budgetTargetId.replaceFirst('alloc:', '')
                              : '',
                          linkedWalletId: _budgetTargetId.startsWith('jar:')
                              ? _budgetTargetId.replaceFirst('jar:', '')
                              : '',
                          existing: visibleCategories,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Recurring weekday ──
                    if (widget.recurringMode &&
                        (_recurrencePattern == RecurrencePattern.weekly.value ||
                            _recurrencePattern ==
                                RecurrencePattern.biweekly.value)) ...[
                      DropdownButtonFormField<int>(
                        value: _recurrenceWeekday,
                        decoration: const InputDecoration(
                            labelText: 'اليوم في الأسبوع'),
                        items: [
                          DropdownMenuItem(value: 1, child: Text('الاثنين')),
                          DropdownMenuItem(value: 2, child: Text('الثلاثاء')),
                          DropdownMenuItem(value: 3, child: Text('الأربعاء')),
                          DropdownMenuItem(value: 4, child: Text('الخميس')),
                          DropdownMenuItem(value: 5, child: Text('الجمعة')),
                          DropdownMenuItem(value: 6, child: Text('السبت')),
                          DropdownMenuItem(value: 7, child: Text('الأحد')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _recurrenceWeekday = v);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── INCOME fields ── (نفس ترتيب المصروف)
                    if (_type == TransactionType.income.value) ...[
                      const SizedBox(height: 4),
                      _RowCard(
                        label: 'هدف الإيداع',
                        value: incomeTargetLabel,
                        icon: Icons.download_for_offline_rounded,
                        onTap: () =>
                            _openIncomeTargetPicker(budget, selectedWalletName),
                      ),
                      const SizedBox(height: 8),
                      _CategoriesSection(
                        categories: state.categories
                            .where((c) => c.scope == 'income')
                            .toList(),
                        selectedId: _selectedIncomeCategoryId,
                        onSelectChange: (id) =>
                            setState(() => _selectedIncomeCategoryId = id),
                        onAdd: () => _openAddCategoryDialog(
                          budgetScope: BudgetScope.outsideBudget.value,
                          allocationId: '',
                          linkedWalletId: '',
                          existing: state.categories
                              .where((c) => c.scope == 'income')
                              .toList(),
                          scope: 'income',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 10),

                    // ── Date + Time row (2/3 + 1/3) ──
                    _DateTimeRow(
                      date: _date,
                      time: _time,
                      onDateTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setState(() => _date = picked);
                      },
                      onTimeTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked != null) setState(() => _time = picked);
                      },
                    ),
                    const SizedBox(height: 10),

                    // ── Notes ──
                    TextField(
                      controller: _notesController,
                      maxLines: 1,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Delete buttons ──
                    if (widget.recurringMode && widget.initialRecurring != null)
                      TextButton(
                        onPressed: () async {
                          await widget.cubit.deleteRecurringTransaction(
                            widget.initialRecurring!.id,
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'حذف المعاملة المتكررة',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    if (!widget.recurringMode &&
                        widget.initialTransaction != null)
                      TextButton(
                        onPressed: () async {
                          await widget.cubit
                              .deleteTransaction(widget.initialTransaction!.id);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'حذف المعاملة',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),

                    // ── Submit ──
                    FilledButton(
                      onPressed: () async {
                              // حماية من الضغط المزدوج — synchronous guard
                              if (_isSaving || !_canSubmit) return;
                              _isSaving = true; // يتحدد فوراً قبل أي await
                              setState(() {});   // تحديث الـ UI لتعطيل الزر
                              try {
                                if (amount <= 0) {
                                  _showValidationError(
                                      'أدخل مبلغًا صحيحًا أكبر من صفر.');
                                  return;
                                }
                                if (_walletId.isEmpty) {
                                  _showValidationError(
                                      'اختر محفظة أو اختر "بدون محفظة" أولًا.');
                                  return;
                                }
                                if (_type == TransactionType.expense.value &&
                                    _budgetScope ==
                                        BudgetScope.withinBudget.value &&
                                    _budgetTargetId.isEmpty) {
                                  _showValidationError(
                                      'اختر مخصصًا أو حصالة للمعاملة داخل الميزانية.');
                                  return;
                                }
                                if (_budgetTargetId == 'unallocated' &&
                                    amount > budget.unallocatedAmount) {
                                  _showValidationError(
                                      'المبلغ أكبر من المتاح في غير المخصص.');
                                  return;
                                }
                                if (_type == TransactionType.income.value &&
                                    _incomeBudgetScope ==
                                        BudgetScope.withinBudget.value &&
                                    _incomeSourceId == 'wallet-only' &&
                                    _incomeJarId.isEmpty) {
                                  _showValidationError(
                                      'اختر مصدر دخل أو حصالة للدخل داخل الميزانية.');
                                  return;
                                }
                                if (widget.recurringMode &&
                                    _recurringNameController.text
                                        .trim()
                                        .isEmpty) {
                                  _showValidationError(
                                      'اكتب اسم المعاملة المتكررة.');
                                  return;
                                }

                                if (!widget.recurringMode &&
                                    _type == TransactionType.expense.value &&
                                    _walletId == 'no-wallet' &&
                                    _budgetTargetId.startsWith('jar:')) {
                                  final selectedJarId =
                                      _budgetTargetId.replaceFirst('jar:', '');
                                  final jar = budget.linkedWallets.firstWhere(
                                      (j) => j.id == selectedJarId,
                                      orElse: () => const LinkedWalletEntity(
                                            id: '',
                                            name: '',
                                            monthlyAmount: 0,
                                            executionDay: 1,
                                            fundingSource: '',
                                            funding: [],
                                            icon: '',
                                            iconColor: '',
                                            automationType: '',
                                            categories: [],
                                          ));
                                  if (jar.id.isNotEmpty) {
                                    final fundedAmount = jar.walletSources
                                        .fold<double>(
                                            0,
                                            (sum, source) =>
                                                sum + source.amount);
                                    final unfundedAmount =
                                        jar.balance - fundedAmount;
                                    if (amount > unfundedAmount) {
                                      _showValidationError(
                                          'المبلغ أكبر من الرصيد غير الممول في الحصالة (${unfundedAmount.toStringAsFixed(2)}). اختر محفظة البنك الممول للخصم منها.');
                                      return;
                                    }
                                  }
                                }

                                if (!widget.recurringMode &&
                                    _type == TransactionType.expense.value &&
                                    _walletId != 'no-wallet') {
                                  final currentWallet = wallets
                                      .where((wallet) => wallet.id == _walletId)
                                      .toList();
                                  if (currentWallet.isNotEmpty) {
                                    final approved =
                                        await _confirmExpenseImpact(
                                      wallet: currentWallet.first,
                                      amount: amount,
                                    );
                                    if (!approved) return;
                                  }
                                }

                                final selectedJarId = _budgetTargetId
                                        .startsWith('jar:')
                                    ? _budgetTargetId.replaceFirst('jar:', '')
                                    : null;

                                if (widget.recurringMode) {
                                  final recurring = widget.initialRecurring;
                                  final recurringEntity =
                                      RecurringTransactionEntity(
                                    id: recurring?.id ??
                                        'rec-${DateTime.now().microsecondsSinceEpoch}',
                                    name: _recurringNameController.text.trim(),
                                    type: _type,
                                    amount: amount,
                                    dayOfMonth: _date.day.clamp(1, 28),
                                    executionType: AutomationType.confirm.value,
                                    walletId: _walletId == 'no-wallet'
                                        ? ''
                                        : _walletId,
                                    budgetScope:
                                        _type == TransactionType.expense.value
                                            ? _budgetScope
                                            : _incomeBudgetScope,
                                    recurrencePattern: _recurrencePattern,
                                    icon: _recurringIconName,
                                    iconColor: _recurringIconColor,
                                    weekday: (_recurrencePattern ==
                                                RecurrencePattern
                                                    .weekly.value ||
                                            _recurrencePattern ==
                                                RecurrencePattern
                                                    .biweekly.value)
                                        ? _recurrenceWeekday
                                        : null,
                                    allocationId: _type ==
                                                TransactionType.expense.value &&
                                            _budgetScope ==
                                                BudgetScope
                                                    .withinBudget.value &&
                                            _budgetTargetId.startsWith('alloc:')
                                        ? _budgetTargetId.replaceFirst(
                                            'alloc:', '')
                                        : null,
                                    targetJarId:
                                        _type == TransactionType.income.value &&
                                                _incomeBudgetScope ==
                                                    BudgetScope
                                                        .withinBudget.value &&
                                                _incomeJarId.isNotEmpty
                                            ? _incomeJarId
                                            : (_type ==
                                                        TransactionType
                                                            .expense.value &&
                                                    _budgetTargetId
                                                        .startsWith('jar:')
                                                ? selectedJarId
                                                : null),
                                    incomeSourceId:
                                        _type == TransactionType.income.value &&
                                                _incomeSourceId != 'wallet-only'
                                            ? _incomeSourceId
                                            : null,
                                    notes: _notesController.text.trim().isEmpty
                                        ? null
                                        : _notesController.text.trim(),
                                    isActive: recurring?.isActive ?? true,
                                  );
                                  if (recurring == null) {
                                    await widget.cubit.addRecurringTransaction(
                                      name: recurringEntity.name,
                                      type: recurringEntity.type,
                                      amount: recurringEntity.amount,
                                      dayOfMonth: recurringEntity.dayOfMonth,
                                      executionType:
                                          recurringEntity.executionType,
                                      walletId: recurringEntity.walletId,
                                      budgetScope: recurringEntity.budgetScope,
                                      recurrencePattern:
                                          recurringEntity.recurrencePattern,
                                      icon: recurringEntity.icon,
                                      iconColor: recurringEntity.iconColor,
                                      weekday: recurringEntity.weekday,
                                      allocationId:
                                          recurringEntity.allocationId,
                                      targetJarId: recurringEntity.targetJarId,
                                      incomeSourceId:
                                          recurringEntity.incomeSourceId,
                                      notes: recurringEntity.notes,
                                    );
                                  } else {
                                    await widget.cubit
                                        .updateRecurringTransaction(
                                            recurringEntity);
                                  }
                                } else {
                                  if (widget.initialTransaction != null) {
                                    await widget.cubit.deleteTransaction(
                                      widget.initialTransaction!.id,
                                    );
                                  }
                                  await widget.cubit.addTransaction(
                                    walletId: _walletId == 'no-wallet'
                                        ? null
                                        : _walletId,
                                    toWalletId:
                                        _type == TransactionType.income.value &&
                                                _incomeBudgetScope ==
                                                    BudgetScope
                                                        .withinBudget.value &&
                                                _incomeJarId.isNotEmpty
                                            ? _incomeJarId
                                            : selectedJarId,
                                    amount: amount,
                                    type: _type,
                                    createdAt: DateTime(
                                      _date.year,
                                      _date.month,
                                      _date.day,
                                      _time.hour,
                                      _time.minute,
                                    ),
                                    allocationId: _type ==
                                                TransactionType.expense.value &&
                                            _budgetScope ==
                                                BudgetScope
                                                    .withinBudget.value &&
                                            _budgetTargetId.startsWith('alloc:')
                                        ? _budgetTargetId.replaceFirst(
                                            'alloc:', '')
                                        : null,
                                    budgetScope: _type ==
                                            TransactionType.expense.value
                                        ? _budgetScope
                                        : _type == TransactionType.income.value
                                            ? _incomeBudgetScope
                                            : null,
                                    incomeSourceId:
                                        _type == TransactionType.income.value &&
                                                _incomeSourceId != 'wallet-only'
                                            ? _incomeSourceId
                                            : null,
                                    transferType: widget.initialTransaction
                                                ?.transferType ==
                                            TransferType
                                                .jarFundingPhysical.value
                                        ? TransferType.jarFundingPhysical.value
                                        : _type ==
                                                    TransactionType
                                                        .income.value &&
                                                _incomeBudgetScope ==
                                                    BudgetScope
                                                        .withinBudget.value &&
                                                _incomeJarId.isNotEmpty
                                            ? TransferType
                                                .depositWithJarLabel.value
                                            : null,
                                    notes: _notesController.text.trim().isEmpty
                                        ? null
                                        : _notesController.text.trim(),
                                    categoryId: _selectedCategoryId,
                                  );
                                }
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(widget.recurringMode
                                          ? 'تم حفظ المعاملة المتكررة.'
                                          : (_type ==
                                                  TransactionType.income.value
                                              ? 'تم تسجيل الدخل.'
                                              : 'تم تسجيل المعاملة.'))),
                                );
                                Navigator.of(context).pop();
                              } finally {
                                if (mounted) setState(() => _isSaving = false);
                              }
                            },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        widget.recurringMode
                            ? (widget.initialRecurring == null
                                ? 'حفظ المعاملة المتكررة'
                                : 'تحديث التكرار')
                            : widget.initialTransaction != null
                                ? 'حفظ التعديل'
                                : (_type == TransactionType.income.value
                                    ? 'تسجيل الدخل'
                                    : 'تسجيل المعاملة'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
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

  // ─────────────────────────────────────────────────────────────────────────
  // TYPE TOGGLE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _typeSegmentedToggle(ThemeData theme) {
    final activeOnRight = _type == TransactionType.income.value;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment:
                activeOnRight ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: MediaQuery.of(context).size.width > 420 ? 190 : 165,
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E7F5C),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33207B5A),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.recurringMode
                      ? null
                      : () => setState(() {
                            _type = TransactionType.expense.value;
                            _selectedIncomeCategoryId = null;
                          }),
                  child: Center(
                    child: Text(
                      'مصروف',
                      style: TextStyle(
                        color: activeOnRight ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.recurringMode
                      ? null
                      : () => setState(() {
                            _type = TransactionType.income.value;
                            _budgetTargetId = '';
                            _selectedCategoryId = null;
                          }),
                  child: Center(
                    child: Text(
                      'دخل',
                      style: TextStyle(
                        color: activeOnRight ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WALLET PICKER
  // ─────────────────────────────────────────────────────────────────────────
  void _openWalletPicker(List<WalletEntity> wallets) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFFFFBF1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.88,
        expand: false,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const Text(
              'اختر المحفظة',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 14),

            // ── No wallet option ──
            GestureDetector(
              onTap: () {
                setState(() => _walletId = 'no-wallet');
                Navigator.pop(sheetCtx);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: _walletId == 'no-wallet'
                      ? const Color(0xFF165b47).withValues(alpha: 0.10)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _walletId == 'no-wallet'
                        ? const Color(0xFF165b47).withValues(alpha: 0.55)
                        : const Color(0xFF165b47).withValues(alpha: 0.18),
                    width: _walletId == 'no-wallet' ? 1.8 : 1,
                  ),
                  boxShadow: _walletId == 'no-wallet'
                      ? [
                          BoxShadow(
                            color:
                                const Color(0xFF165b47).withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF165b47).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.money_off_csred_rounded,
                          color: Color(0xFF165b47),
                          size: 26,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'بدون محفظة (افتراضي)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF165b47),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'تُسجَّل المعاملة دون التأثير على أي رصيد فعلي',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF165b47),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_walletId == 'no-wallet')
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF165b47), size: 24),
                  ],
                ),
              ),
            ),

            if (wallets.isNotEmpty) ...[
              const _SheetSectionLabel(label: 'المحافظ'),
              const SizedBox(height: 10),
            ],

            ...wallets.map((wallet) {
              final accent = _parseColor(wallet.iconColor ?? '#165b47');
              final isSelected = _walletId == wallet.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _walletId = wallet.id);
                    Navigator.pop(sheetCtx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withValues(alpha: 0.10)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? accent.withValues(alpha: 0.55)
                            : accent.withValues(alpha: 0.18),
                        width: isSelected ? 1.8 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: AppIconPickerDialog.iconWidgetForName(
                              wallet.icon ?? 'account_balance_wallet',
                              color: accent,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                wallet.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? accent
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${wallet.balance.toStringAsFixed(2)} رصيد',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: accent.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle_rounded,
                              color: accent, size: 24),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ALLOCATION PICKER — redesigned bottom sheet
  // ─────────────────────────────────────────────────────────────────────────
  void _openAllocationPicker(
    List<DropdownMenuItem<String>> allocationItems,
    BudgetSetupEntity budget,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            Theme.of(sheetCtx);

            // ── Outside-budget option ──
            Widget outsideOption() {
              final selected = _budgetTargetId.isEmpty;
              return _AllocationOption(
                isSelected: selected,
                onTap: () {
                  setState(() {
                    _budgetTargetId = '';
                    _budgetScope = BudgetScope.outsideBudget.value;
                  });
                  Navigator.pop(sheetCtx);
                },
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.public_off_rounded,
                          color: Color(0xFF2F6F5E)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'خارج الميزانية',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF1E7F5C)),
                  ],
                ),
              );
            }

            // ── Allocation list ──
            final allocations = budget.allocations;
            final jars = budget.linkedWallets;
            final totalIncome =
                budget.totalIncome <= 0 ? 1.0 : budget.totalIncome;

            return SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.84,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // Header
                  const Text(
                    'اختر المخصص',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 14),

                  // Outside budget
                  outsideOption(),
                  const SizedBox(height: 16),

                  // Divider + allocations label
                  if (allocations.isNotEmpty || budget.unallocatedAmount > 0)
                    _SheetSectionLabel(label: 'المخصصات'),

                  // Unallocated
                  if (budget.unallocatedAmount > 0) ...[
                    const SizedBox(height: 8),
                    _AllocationOption(
                      isSelected: _budgetTargetId == 'unallocated',
                      onTap: () {
                        setState(() {
                          _budgetTargetId = 'unallocated';
                          _budgetScope = BudgetScope.withinBudget.value;
                        });
                        Navigator.pop(sheetCtx);
                      },
                      child: _AllocationRow(
                        icon: Icons.category_outlined,
                        iconColor: const Color(0xFF2F6F5E),
                        name: 'غير المخصص',
                        progressLabel:
                            '${budget.unallocatedAmount.toStringAsFixed(2)} متبقي',
                        ratio: (budget.unallocatedAmount / totalIncome)
                            .clamp(0.0, 1.0),
                        isSelected: _budgetTargetId == 'unallocated',
                      ),
                    ),
                  ],

                  // Allocations
                  ...allocations.map((a) {
                    final id = 'alloc:${a.id}';
                    final planned = a.funding
                        .fold<double>(0, (s, f) => s + f.plannedAmount);
                    final ratio = (planned / totalIncome).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _AllocationOption(
                        isSelected: _budgetTargetId == id,
                        onTap: () {
                          setState(() {
                            _budgetTargetId = id;
                            _budgetScope = BudgetScope.withinBudget.value;
                          });
                          Navigator.pop(sheetCtx);
                        },
                        child: _AllocationRow(
                          icon: Icons.pie_chart_outline_rounded,
                          iconColor: const Color(0xFF2F6F5E),
                          name: a.name,
                          progressLabel: '${planned.toStringAsFixed(2)} مخطط',
                          ratio: ratio,
                          isSelected: _budgetTargetId == id,
                        ),
                      ),
                    );
                  }),

                  // Jars section — no progress bar, show balance like wallet
                  if (jars.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SheetSectionLabel(label: 'الحصالات'),
                    ...jars.map((jar) {
                      final id = 'jar:${jar.id}';
                      final isJarSelected = _budgetTargetId == id;
                      final jarAccent = jar.iconColor.isNotEmpty
                          ? _parseColor(jar.iconColor)
                          : const Color(0xFF8B5A2B);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _AllocationOption(
                          isSelected: isJarSelected,
                          onTap: () {
                            setState(() {
                              _budgetTargetId = id;
                              _budgetScope = BudgetScope.withinBudget.value;
                            });
                            Navigator.pop(sheetCtx);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: jarAccent.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Center(
                                  child: AppIconPickerDialog.iconWidgetForName(
                                    jar.icon.isNotEmpty ? jar.icon : 'savings',
                                    color: jarAccent,
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      jar.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${jar.balance.toStringAsFixed(2)} رصيد',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            jarAccent.withValues(alpha: 0.78),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isJarSelected)
                                Icon(Icons.check_circle_rounded,
                                    color: jarAccent, size: 20),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INCOME TARGET PICKER
  // ─────────────────────────────────────────────────────────────────────────
  void _openIncomeTargetPicker(
    BudgetSetupEntity budget,
    String walletName,
  ) {
    final jars = budget.linkedWallets;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetCtx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.78,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _AllocationOption(
              isSelected:
                  _incomeBudgetScope == BudgetScope.outsideBudget.value &&
                      _incomeSourceId == 'wallet-only' &&
                      _incomeJarId.isEmpty,
              onTap: () {
                setState(() {
                  _incomeBudgetScope = BudgetScope.outsideBudget.value;
                  _incomeSourceId = 'wallet-only';
                  _incomeJarId = '';
                });
                Navigator.pop(sheetCtx);
              },
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.download_for_offline_rounded,
                      color: Color(0xFF2F6F5E),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'إيداع للمحفظة فقط',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الإيداع يذهب إلى محفظة $walletName فقط.',
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                Theme.of(sheetCtx).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_incomeBudgetScope == BudgetScope.outsideBudget.value &&
                      _incomeSourceId == 'wallet-only' &&
                      _incomeJarId.isEmpty)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF1E7F5C),
                    ),
                ],
              ),
            ),
            if (budget.incomeSources.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _SheetSectionLabel(label: 'مصادر الدخل'),
              const SizedBox(height: 10),
              ...budget.incomeSources.map((source) {
                final selected =
                    _incomeBudgetScope == BudgetScope.withinBudget.value &&
                        _incomeJarId.isEmpty &&
                        _incomeSourceId == source.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AllocationOption(
                    isSelected: selected,
                    onTap: () {
                      setState(() {
                        _incomeBudgetScope = BudgetScope.withinBudget.value;
                        _incomeSourceId = source.id;
                        _incomeJarId = '';
                      });
                      Navigator.pop(sheetCtx);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFF1E7F5C),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                source.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                source.isVariable
                                    ? 'مصدر دخل متغير داخل الميزانية'
                                    : 'مخطط ${source.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(sheetCtx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF1E7F5C),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (jars.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _SheetSectionLabel(label: 'الحصالات'),
              const SizedBox(height: 10),
              ...jars.map((jar) {
                final selected =
                    _incomeBudgetScope == BudgetScope.withinBudget.value &&
                        _incomeJarId == jar.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AllocationOption(
                    isSelected: selected,
                    onTap: () {
                      setState(() {
                        _incomeBudgetScope = BudgetScope.withinBudget.value;
                        _incomeSourceId = 'wallet-only';
                        _incomeJarId = jar.id;
                      });
                      Navigator.pop(sheetCtx);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE7F4F1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.monetization_on_rounded,
                            color: Color(0xFF2F6F5E),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                jar.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الرصيد ${jar.balance.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(sheetCtx)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF1E7F5C),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CATEGORIES BLOCK — selectable chips
  // ─────────────────────────────────────────────────────────────────────────
  Widget _categoriesBlock({
    required String title,
    required List<CategoryEntity> categories,
    required VoidCallback? onAdd,
    String? selectedId,
    void Function(String? id)? onSelectChange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة فئة'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (categories.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: const Text('لا توجد فئات حتى الآن لهذا الجزء.'),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((c) {
              final color = _parseColor(c.color);
              final effectiveSelected = selectedId ?? _selectedCategoryId;
              final selected = effectiveSelected == c.id;
              return GestureDetector(
                onTap: () {
                  if (onSelectChange != null) {
                    onSelectChange(selected ? null : c.id);
                  } else {
                    setState(
                        () => _selectedCategoryId = selected ? null : c.id);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? color.withValues(alpha: 0.22)
                        : color.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? color.withValues(alpha: 0.7)
                          : color.withValues(alpha: 0.2),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: AppIconPickerDialog.iconWidgetForName(
                          c.icon,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        c.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? color : null,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_rounded, size: 14, color: color),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD CATEGORY DIALOG
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _openAddCategoryDialog({
    required String budgetScope,
    required String allocationId,
    required String linkedWalletId,
    required List<CategoryEntity> existing,
    String scope = 'expense',
  }) async {
    _newCategoryController.clear();
    var selectedIcon = 'restaurant';
    var selectedColor = '#165b47';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            title: const Text('إضافة فئة'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اسم الفئة'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _newCategoryController,
                      decoration:
                          const InputDecoration(hintText: 'اكتب اسم الفئة'),
                      onChanged: (_) => setDialog(() {}),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await AppIconPickerDialog.show(
                            context,
                            initialIconName: selectedIcon,
                            initialColorHex: selectedColor,
                            title: 'اختيار أيقونة الفئة',
                            name: _newCategoryController.text,
                          );
                          if (picked == null) return;
                          setDialog(() {
                            selectedIcon = picked.iconName;
                            selectedColor = picked.colorHex;
                          });
                        },
                        icon: const Icon(Icons.palette_outlined),
                        label: const Text('اختيار الأيقونة واللون'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: _parseColor(selectedColor),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: AppIconPickerDialog.iconWidgetForName(
                                selectedIcon,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_newCategoryController.text.isEmpty
                              ? 'اسم الفئة'
                              : _newCategoryController.text),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تم'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;

    final category = CategoryEntity(
      id: 'cat-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      icon: selectedIcon,
      color: selectedColor,
      scope: scope,
      allocationId: budgetScope == BudgetScope.withinBudget.value &&
              allocationId != 'unallocated'
          ? allocationId
          : null,
    );

    if (budgetScope == BudgetScope.withinBudget.value &&
        allocationId.isNotEmpty &&
        allocationId != 'unallocated') {
      await widget.cubit.updateAllocationCategories(
        allocationId: allocationId,
        categories: [...existing, category],
      );
    } else if (budgetScope == BudgetScope.withinBudget.value &&
        linkedWalletId.isNotEmpty) {
      await widget.cubit.updateLinkedWalletCategories(
        linkedWalletId: linkedWalletId,
        categories: [...existing, category],
      );
    } else {
      final current = widget.cubit.state.categories;
      await widget.cubit.setCategories([...current, category]);
    }

    if (!mounted) return;
    // تحديد الفئة الجديدة تلقائياً بعد إضافتها
    setState(() => _selectedCategoryId = category.id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Color _parseColor(String hex) {
    final value = int.parse(hex.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | value);
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRIVATE HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

/// قسم الفئات — دائماً ظاهر مع بوكس خضر
class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({
    required this.categories,
    required this.selectedId,
    required this.onSelectChange,
    required this.onAdd,
  });
  final List<CategoryEntity> categories;
  final String? selectedId;
  final void Function(String? id) onSelectChange;
  final VoidCallback onAdd;

  static const _accent = Color(0xFF165b47);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.35), width: 1.5),
        color: _accent.withValues(alpha: 0.03),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.label_outline_rounded, size: 16, color: _accent),
              const SizedBox(width: 6),
              const Text(
                'الفئة',
                style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_rounded, size: 13, color: _accent),
                      SizedBox(width: 3),
                      Text('فئة جديدة',
                          style: TextStyle(
                              color: _accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (categories.isEmpty)
            Center(
              child: Text(
                'لا توجد فئات — اضغط + لإضافة فئة',
                style: TextStyle(
                    fontSize: 12,
                    color: _accent.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((c) {
                final isSelected = selectedId == c.id;
                final color = _parseHex(c.color);
                return GestureDetector(
                  onTap: () => onSelectChange(isSelected ? null : c.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color
                          : color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? color
                            : color.withValues(alpha: 0.25),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIconPickerDialog.iconWidgetForName(
                          c.icon,
                          color: isSelected ? Colors.white : color,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : color,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  static Color _parseHex(String hex) {
    final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x165b47;
    return Color(0xFF000000 | v);
  }
}

/// Large amount input at the top
class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          Text(
            'المبلغ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextField(
            controller: controller,
            autofocus: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: '0.00',
              hintStyle: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Color(0xFFCCCCCC),
              ),
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic tappable row card (wallet, allocation)
class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF2F6F5E)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date (2/3) + Time (1/3) row
class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.date,
    required this.time,
    required this.onDateTap,
    required this.onTimeTap,
  });
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onDateTap;
  final VoidCallback onTimeTap;

  static const _accent = Color(0xFF2F6F5E);

  String get _dateLabel {
    const months = ['يناير','فبراير','مارس','أبريل','مايو','يونيو',
                    'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'];
    return '${date.day} ${months[date.month - 1]}';
  }

  String get _timeLabel {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'ص' : 'م';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = Border.all(
      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
    );

    Widget pill({
      required IconData icon,
      required String label,
      required String value,
      required VoidCallback onTap,
      int flex = 1,
    }) {
      return Expanded(
        flex: flex,
        child: Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: border,
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 17, color: _accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        pill(
          icon: Icons.calendar_today_rounded,
          label: 'التاريخ',
          value: _dateLabel,
          onTap: onDateTap,
          flex: 1,
        ),
        const SizedBox(width: 8),
        pill(
          icon: Icons.schedule_rounded,
          label: 'الوقت',
          value: _timeLabel,
          onTap: onTimeTap,
          flex: 1,
        ),
      ],
    );
  }
}

/// Tappable container for allocation options in the bottom sheet
class _AllocationOption extends StatelessWidget {
  const _AllocationOption({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? const Color(0xFF1E7F5C).withValues(alpha: 0.07)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1E7F5C).withValues(alpha: 0.4)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Row inside the allocation option (icon + name + progress bar)
class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.progressLabel,
    required this.ratio,
    required this.isSelected,
  });
  final IconData icon;
  final Color iconColor;
  final String name;
  final String progressLabel;
  final double ratio;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF1E7F5C), size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(progressLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  backgroundColor: iconColor.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Section label divider in the allocation sheet
class _SheetSectionLabel extends StatelessWidget {
  const _SheetSectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
      ],
    );
  }
}
