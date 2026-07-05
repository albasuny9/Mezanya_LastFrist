import 'package:mezanya_app/core/constants/transaction_types.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../data/subscription_service_presets.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/services/recurring_schedule_engine.dart';
import '../widgets/recurring_income_post_dialog.dart';

double _safeProgress(double value, double total) {
  if (total <= 0 || !value.isFinite || !total.isFinite) return 0;
  return (value / total).clamp(0.0, 1.0).toDouble();
}

class RecurringTransactionComposerResult {
  const RecurringTransactionComposerResult._({
    this.recurring,
    this.deleteRequested = false,
  });

  const RecurringTransactionComposerResult.saved(
    RecurringTransactionEntity recurring,
  ) : this._(recurring: recurring);

  const RecurringTransactionComposerResult.deleted()
      : this._(deleteRequested: true);

  final RecurringTransactionEntity? recurring;
  final bool deleteRequested;
}

class RecurringTransactionComposerScreen extends StatefulWidget {
  const RecurringTransactionComposerScreen({
    super.key,
    required this.cubit,
    required this.initialType,
    this.initialRecurring,
    this.initialWithinBudget = false,
    this.initialExpensePlanKind,
    this.returnOnSave = false,
    this.allowDelete = false,
    this.subscriptionOnlyMode = false,
    this.debtOnlyMode = false,
    this.initialSubscriptionPresetId,
    this.initialLentMode = false,
  });

  final AppCubit cubit;
  final String initialType;
  final RecurringTransactionEntity? initialRecurring;
  final bool initialWithinBudget;
  final String? initialExpensePlanKind;
  final bool returnOnSave;
  final bool allowDelete;
  final bool subscriptionOnlyMode;
  final bool debtOnlyMode;
  final String? initialSubscriptionPresetId;
  final bool initialLentMode;

  @override
  State<RecurringTransactionComposerScreen> createState() =>
      _RecurringTransactionComposerScreenState();
}

class _RecurringTransactionComposerScreenState
    extends State<RecurringTransactionComposerScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _debtPrincipalController = TextEditingController();
  final _installmentCountController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _notesController = TextEditingController();

  late String _type;
  late String _walletId;
  late bool _withinBudget;
  late String _executionType;
  late String _recurrencePattern;
  late String _iconName;
  late String _iconColor;
  late String _expensePlanKind;
  late DateTime _firstPaymentDate;

  bool _isVariableIncome = false;
  bool _isDebtOrSubscription = true;
  bool _isSaving = false;
  late bool _isLentMode;

  // ── حقول فورم السلفة ──────────────────────────────────────────────────────
  final _lentNameController = TextEditingController();
  final _lentAmountController = TextEditingController();
  final _lentNotesController = TextEditingController();
  String _lentWalletId = '';
  DateTime _lentReturnDate = DateTime.now().add(const Duration(days: 30));
  bool _lentIsMonthly = false;
  int _monthlyDay = 1;
  int _yearlyMonth = 1;
  int _yearlyDay = 1;
  int _reminderLeadDays = 0;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final Set<int> _selectedWeekdays = <int>{};
  final Set<String> _selectedCategoryIds = <String>{};
  String? _allocationId;
  String? _targetJarId;

  @override
  void initState() {
    super.initState();
    final state = widget.cubit.state;
    final recurring = widget.initialRecurring;
    _type = recurring?.type ?? widget.initialType;
    _walletId = recurring?.walletId ??
        (state.wallets.isNotEmpty ? state.wallets.first.id : '');
    _lentWalletId = state.wallets.isNotEmpty ? state.wallets.first.id : '';
    _withinBudget = recurring != null
        ? recurring.budgetScope == BudgetScope.withinBudget.value
        : widget.initialWithinBudget;
    _executionType = recurring?.executionType ?? AutomationType.confirm.value;
    _recurrencePattern =
        recurring?.recurrencePattern ?? RecurrencePattern.monthly.value;
    _iconName = recurring?.icon ??
        (_type == TransactionType.income.value ? 'cash' : 'category');
    _iconColor = recurring?.iconColor ??
        (_type == TransactionType.income.value ? '#0f9d7a' : '#c65d2e');
    _expensePlanKind =
        recurring?.expensePlanKind ?? widget.initialExpensePlanKind ?? 'normal';
    _nameController.text = recurring?.name ?? '';
    _amountController.text = recurring == null
        ? ''
        : recurring.amount <= 0
            ? ''
            : recurring.amount.toStringAsFixed(2);
    _notesController.text = recurring?.notes ?? '';
    final principal = recurring?.debtPrincipalTotal;
    _debtPrincipalController.text =
        principal != null && principal > 0 ? principal.toStringAsFixed(2) : '';
    _installmentCountController.text =
        recurring?.installmentCount != null && recurring!.installmentCount! > 0
            ? recurring.installmentCount.toString()
            : '';
    final downPay = recurring?.installmentDownPayment;
    _downPaymentController.text =
        downPay != null && downPay > 0 ? downPay.toStringAsFixed(2) : '';
    _isVariableIncome = recurring?.isVariableIncome ?? false;
    _isDebtOrSubscription = recurring?.isDebtOrSubscription ??
        (_expensePlanKind == ExpensePlanKind.installment.value ||
            _expensePlanKind == ExpensePlanKind.subscription.value);
    _monthlyDay = (recurring?.dayOfMonth ?? 1).clamp(1, 28);
    _yearlyDay = (recurring?.dayOfMonth ?? 1).clamp(1, 28);
    _yearlyMonth =
        (recurring?.monthOfYear ?? DateTime.now().month).clamp(1, 12);
    _reminderLeadDays = recurring?.reminderLeadDays ?? 0;
    _allocationId = recurring?.allocationId;
    _targetJarId = recurring?.targetJarId;
    if (_type == TransactionType.income.value) {
      _allocationId = null;
      if (_targetJarId != null &&
          recurring?.budgetScope == BudgetScope.withinBudget.value) {
        _withinBudget = false;
      }
    }
    _selectedCategoryIds.addAll(recurring?.categoryIds ?? const <String>[]);
    _selectedWeekdays.addAll(
      recurring?.weekdays.isNotEmpty == true
          ? recurring!.weekdays
          : recurring?.weekday != null
              ? <int>{recurring!.weekday!}
              : <int>{DateTime.now().weekday},
    );
    _selectedTime = _parseStoredTime(recurring?.scheduledTime);

    // تاريخ أول دفعة
    final anchor = recurring?.anchorDate != null
        ? DateTime.tryParse(recurring!.anchorDate!)
        : null;
    if (anchor != null) {
      _firstPaymentDate = anchor;
    } else {
      final now = DateTime.now();
      _firstPaymentDate = DateTime(now.year, now.month, now.day + 1);
    }

    _isLentMode = widget.initialLentMode;

    if (widget.subscriptionOnlyMode &&
        widget.initialSubscriptionPresetId != null) {
      final preset = subscriptionPresetById(widget.initialSubscriptionPresetId);
      if (preset != null) {
        _nameController.text = preset.name;
        _iconName = preset.iconName;
        _iconColor = preset.colorHex;
      }
    }

    if (_type == TransactionType.income.value &&
        _withinBudget &&
        _isVariableIncome) {
      _executionType = 'manual';
    }

    _nameController.addListener(_refreshFormState);
    _amountController.addListener(_refreshFormState);
    _debtPrincipalController.addListener(_refreshFormState);
    _installmentCountController.addListener(_refreshFormState);
    _downPaymentController.addListener(_refreshFormState);
  }

  @override
  void dispose() {
    _nameController.removeListener(_refreshFormState);
    _amountController.removeListener(_refreshFormState);
    _debtPrincipalController.removeListener(_refreshFormState);
    _installmentCountController.removeListener(_refreshFormState);
    _downPaymentController.removeListener(_refreshFormState);
    _nameController.dispose();
    _amountController.dispose();
    _debtPrincipalController.dispose();
    _installmentCountController.dispose();
    _downPaymentController.dispose();
    _notesController.dispose();
    _lentNameController.dispose();
    _lentAmountController.dispose();
    _lentNotesController.dispose();
    super.dispose();
  }

  // ── computed helpers for installment mode ─────────────────────────────────

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

  // ── visibility helpers ────────────────────────────────────────────────────

  bool get _showAmount => !(_type == TransactionType.income.value &&
      _withinBudget &&
      _isVariableIncome);

  bool get _showRecurrenceDetails => !(_type == TransactionType.income.value &&
      _withinBudget &&
      _isVariableIncome);

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

  bool get _canSave {
    if (_isSaving || _nameController.text.trim().isEmpty || _walletId.isEmpty) {
      return false;
    }
    if (_isExpenseInstallment) {
      final amt = _enteredInstallment;
      if (amt <= 0) return false;
      return true;
    }
    if (_showAmount) {
      final amt = double.tryParse(_amountController.text.trim()) ?? 0;
      if (amt < 0) return false;
      if (amt == 0 && !_isExpenseSubscription && !widget.subscriptionOnlyMode) {
        return false;
      }
    }
    if (_type == TransactionType.expense.value &&
        _withinBudget &&
        !_isDebtOrSubscription &&
        _allocationId == null &&
        _targetJarId == null) {
      return false;
    }
    if (_showRecurrenceDetails && _isWeekPattern && _selectedWeekdays.isEmpty) {
      return false;
    }
    return true;
  }

  void _refreshFormState() {
    if (!mounted) return;
    setState(() {});
  }

  String _composerTitle() {
    final isNew = widget.initialRecurring == null;
    if (widget.subscriptionOnlyMode ||
        _expensePlanKind == ExpensePlanKind.subscription.value) {
      return isNew ? 'إضافة اشتراك' : 'تعديل اشتراك';
    }
    if (widget.debtOnlyMode ||
        _expensePlanKind == ExpensePlanKind.installment.value) {
      if (_isLentMode) return 'سلّفت حد';
      return isNew ? 'إضافة قسط' : 'تعديل قسط';
    }
    if (_type == TransactionType.income.value) {
      return isNew ? 'إضافة دخل متكرر' : 'تعديل دخل متكرر';
    }
    return isNew ? 'إضافة مصروف متكرر' : 'تعديل مصروف متكرر';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.cubit.state;
    final budget = state.budgetSetup;
    final wallets = state.wallets;
    final visibleCategories = _visibleCategories(state.categories, budget);

    final isSubscriptionOnly =
        widget.subscriptionOnlyMode && widget.initialRecurring == null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_composerTitle()),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ── وضع القسط المبسّط ──────────────────────────────────────
            if (_isExpenseInstallment &&
                (widget.debtOnlyMode ||
                    _expensePlanKind == ExpensePlanKind.installment.value)) ...[
              _debtLentToggle(theme),
              const SizedBox(height: 18),
              if (_isLentMode) ...[
                ..._lentFormContent(theme, state.wallets),
              ] else ...[
                _installmentHeroHeader(theme),
                const SizedBox(height: 18),
                ..._installmentFormChildren(theme, wallets),
              ],
            ] else ...[
              // ── النموذج العادي ────────────────────────────────────────
              if (!isSubscriptionOnly && !widget.debtOnlyMode) ...[
                _typeSwitcher(theme),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المعاملة',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (_type == TransactionType.income.value && _withinBudget) ...[
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
              if (_showAmount) ...[
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: _type == TransactionType.expense.value &&
                            _withinBudget &&
                            _isExpenseInstallment
                        ? 'مبلغ القسط أو الدفعة'
                        : 'المبلغ',
                    prefixIcon: const Icon(Icons.payments_rounded),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_type == TransactionType.expense.value &&
                  _withinBudget &&
                  _isExpenseInstallment) ...[
                TextField(
                  controller: _debtPrincipalController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'إجمالي الدين (الأصل)',
                    helperText:
                        'مثل ١٠٠٠٠ — يُستخدم في الميزانية لحساب المتبقي والنسبة',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                value: _walletId.isEmpty ? null : _walletId,
                decoration: const InputDecoration(
                  labelText: 'المحفظة',
                  prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                ),
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem<String>(
                        value: wallet.id,
                        child: Text(wallet.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _walletId = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (!isSubscriptionOnly && !widget.debtOnlyMode) ...[
                _budgetScopePickerTile(budget),
                const SizedBox(height: 12),
              ],
              _surfaceSection(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الأيقونة واللون'),
                  subtitle: const Text('تظهر داخل التخطيط والميزانية'),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _parseColor(_iconColor).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: AppIconPickerDialog.iconWidgetForName(
                      _iconName,
                      color: _parseColor(_iconColor),
                      size: 22,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _pickIcon,
                ),
              ),
              const SizedBox(height: 12),
              _categorySection(visibleCategories, budget),
              const SizedBox(height: 12),
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
                        child: Text('يومي')),
                    DropdownMenuItem(
                        value: RecurrencePattern.weekly.value,
                        child: Text('أسبوعي')),
                    DropdownMenuItem(
                        value: RecurrencePattern.biweekly.value,
                        child: Text('كل أسبوعين')),
                    DropdownMenuItem(
                        value: RecurrencePattern.every3Weeks.value,
                        child: Text('كل 3 أسابيع')),
                    DropdownMenuItem(
                        value: RecurrencePattern.monthly.value,
                        child: Text('شهري')),
                    DropdownMenuItem(
                        value: RecurrencePattern.every2Months.value,
                        child: Text('كل شهرين')),
                    DropdownMenuItem(
                        value: RecurrencePattern.every3Months.value,
                        child: Text('كل 3 شهور')),
                    DropdownMenuItem(
                        value: RecurrencePattern.every6Months.value,
                        child: Text('كل 6 شهور')),
                    DropdownMenuItem(
                        value: RecurrencePattern.yearly.value,
                        child: Text('سنوي')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _recurrencePattern = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _recurrenceDetails(),
                const SizedBox(height: 12),
              ],
              if (_type == TransactionType.income.value &&
                  _withinBudget &&
                  _isVariableIncome)
                _surfaceSection(
                  child: const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('دخل متغير'),
                    subtitle: Text(
                      'سيتم تسجيله يدويًا فقط بدون تاريخ أو تكرار ثابت',
                    ),
                  ),
                )
              else ...[
                DropdownButtonFormField<String>(
                  value: _executionType,
                  decoration: const InputDecoration(
                    labelText: 'طريقة التنفيذ',
                    prefixIcon: Icon(Icons.bolt_rounded),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: AutomationType.auto.value,
                        child: Text('تلقائي')),
                    DropdownMenuItem(
                        value: AutomationType.confirm.value,
                        child: Text('يحتاج تأكيد')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _executionType = value);
                    }
                  },
                ),
                if (_executionType == AutomationType.confirm.value) ...[
                  const SizedBox(height: 12),
                  _reminderDropdown(),
                ],
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 18),
              _saveButton(),
              if (widget.allowDelete && widget.initialRecurring != null) ...[
                const SizedBox(height: 12),
                _deleteButton(theme),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── توجل دين / سلّفت ─────────────────────────────────────────────────────

  Widget _debtLentToggle(ThemeData theme) {
    const debtColor = Color(0xFFC65D2E);
    const lentColor = Color(0xFF1A7A4A);
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _toggleTile(
              selected: !_isLentMode,
              label: 'دين',
              icon: Icons.account_balance_outlined,
              color: debtColor,
              onTap: () => setState(() => _isLentMode = false),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _toggleTile(
              selected: _isLentMode,
              label: 'سلّفت حد',
              icon: Icons.handshake_outlined,
              color: lentColor,
              onTap: () => setState(() => _isLentMode = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleTile({
    required bool selected,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? color : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: selected ? color : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── فورم السلفة المدمج ────────────────────────────────────────────────────

  List<Widget> _lentFormContent(ThemeData theme, List<dynamic> wallets) {
    const accent = Color(0xFF1A7A4A);
    return [
      // Hero banner
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A7A4A), Color(0xFF2DAE6B)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A7A4A).withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child:
                  Icon(Icons.handshake_outlined, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تسجيل سلفة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'المبلغ يُخصم من المحفظة فوراً',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // اسم الشخص
      TextField(
        controller: _lentNameController,
        decoration: const InputDecoration(
          labelText: 'اسم الشخص',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),

      // الأيقونة واللون
      _surfaceSection(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('الأيقونة واللون'),
          subtitle: const Text('تظهر في التقارير والميزانية'),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _parseColor(_iconColor).withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: AppIconPickerDialog.iconWidgetForName(
              _iconName,
              color: _parseColor(_iconColor),
              size: 22,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _pickIcon,
        ),
      ),
      const SizedBox(height: 12),

      // المبلغ
      TextField(
        controller: _lentAmountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'المبلغ المسلَّف',
          prefixIcon: Icon(Icons.payments_outlined),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 12),

      // المحفظة
      if (wallets.isNotEmpty) ...[
        DropdownButtonFormField<String>(
          value: _lentWalletId.isEmpty ? null : _lentWalletId,
          decoration: const InputDecoration(
            labelText: 'المحفظة',
            prefixIcon: Icon(Icons.account_balance_wallet_rounded),
          ),
          items: wallets
              .map(
                (w) => DropdownMenuItem<String>(
                  value: w.id as String,
                  child: Text(w.name as String),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _lentWalletId = v);
          },
        ),
        const SizedBox(height: 12),
      ],

      // تاريخ الاسترداد
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: _lentReturnDate,
            firstDate: DateTime.now(),
            lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
          );
          if (d != null) setState(() => _lentReturnDate = d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Icon(
              Icons.calendar_month_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Text(
              'تاريخ الاسترداد المتوقع: ${_lentReturnDate.day}/${_lentReturnDate.month}/${_lentReturnDate.year}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 4),

      // أقساط شهرية
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _lentIsMonthly,
        title: const Text('يردها أقساط شهرية',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle:
            const Text('سيظهر تذكير شهري', style: TextStyle(fontSize: 12)),
        onChanged: (v) => setState(() => _lentIsMonthly = v),
      ),

      // ملاحظة
      TextField(
        controller: _lentNotesController,
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
          onPressed: () => _saveLent(),
          icon: const Icon(Icons.check_rounded),
          label: const Text(
            'تسجيل السلفة',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
    ];
  }

  Future<void> _saveLent() async {
    final name = _lentNameController.text.trim();
    final amount = double.tryParse(_lentAmountController.text.trim()) ?? 0;
    if (name.isEmpty || amount <= 0 || _lentWalletId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('من فضلك أدخل اسم الشخص والمبلغ والمحفظة'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    await widget.cubit.addLentRecord(
      personName: name,
      amount: amount,
      walletId: _lentWalletId,
      expectedReturnDate: _lentReturnDate,
      isMonthlyInstallments: _lentIsMonthly,
      notes: _lentNotesController.text.trim().isEmpty
          ? null
          : _lentNotesController.text.trim(),
    );
    if (mounted) Navigator.pop(context);
  }

  // ── نموذج القسط الجديد ────────────────────────────────────────────────────

  Widget _installmentHeroHeader(ThemeData theme) {
    final accent = _parseColor(_iconColor);
    final isNew = widget.initialRecurring == null;
    final calcInstallment = _calculatedInstallment;

    return Container(
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
                _iconName,
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
                      ? (isNew ? 'قسط جديد' : 'تعديل القسط')
                      : _nameController.text.trim(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'عدد الأقساط: ${_installmentCountController.text.isEmpty ? '0' : _installmentCountController.text}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'قيمة القسط: ${calcInstallment.toStringAsFixed(2)}',
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
    );
  }

  List<Widget> _installmentFormChildren(
      ThemeData theme, List<dynamic> wallets) {
    final calcInstallment = _calculatedInstallment;
    final hasCalc = calcInstallment > 0;
    final riba = _ribaAmount;
    final hasRiba = riba > 0.005;

    return [
      // القسم الأول: البيانات الأساسية
      _EditorSection(
        title: 'البيانات الأساسية',
        subtitle: 'حدد اسم القسط واختر له أيقونة تميزه في الميزانية.',
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم القسط أو المنتج',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            _surfaceSection(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('الأيقونة واللون'),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _parseColor(_iconColor).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: AppIconPickerDialog.iconWidgetForName(
                    _iconName,
                    color: _parseColor(_iconColor),
                    size: 22,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _pickIcon,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // القسم الثاني: تفاصيل المبلغ والجدولة
      _EditorSection(
        title: 'تفاصيل القسط',
        subtitle: 'أدخل المبالغ وتاريخ أول دفعة لنقوم بجدولة الأقساط تلقائياً.',
        child: Column(
          children: [
            TextField(
              controller: _debtPrincipalController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المبلغ الإجمالي',
                helperText: 'السعر الأصلي للمنتج أو قيمة الدين الكامل',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _installmentCountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'عدد الأقساط',
                prefixIcon: Icon(Icons.format_list_numbered_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _downPaymentController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'المقدم',
                prefixIcon: Icon(Icons.monetization_on_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'القسط الشهري',
                    helperText: hasCalc
                        ? 'المحسوب: ${calcInstallment.toStringAsFixed(2)}'
                        : 'أدخل المبلغ الإجمالي والعدد أولاً',
                    prefixIcon: const Icon(Icons.payments_rounded),
                    suffixIcon: hasCalc
                        ? IconButton(
                            icon: const Icon(Icons.calculate_rounded, size: 18),
                            tooltip: 'تطبيق المبلغ المحسوب',
                            onPressed: () {
                              _amountController.text =
                                  calcInstallment.toStringAsFixed(2);
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                if (hasRiba) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC65D2E).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFC65D2E).withValues(alpha: 0.35),
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
            ),
            const SizedBox(height: 14),
            _surfaceSection(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: const Text('تاريخ أول دفعة'),
                subtitle: Text(
                  '${_firstPaymentDate.day}/${_firstPaymentDate.month}/${_firstPaymentDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_left_rounded),
                onTap: _pickFirstPaymentDate,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // القسم الثالث: الإعدادات والمحفظة
      _EditorSection(
        title: 'الإعدادات والمحفظة',
        subtitle: 'حدد المحفظة التي سيتم الخصم منها وطريقة تنفيذ العملية.',
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _walletId.isEmpty ? null : _walletId,
              decoration: const InputDecoration(
                labelText: 'المحفظة',
                prefixIcon: Icon(Icons.account_balance_wallet_rounded),
              ),
              items: (widget.cubit.state.wallets)
                  .map(
                    (wallet) => DropdownMenuItem<String>(
                      value: wallet.id,
                      child: Text(wallet.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _walletId = value);
                }
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _executionType,
              decoration: const InputDecoration(
                labelText: 'طريقة التنفيذ',
                prefixIcon: Icon(Icons.bolt_rounded),
              ),
              items: [
                DropdownMenuItem(
                    value: AutomationType.auto.value, child: Text('تلقائي')),
                DropdownMenuItem(
                    value: AutomationType.confirm.value,
                    child: Text('يحتاج تأكيد')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _executionType = value);
                }
              },
            ),
            if (_executionType == AutomationType.confirm.value) ...[
              const SizedBox(height: 12),
              _reminderDropdown(),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),

      _saveButton(),
      if (widget.allowDelete && widget.initialRecurring != null) ...[
        const SizedBox(height: 12),
        _deleteButton(Theme.of(context)),
      ],
    ];
  }

  Future<void> _pickFirstPaymentDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstPaymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null) {
      setState(() => _firstPaymentDate = picked);
    }
  }

  Widget _reminderDropdown() {
    return DropdownButtonFormField<int>(
      value: _reminderLeadDays,
      decoration: InputDecoration(
        labelText: _recurrencePattern == RecurrencePattern.daily.value ||
                _isWeekPattern
            ? 'وقت الإشعار'
            : 'وقت الإشعار',
        prefixIcon: const Icon(Icons.notifications_active_rounded),
      ),
      items: (_recurrencePattern == RecurrencePattern.daily.value ||
              _isWeekPattern)
          ? const [
              DropdownMenuItem(
                value: 0,
                child: Text('في الوقت المحدد'),
              ),
              DropdownMenuItem(
                value: 1,
                child: Text('قبلها بساعة'),
              ),
              DropdownMenuItem(
                value: 2,
                child: Text('قبلها بساعتين'),
              ),
              DropdownMenuItem(
                value: 3,
                child: Text('قبلها بـ 3 ساعات'),
              ),
            ]
          : const [
              DropdownMenuItem(value: 0, child: Text('في نفس اليوم')),
              DropdownMenuItem(value: 1, child: Text('مبكر بيوم')),
              DropdownMenuItem(value: 2, child: Text('مبكر بيومين')),
              DropdownMenuItem(value: 3, child: Text('مبكر بـ 3 أيام')),
            ],
      onChanged: (value) {
        if (value != null) {
          setState(() => _reminderLeadDays = value);
        }
      },
    );
  }

  Widget _saveButton() {
    return FilledButton(
      onPressed: _canSave ? _save : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(_isSaving
            ? 'جارٍ الحفظ...'
            : widget.initialRecurring == null
                ? 'حفظ المعاملة'
                : 'تحديث المعاملة'),
      ),
    );
  }

  Widget _deleteButton(ThemeData theme) {
    return Center(
      child: TextButton.icon(
        onPressed: _deleteFromComposer,
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('حذف المعاملة'),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Widget _typeSwitcher(ThemeData theme) {
    final isIncome = _type == TransactionType.income.value;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _switcherItem(
              selected: !isIncome,
              label: 'مصروف',
              icon: Icons.arrow_outward_rounded,
              onTap: () {
                setState(() {
                  _type = TransactionType.expense.value;
                  if (_withinBudget) {
                    _expensePlanKind = widget.initialExpensePlanKind ??
                        (_expensePlanKind == 'normal'
                            ? ExpensePlanKind.installment.value
                            : _expensePlanKind);
                    _isDebtOrSubscription = _expensePlanKind != 'normal';
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _switcherItem(
              selected: isIncome,
              label: 'دخل',
              icon: Icons.arrow_downward_rounded,
              onTap: () {
                setState(() {
                  _type = TransactionType.income.value;
                  _allocationId = null;
                  _targetJarId = null;
                  _expensePlanKind = 'normal';
                  _isDebtOrSubscription = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _switcherItem({
    required bool selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? Colors.white : theme.colorScheme.onSurface),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _budgetScopePickerTile(BudgetSetupEntity budget) {
    final label = _budgetScopeLabel(budget);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => _openBudgetScopePicker(budget),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(
                _withinBudget
                    ? Icons.pie_chart_outline_rounded
                    : Icons.public_off_rounded,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('المخصص',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            )),
                    const SizedBox(height: 2),
                    Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _budgetScopeLabel(BudgetSetupEntity budget) {
    if (!_withinBudget) {
      if (_type == TransactionType.income.value && _targetJarId != null) {
        final j =
            budget.linkedWallets.where((j) => j.id == _targetJarId).toList();
        if (j.isNotEmpty) return 'حصالة: ${j.first.name}';
      }
      return _type == TransactionType.income.value
          ? 'دخل للمحفظة فقط'
          : 'خارج الميزانية';
    }
    if (_type == TransactionType.expense.value && _allocationId != null) {
      final a = budget.allocations.where((a) => a.id == _allocationId).toList();
      if (a.isNotEmpty) return 'مخصص: ${a.first.name}';
    }
    if (_targetJarId != null) {
      final j =
          budget.linkedWallets.where((j) => j.id == _targetJarId).toList();
      if (j.isNotEmpty) return 'حصالة: ${j.first.name}';
    }
    return _type == TransactionType.income.value
        ? 'دخل للميزانية الشهرية'
        : 'داخل الميزانية (عام)';
  }

  void _openBudgetScopePicker(BudgetSetupEntity budget) {
    final totalIncome = budget.totalIncome <= 0 ? 1.0 : budget.totalIncome;
    final selectedWalletName = widget.cubit.state.wallets
        .where((wallet) => wallet.id == _walletId)
        .map((wallet) => wallet.name)
        .cast<String?>()
        .firstWhere((name) => name != null, orElse: () => null);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              _type == TransactionType.income.value ? 'وجهة الدخل' : 'المخصص',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _ScopeOptionTile(
              isSelected: !_withinBudget,
              icon: _type == TransactionType.income.value
                  ? Icons.account_balance_wallet_rounded
                  : Icons.public_off_rounded,
              iconColor: Colors.grey,
              title: _type == TransactionType.income.value
                  ? 'دخل لمحفظة ${selectedWalletName ?? "مختارة"} فقط'
                  : 'خارج الميزانية',
              subtitle: _type == TransactionType.income.value
                  ? 'يزود رصيد المحفظة بدون دخوله في خطة الميزانية'
                  : 'لن تُحتسب في خطة الميزانية',
              progress: null,
              onTap: () {
                setState(() {
                  _withinBudget = false;
                  _allocationId = null;
                  _targetJarId = null;
                  _isDebtOrSubscription = false;
                  _expensePlanKind = 'normal';
                  _isVariableIncome = false;
                });
                Navigator.pop(ctx);
              },
            ),
            if (_type == TransactionType.income.value) ...[
              const SizedBox(height: 8),
              _ScopeOptionTile(
                isSelected: _withinBudget &&
                    _allocationId == null &&
                    _targetJarId == null,
                icon: Icons.calendar_month_rounded,
                iconColor: Theme.of(context).colorScheme.primary,
                title: 'دخل للميزانية الشهرية',
                subtitle: 'يدخل ضمن دخل الدورة بدون ربطه بمخصص أو حصالة',
                progress: null,
                onTap: () {
                  setState(() {
                    _withinBudget = true;
                    _allocationId = null;
                    _targetJarId = null;
                    _isDebtOrSubscription = false;
                    _expensePlanKind = 'normal';
                  });
                  Navigator.pop(ctx);
                },
              ),
              if (budget.linkedWallets.isNotEmpty) ...[
                const SizedBox(height: 14),
                const _ScopeDivider(label: 'الحصالات'),
                const SizedBox(height: 8),
                ...budget.linkedWallets.map((jar) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ScopeOptionTile(
                      isSelected: !_withinBudget && _targetJarId == jar.id,
                      icon: Icons.savings_outlined,
                      iconColor: const Color(0xFF8B6B3D),
                      title: jar.name,
                      subtitle:
                          'دخل مباشر للحصالة — خارج الميزانية (${jar.balance.toStringAsFixed(0)} رصيد)',
                      progress: _safeProgress(jar.balance, totalIncome),
                      onTap: () {
                        setState(() {
                          _withinBudget = false;
                          _targetJarId = jar.id;
                          _allocationId = null;
                          _isDebtOrSubscription = false;
                          _expensePlanKind = 'normal';
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  );
                }),
              ],
            ] else if (_type == TransactionType.expense.value) ...[
              const SizedBox(height: 14),
              const _ScopeDivider(label: 'المخصصات'),
              const SizedBox(height: 8),
              ...budget.allocations.map((a) {
                final planned =
                    a.funding.fold<double>(0, (s, f) => s + f.plannedAmount);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ScopeOptionTile(
                    isSelected: _withinBudget &&
                        _allocationId == a.id &&
                        _targetJarId == null,
                    icon: Icons.pie_chart_outline_rounded,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: a.name,
                    subtitle: '${planned.toStringAsFixed(0)} مخطط',
                    progress: _safeProgress(planned, totalIncome),
                    onTap: () {
                      setState(() {
                        _withinBudget = true;
                        _allocationId = a.id;
                        _targetJarId = null;
                        _isDebtOrSubscription = false;
                        _expensePlanKind = 'normal';
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
              const SizedBox(height: 8),
              const _ScopeDivider(label: 'الحصالات'),
              const SizedBox(height: 8),
              ...budget.linkedWallets.map((jar) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ScopeOptionTile(
                    isSelected: _withinBudget &&
                        _targetJarId == jar.id &&
                        _allocationId == null,
                    icon: Icons.savings_outlined,
                    iconColor: const Color(0xFF8B6B3D),
                    title: jar.name,
                    subtitle: '${jar.balance.toStringAsFixed(0)} رصيد',
                    progress: _safeProgress(jar.balance, totalIncome),
                    onTap: () {
                      setState(() {
                        _withinBudget = true;
                        _targetJarId = jar.id;
                        _allocationId = null;
                        _isDebtOrSubscription = false;
                        _expensePlanKind = 'normal';
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categorySection(
      List<CategoryEntity> categories, BudgetSetupEntity budget) {
    return _surfaceSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('الفئات',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              TextButton.icon(
                onPressed: () => _openAddCategoryDialog(budget, categories),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('إضافة فئة'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (categories.isEmpty)
            const Text('لا توجد فئات متاحة لهذا الجزء')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map(
                    (category) => FilterChip(
                      selected: _selectedCategoryIds.contains(category.id),
                      label: Text(category.name),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategoryIds.add(category.id);
                          } else {
                            _selectedCategoryIds.remove(category.id);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _openAddCategoryDialog(
    BudgetSetupEntity budget,
    List<CategoryEntity> existing,
  ) async {
    final nameCtrl = TextEditingController();
    var iconName = 'category';
    var iconColor = '#165b47';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('إضافة فئة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                onChanged: (_) => setDialog(() {}),
                decoration: const InputDecoration(hintText: 'اسم الفئة'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await AppIconPickerDialog.show(
                    ctx,
                    initialIconName: iconName,
                    initialColorHex: iconColor,
                    title: 'اختر أيقونة الفئة',
                    name: nameCtrl.text,
                  );
                  if (picked == null) return;
                  setDialog(() {
                    iconName = picked.iconName;
                    iconColor = picked.colorHex;
                  });
                },
                icon: const Icon(Icons.palette_outlined),
                label: const Text('الأيقونة واللون'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: nameCtrl.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;

    final category = CategoryEntity(
      id: 'cat-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      icon: iconName,
      color: iconColor,
      scope: _type == TransactionType.income.value ? 'income' : 'expense',
      allocationId: (_withinBudget &&
              _allocationId != null &&
              _allocationId != 'unallocated')
          ? _allocationId
          : null,
    );

    if (_withinBudget && _allocationId != null) {
      final alloc =
          budget.allocations.where((a) => a.id == _allocationId).toList();
      if (alloc.isNotEmpty) {
        await widget.cubit.updateAllocationCategories(
          allocationId: _allocationId!,
          categories: [...alloc.first.categories, category],
        );
      }
    } else if (_withinBudget && _targetJarId != null) {
      final jar =
          budget.linkedWallets.where((j) => j.id == _targetJarId).toList();
      if (jar.isNotEmpty) {
        await widget.cubit.updateLinkedWalletCategories(
          linkedWalletId: _targetJarId!,
          categories: [...jar.first.categories, category],
        );
      }
    } else {
      final current = widget.cubit.state.categories;
      await widget.cubit.setCategories([...current, category]);
    }
    if (mounted) setState(() {});
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
            onDaySelected: (day) {
              setState(() => _monthlyDay = day);
            },
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
                    if (value != null) {
                      setState(() => _yearlyMonth = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DayPickerTile(
                  label: 'اليوم',
                  selectedDay: _yearlyDay,
                  onDaySelected: (day) {
                    setState(() => _yearlyDay = day);
                  },
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
            context: context,
            initialTime: _selectedTime,
          );
          if (picked != null) {
            setState(() => _selectedTime = picked);
          }
        },
      ),
    );
  }

  List<CategoryEntity> _visibleCategories(
    List<CategoryEntity> allCategories,
    BudgetSetupEntity budget,
  ) {
    if (_type == TransactionType.expense.value && _withinBudget) {
      if (_allocationId != null) {
        final allocation =
            budget.allocations.where((item) => item.id == _allocationId);
        if (allocation.isNotEmpty) {
          return allocation.first.categories;
        }
      }
      if (_targetJarId != null) {
        final jar =
            budget.linkedWallets.where((item) => item.id == _targetJarId);
        if (jar.isNotEmpty) {
          return jar.first.categories;
        }
      }
    }
    return allCategories.where((category) => category.scope == _type).toList();
  }

  Future<void> _pickIcon() async {
    final picked = await AppIconPickerDialog.show(
      context,
      initialIconName: _iconName,
      initialColorHex: _iconColor,
      title: 'اختيار أيقونة المعاملة',
      name: _nameController.text,
    );
    if (picked == null) return;
    setState(() {
      _iconName = picked.iconName;
      _iconColor = picked.colorHex;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;

    final effectivePattern = _isExpenseInstallment
        ? RecurrencePattern.monthly.value
        : (_type == TransactionType.income.value &&
                _withinBudget &&
                _isVariableIncome
            ? RecurrencePattern.manualVariable.value
            : _recurrencePattern);

    final effectiveExecutionType = _type == TransactionType.income.value &&
            _withinBudget &&
            _isVariableIncome
        ? 'manual'
        : _executionType;

    final principalRaw = double.tryParse(_debtPrincipalController.text.trim());
    final debtPrincipalTotal = (_type == TransactionType.expense.value &&
            _withinBudget &&
            _isExpenseInstallment &&
            principalRaw != null &&
            principalRaw > 0)
        ? principalRaw
        : null;

    final countRaw = int.tryParse(_installmentCountController.text.trim());
    final installmentCount =
        (_isExpenseInstallment && countRaw != null && countRaw > 0)
            ? countRaw
            : null;

    final downPayRaw = double.tryParse(_downPaymentController.text.trim());
    final installmentDownPayment =
        (_isExpenseInstallment && downPayRaw != null && downPayRaw > 0)
            ? downPayRaw
            : null;

    // اليوم الشهري للأقساط يُستخرج من تاريخ أول دفعة
    final effectiveDayOfMonth = _isExpenseInstallment
        ? _firstPaymentDate.day.clamp(1, 28)
        : (_recurrencePattern == RecurrencePattern.yearly.value
            ? _yearlyDay
            : _isMonthPattern
                ? _monthlyDay
                : 1);

    final effectiveAnchorDate = _isExpenseInstallment
        ? _firstPaymentDate.toIso8601String()
        : widget.initialRecurring?.anchorDate;

    final draftId = widget.initialRecurring?.id ??
        'rec-${DateTime.now().microsecondsSinceEpoch}';

    final recurringDraft = RecurringTransactionEntity(
      id: draftId,
      name: _nameController.text.trim(),
      type: _type,
      amount: _showAmount ? amount : 0,
      dayOfMonth: effectiveDayOfMonth,
      executionType: effectiveExecutionType,
      walletId: _walletId,
      budgetScope: _isExpenseInstallment
          ? BudgetScope.withinBudget.value
          : (_withinBudget
              ? BudgetScope.withinBudget.value
              : BudgetScope.outsideBudget.value),
      recurrencePattern: effectivePattern,
      icon: _iconName,
      iconColor: _iconColor,
      weekday: _selectedWeekdays.isEmpty ? null : _selectedWeekdays.first,
      weekdays: _selectedWeekdays.toList()..sort(),
      monthOfYear: _recurrencePattern == RecurrencePattern.yearly.value
          ? _yearlyMonth
          : null,
      anchorDate: effectiveAnchorDate,
      scheduledTime: _isExpenseInstallment
          ? null
          : (_showRecurrenceDetails ? _formatTime(_selectedTime) : null),
      reminderLeadDays: effectiveExecutionType == AutomationType.confirm.value
          ? _reminderLeadDays
          : null,
      allocationId: _type == TransactionType.expense.value &&
              _withinBudget &&
              !_isDebtOrSubscription
          ? _allocationId
          : null,
      targetJarId: (_type == TransactionType.expense.value &&
                  _withinBudget &&
                  !_isDebtOrSubscription) ||
              (_type == TransactionType.income.value && _targetJarId != null)
          ? _targetJarId
          : null,
      incomeSourceId: widget.initialRecurring?.incomeSourceId,
      categoryIds: _selectedCategoryIds.toList(),
      isVariableIncome: _isVariableIncome,
      isDebtOrSubscription: _isExpenseInstallment ||
          (_type == TransactionType.expense.value &&
              _withinBudget &&
              _isDebtOrSubscription),
      expensePlanKind:
          _type == TransactionType.expense.value ? _expensePlanKind : null,
      debtPrincipalTotal: debtPrincipalTotal,
      installmentCount: installmentCount,
      installmentDownPayment: installmentDownPayment,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final recurring = effectiveAnchorDate != null
        ? recurringDraft
        : recurringDraft.copyWith(
            anchorDate:
                RecurringScheduleEngine.defaultAnchorDate(recurringDraft)
                    .toIso8601String(),
          );

    if (widget.returnOnSave) {
      if (!mounted) return;
      Navigator.of(context).pop(
        RecurringTransactionComposerResult.saved(recurring),
      );
      return;
    }

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

    if (!mounted) return;
    if (widget.subscriptionOnlyMode && widget.initialRecurring == null) {
      Navigator.of(context).pop();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
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

  Future<void> _deleteFromComposer() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المعاملة'),
        content: const Text(
          'سيتم حذف هذه المعاملة المتكررة. هل تريد المتابعة؟',
        ),
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

    if (widget.returnOnSave) {
      Navigator.of(context)
          .pop(const RecurringTransactionComposerResult.deleted());
      return;
    }

    if (widget.initialRecurring != null) {
      await widget.cubit
          .deleteRecurringTransaction(widget.initialRecurring!.id);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
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

  String _formatTime(TimeOfDay time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
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

  Color _parseColor(String hex) {
    final value =
        int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x165b47;
    return Color(0xFF000000 | value);
  }
}

// ── Scope picker helpers ───────────────────────────────────────────────────
class _ScopeOptionTile extends StatelessWidget {
  const _ScopeOptionTile({
    required this.isSelected,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.onTap,
  });
  final bool isSelected;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressValue = progress?.isFinite == true
        ? progress!.clamp(0.0, 1.0).toDouble()
        : null;
    return Material(
      color: isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.45)
                  : theme.colorScheme.outlineVariant,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle_rounded,
                            color: theme.colorScheme.primary, size: 18),
                    ]),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600)),
                    if (progress != null) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 4,
                          backgroundColor: iconColor.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeDivider extends StatelessWidget {
  const _ScopeDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child:
                Divider(color: Theme.of(context).colorScheme.outlineVariant)),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Expanded(
            child:
                Divider(color: Theme.of(context).colorScheme.outlineVariant)),
      ],
    );
  }
}

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

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
