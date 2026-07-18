import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../form/_shared/row_card.dart';
import '../form/_shared/shared_amount_field.dart';
import '../form/pickers/wallet_picker_sheet.dart';

// ---------------------------------------------------------------------------
// Step 3 of the Budget Income extraction migration (see Decisions Log).
// IncomeSourceEditorScreen is now the real, dedicated Budget Income editor:
// Identity (icon, color, name, company name) + Financial Defaults (wallet,
// fixed/variable, default amount). Scheduling is intentionally NOT handled
// here yet — a separate section is planned for the next step.
//
// Behavior bridge (temporary, documented): on save this screen still
// produces a RecurringTransactionEntity-shaped result so the three existing
// caller sites (budget_setup_screen.dart x2, budget_tracking_screen.dart x1)
// continue deriving IncomeSourceEntity exactly as before — zero change to
// that derivation logic in this step. companyName/notes are captured in
// local state but have nowhere to persist yet (RecurringTransactionEntity
// has no such fields) — known limitation, to be resolved when the
// ownership flip (IncomeSource as source of truth) is implemented.
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
  late final TextEditingController _nameController;
  late final TextEditingController _companyController;
  late final TextEditingController _amountController;
  final FocusNode _amountFocus = FocusNode();

  late String _iconName;
  late String _iconColorHex;
  late String _walletId;
  late bool _isVariable;

  @override
  void initState() {
    super.initState();
    final r = widget.initialRecurring;
    _nameController = TextEditingController(text: r?.name ?? '');
    // لا يوجد حقل companyName على RecurringTransactionEntity بعد — يبدأ فارغًا
    // دائمًا حاليًا (قيد معروف، راجع التعليق أعلى الملف).
    _companyController = TextEditingController();
    _isVariable = r?.isVariableIncome ?? false;
    _amountController = TextEditingController(
      text: (r == null || _isVariable || r.amount == 0)
          ? ''
          : r.amount.toStringAsFixed(2),
    );
    _iconName = r?.icon ?? 'cash';
    _iconColorHex = r?.iconColor ?? '#2F6F5E';
    final wallets = widget.cubit.state.wallets;
    _walletId = r?.walletId ??
        (wallets.isNotEmpty ? wallets.first.id : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  String _walletName() {
    final wallets = widget.cubit.state.wallets;
    final match = wallets.where((w) => w.id == _walletId).toList();
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
      currentWalletId: _walletId,
      onSelected: (id) {
        if (mounted) setState(() => _walletId = id);
      },
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب اسم مصدر الدخل')),
      );
      return;
    }
    final amount = _isVariable
        ? 0.0
        : (double.tryParse(_amountController.text.trim()) ?? 0);

    final r = widget.initialRecurring;
    final result = RecurringTransactionEntity(
      id: r?.id ?? '',
      name: name,
      type: TransactionType.income.value,
      amount: amount,
      dayOfMonth: r?.dayOfMonth ?? DateTime.now().day.clamp(1, 28),
      executionType: r?.executionType ?? AutomationType.confirm.value,
      walletId: _walletId,
      budgetScope: BudgetScope.withinBudget.value,
      recurrencePattern: r?.recurrencePattern ?? RecurrencePattern.monthly.value,
      icon: _iconName,
      iconColor: _iconColorHex,
      isVariableIncome: _isVariable,
      allocationId: r?.allocationId,
      targetJarId: r?.targetJarId,
      incomeSourceId: r?.incomeSourceId,
      categoryIds: r?.categoryIds ?? const [],
      isActive: r?.isActive ?? true,
    );
    Navigator.of(context).pop(IncomeSourceEditorResult.saved(result));
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
              value: _isVariable,
              onChanged: (v) => setState(() => _isVariable = v),
            ),
            if (!_isVariable) ...[
              const SizedBox(height: 10),
              SharedAmountField(
                controller: _amountController,
                focusNode: _amountFocus,
                label: 'المبلغ الافتراضي',
              ),
            ],
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
