import 'package:flutter/material.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/services/recurring_schedule_engine.dart';
import '../widgets/recurring_income_post_dialog.dart';
import 'pickers/allocation_picker_sheet.dart';
import 'pickers/category_add_dialog.dart';
import 'pickers/income_target_picker_sheet.dart';
import 'pickers/wallet_picker_sheet.dart';
import 'sections/actions_section.dart';
import 'sections/amount_section.dart';
import 'sections/category_section.dart';
import 'sections/datetime_section.dart';
import 'sections/notes_section.dart';
import 'sections/recurring_settings_section.dart';
import 'sections/target_section.dart';
import 'sections/type_section.dart';
import 'sections/wallet_section.dart';
import 'transaction_form_controller.dart';

// ---------------------------------------------------------------------------
// TransactionEntryForm
//
// Canonical entry form shared by AddTransactionScreen and
// RecurringTransactionComposerScreen. Holds all form state via
// TransactionFormController. Each visual concern is delegated to a focused
// section widget. Submit and delete logic lives here because it needs the
// cubit and Navigator context.
// ---------------------------------------------------------------------------

class TransactionEntryForm extends StatefulWidget {
  const TransactionEntryForm({
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
  final void Function(RecurringTransactionEntity recurring)? onSaved;
  final void Function()? onDeleted;

  @override
  State<TransactionEntryForm> createState() => _TransactionEntryFormState();
}

class _TransactionEntryFormState extends State<TransactionEntryForm> {
  late final TransactionFormController _ctrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final state = widget.cubit.state;
    _ctrl = TransactionFormController.create(
      wallets: state.wallets,
      recurringMode: widget.recurringMode,
      recurringType: widget.recurringType,
      initialRecurring: widget.initialRecurring,
      initialTransaction: widget.initialTransaction,
      subscriptionOnlyMode: widget.subscriptionOnlyMode,
      debtOnlyMode: widget.debtOnlyMode,
      initialExpensePlanKind: widget.initialExpensePlanKind,
    );
    _ensureRecurringIncomeSourceSelected();
    _ctrl.amountController.addListener(_rebuild);
    _ctrl.debtPrincipalController.addListener(_rebuild);
    _ctrl.installmentCountController.addListener(_rebuild);
    _ctrl.downPaymentController.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  bool get _requiresExistingIncomeSource =>
      widget.recurringMode && _ctrl.type == TransactionType.income.value;

  void _ensureRecurringIncomeSourceSelected() {
    if (!_requiresExistingIncomeSource) return;
    final sources = widget.cubit.state.budgetSetup.incomeSources;
    final selected = sources.where((s) => s.id == _ctrl.incomeSourceId);

    _ctrl.incomeBudgetScope = BudgetScope.withinBudget.value;
    _ctrl.incomeJarId = '';
    if (selected.isNotEmpty) {
      _applyIncomeSourceDefaults(selected.first);
      return;
    }
    if (sources.isEmpty) {
      _ctrl.incomeSourceId = 'wallet-only';
      return;
    }
    _ctrl.incomeSourceId = sources.first.id;
    _applyIncomeSourceDefaults(sources.first);
  }

  void _applyIncomeSourceDefaults(IncomeSourceEntity source) {
    _ctrl.incomeBudgetScope = BudgetScope.withinBudget.value;
    _ctrl.incomeSourceId = source.id;
    _ctrl.incomeJarId = '';
    _ctrl.isVariableIncome = source.isVariable;
    if (source.isVariable) {
      _ctrl.executionType = 'manual';
      _ctrl.amountController.clear();
    }
  }

  // ── Focus helpers ────────────────────────────────────────────────────────
  /// Removes focus from the amount field and dismisses the keyboard.
  /// Call before opening any picker, selector, dialog, or bottom sheet.
  /// Call again after the picker closes to prevent focus restoration.
  void _unfocusAmount() {
    if (mounted) _ctrl.amountFocusNode.unfocus();
  }

  @override
  void dispose() {
    _ctrl.amountController.removeListener(_rebuild);
    _ctrl.debtPrincipalController.removeListener(_rebuild);
    _ctrl.installmentCountController.removeListener(_rebuild);
    _ctrl.downPaymentController.removeListener(_rebuild);
    _ctrl.dispose();
    super.dispose();
  }

  // ── Smart wallet default ─────────────────────────────────────────────────
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
    final walletExists =
        s.wallets.any((w) => w.id == src.first.targetWalletId);
    if (walletExists) {
      setState(() => _ctrl.walletId = src.first.targetWalletId);
    }
  }

  // ── Expense impact confirmation ──────────────────────────────────────────
  Future<bool> _confirmExpenseImpact({
    required WalletEntity wallet,
    required double amount,
  }) async {
    final state = widget.cubit.state;
    var effectiveBalance = wallet.balance;
    if (widget.initialTransaction?.walletId == wallet.id) {
      if (widget.initialTransaction?.type == TransactionType.expense.value) {
        effectiveBalance += widget.initialTransaction!.amount;
      } else if (widget.initialTransaction?.type ==
          TransactionType.income.value) {
        effectiveBalance -= widget.initialTransaction!.amount;
      }
    }

    double reserved = 0;
    for (final d in state.moneyDistributions) {
      if (d.walletId == wallet.id) reserved += d.amount;
    }
    if (reserved < 0) reserved = 0;

    final availableNet = effectiveBalance - reserved;
    final usesReservedFunds = amount > availableNet;
    final goesNegative = (effectiveBalance - amount) < 0;
    if (!usesReservedFunds && !goesNegative) return true;

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
            Text(wallet.name,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            ...messages.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(m),
                )),
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

  // ── Category add (needs cubit to persist) ────────────────────────────────
  Future<void> _handleAddCategory({
    required String budgetScope,
    required String allocationId,
    required String linkedWalletId,
    required List<CategoryEntity> existing,
    String scope = 'expense',
  }) async {
    _unfocusAmount();
    final draft = await showCategoryAddDialog(
      context,
      nameController: _ctrl.newCategoryController,
    );
    _unfocusAmount();
    if (draft == null) return;
    final name = draft.name;
    if (name.isEmpty) return;

    final category = CategoryEntity(
      id: 'cat-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      icon: draft.iconName,
      color: draft.colorHex,
      scope: scope,
      allocationId: budgetScope == BudgetScope.withinBudget.value &&
              allocationId.isNotEmpty &&
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
      await widget.cubit
          .setCategories([...widget.cubit.state.categories, category]);
    }

    if (!mounted) return;
    setState(() {
      if (scope == 'income') {
        _ctrl.selectedIncomeCategoryId = category.id;
      } else {
        _ctrl.selectedCategoryId = category.id;
      }
    });
  }

  // ── Retroactive income post prompt ───────────────────────────────────────
  Future<void> _maybePromptRetroactiveIncomePost(
    RecurringTransactionEntity recurring,
  ) async {
    final due =
        RecurringScheduleEngine.unhandledDueOccurrence(recurring, DateTime.now());
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

  // ── Derived name for recurring ────────────────────────────────────────────
  String _derivedName() {
    final notes = _ctrl.notesController.text.trim();
    if (notes.isNotEmpty) return notes;
    final state = widget.cubit.state;
    final budget = state.budgetSetup;
    final visible = _ctrl.type == TransactionType.expense.value
        ? ((_ctrl.budgetScope == BudgetScope.withinBudget.value &&
                _ctrl.budgetTargetId.startsWith('alloc:'))
            ? budget.allocations
                .where((a) => _ctrl.budgetTargetId == 'alloc:${a.id}')
                .expand((a) => a.categories)
                .toList()
            : state.categories
                .where((c) => c.scope == 'expense')
                .toList())
        : state.categories.where((c) => c.scope == 'income').toList();
    for (final cat in visible) {
      if (_ctrl.selectedCategoryIds.contains(cat.id)) return cat.name;
    }
    return _ctrl.type == TransactionType.income.value
        ? 'دخل متكرر'
        : 'مصروف متكرر';
  }

  // ── Submit: normal transaction ────────────────────────────────────────────
  Future<void> _submitNormal(
    double amount,
    BudgetSetupEntity budget,
    List<WalletEntity> wallets,
  ) async {
    if (amount <= 0) {
      _showError('أدخل مبلغًا صحيحًا أكبر من صفر.');
      return;
    }
    if (_ctrl.walletId.isEmpty) {
      _showError('اختر محفظة أو اختر "بدون محفظة" أولًا.');
      return;
    }
    if (_ctrl.type == TransactionType.expense.value &&
        _ctrl.budgetScope == BudgetScope.withinBudget.value &&
        _ctrl.budgetTargetId.isEmpty) {
      _showError('اختر مخصصًا أو حصالة للمعاملة داخل الميزانية.');
      return;
    }
    if (_ctrl.budgetTargetId == 'unallocated' &&
        amount > budget.unallocatedAmount) {
      _showError('المبلغ أكبر من المتاح في غير المخصص.');
      return;
    }
    if (_ctrl.type == TransactionType.income.value &&
        _ctrl.incomeBudgetScope == BudgetScope.withinBudget.value &&
        _ctrl.incomeSourceId == 'wallet-only' &&
        _ctrl.incomeJarId.isEmpty) {
      _showError('اختر مصدر دخل أو حصالة للدخل داخل الميزانية.');
      return;
    }

    if (_ctrl.type == TransactionType.expense.value &&
        _ctrl.walletId != 'no-wallet') {
      final currentWallet =
          wallets.where((w) => w.id == _ctrl.walletId).toList();
      if (currentWallet.isNotEmpty) {
        final approved = await _confirmExpenseImpact(
          wallet: currentWallet.first,
          amount: amount,
        );
        if (!approved) return;
      }
    }


    final selectedJarId = _ctrl.budgetTargetId.startsWith('jar:')
        ? _ctrl.budgetTargetId.replaceFirst('jar:', '')
        : null;

    if (widget.initialTransaction != null) {
      await widget.cubit.deleteTransaction(widget.initialTransaction!.id);
    }
    await widget.cubit.addTransaction(
      walletId: _ctrl.walletId == 'no-wallet' ? null : _ctrl.walletId,
      toWalletId: _ctrl.type == TransactionType.income.value &&
              _ctrl.incomeBudgetScope == BudgetScope.withinBudget.value &&
              _ctrl.incomeJarId.isNotEmpty
          ? _ctrl.incomeJarId
          : selectedJarId,
      amount: amount,
      type: _ctrl.type,
      createdAt: DateTime(
        _ctrl.date.year,
        _ctrl.date.month,
        _ctrl.date.day,
        _ctrl.time.hour,
        _ctrl.time.minute,
      ),
      allocationId: _ctrl.type == TransactionType.expense.value &&
              _ctrl.budgetScope == BudgetScope.withinBudget.value &&
              _ctrl.budgetTargetId.startsWith('alloc:')
          ? _ctrl.budgetTargetId.replaceFirst('alloc:', '')
          : null,
      budgetScope: _ctrl.type == TransactionType.expense.value
          ? _ctrl.budgetScope
          : _ctrl.type == TransactionType.income.value
              ? _ctrl.incomeBudgetScope
              : null,
      incomeSourceId: _ctrl.type == TransactionType.income.value &&
              _ctrl.incomeSourceId != 'wallet-only'
          ? _ctrl.incomeSourceId
          : null,
      transferType:
          widget.initialTransaction?.transferType ==
                      TransferType.jarFundingPhysical.value &&
                  _ctrl.type == TransactionType.expense.value
              ? TransferType.jarFundingPhysical.value
              : _ctrl.type == TransactionType.income.value &&
                      _ctrl.incomeJarId.isNotEmpty
                  ? TransferType.depositWithJarLabel.value
                  : null,
      notes: _ctrl.notesController.text.trim().isEmpty
          ? null
          : _ctrl.notesController.text.trim(),
      categoryId: _ctrl.type == TransactionType.income.value
          ? _ctrl.selectedIncomeCategoryId
          : _ctrl.selectedCategoryId,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_ctrl.type == TransactionType.income.value
            ? 'تم تسجيل الدخل.'
            : 'تم تسجيل المعاملة.'),
      ),
    );
    Navigator.of(context).pop();
  }

  // ── Submit: recurring transaction ─────────────────────────────────────────
  Future<void> _submitRecurring(double amount, BudgetSetupEntity budget) async {
    if (_ctrl.walletId.isEmpty) {
      _showError('اختر محفظة أو اختر "بدون محفظة" أولًا.');
      return;
    }

    final selectedJarId = _ctrl.budgetTargetId.startsWith('jar:')
        ? _ctrl.budgetTargetId.replaceFirst('jar:', '')
        : null;
    final selectedAllocId = _ctrl.budgetTargetId.startsWith('alloc:')
        ? _ctrl.budgetTargetId.replaceFirst('alloc:', '')
        : null;

    final effectivePattern = _ctrl.isExpenseInstallment
        ? RecurrencePattern.monthly.value
        : (_ctrl.type == TransactionType.income.value && _ctrl.isVariableIncome
            ? RecurrencePattern.manualVariable.value
            : _ctrl.recurrencePattern);

    final effectiveExecutionType =
        _ctrl.type == TransactionType.income.value && _ctrl.isVariableIncome
            ? 'manual'
            : _ctrl.executionType;

    final effectiveDayOfMonth = _ctrl.isExpenseInstallment
        ? _ctrl.firstPaymentDate.day.clamp(1, 28)
        : (_ctrl.recurrencePattern == RecurrencePattern.yearly.value
            ? _ctrl.yearlyDay
            : (_ctrl.isMonthPattern ? _ctrl.monthlyDay : 1));

    final effectiveAnchorDate = _ctrl.isExpenseInstallment
        ? _ctrl.firstPaymentDate.toIso8601String()
        : widget.initialRecurring?.anchorDate;

    final derivedName = _ctrl.recurringNameController.text.trim().isEmpty
        ? _derivedName()
        : _ctrl.recurringNameController.text.trim();

    final recurringDraft = RecurringTransactionEntity(
      id: widget.initialRecurring?.id ??
          'rec-${DateTime.now().microsecondsSinceEpoch}',
      name: derivedName,
      type: _ctrl.type,
      amount: _ctrl.showAmount ? amount : 0,
      dayOfMonth: effectiveDayOfMonth,
      executionType: effectiveExecutionType,
      walletId: _ctrl.walletId == 'no-wallet' ? '' : _ctrl.walletId,
      budgetScope: _ctrl.isExpenseInstallment
          ? BudgetScope.withinBudget.value
          : (_ctrl.type == TransactionType.expense.value
              ? _ctrl.budgetScope
              : _ctrl.incomeBudgetScope),
      recurrencePattern: effectivePattern,
      icon: _ctrl.recurringIconName,
      iconColor: _ctrl.recurringIconColor,
      weekday: _ctrl.selectedWeekdays.isEmpty
          ? null
          : _ctrl.selectedWeekdays.first,
      weekdays: _ctrl.selectedWeekdays.toList()..sort(),
      monthOfYear:
          _ctrl.recurrencePattern == RecurrencePattern.yearly.value
              ? _ctrl.yearlyMonth
              : null,
      anchorDate: effectiveAnchorDate,
      scheduledTime: !_ctrl.isExpenseInstallment && _ctrl.showRecurrenceDetails
          ? TransactionFormController.formatTime(_ctrl.scheduledTime)
          : null,
      reminderLeadDays:
          effectiveExecutionType == AutomationType.confirm.value
              ? _ctrl.reminderLeadDays
              : null,
      allocationId: _ctrl.type == TransactionType.expense.value &&
              _ctrl.withinBudgetExpense &&
              !_ctrl.isDebtOrSubscription &&
              selectedAllocId != null
          ? selectedAllocId
          : null,
      targetJarId:
          _ctrl.type == TransactionType.income.value &&
                  _ctrl.incomeJarId.isNotEmpty
              ? _ctrl.incomeJarId
              : (_ctrl.type == TransactionType.expense.value &&
                      !_ctrl.isDebtOrSubscription &&
                      selectedJarId != null
                  ? selectedJarId
                  : null),
      incomeSourceId: _ctrl.type == TransactionType.income.value &&
              _ctrl.incomeSourceId != 'wallet-only'
          ? _ctrl.incomeSourceId
          : null,
      categoryIds: _ctrl.selectedCategoryIds.toList(),
      isVariableIncome: _ctrl.isVariableIncome,
      isDebtOrSubscription: _ctrl.isExpenseInstallment ||
          (_ctrl.type == TransactionType.expense.value &&
              _ctrl.isDebtOrSubscription),
      expensePlanKind:
          _ctrl.type == TransactionType.expense.value ? _ctrl.expensePlanKind : null,
      debtPrincipalTotal: _ctrl.isExpenseInstallment
          ? double.tryParse(_ctrl.debtPrincipalController.text.trim())
          : null,
      installmentCount: _ctrl.isExpenseInstallment
          ? int.tryParse(_ctrl.installmentCountController.text.trim())
          : null,
      installmentDownPayment: _ctrl.isExpenseInstallment
          ? double.tryParse(_ctrl.downPaymentController.text.trim())
          : null,
      notes: _ctrl.notesController.text.trim().isEmpty
          ? null
          : _ctrl.notesController.text.trim(),
      isActive: widget.initialRecurring?.isActive ?? true,
    );

    final recurring = effectiveAnchorDate != null
        ? recurringDraft
        : recurringDraft.copyWith(
            anchorDate: RecurringScheduleEngine.defaultAnchorDate(recurringDraft)
                .toIso8601String(),
          );

    if (widget.onSaved != null) {
      widget.onSaved!(recurring);
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

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ المعاملة المتكررة.')),
    );
    Navigator.of(context).pop();
  }

  // ── Delete recurring ──────────────────────────────────────────────────────
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

  void _showError(String message) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = widget.cubit.state;
    final wallets = state.wallets;
    final budget = state.budgetSetup;
    final amount = double.tryParse(_ctrl.amountController.text.trim()) ?? 0;
    final theme = Theme.of(context);
    final locked = widget.subscriptionOnlyMode || widget.debtOnlyMode;

    // ── Derived labels ──────────────────────────────────────────────────────
    final selectedWallet =
        wallets.where((w) => w.id == _ctrl.walletId).toList();
    final selectedWalletName = _ctrl.walletId == 'no-wallet'
        ? 'بدون محفظة (افتراضي)'
        : selectedWallet.isEmpty
            ? 'اختر المحفظة'
            : selectedWallet.first.name;

    final selectedAllocation = budget.allocations
        .where((a) => _ctrl.budgetTargetId == 'alloc:${a.id}')
        .toList();
    final selectedJar = budget.linkedWallets
        .where((j) => _ctrl.budgetTargetId == 'jar:${j.id}')
        .toList();
    final selectedAllocationName = _ctrl.budgetTargetId == 'unallocated'
        ? 'غير المخصص'
        : selectedJar.isNotEmpty
            ? 'حصالة: ${selectedJar.first.name}'
            : selectedAllocation.isEmpty
                ? 'خارج الميزانية'
                : selectedAllocation.first.name;

    final selectedIncomeJar = budget.linkedWallets
        .where((j) => j.id == _ctrl.incomeJarId)
        .toList();
    final selectedIncomeJarName = selectedIncomeJar.isEmpty
        ? 'اختر الحصالة'
        : selectedIncomeJar.first.name;
    final selectedIncomeSource = budget.incomeSources
        .where((item) => item.id == _ctrl.incomeSourceId)
        .toList();
    final incomeTargetLabel = _ctrl.incomeJarId.isNotEmpty
        ? 'حصالتي: $selectedIncomeJarName'
        : selectedIncomeSource.isNotEmpty
            ? 'مصدر دخل: ${selectedIncomeSource.first.name}'
            : 'إيداع لمحفظة $selectedWalletName فقط';

    // ── Categories ──────────────────────────────────────────────────────────
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
    final visibleIncomeCategories = _ctrl.incomeJarId.isNotEmpty
        ? incomeJarCategories
        : state.categories.where((c) => c.scope == 'income').toList();
    final visibleCategories = _ctrl.budgetTargetId.startsWith('alloc:')
        ? allocationCategories
        : _ctrl.budgetTargetId.startsWith('jar:')
            ? jarCategories
            : generalExpenseCategories;

    // ── Invalidate budgetTargetId if it no longer exists ───────────────────
    final allocationItems = [
      if (budget.unallocatedAmount > 0) 'unallocated',
      ...budget.allocations.map((a) => 'alloc:${a.id}'),
      ...budget.linkedWallets.map((j) => 'jar:${j.id}'),
    ].toSet();
    if (_ctrl.budgetTargetId.isNotEmpty &&
        !allocationItems.contains(_ctrl.budgetTargetId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _ctrl.budgetTargetId = '');
      });
    }

    return Container(
      decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // ── Type toggle ──
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: TypeSection(
                  type: _ctrl.type,
                  locked: locked,
                  onTypeChanged: (newType) => setState(() {
                    _ctrl.type = newType;
                    if (newType == TransactionType.income.value) {
                      _ctrl.budgetTargetId = '';
                      _ctrl.selectedCategoryId = null;
                      _ctrl.isDebtOrSubscription = false;
                      _ctrl.expensePlanKind = 'normal';
                      _ensureRecurringIncomeSourceSelected();
                    } else {
                      _ctrl.selectedIncomeCategoryId = null;
                    }
                  }),
                ),
              ),

              // ── Scrollable body ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  children: [
                    // Amount
                    AmountSection(
                      ctrl: _ctrl,
                      recurringMode: widget.recurringMode,
                      focusNode: _ctrl.amountFocusNode,
                    ),

                    // Expense: allocation
                    if (_ctrl.type == TransactionType.expense.value) ...[
                      const SizedBox(height: 8),
                      TargetSection(
                        type: _ctrl.type,
                        allocationName: _ctrl.budgetTargetId.isEmpty
                            ? 'خارج الميزانية'
                            : selectedAllocationName,
                        incomeTargetLabel: incomeTargetLabel,
                        onOpenAllocationPicker: () {
                          _unfocusAmount();
                          showAllocationPickerSheet(
                            context,
                            budget: budget,
                            selectedTargetId: _ctrl.budgetTargetId,
                            onSelected: (targetId, budgetScope) {
                              setState(() {
                                _ctrl.budgetTargetId = targetId;
                                _ctrl.budgetScope = budgetScope;
                              });
                              if (targetId.isNotEmpty) {
                                _autoSetWalletFromAllocation(targetId);
                              }
                            },
                          );
                        },
                        onOpenIncomeTargetPicker: () {},
                      ),
                    ],

                    // Wallet
                    const SizedBox(height: 8),
                    WalletSection(
                      walletName: selectedWalletName,
                      onOpenPicker: () {
                        _unfocusAmount();
                        showWalletPickerSheet(
                          context,
                          wallets: wallets,
                          currentWalletId: _ctrl.walletId,
                          onSelected: (id) =>
                              setState(() => _ctrl.walletId = id),
                        );
                      },
                    ),

                    // Categories
                    const SizedBox(height: 8),
                    if (_ctrl.type == TransactionType.expense.value)
                      CategorySection(
                        recurringMode: widget.recurringMode,
                        categories: visibleCategories,
                        selectedId: widget.recurringMode
                            ? (_ctrl.selectedCategoryIds.isEmpty
                                ? null
                                : _ctrl.selectedCategoryIds.first)
                            : _ctrl.selectedCategoryId,
                        onSelectChange: (id) => setState(() {
                          if (widget.recurringMode) {
                            _ctrl.selectedCategoryIds.clear();
                            if (id != null) _ctrl.selectedCategoryIds.add(id);
                          } else {
                            _ctrl.selectedCategoryId = id;
                          }
                        }),
                        onAdd: () => _handleAddCategory(
                          budgetScope: _ctrl.budgetScope,
                          allocationId: _ctrl.budgetTargetId.startsWith('alloc:')
                              ? _ctrl.budgetTargetId.replaceFirst('alloc:', '')
                              : '',
                          linkedWalletId:
                              _ctrl.budgetTargetId.startsWith('jar:')
                                  ? _ctrl.budgetTargetId
                                      .replaceFirst('jar:', '')
                                  : '',
                          existing: visibleCategories,
                        ),
                      ),

                    // Income fields
                    if (_ctrl.type == TransactionType.income.value) ...[
                      const SizedBox(height: 4),
                      TargetSection(
                        type: _ctrl.type,
                        allocationName: selectedAllocationName,
                        incomeTargetLabel: incomeTargetLabel,
                        onOpenAllocationPicker: () {},
                        onOpenIncomeTargetPicker: () {
                          _unfocusAmount();
                          showIncomeTargetPickerSheet(
                            context,
                            budget: budget,
                            walletName: selectedWalletName,
                            currentIncomeBudgetScope: _ctrl.incomeBudgetScope,
                            currentIncomeSourceId: _ctrl.incomeSourceId,
                            currentIncomeJarId: _ctrl.incomeJarId,
                            incomeSourcesOnly: _requiresExistingIncomeSource,
                            onSelected: (incomeBudgetScope, incomeSourceId,
                                incomeJarId) {
                              setState(() {
                                _ctrl.incomeBudgetScope = incomeBudgetScope;
                                _ctrl.incomeSourceId = incomeSourceId;
                                _ctrl.incomeJarId = incomeJarId;
                                if (_requiresExistingIncomeSource) {
                                  final selectedSource = budget.incomeSources
                                      .where((s) => s.id == incomeSourceId);
                                  if (selectedSource.isNotEmpty) {
                                    _applyIncomeSourceDefaults(
                                      selectedSource.first,
                                    );
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      CategorySection(
                        recurringMode: widget.recurringMode,
                        categories: visibleIncomeCategories,
                        selectedId: widget.recurringMode
                            ? (_ctrl.selectedCategoryIds.isEmpty
                                ? null
                                : _ctrl.selectedCategoryIds.first)
                            : _ctrl.selectedIncomeCategoryId,
                        onSelectChange: (id) => setState(() {
                          if (widget.recurringMode) {
                            _ctrl.selectedCategoryIds.clear();
                            if (id != null) _ctrl.selectedCategoryIds.add(id);
                          } else {
                            _ctrl.selectedIncomeCategoryId = id;
                          }
                        }),
                        onAdd: () => _handleAddCategory(
                          budgetScope: _ctrl.incomeJarId.isNotEmpty
                              ? BudgetScope.withinBudget.value
                              : BudgetScope.outsideBudget.value,
                          allocationId: '',
                          linkedWalletId: _ctrl.incomeJarId,
                          existing: visibleIncomeCategories,
                          scope: 'income',
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Date + Time (hidden in recurring mode)
                    if (!widget.recurringMode) ...[
                      DateTimeSection(
                        date: _ctrl.date,
                        time: _ctrl.time,
                        onDateChanged: (d) => setState(() => _ctrl.date = d),
                        onTimeChanged: (t) => setState(() => _ctrl.time = t),
                        onBeforeOpen: _unfocusAmount,
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Notes
                    NotesSection(controller: _ctrl.notesController),
                    const SizedBox(height: 16),

                    // Recurring settings
                    if (widget.recurringMode) ...[
                      RecurringSettingsSection(
                        ctrl: _ctrl,
                        onChanged: () => setState(() {}),
                        allowVariableIncomeToggle:
                            !_requiresExistingIncomeSource,
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Actions
                    ActionsSection(
                      isSaving: _isSaving,
                      canSubmit: _ctrl.canSubmit(
                        recurringMode: widget.recurringMode,
                        subscriptionOnlyMode: widget.subscriptionOnlyMode,
                      ),
                      recurringMode: widget.recurringMode,
                      hasInitialRecurring: widget.initialRecurring != null,
                      hasInitialTransaction:
                          widget.initialTransaction != null,
                      allowDelete: widget.allowDelete,
                      type: _ctrl.type,
                      onSubmit: () async {
                        if (_isSaving) return;
                        setState(() => _isSaving = true);
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
                      onDeleteRecurring: _deleteRecurring,
                      onDeleteTransaction: () async {
                        await widget.cubit.deleteTransaction(
                            widget.initialTransaction!.id);
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                      },
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
}
