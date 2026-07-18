import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../form/_shared/row_card.dart';
import '../form/_shared/shared_amount_field.dart';
import '../form/pickers/wallet_picker_sheet.dart';
import '../form/sections/scheduling_section.dart';
import '../form/transaction_form_controller.dart';

// ---------------------------------------------------------------------------
// Steps 1, 3 & 4 of the Budget Income extraction migration (see Decisions Log).
// IncomeSourceEditorScreen — the dedicated Budget Income editor:
//   1. Identity        (icon, color, name, company name)
//   2. Financial Defaults (wallet, fixed/variable, default amount)
//   3. Scheduling       (recurrence, execution policy, reminder — reused
//                        as-is from the shared TransactionFormController /
//                        SchedulingSection, zero behavior change)
//
// Behavior bridge (temporary, documented — unchanged from Step 3): on save
// this screen still produces a RecurringTransactionEntity-shaped result so
// the three existing caller sites continue deriving IncomeSourceEntity
// exactly as before. companyName/notes remain captured locally with no
// persistence target yet (known limitation, unchanged from Step 3).
//
// Scheduling state lives entirely inside a real TransactionFormController
// instance (via TransactionFormController.create) so SchedulingSection —
// and the field-derivation logic on save — are the EXACT same code used by
// the normal recurring-transaction flow. No scheduling logic is duplicated
// or reimplemented here.
// ---------------------------------------------------------------------------

class IncomeSourceEditorResult {
  const IncomeSourceEditorResult._({
    this.recurring,
    this.deleteRequested = false,
  });

  const IncomeSourceEditorResult.saved(RecurringTransactionEntity recurring)
      : this._(recurring: recurring);

  const IncomeSourceEditorResult.deleted() : this._(deleteRequested: true);

  final RecurringTransactionEntity? recurring;
  final bool deleteRequested;
}

class IncomeSourceEditorScreen extends StatefulWidget {
  const IncomeSourceEditorScreen({
    super.key,
    required this.cubit,
    this.initialRecurring,
    this.allowDelete = false,
  });

  final AppCubit cubit;
  final RecurringTransactionEntity? initialRecurring;
  final bool allowDelete;

  @override
  State<IncomeSourceEditorScreen> createState() =>
      _IncomeSourceEditorScreenState();
}

class _IncomeSourceEditorScreenState extends State<IncomeSourceEditorScreen> {
  // Identity (owned locally by this screen — not part of the shared
  // recurring-transaction controller, per the Step 3 ownership split).
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late String _iconName;
  late String _iconColorHex;

  // Financial Defaults + Scheduling — both live on a real
  // TransactionFormController so all scheduling UI/logic is 100% shared,
  // zero duplication.
  late final TransactionFormController _ctrl;
  final FocusNode _amountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecurring;
    _nameController = TextEditingController(text: r?.name ?? '');
    // لا يوجد حقل companyName على RecurringTransactionEntity بعد — يبدأ فارغًا
    // دائمًا حاليًا (قيد معروف، راجع التعليق أعلى الملف).
    _companyController = TextEditingController();
    _iconName = r?.icon ?? 'cash';
    _iconColorHex = r?.iconColor ?? '#2F6F5E';

    _ctrl = TransactionFormController.create(
      wallets: widget.cubit.state.wallets,
      recurringMode: true,
      recurringType: TransactionType.income.value,
      initialRecurring: r,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _amountFocus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  String _walletName() {
    final wallets = widget.cubit.state.wallets;
    final match = wallets.where((w) => w.id == _ctrl.walletId).toList();
    return match.isNotEmpty ? match.first.name : 'اختر محفظة';
  }

  Future<void> _pickIcon() async {
    final result = await AppIconPickerDialog.show(
      context,
      initialIconName: _iconName,
      initialColorHex: _iconColorHex,
      title: 'أيقونة مصدر الدخل',
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
    );
    if (result != null && mounted) {
      setState(() {
        _iconName = result.iconName;
        _iconColorHex = result.colorHex;
      });
    }
  }

  void _pickWallet() {
    showWalletPickerSheet(
      context,
      wallets: widget.cubit.state.wallets,
      currentWalletId: _ctrl.walletId,
      onSelected: (id) {
        if (mounted) setState(() => _ctrl.walletId = id);
      },
    );
  }

  // نفس منطق اشتقاق حقول الجدولة الموجود في TransactionEntryForm._submitRecurring
  // (فرع الدخل تحديدًا) — بلا أي تغيير في السلوك أو إعادة تنفيذ منطق مختلف.
  RecurringTransactionEntity _buildResult() {
    final amount = _ctrl.showAmount
        ? (double.tryParse(_ctrl.amountController.text.trim()) ?? 0)
        : 0.0;

    final effectivePattern = _ctrl.isVariableIncome
        ? RecurrencePattern.manualVariable.value
        : _ctrl.recurrencePattern;
    final effectiveExecutionType =
        _ctrl.isVariableIncome ? 'manual' : _ctrl.executionType;
    final effectiveDayOfMonth =
        _ctrl.recurrencePattern == RecurrencePattern.yearly.value
            ? _ctrl.yearlyDay
            : (_ctrl.isMonthPattern ? _ctrl.monthlyDay : 1);

    return RecurringTransactionEntity(
      id: widget.initialRecurring?.id ??
          'rec-${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      type: TransactionType.income.value,
      amount: amount,
      dayOfMonth: effectiveDayOfMonth,
      executionType: effectiveExecutionType,
      walletId: _ctrl.walletId == 'no-wallet' ? '' : _ctrl.walletId,
      budgetScope: BudgetScope.withinBudget.value,
      recurrencePattern: effectivePattern,
      icon: _iconName,
      iconColor: _iconColorHex,
      weekday:
          _ctrl.selectedWeekdays.isEmpty ? null : _ctrl.selectedWeekdays.first,
      weekdays: _ctrl.selectedWeekdays.toList()..sort(),
      monthOfYear: _ctrl.recurrencePattern == RecurrencePattern.yearly.value
          ? _ctrl.yearlyMonth
          : null,
      anchorDate: widget.initialRecurring?.anchorDate,
      scheduledTime: _ctrl.showRecurrenceDetails
          ? TransactionFormController.formatTime(_ctrl.scheduledTime)
          : null,
      reminderLeadDays: effectiveExecutionType == AutomationType.confirm.value
          ? _ctrl.reminderLeadDays
          : null,
      incomeSourceId: widget.initialRecurring?.incomeSourceId,
      categoryIds: _ctrl.selectedCategoryIds.toList(),
      isVariableIncome: _ctrl.isVariableIncome,
      isActive: widget.initialRecurring?.isActive ?? true,
    );
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم مصدر الدخل')),
      );
      return;
    }
    Navigator.of(context)
        .pop(IncomeSourceEditorResult.saved(_buildResult()));
  }

  void _delete() {
    Navigator.of(context).pop(const IncomeSourceEditorResult.deleted());
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initialRecurring == null;
    final theme = Theme.of(context);
    final iconColor = Color(
      int.parse(_iconColorHex.replaceFirst('#', '0xFF')),
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isNew ? 'إضافة دخل' : 'تعديل دخل'),
        actions: [
          if (widget.allowDelete && !isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ── Identity ───────────────────────────────────────────────
            const _SectionLabel('الهوية'),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: _pickIcon,
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: iconColor.withValues(alpha: 0.15),
                  child: Icon(
                    AppIconPickerDialog.iconDataForName(_iconName),
                    color: iconColor,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'اسم مصدر الدخل',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _companyController,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                labelText: 'اسم الجهة (اختياري)',
              ),
            ),
            const SizedBox(height: 24),

            // ── Financial Defaults ────────────────────────────────────
            const _SectionLabel('الإعدادات المالية الافتراضية'),
            const SizedBox(height: 10),
            FormRowCard(
              label: 'المحفظة الافتراضية',
              value: _walletName(),
              icon: Icons.account_balance_wallet_outlined,
              onTap: _pickWallet,
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('دخل متغيّر'),
              subtitle: const Text('المبلغ يختلف كل مرة، لا يوجد مبلغ ثابت'),
              value: _ctrl.isVariableIncome,
              onChanged: (v) {
                setState(() {
                  _ctrl.isVariableIncome = v;
                  if (v) {
                    _ctrl.executionType = 'manual';
                    _ctrl.amountController.clear();
                  }
                });
              },
            ),
            if (_ctrl.showAmount) ...[
              const SizedBox(height: 10),
              SharedAmountField(
                controller: _ctrl.amountController,
                focusNode: _amountFocus,
                label: 'المبلغ الافتراضي',
              ),
            ],
            const SizedBox(height: 24),

            // ── Scheduling ─────────────────────────────────────────────
            const _SectionLabel('الجدولة'),
            const SizedBox(height: 10),
            SchedulingSection(
              ctrl: _ctrl,
              onChanged: () => setState(() {}),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
    );
  }
}
