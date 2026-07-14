import 'package:flutter/material.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../money_distribution/domain/services/distribution_engine.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/recurring_schedule_engine.dart';
import '../widgets/recurring_income_post_dialog.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    required this.cubit,
    this.initialTransaction,
    this.recurringMode = false,
    this.recurringType,
    this.initialRecurring,
    this.subscriptionOnlyMode = false,
    this.debtOnlyMode = false,
    this.initialExpensePlanKind,
    this.allowDelete = false,
    this.onSaved,
    this.onDeleted,
  });

  final AppCubit cubit;
  final TransactionEntity? initialTransaction;
  final bool recurringMode;
  final String? recurringType;
  final RecurringTransactionEntity? initialRecurring;
  final bool subscriptionOnlyMode;
  final bool debtOnlyMode;
  final String? initialExpensePlanKind;
  final bool allowDelete;
  // Called instead of cubit + pop when set (returnOnSave pattern).
  final void Function(RecurringTransactionEntity recurring)? onSaved;
  // Called instead of cubit + pop on delete when set.
  final void Function()? onDeleted;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // ── Basic transaction state ────────────────────────────────────────────────
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
  bool _isSaving = false;
  String? _selectedCategoryId;
  String? _selectedIncomeCategoryId;

  // ── Recurring-specific state ───────────────────────────────────────────────
  String _recurrencePattern = RecurrencePattern.monthly.value;
  int _recurrenceWeekday = DateTime.now().weekday; // legacy single weekday
  String _recurringIconName = 'category';
  String _recurringIconColor = '#165b47';
  String _executionType = AutomationType.confirm.value;
  String _expensePlanKind = 'normal';
  bool _isDebtOrSubscription = false;
  bool _isVariableIncome = false;
  DateTime _firstPaymentDate = DateTime.now().add(const Duration(days: 1));
  int _reminderLeadDays = 0;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _selectedWeekdays = <int>{};
  final Set<String> _selectedCategoryIds =
      <String>{}; // multi-select for recurring
  int _monthlyDay = 1;
  int _yearlyMonth = 1;
  int _yearlyDay = 1;
  final _debtPrincipalController = TextEditingController();
  final _installmentCountController = TextEditingController();
  final _downPaymentController = TextEditingController();

  // ── computed helpers for recurring ────────────────────────────────────────

  bool get _isWeekPattern =>
      _recurrencePattern == RecurrencePattern.weekly.value ||
      _recurrencePattern == RecurrencePattern.biweekly.value ||
      _recurrencePattern == RecurrencePattern.every3Weeks.value;

  bool get _isMonthPattern =>
      _recurrencePattern == RecurrencePattern.monthly.value ||
      _recurrencePattern == RecurrencePattern.every2Months.value ||
      _recurrencePattern == RecurrencePattern.every3Months.value ||
      _recurrencePattern == RecurrencePattern.every6Months.value;

  bool get _isExpenseInstallment =>
      _expensePlanKind == ExpensePlanKind.installment.value;

  bool get _isExpenseSubscription =>
      _expensePlanKind == ExpensePlanKind.subscription.value;

  bool get _showAmount =>
      !(_type == TransactionType.income.value && _isVariableIncome);

  bool get _showRecurrenceDetails =>
      !(_type == TransactionType.income.value && _isVariableIncome);

  double get _totalPrincipal =>
      double.tryParse(_debtPrincipalController.text.trim()) ?? 0;

  int get _installmentCount =>
      int.tryParse(_installmentCountController.text.trim()) ?? 0;

  double get _downPayment =>
      double.tryParse(_downPaymentController.text.trim()) ?? 0;

  double get _calculatedInstallment {
    final n = _installmentCount;
    if (n <= 0) return 0;
    final net = _totalPrincipal - _downPayment;
    if (net <= 0) return 0;
    return net / n;
  }

  double get _enteredInstallment =>
      double.tryParse(_amountController.text.trim()) ?? 0;

  double get _ribaAmount {
    final calc = _calculatedInstallment;
    if (calc <= 0) return 0;
    final diff = _enteredInstallment - calc;
    return diff > 0 ? diff : 0;
  }

  // ── withinBudget for recurring (expense / income) ──────────────────────────
  bool get _withinBudgetExpense =>
      _budgetScope == BudgetScope.withinBudget.value;

  bool get _withinBudgetIncome =>
      _incomeBudgetScope == BudgetScope.withinBudget.value;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_refreshAmountPreview);
    _debtPrincipalController.addListener(_refreshAmountPreview);
    _installmentCountController.addListener(_refreshAmountPreview);
    _downPaymentController.addListener(_refreshAmountPreview);
    final state = widget.cubit.state;
    _walletId = state.wallets.isNotEmpty ? state.wallets.first.id : '';
    _incomeSourceId = 'wallet-only';
    _incomeJarId = '';

    if (widget.recurringMode) {
      _type = widget.recurringType ?? TransactionType.expense.value;
      if (widget.subscriptionOnlyMode) {
        _type = TransactionType.expense.value;
        _expensePlanKind =
            widget.initialExpensePlanKind ?? ExpensePlanKind.subscription.value;
        _isDebtOrSubscription = true;
      }
      if (widget.debtOnlyMode) {
        _type = TransactionType.expense.value;
        _expensePlanKind =
            widget.initialExpensePlanKind ?? ExpensePlanKind.installment.value;
        _isDebtOrSubscription = true;
      }

      final r = widget.initialRecurring;
      if (r != null) {
        _type = r.type;
        _walletId = r.walletId;
        _amountController.text =
            r.amount <= 0 ? '' : r.amount.toStringAsFixed(2);
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
          _budgetScope = BudgetScope.withinBudget.value;
        } else if (r.targetJarId != null &&
            r.type == TransactionType.expense.value) {
          _budgetTargetId = 'jar:${r.targetJarId!}';
          _budgetScope = BudgetScope.withinBudget.value;
        }
        _date = DateTime(_date.year, _date.month, r.dayOfMonth.clamp(1, 28));

        // New recurring fields
        _executionType = r.executionType;
        _expensePlanKind =
            r.expensePlanKind ?? widget.initialExpensePlanKind ?? 'normal';
        _isDebtOrSubscription = r.isDebtOrSubscription;
        _isVariableIncome = r.isVariableIncome;
        _monthlyDay = (r.dayOfMonth).clamp(1, 28);
        _yearlyDay = (r.dayOfMonth).clamp(1, 28);
        _yearlyMonth = (r.monthOfYear ?? DateTime.now().month).clamp(1, 12);
        _reminderLeadDays = r.reminderLeadDays ?? 0;
        _selectedCategoryIds.addAll(r.categoryIds);
        _selectedWeekdays.addAll(
          r.weekdays.isNotEmpty
              ? r.weekdays
              : r.weekday != null
                  ? <int>{r.weekday!}
                  : <int>{DateTime.now().weekday},
        );
        _selectedTime = _parseStoredTime(r.scheduledTime);

        final anchor =
            r.anchorDate != null ? DateTime.tryParse(r.anchorDate!) : null;
        if (anchor != null) {
          _firstPaymentDate = anchor;
        }

        final principal = r.debtPrincipalTotal;
        _debtPrincipalController.text = principal != null && principal > 0
            ? principal.toStringAsFixed(2)
            : '';
        _installmentCountController.text =
            r.installmentCount != null && r.installmentCount! > 0
                ? r.installmentCount.toString()
                : '';
        final downPay = r.installmentDownPayment;
        _downPaymentController.text =
            downPay != null && downPay > 0 ? downPay.toStringAsFixed(2) : '';
      } else {
        // New recurring — default icon by type
        _recurringIconName =
            _type == TransactionType.income.value ? 'cash' : 'category';
        _recurringIconColor =
            _type == TransactionType.income.value ? '#0f9d7a' : '#c65d2e';
        _selectedWeekdays.add(DateTime.now().weekday);
        _monthlyDay = DateTime.now().day.clamp(1, 28);
      }

      if (_type == TransactionType.income.value && _isVariableIncome) {
        _executionType = 'manual';
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
      if (_incomeJarId.isEmpty && t.toWalletId != null) {
        _incomeJarId = t.toWalletId!;
      }
      if (t.type == TransactionType.income.value) {
        _selectedIncomeCategoryId = t.categoryId;
      } else {
        _selectedCategoryId = t.categoryId;
      }
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_refreshAmountPreview);
    _debtPrincipalController.removeListener(_refreshAmountPreview);
    _installmentCountController.removeListener(_refreshAmountPreview);
    _downPaymentController.removeListener(_refreshAmountPreview);
    _amountController.dispose();
    _notesController.dispose();
    _recurringNameController.dispose();
    _newCategoryController.dispose();
    _debtPrincipalController.dispose();
    _installmentCountController.dispose();
    _downPaymentController.dispose();
    super.dispose();
  }

  void _refreshAmountPreview() {
    if (mounted) setState(() {});
  }

  double _walletReservedAmount(String walletId) {
    final reserved = DistributionEngine.totalFromWallet(
      widget.cubit.state.moneyDistributions,
      walletId,
    );
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
    if (_isSaving || _walletId.isEmpty) return false;

    if (widget.recurringMode) {
      if (_isExpenseInstallment) {
        return _enteredInstallment > 0;
      }
      if (_showAmount) {
        final amt = double.tryParse(_amountController.text.trim()) ?? 0;
        if (amt < 0) return false;
        if (amt == 0 &&
            !_isExpenseSubscription &&
            !widget.subscriptionOnlyMode) {
          return false;
        }
      }
      if (_showRecurrenceDetails &&
          _isWeekPattern &&
          _selectedWeekdays.isEmpty) {
        return false;
      }
      if (_type == TransactionType.expense.value &&
          _withinBudgetExpense &&
          !_isDebtOrSubscription &&
          _budgetTargetId.isEmpty) {
        return false;
      }
      return true;
    }

    // Normal transaction mode
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) return false;
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
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SMART WALLET DEFAULT
  // ─────────────────────────────────────────────────────────────────────────

  void _autoSetWalletFromAllocation(String budgetTargetId) {
    final s = widget.cubit.state;
    final budget = s.budgetSetup;

    String? incomeSourceId;
    if (budgetTargetId.startsWith('alloc:')) {
      final allocId = budgetTargetId.replaceFirst('alloc:', '');
      final alloc = budget.allocations.where((a) => a.id == allocId).toList();
      if (alloc.isEmpty || alloc.first.funding.isEmpty) return;
      incomeSourceId = alloc.first.funding.first.incomeSourceId;
    } else if (budgetTargetId.startsWith('jar:')) {
      final jarId = budgetTargetId.replaceFirst('jar:', '');
      final jar = budget.linkedWallets.where((j) => j.id == jarId).toList();
      if (jar.isEmpty || jar.first.funding.isEmpty) return;
      incomeSourceId = jar.first.funding.first.incomeSourceId;
    }
    if (incomeSourceId == null) return;
    final src =
        budget.incomeSources.where((s) => s.id == incomeSourceId).toList();
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
    final jarCategories = selectedJar.isEmpty
        ? <CategoryEntity>[]
        : selectedJar.first.categories
            .where((c) => c.scope == 'expense')
            .toList();
    final incomeJarCategories = selectedIncomeJar.isEmpty
        ? <CategoryEntity>[]
        : selectedIncomeJar.first.categories
            .where((c) => c.scope == 'income')
            .toList();
    final generalExpenseCategories = state.categories
        .where((c) => c.scope == 'expense' && c.incomeSourceId == null)
        .toList();
    final visibleIncomeCategories = _incomeJarId.isNotEmpty
        ? incomeJarCategories
        : state.categories.where((c) => c.scope == 'income').toList();
    final visibleCategories = _budgetScope == BudgetScope.withinBudget.value &&
            _budgetTargetId.startsWith('alloc:')
        ? allocationCategories
        : (_budgetScope == BudgetScope.withinBudget.value &&
                _budgetTargetId.startsWith('jar:'))
            ? jarCategories
            : generalExpenseCategories;

    // ── recurring: visible categories for multi-select ──
    final recurringVisibleCategories = widget.recurringMode
        ? (_type == TransactionType.expense.value
            ? visibleCategories
            : visibleIncomeCategories)
        : <CategoryEntity>[];

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
                    // ── Amount ──
                    if (!widget.recurringMode || _showAmount) ...[
                      _AmountField(controller: _amountController),
                      const SizedBox(height: 10),
                    ],

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

                    // ── EXPENSE: categories ──
                    if (_type == TransactionType.expense.value) ...[
                      if (widget.recurringMode)
                        _buildRecurringCategories(
                          categories: recurringVisibleCategories,
                          budget: budget,
                        )
                      else
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

                    // ── INCOME fields ──
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
                      if (widget.recurringMode)
                        _buildRecurringCategories(
                          categories: recurringVisibleCategories,
                          budget: budget,
                        )
                      else
                        _CategoriesSection(
                          categories: visibleIncomeCategories,
                          selectedId: _selectedIncomeCategoryId,
                          onSelectChange: (id) =>
                              setState(() => _selectedIncomeCategoryId = id),
                          onAdd: () => _openAddCategoryDialog(
                            budgetScope: _incomeJarId.isNotEmpty
                                ? BudgetScope.withinBudget.value
                                : BudgetScope.outsideBudget.value,
                            allocationId: '',
                            linkedWalletId: _incomeJarId,
                            existing: visibleIncomeCategories,
                            scope: 'income',
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 10),

                    // ── Date + Time row (hidden in recurring mode) ──
                    if (!widget.recurringMode) ...[
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
                    ],

                    // ── Notes ──
                    TextField(
                      controller: _notesController,
                      maxLines: 1,
                      decoration: InputDecoration(
                        labelText: 'ملاحظات',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ═══════════════════════════════════════════════════════
                    // RECURRING SETTINGS SECTION
                    // ═══════════════════════════════════════════════════════
                    if (widget.recurringMode) ...[
                      _scheduleSectionHeader(),
                      const SizedBox(height: 14),

                      // ── Name ──
                      TextField(
                        controller: _recurringNameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم المعاملة المتكررة',
                          prefixIcon: Icon(Icons.label_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Icon / Color ──
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
                      const SizedBox(height: 12),

                      // ── Variable income toggle ──
                      if (_type == TransactionType.income.value &&
                          _withinBudgetIncome) ...[
                        _surfaceSection(
                          child: SwitchListTile.adaptive(
                            value: _isVariableIncome,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('دخل متغير'),
                            subtitle: const Text(
                              'الدخل المتغير يكون يدويًا ولا يحتاج مبلغ أو توقيت ثابت',
                            ),
                            onChanged: (value) {
                              setState(() {
                                _isVariableIncome = value;
                                if (value) {
                                  _executionType = 'manual';
                                  _amountController.clear();
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Recurrence pattern + details ──
                      if (_showRecurrenceDetails) ...[
                        DropdownButtonFormField<String>(
                          value: _recurrencePattern,
                          decoration: const InputDecoration(
                            labelText: 'نوع التكرار',
                            prefixIcon: Icon(Icons.repeat_rounded),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: RecurrencePattern.daily.value,
                                child: const Text('يومي')),
                            DropdownMenuItem(
                                value: RecurrencePattern.weekly.value,
                                child: const Text('أسبوعي')),
                            DropdownMenuItem(
                                value: RecurrencePattern.biweekly.value,
                                child: const Text('كل أسبوعين')),
                            DropdownMenuItem(
                                value: RecurrencePattern.every3Weeks.value,
                                child: const Text('كل 3 أسابيع')),
                            DropdownMenuItem(
                                value: RecurrencePattern.monthly.value,
                                child: const Text('شهري')),
                            DropdownMenuItem(
                                value: RecurrencePattern.every2Months.value,
                                child: const Text('كل شهرين')),
                            DropdownMenuItem(
                                value: RecurrencePattern.every3Months.value,
                                child: const Text('كل 3 شهور')),
                            DropdownMenuItem(
                                value: RecurrencePattern.every6Months.value,
                                child: const Text('كل 6 شهور')),
                            DropdownMenuItem(
                                value: RecurrencePattern.yearly.value,
                                child: const Text('سنوي')),
                          ],
                          onChanged: (v) {
                            if (v != null)
                              setState(() => _recurrencePattern = v);
                          },
                        ),
                        const SizedBox(height: 12),
                        _recurrenceDetails(),
                        const SizedBox(height: 12),

                        // ── Execution type ──
                        DropdownButtonFormField<String>(
                          value: _executionType,
                          decoration: const InputDecoration(
                            labelText: 'طريقة التنفيذ',
                            prefixIcon: Icon(Icons.bolt_rounded),
                          ),
                          items: [
                            DropdownMenuItem(
                                value: AutomationType.auto.value,
                                child: const Text('تلقائي')),
                            DropdownMenuItem(
                                value: AutomationType.confirm.value,
                                child: const Text('يحتاج تأكيد')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _executionType = v);
                          },
                        ),
                        if (_executionType == AutomationType.confirm.value) ...[
                          const SizedBox(height: 12),
                          _reminderDropdown(),
                        ],
                      ] else ...[
                        // variable income info tile
                        _surfaceSection(
                          child: const ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.info_outline_rounded),
                            title: Text('دخل متغير'),
                            subtitle: Text(
                              'سيتم تسجيله يدويًا فقط بدون تاريخ أو تكرار ثابت',
                            ),
                          ),
                        ),
                      ],

                      // ── Installment fields ──
                      if (_isExpenseInstallment) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: _debtPrincipalController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'المبلغ الإجمالي',
                            helperText:
                                'السعر الأصلي للمنتج أو قيمة الدين الكامل',
                            prefixIcon: Icon(Icons.account_balance_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _installmentCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عدد الأقساط',
                            prefixIcon:
                                Icon(Icons.format_list_numbered_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _downPaymentController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'المقدم',
                            prefixIcon: Icon(Icons.monetization_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Installment amount field
                        Builder(builder: (ctx) {
                          final calcInstallment = _calculatedInstallment;
                          final hasCalc = calcInstallment > 0;
                          final riba = _ribaAmount;
                          final hasRiba = riba > 0.005;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'القسط الشهري',
                                  helperText: hasCalc
                                      ? 'المحسوب: ${calcInstallment.toStringAsFixed(2)}'
                                      : 'أدخل المبلغ الإجمالي والعدد أولاً',
                                  prefixIcon:
                                      const Icon(Icons.payments_rounded),
                                  suffixIcon: hasCalc
                                      ? IconButton(
                                          icon: const Icon(
                                              Icons.calculate_rounded,
                                              size: 18),
                                          tooltip: 'تطبيق المبلغ المحسوب',
                                          onPressed: () {
                                            _amountController.text =
                                                calcInstallment
                                                    .toStringAsFixed(2);
                                            setState(() {});
                                          },
                                        )
                                      : null,
                                ),
                              ),
                              if (hasRiba) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC65D2E)
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFC65D2E)
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning_amber_rounded,
                                          color: Color(0xFFC65D2E), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'ربا / فائدة زيادة: ${riba.toStringAsFixed(2)} لكل قسط'
                                          ' (${(riba * _installmentCount).toStringAsFixed(2)} إجمالي)',
                                          style: const TextStyle(
                                            color: Color(0xFFC65D2E),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        }),
                        const SizedBox(height: 12),
                        // First payment date
                        _surfaceSection(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.event_rounded),
                            title: const Text('تاريخ أول دفعة'),
                            subtitle: Text(
                              '${_firstPaymentDate.day}/${_firstPaymentDate.month}/${_firstPaymentDate.year}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            trailing: const Icon(Icons.chevron_left_rounded),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _firstPaymentDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2040),
                              );
                              if (picked != null) {
                                setState(() => _firstPaymentDate = picked);
                              }
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),
                    ], // end recurring settings section

                    // ── Delete buttons ──
                    if (widget.recurringMode &&
                        widget.initialRecurring != null &&
                        widget.allowDelete)
                      TextButton.icon(
                        onPressed: _deleteRecurring,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('حذف المعاملة'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
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
                        if (_isSaving || !_canSubmit) return;
                        _isSaving = true;
                        setState(() {});
                        try {
                          if (widget.recurringMode) {
                            await _submitRecurring(amount, budget);
                          } else {
                            await _submitNormal(amount, budget, wallets);
                          }
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
                        _isSaving
                            ? 'جارٍ الحفظ...'
                            : widget.recurringMode
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
  // SUBMIT: NORMAL TRANSACTION
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submitNormal(
    double amount,
    BudgetSetupEntity budget,
    List<WalletEntity> wallets,
  ) async {
    if (amount <= 0) {
      _showValidationError('أدخل مبلغًا صحيحًا أكبر من صفر.');
      return;
    }
    if (_walletId.isEmpty) {
      _showValidationError('اختر محفظة أو اختر "بدون محفظة" أولًا.');
      return;
    }
    if (_type == TransactionType.expense.value &&
        _budgetScope == BudgetScope.withinBudget.value &&
        _budgetTargetId.isEmpty) {
      _showValidationError('اختر مخصصًا أو حصالة للمعاملة داخل الميزانية.');
      return;
    }
    if (_budgetTargetId == 'unallocated' && amount > budget.unallocatedAmount) {
      _showValidationError('المبلغ أكبر من المتاح في غير المخصص.');
      return;
    }
    if (_type == TransactionType.income.value &&
        _incomeBudgetScope == BudgetScope.withinBudget.value &&
        _incomeSourceId == 'wallet-only' &&
        _incomeJarId.isEmpty) {
      _showValidationError('اختر مصدر دخل أو حصالة للدخل داخل الميزانية.');
      return;
    }

    if (_type == TransactionType.expense.value && _walletId != 'no-wallet') {
      final currentWallet =
          wallets.where((wallet) => wallet.id == _walletId).toList();
      if (currentWallet.isNotEmpty) {
        final approved = await _confirmExpenseImpact(
          wallet: currentWallet.first,
          amount: amount,
        );
        if (!approved) return;
      }
    }

    final selectedJarId = _budgetTargetId.startsWith('jar:')
        ? _budgetTargetId.replaceFirst('jar:', '')
        : null;

    if (widget.initialTransaction != null) {
      await widget.cubit.deleteTransaction(widget.initialTransaction!.id);
    }
    await widget.cubit.addTransaction(
      walletId: _walletId == 'no-wallet' ? null : _walletId,
      toWalletId: _type == TransactionType.income.value &&
              _incomeBudgetScope == BudgetScope.withinBudget.value &&
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
      allocationId: _type == TransactionType.expense.value &&
              _budgetScope == BudgetScope.withinBudget.value &&
              _budgetTargetId.startsWith('alloc:')
          ? _budgetTargetId.replaceFirst('alloc:', '')
          : null,
      budgetScope: _type == TransactionType.expense.value
          ? _budgetScope
          : _type == TransactionType.income.value
              ? _incomeBudgetScope
              : null,
      incomeSourceId: _type == TransactionType.income.value &&
              _incomeSourceId != 'wallet-only'
          ? _incomeSourceId
          : null,
      transferType: widget.initialTransaction?.transferType ==
                  TransferType.jarFundingPhysical.value &&
              _type == TransactionType.expense.value
          ? TransferType.jarFundingPhysical.value
          : _type == TransactionType.income.value && _incomeJarId.isNotEmpty
              ? TransferType.depositWithJarLabel.value
              : null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      categoryId: _type == TransactionType.income.value
          ? _selectedIncomeCategoryId
          : _selectedCategoryId,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(_type == TransactionType.income.value
              ? 'تم تسجيل الدخل.'
              : 'تم تسجيل المعاملة.')),
    );
    Navigator.of(context).pop();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUBMIT: RECURRING TRANSACTION
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _submitRecurring(
    double amount,
    BudgetSetupEntity budget,
  ) async {
    if (_walletId.isEmpty) {
      _showValidationError('اختر محفظة أو اختر "بدون محفظة" أولًا.');
      return;
    }

    final selectedJarId = _budgetTargetId.startsWith('jar:')
        ? _budgetTargetId.replaceFirst('jar:', '')
        : null;
    final selectedAllocId = _budgetTargetId.startsWith('alloc:')
        ? _budgetTargetId.replaceFirst('alloc:', '')
        : null;

    final effectivePattern = _isExpenseInstallment
        ? RecurrencePattern.monthly.value
        : (_type == TransactionType.income.value && _isVariableIncome
            ? RecurrencePattern.manualVariable.value
            : _recurrencePattern);

    final effectiveExecutionType =
        _type == TransactionType.income.value && _isVariableIncome
            ? 'manual'
            : _executionType;

    final effectiveDayOfMonth = _isExpenseInstallment
        ? _firstPaymentDate.day.clamp(1, 28)
        : (_recurrencePattern == RecurrencePattern.yearly.value
            ? _yearlyDay
            : (_isMonthPattern ? _monthlyDay : 1));

    final effectiveAnchorDate = _isExpenseInstallment
        ? _firstPaymentDate.toIso8601String()
        : widget.initialRecurring?.anchorDate;

    final derivedName = _recurringNameController.text.trim().isEmpty
        ? _derivedName()
        : _recurringNameController.text.trim();

    final recurringDraft = RecurringTransactionEntity(
      id: widget.initialRecurring?.id ??
          'rec-${DateTime.now().microsecondsSinceEpoch}',
      name: derivedName,
      type: _type,
      amount: _showAmount ? amount : 0,
      dayOfMonth: effectiveDayOfMonth,
      executionType: effectiveExecutionType,
      walletId: _walletId == 'no-wallet' ? '' : _walletId,
      budgetScope: _isExpenseInstallment
          ? BudgetScope.withinBudget.value
          : (_type == TransactionType.expense.value
              ? _budgetScope
              : _incomeBudgetScope),
      recurrencePattern: effectivePattern,
      icon: _recurringIconName,
      iconColor: _recurringIconColor,
      weekday: _selectedWeekdays.isEmpty ? null : _selectedWeekdays.first,
      weekdays: _selectedWeekdays.toList()..sort(),
      monthOfYear: _recurrencePattern == RecurrencePattern.yearly.value
          ? _yearlyMonth
          : null,
      anchorDate: effectiveAnchorDate,
      scheduledTime: !_isExpenseInstallment && _showRecurrenceDetails
          ? _formatTime(_selectedTime)
          : null,
      reminderLeadDays: effectiveExecutionType == AutomationType.confirm.value
          ? _reminderLeadDays
          : null,
      allocationId: _type == TransactionType.expense.value &&
              _withinBudgetExpense &&
              !_isDebtOrSubscription &&
              selectedAllocId != null
          ? selectedAllocId
          : null,
      targetJarId:
          _type == TransactionType.income.value && _incomeJarId.isNotEmpty
              ? _incomeJarId
              : (_type == TransactionType.expense.value &&
                      !_isDebtOrSubscription &&
                      selectedJarId != null
                  ? selectedJarId
                  : null),
      incomeSourceId: _type == TransactionType.income.value &&
              _incomeSourceId != 'wallet-only'
          ? _incomeSourceId
          : null,
      categoryIds: _selectedCategoryIds.toList(),
      isVariableIncome: _isVariableIncome,
      isDebtOrSubscription: _isExpenseInstallment ||
          (_type == TransactionType.expense.value && _isDebtOrSubscription),
      expensePlanKind:
          _type == TransactionType.expense.value ? _expensePlanKind : null,
      debtPrincipalTotal: _isExpenseInstallment
          ? double.tryParse(_debtPrincipalController.text.trim())
          : null,
      installmentCount: _isExpenseInstallment
          ? int.tryParse(_installmentCountController.text.trim())
          : null,
      installmentDownPayment: _isExpenseInstallment
          ? double.tryParse(_downPaymentController.text.trim())
          : null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      isActive: widget.initialRecurring?.isActive ?? true,
    );

    // Apply defaultAnchorDate if no anchor set
    final recurring = effectiveAnchorDate != null
        ? recurringDraft
        : recurringDraft.copyWith(
            anchorDate:
                RecurringScheduleEngine.defaultAnchorDate(recurringDraft)
                    .toIso8601String(),
          );

    // onSaved callback (returnOnSave pattern from composer wrapper)
    if (widget.onSaved != null) {
      widget.onSaved!(recurring);
      return;
    }

    // Normal flow: persist via cubit
    if (widget.initialRecurring == null) {
      await widget.cubit.addRecurringTransaction(
        id: recurring.id,
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
        allocationId: recurring.allocationId,
        targetJarId: recurring.targetJarId,
        incomeSourceId: recurring.incomeSourceId,
        categoryIds: recurring.categoryIds,
        isVariableIncome: recurring.isVariableIncome,
        isDebtOrSubscription: recurring.isDebtOrSubscription,
        expensePlanKind: recurring.expensePlanKind,
        debtPrincipalTotal: recurring.debtPrincipalTotal,
        installmentCount: recurring.installmentCount,
        installmentDownPayment: recurring.installmentDownPayment,
        notes: recurring.notes,
      );
      if (recurring.type == TransactionType.income.value &&
          (recurring.incomeSourceId ?? '').isEmpty) {
        await _maybePromptRetroactiveIncomePost(recurring);
      }
    } else {
      await widget.cubit.updateRecurringTransaction(
        widget.initialRecurring!.copyWith(
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
          allocationId: recurring.allocationId,
          targetJarId: recurring.targetJarId,
          incomeSourceId: recurring.incomeSourceId,
          categoryIds: recurring.categoryIds,
          isVariableIncome: recurring.isVariableIncome,
          isDebtOrSubscription: recurring.isDebtOrSubscription,
          expensePlanKind: recurring.expensePlanKind,
          debtPrincipalTotal: recurring.debtPrincipalTotal,
          installmentCount: recurring.installmentCount,
          installmentDownPayment: recurring.installmentDownPayment,
          notes: recurring.notes,
        ),
      );
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ المعاملة المتكررة.')),
    );
    Navigator.of(context).pop();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE RECURRING
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _deleteRecurring() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المعاملة'),
        content:
            const Text('سيتم حذف هذه المعاملة المتكررة. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    if (widget.onDeleted != null) {
      widget.onDeleted!();
      return;
    }

    if (widget.initialRecurring != null) {
      await widget.cubit
          .deleteRecurringTransaction(widget.initialRecurring!.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TYPE TOGGLE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _typeSegmentedToggle(ThemeData theme) {
    final activeOnRight = _type == TransactionType.income.value;
    // In subscription/debt-only modes the type is locked
    final locked = widget.subscriptionOnlyMode || widget.debtOnlyMode;
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
                  onTap: locked
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
                  onTap: locked
                      ? null
                      : () => setState(() {
                            _type = TransactionType.income.value;
                            _budgetTargetId = '';
                            _selectedCategoryId = null;
                            _isDebtOrSubscription = false;
                            _expensePlanKind = 'normal';
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
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.category_outlined,
                              color: Color(0xFF2F6F5E),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'غير المخصص',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            budget.unallocatedAmount.toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_budgetTargetId == 'unallocated') ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF1E7F5C),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Allocations
                  ...allocations.map((a) {
                    final id = 'alloc:${a.id}';
                    final remaining = a.balance;
                    final planned = a.funding
                        .fold<double>(0, (s, f) => s + f.plannedAmount);
                    final ratio = planned <= 0
                        ? 0.0
                        : (remaining / planned).clamp(0.0, 1.0);
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
                          icon: AppIconPickerDialog.iconDataForName(a.icon),
                          iconColor: _parseColor(a.iconColor),
                          name: a.name,
                          progressLabel: '${planned.toStringAsFixed(2)} مخطط',
                          ratio: ratio,
                          isSelected: _budgetTargetId == id,
                        ),
                      ),
                    );
                  }),

                  // Jars section
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
  // ignore: unused_element
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
    setState(() {
      if (scope == 'income') {
        _selectedIncomeCategoryId = category.id;
      } else {
        _selectedCategoryId = category.id;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECURRING SECTION HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _scheduleSectionHeader() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.repeat_rounded,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'الإعدادات المتكررة',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _recurrenceDetails() {
    if (_recurrencePattern == RecurrencePattern.daily.value) {
      return _timeTile();
    }
    if (_isWeekPattern) {
      return Column(
        children: [
          _weekdayPicker(),
          const SizedBox(height: 12),
          _timeTile(),
        ],
      );
    }
    if (_isMonthPattern) {
      return Column(
        children: [
          _DayPickerTile(
            label: 'اليوم الشهري',
            selectedDay: _monthlyDay,
            onDaySelected: (day) => setState(() => _monthlyDay = day),
          ),
          const SizedBox(height: 12),
          _timeTile(),
        ],
      );
    }
    if (_recurrencePattern == RecurrencePattern.yearly.value) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _yearlyMonth,
                  decoration: const InputDecoration(
                    labelText: 'الشهر',
                    prefixIcon: Icon(Icons.date_range_rounded),
                  ),
                  items: List.generate(
                    12,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(_monthLabel(index + 1)),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) setState(() => _yearlyMonth = value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DayPickerTile(
                  label: 'اليوم',
                  selectedDay: _yearlyDay,
                  onDaySelected: (day) => setState(() => _yearlyDay = day),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _timeTile(),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _weekdayPicker() {
    return _surfaceSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أيام التكرار',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final weekday = index + 1;
              return FilterChip(
                selected: _selectedWeekdays.contains(weekday),
                label: Text(_weekdayLabel(weekday)),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedWeekdays.add(weekday);
                    } else {
                      _selectedWeekdays.remove(weekday);
                    }
                  });
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _timeTile() {
    final label = _formatTime(_selectedTime);
    return _surfaceSection(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_rounded),
        title: const Text('الوقت'),
        subtitle: Text(label),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () async {
          final picked = await showTimePicker(
              context: context, initialTime: _selectedTime);
          if (picked != null) setState(() => _selectedTime = picked);
        },
      ),
    );
  }

  Widget _reminderDropdown() {
    return DropdownButtonFormField<int>(
      value: _reminderLeadDays,
      decoration: const InputDecoration(
        labelText: 'وقت الإشعار',
        prefixIcon: Icon(Icons.notifications_active_rounded),
      ),
      items: (_recurrencePattern == RecurrencePattern.daily.value ||
              _isWeekPattern)
          ? const [
              DropdownMenuItem(value: 0, child: Text('في الوقت المحدد')),
              DropdownMenuItem(value: 1, child: Text('قبلها بساعة')),
              DropdownMenuItem(value: 2, child: Text('قبلها بساعتين')),
              DropdownMenuItem(value: 3, child: Text('قبلها بـ 3 ساعات')),
            ]
          : const [
              DropdownMenuItem(value: 0, child: Text('في نفس اليوم')),
              DropdownMenuItem(value: 1, child: Text('مبكر بيوم')),
              DropdownMenuItem(value: 2, child: Text('مبكر بيومين')),
              DropdownMenuItem(value: 3, child: Text('مبكر بـ 3 أيام')),
            ],
      onChanged: (value) {
        if (value != null) setState(() => _reminderLeadDays = value);
      },
    );
  }

  Widget _surfaceSection({required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: child,
    );
  }

  /// Multi-select category chips for recurring mode.
  Widget _buildRecurringCategories({
    required List<CategoryEntity> categories,
    required BudgetSetupEntity budget,
  }) {
    return _CategoriesSection(
      categories: categories,
      selectedId:
          _selectedCategoryIds.isEmpty ? null : _selectedCategoryIds.first,
      onSelectChange: (id) {
        setState(() {
          _selectedCategoryIds.clear();
          if (id != null) {
            _selectedCategoryIds.add(id);
          }
        });
      },
      onAdd: () => _openAddCategoryDialog(
        budgetScope: _type == TransactionType.expense.value
            ? _budgetScope
            : _incomeBudgetScope,
        allocationId: _budgetTargetId.startsWith('alloc:')
            ? _budgetTargetId.replaceFirst('alloc:', '')
            : '',
        linkedWalletId: _budgetTargetId.startsWith('jar:')
            ? _budgetTargetId.replaceFirst('jar:', '')
            : _incomeJarId,
        existing: categories,
        scope: _type == TransactionType.income.value ? 'income' : 'expense',
      ),
    );
  }

  String _derivedName() {
    final notes = _notesController.text.trim();
    if (notes.isNotEmpty) return notes;
    final state = widget.cubit.state;
    final budget = state.budgetSetup;
    final visible = _type == TransactionType.expense.value
        ? ((_budgetScope == BudgetScope.withinBudget.value &&
                _budgetTargetId.startsWith('alloc:'))
            ? budget.allocations
                .where((a) => _budgetTargetId == 'alloc:${a.id}')
                .expand((a) => a.categories)
                .toList()
            : state.categories.where((c) => c.scope == 'expense').toList())
        : state.categories.where((c) => c.scope == 'income').toList();
    for (final cat in visible) {
      if (_selectedCategoryIds.contains(cat.id)) return cat.name;
    }
    return _type == TransactionType.income.value ? 'دخل متكرر' : 'مصروف متكرر';
  }

  Future<void> _maybePromptRetroactiveIncomePost(
    RecurringTransactionEntity recurring,
  ) async {
    final due = RecurringScheduleEngine.unhandledDueOccurrence(
      recurring,
      DateTime.now(),
    );
    if (due == null || !mounted) return;

    final result = await RecurringIncomePostDialog.show(
      context,
      name: recurring.name,
      defaultAmount: recurring.amount,
      occurrence: due,
      allowVariableAmount: recurring.isVariableIncome,
      isRetroactivePrompt: true,
    );
    if (!mounted || result == null || !result.approved) return;

    final logMessage =
        'تم تسجيل دخل متكرر: ${recurring.name} (${result.amount.toStringAsFixed(2)})';
    await widget.cubit.recordRecurringIncomeOccurrence(
      recurring: recurring,
      amount: result.amount,
      occurrence: result.occurrenceDate,
      transactionNotes: recurring.name,
      logDetails: logMessage,
      titleOverride: logMessage,
    );
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

  String _formatTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  TimeOfDay _parseStoredTime(String? value) {
    if (value == null || !value.contains(':')) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = int.tryParse(parts.last) ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case 1:
        return 'الإثنين';
      case 2:
        return 'الثلاثاء';
      case 3:
        return 'الأربعاء';
      case 4:
        return 'الخميس';
      case 5:
        return 'الجمعة';
      case 6:
        return 'السبت';
      default:
        return 'الأحد';
    }
  }

  String _monthLabel(int month) {
    const labels = <String>[
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
    return labels[month - 1];
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            isSelected ? color : color.withValues(alpha: 0.25),
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
    const months = [
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
      'ديسمبر'
    ];
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
    final progressValue =
        ratio.isFinite ? ratio.clamp(0.0, 1.0).toDouble() : 0.0;
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
                  value: progressValue,
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

/// Day-of-month picker tile (used by recurring section)
class _DayPickerTile extends StatelessWidget {
  const _DayPickerTile({
    this.label,
    required this.selectedDay,
    required this.onDaySelected,
  });

  final String? label;
  final int selectedDay;
  final ValueChanged<int> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        GestureDetector(
          onTap: () => _showDaySheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 20, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'اليوم $selectedDay من كل شهر',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Icon(Icons.unfold_more_rounded,
                    size: 20, color: colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDaySheet(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                'اختر اليوم الشهري',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
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
