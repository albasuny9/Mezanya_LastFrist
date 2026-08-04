import 'package:flutter/material.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/transaction_entity.dart';

// ---------------------------------------------------------------------------
// Plain state container — no ChangeNotifier, no business logic.
// The form widget holds one of these and calls setState() on mutations.
// ---------------------------------------------------------------------------
class TransactionFormController {
  TransactionFormController._({
    required this.type,
    required this.budgetScope,
    required this.incomeBudgetScope,
    required this.walletId,
    required this.budgetTargetId,
    required this.incomeSourceId,
    required this.incomeJarId,
    required this.date,
    required this.time,
    this.selectedCategoryId,
    this.selectedIncomeCategoryId,
    required this.recurrencePattern,
    required this.recurringIconName,
    required this.recurringIconColor,
    required this.executionType,
    required this.expensePlanKind,
    required this.isDebtOrSubscription,
    required this.isVariableIncome,
    required this.firstPaymentDate,
    required this.reminderLeadDays,
    required this.scheduledTime,
    required this.selectedWeekdays,
    required this.selectedCategoryIds,
    required this.monthlyDay,
    required this.yearlyMonth,
    required this.yearlyDay,
    required this.amountController,
    required this.notesController,
    required this.recurringNameController,
    required this.newCategoryController,
    required this.debtPrincipalController,
    required this.installmentCountController,
    required this.downPaymentController,
  });

  // ── Basic transaction state ──────────────────────────────────────────────
  String type;
  String budgetScope;
  String incomeBudgetScope;
  String walletId;
  String budgetTargetId;
  String incomeSourceId;
  String incomeJarId;
  DateTime date;
  TimeOfDay time;
  String? selectedCategoryId;
  String? selectedIncomeCategoryId;

  // ── Recurring state ──────────────────────────────────────────────────────
  String recurrencePattern;
  String recurringIconName;
  String recurringIconColor;
  String executionType;
  String expensePlanKind;
  bool isDebtOrSubscription;
  bool isVariableIncome;
  DateTime firstPaymentDate;
  int reminderLeadDays;
  TimeOfDay scheduledTime;
  final Set<int> selectedWeekdays;
  final Set<String> selectedCategoryIds;
  int monthlyDay;
  int yearlyMonth;
  int yearlyDay;

  // ── Text controllers ─────────────────────────────────────────────────────
  final TextEditingController amountController;
  final TextEditingController notesController;
  final TextEditingController recurringNameController;
  final TextEditingController newCategoryController;
  final TextEditingController debtPrincipalController;
  final TextEditingController installmentCountController;
  final TextEditingController downPaymentController;

  // ── Focus nodes ───────────────────────────────────────────────────────────
  final FocusNode amountFocusNode = FocusNode();

  // ── Computed: pattern helpers ─────────────────────────────────────────────
  bool get isWeekPattern =>
      recurrencePattern == RecurrencePattern.weekly.value ||
      recurrencePattern == RecurrencePattern.biweekly.value ||
      recurrencePattern == RecurrencePattern.every3Weeks.value;

  bool get isMonthPattern =>
      recurrencePattern == RecurrencePattern.monthly.value ||
      recurrencePattern == RecurrencePattern.every2Months.value ||
      recurrencePattern == RecurrencePattern.every3Months.value ||
      recurrencePattern == RecurrencePattern.every6Months.value;

  bool get isExpenseInstallment =>
      expensePlanKind == ExpensePlanKind.installment.value;

  bool get isExpenseSubscription =>
      expensePlanKind == ExpensePlanKind.subscription.value;

  bool get showAmount =>
      !(type == TransactionType.income.value && isVariableIncome);

  bool get showRecurrenceDetails =>
      !(type == TransactionType.income.value && isVariableIncome);

  bool get withinBudgetExpense =>
      budgetScope == BudgetScope.withinBudget.value;

  bool get withinBudgetIncome =>
      incomeBudgetScope == BudgetScope.withinBudget.value;

  // ── Computed: installment math ────────────────────────────────────────────
  double get totalPrincipal =>
      double.tryParse(debtPrincipalController.text.trim()) ?? 0;

  int get installmentCount =>
      int.tryParse(installmentCountController.text.trim()) ?? 0;

  double get downPayment =>
      double.tryParse(downPaymentController.text.trim()) ?? 0;

  double get calculatedInstallment {
    final n = installmentCount;
    if (n <= 0) return 0;
    final net = totalPrincipal - downPayment;
    if (net <= 0) return 0;
    return net / n;
  }

  double get enteredInstallment =>
      double.tryParse(amountController.text.trim()) ?? 0;

  double get ribaAmount {
    final calc = calculatedInstallment;
    if (calc <= 0) return 0;
    final diff = enteredInstallment - calc;
    return diff > 0 ? diff : 0;
  }

  // ── Validation ────────────────────────────────────────────────────────────
  bool canSubmit({
    required bool recurringMode,
    required bool subscriptionOnlyMode,
  }) {
    if (walletId.isEmpty) return false;

    if (recurringMode) {
      if (isExpenseInstallment) return enteredInstallment > 0;
      if (showAmount) {
        final amt = double.tryParse(amountController.text.trim()) ?? 0;
        if (amt < 0) return false;
        if (amt == 0 && !isExpenseSubscription && !subscriptionOnlyMode) {
          return false;
        }
      }
      if (showRecurrenceDetails && isWeekPattern && selectedWeekdays.isEmpty) {
        return false;
      }
      if (type == TransactionType.expense.value &&
          withinBudgetExpense &&
          !isDebtOrSubscription &&
          budgetTargetId.isEmpty) {
        return false;
      }
      return true;
    }

    // Normal transaction mode
    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) return false;
    if (type == TransactionType.expense.value &&
        budgetScope == BudgetScope.withinBudget.value &&
        budgetTargetId.isEmpty) {
      return false;
    }
    if (type == TransactionType.income.value &&
        incomeBudgetScope == BudgetScope.withinBudget.value &&
        incomeSourceId == 'wallet-only' &&
        incomeJarId.isEmpty) {
      return false;
    }
    return true;
  }

  void dispose() {
    amountFocusNode.dispose();
    amountController.dispose();
    notesController.dispose();
    recurringNameController.dispose();
    newCategoryController.dispose();
    debtPrincipalController.dispose();
    installmentCountController.dispose();
    downPaymentController.dispose();
  }

  // ── Factory: initialize from entry-point widget params ────────────────────
  factory TransactionFormController.create({
    required List<WalletEntity> wallets,
    required bool recurringMode,
    String? recurringType,
    RecurringTransactionEntity? initialRecurring,
    TransactionEntity? initialTransaction,
    bool subscriptionOnlyMode = false,
    bool debtOnlyMode = false,
    String? initialExpensePlanKind,
  }) {
    // Defaults
    String type = TransactionType.expense.value;
    String budgetScope = BudgetScope.outsideBudget.value;
    String incomeBudgetScope = BudgetScope.outsideBudget.value;
    String walletId = wallets.isNotEmpty ? wallets.first.id : '';
    String budgetTargetId = '';
    String incomeSourceId = 'wallet-only';
    String incomeJarId = '';
    DateTime date = DateTime.now();
    TimeOfDay time = TimeOfDay.now();
    String? selectedCategoryId;
    String? selectedIncomeCategoryId;

    // Recurring defaults
    String recurrencePattern = RecurrencePattern.monthly.value;
    String recurringIconName = 'category';
    String recurringIconColor = '#c65d2e';
    String executionType = AutomationType.confirm.value;
    String expensePlanKind = 'normal';
    bool isDebtOrSubscription = false;
    bool isVariableIncome = false;
    DateTime firstPaymentDate = DateTime.now().add(const Duration(days: 1));
    int reminderLeadDays = 0;
    TimeOfDay scheduledTime = const TimeOfDay(hour: 9, minute: 0);
    final selectedWeekdays = <int>{DateTime.now().weekday};
    final selectedCategoryIds = <String>{};
    int monthlyDay = DateTime.now().day.clamp(1, 28);
    int yearlyMonth = DateTime.now().month;
    int yearlyDay = DateTime.now().day.clamp(1, 28);

    // Controllers
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    final recurringNameController = TextEditingController();
    final newCategoryController = TextEditingController();
    final debtPrincipalController = TextEditingController();
    final installmentCountController = TextEditingController();
    final downPaymentController = TextEditingController();

    // ── Recurring mode init ───────────────────────────────────────────────
    if (recurringMode) {
      type = recurringType ?? TransactionType.expense.value;

      if (subscriptionOnlyMode) {
        type = TransactionType.expense.value;
        expensePlanKind =
            initialExpensePlanKind ?? ExpensePlanKind.subscription.value;
        isDebtOrSubscription = true;
      }
      if (debtOnlyMode) {
        type = TransactionType.expense.value;
        expensePlanKind =
            initialExpensePlanKind ?? ExpensePlanKind.installment.value;
        isDebtOrSubscription = true;
      }

      final r = initialRecurring;
      if (r != null) {
        type = r.type;
        walletId = r.walletId;
        amountController.text =
            r.amount <= 0 ? '' : r.amount.toStringAsFixed(2);
        notesController.text = r.notes ?? '';
        recurringNameController.text = r.name;
        recurrencePattern = r.recurrencePattern;
        recurringIconName = r.icon;
        recurringIconColor = r.iconColor;
        budgetScope = r.budgetScope;
        incomeBudgetScope = r.budgetScope;
        incomeSourceId = r.incomeSourceId ?? incomeSourceId;
        incomeJarId = r.targetJarId ?? '';

        if (r.allocationId != null) {
          budgetTargetId = 'alloc:${r.allocationId!}';
          budgetScope = BudgetScope.withinBudget.value;
        } else if (r.targetJarId != null &&
            r.type == TransactionType.expense.value) {
          budgetTargetId = 'jar:${r.targetJarId!}';
          budgetScope = BudgetScope.outsideBudget.value;
        }

        date = DateTime(date.year, date.month, r.dayOfMonth.clamp(1, 28));
        executionType = r.executionType;
        expensePlanKind =
            r.expensePlanKind ?? initialExpensePlanKind ?? 'normal';
        isDebtOrSubscription = r.isDebtOrSubscription;
        isVariableIncome = r.isVariableIncome;
        monthlyDay = r.dayOfMonth.clamp(1, 28);
        yearlyDay = r.dayOfMonth.clamp(1, 28);
        yearlyMonth = (r.monthOfYear ?? DateTime.now().month).clamp(1, 12);
        reminderLeadDays = r.reminderLeadDays ?? 0;
        selectedCategoryIds.addAll(r.categoryIds);

        selectedWeekdays.clear();
        selectedWeekdays.addAll(
          r.weekdays.isNotEmpty
              ? r.weekdays
              : r.weekday != null
                  ? <int>{r.weekday!}
                  : <int>{DateTime.now().weekday},
        );

        scheduledTime = _parseStoredTime(r.scheduledTime);

        final anchor =
            r.anchorDate != null ? DateTime.tryParse(r.anchorDate!) : null;
        if (anchor != null) firstPaymentDate = anchor;

        final principal = r.debtPrincipalTotal;
        debtPrincipalController.text =
            principal != null && principal > 0
                ? principal.toStringAsFixed(2)
                : '';
        installmentCountController.text =
            r.installmentCount != null && r.installmentCount! > 0
                ? r.installmentCount.toString()
                : '';
        final downPay = r.installmentDownPayment;
        downPaymentController.text =
            downPay != null && downPay > 0 ? downPay.toStringAsFixed(2) : '';
      } else {
        // New recurring — defaults by type
        recurringIconName =
            type == TransactionType.income.value ? 'cash' : 'category';
        recurringIconColor =
            type == TransactionType.income.value ? '#0f9d7a' : '#c65d2e';
      }

      if (type == TransactionType.income.value && isVariableIncome) {
        executionType = 'manual';
      }
    }

    // ── Normal transaction init ───────────────────────────────────────────
    final t = initialTransaction;
    if (t != null) {
      type = t.type;
      date = t.createdAt;
      time = TimeOfDay(hour: t.createdAt.hour, minute: t.createdAt.minute);
      walletId = t.walletId ?? walletId;
      amountController.text = t.amount.toStringAsFixed(2);
      notesController.text = t.notes ?? '';
      incomeSourceId = t.incomeSourceId ?? incomeSourceId;

      if (t.type == TransactionType.expense.value) {
        budgetScope = t.budgetScope ?? BudgetScope.outsideBudget.value;
        if (t.allocationId != null) {
          budgetTargetId = 'alloc:${t.allocationId!}';
        } else if (t.toWalletId != null) {
          budgetTargetId = 'jar:${t.toWalletId!}';
        }
      }
      if (t.type == TransactionType.income.value) {
        incomeBudgetScope =
            t.budgetScope == BudgetScope.withinBudget.value
                ? BudgetScope.withinBudget.value
                : BudgetScope.outsideBudget.value;
        incomeJarId = t.toWalletId ?? '';
        selectedIncomeCategoryId = t.categoryId;
      } else {
        selectedCategoryId = t.categoryId;
      }
      if (incomeJarId.isEmpty && t.toWalletId != null) {
        incomeJarId = t.toWalletId!;
      }
    }

    return TransactionFormController._(
      type: type,
      budgetScope: budgetScope,
      incomeBudgetScope: incomeBudgetScope,
      walletId: walletId,
      budgetTargetId: budgetTargetId,
      incomeSourceId: incomeSourceId,
      incomeJarId: incomeJarId,
      date: date,
      time: time,
      selectedCategoryId: selectedCategoryId,
      selectedIncomeCategoryId: selectedIncomeCategoryId,
      recurrencePattern: recurrencePattern,
      recurringIconName: recurringIconName,
      recurringIconColor: recurringIconColor,
      executionType: executionType,
      expensePlanKind: expensePlanKind,
      isDebtOrSubscription: isDebtOrSubscription,
      isVariableIncome: isVariableIncome,
      firstPaymentDate: firstPaymentDate,
      reminderLeadDays: reminderLeadDays,
      scheduledTime: scheduledTime,
      selectedWeekdays: selectedWeekdays,
      selectedCategoryIds: selectedCategoryIds,
      monthlyDay: monthlyDay,
      yearlyMonth: yearlyMonth,
      yearlyDay: yearlyDay,
      amountController: amountController,
      notesController: notesController,
      recurringNameController: recurringNameController,
      newCategoryController: newCategoryController,
      debtPrincipalController: debtPrincipalController,
      installmentCountController: installmentCountController,
      downPaymentController: downPaymentController,
    );
  }

  // ── Time formatting helpers (used during init) ────────────────────────────
  static TimeOfDay _parseStoredTime(String? value) {
    if (value == null || !value.contains(':')) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 9;
    final minute = int.tryParse(parts.last) ?? 0;
    return TimeOfDay(
        hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  static String formatTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
