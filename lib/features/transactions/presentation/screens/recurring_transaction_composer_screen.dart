import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../data/subscription_service_presets.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../form/transaction_entry_form.dart';

// ---------------------------------------------------------------------------
// Result type — kept for backward compat with all existing callers that use
// the returnOnSave / Navigator.push<RecurringTransactionComposerResult> pattern
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Screen — thin Scaffold wrapper around TransactionEntryForm.
// Only the lent form is handled here (it is a completely different UX with
// its own fields and submit path — a separate domain concept per the
// Transaction Lifecycle chapter, not part of the shared entry form).
// ---------------------------------------------------------------------------
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
  // ── Lent-mode state (unique to this screen — not in AddTransactionScreen) ─
  late bool _isLentMode;
  final _lentNameController = TextEditingController();
  final _lentAmountController = TextEditingController();
  final _lentNotesController = TextEditingController();
  String _lentWalletId = '';
  DateTime _lentReturnDate =
      DateTime.now().add(const Duration(days: 30));
  bool _lentIsMonthly = false;
  bool _isSaving = false;

  // Subscription preset override fields (applied on top of AddTransactionScreen)
  String? _presetIconName;
  String? _presetIconColor;

  @override
  void initState() {
    super.initState();
    _isLentMode = widget.initialLentMode;
    final state = widget.cubit.state;
    _lentWalletId =
        state.wallets.isNotEmpty ? state.wallets.first.id : '';

    // Apply subscription preset (icon / notes) if provided.
    // AddTransactionScreen will pick up the initialRecurring; preset only
    // matters for brand-new subscriptions where initialRecurring == null.
    if (widget.subscriptionOnlyMode &&
        widget.initialSubscriptionPresetId != null &&
        widget.initialRecurring == null) {
      final preset =
          subscriptionPresetById(widget.initialSubscriptionPresetId);
      if (preset != null) {
        _presetIconName = preset.iconName;
        _presetIconColor = preset.colorHex;
      }
    }
  }

  @override
  void dispose() {
    _lentNameController.dispose();
    _lentAmountController.dispose();
    _lentNotesController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _composerTitle() {
    final isNew = widget.initialRecurring == null;
    if (widget.subscriptionOnlyMode ||
        widget.initialExpensePlanKind ==
            ExpensePlanKind.subscription.value) {
      return isNew ? 'إضافة اشتراك' : 'تعديل اشتراك';
    }
    if (widget.debtOnlyMode ||
        widget.initialExpensePlanKind ==
            ExpensePlanKind.installment.value) {
      if (_isLentMode) return 'سلّفت حد';
      return isNew ? 'إضافة قسط' : 'تعديل قسط';
    }
    if (widget.initialType == TransactionType.income.value) {
      return isNew ? 'إضافة دخل متكرر' : 'تعديل دخل متكرر';
    }
    return isNew ? 'إضافة مصروف متكرر' : 'تعديل مصروف متكرر';
  }

  // Build the initialRecurring to pass to TransactionEntryForm, optionally
  // patched with subscription preset icon/color.
  RecurringTransactionEntity? get _effectiveInitialRecurring {
    final r = widget.initialRecurring;
    if (r != null) return r;
    if (_presetIconName == null) return null;
    // Return a shell entity just to carry the icon/color defaults.
    // TransactionEntryForm reads icon/iconColor from initialRecurring when set.
    return RecurringTransactionEntity(
      id: '',
      name: '',
      type: widget.initialType,
      amount: 0,
      dayOfMonth: DateTime.now().day.clamp(1, 28),
      executionType: AutomationType.confirm.value,
      walletId: widget.cubit.state.wallets.isNotEmpty
          ? widget.cubit.state.wallets.first.id
          : '',
      budgetScope: widget.initialWithinBudget
          ? BudgetScope.withinBudget.value
          : BudgetScope.outsideBudget.value,
      recurrencePattern: RecurrencePattern.monthly.value,
      icon: _presetIconName!,
      iconColor: _presetIconColor ?? '#c65d2e',
      isDebtOrSubscription: true,
      expensePlanKind: ExpensePlanKind.subscription.value,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_composerTitle()),
      ),
      body: SafeArea(
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    // Lent mode: show the self-contained lent form.
    if (_isLentMode) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (widget.debtOnlyMode) ...[
            _debtLentToggle(theme),
            const SizedBox(height: 18),
          ],
          ..._lentFormContent(theme),
        ],
      );
    }

    // All other modes: delegate entirely to the shared entry form.
    return Column(
      children: [
        // Debt/lent toggle (only shown in debtOnlyMode)
        if (widget.debtOnlyMode) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _debtLentToggle(theme),
          ),
        ],
        Expanded(
          child: TransactionEntryForm(
            cubit: widget.cubit,
            recurringMode: true,
            recurringType: widget.initialType,
            initialRecurring: _effectiveInitialRecurring,
            subscriptionOnlyMode: widget.subscriptionOnlyMode,
            debtOnlyMode: widget.debtOnlyMode,
            initialExpensePlanKind: widget.initialExpensePlanKind,
            allowDelete: widget.allowDelete,
            onSaved: widget.returnOnSave
                ? (entity) {
                    Navigator.of(context).pop(
                        RecurringTransactionComposerResult.saved(entity));
                  }
                : null,
            onDeleted: widget.returnOnSave
                ? () {
                    Navigator.of(context).pop(
                        const RecurringTransactionComposerResult.deleted());
                  }
                : null,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEBT / LENT TOGGLE
  // ─────────────────────────────────────────────────────────────────────────

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
                color:
                    selected ? color : theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LENT FORM (unique to this screen)
  // ─────────────────────────────────────────────────────────────────────────

  List<Widget> _lentFormContent(ThemeData theme) {
    const accent = Color(0xFF1A7A4A);
    final wallets = widget.cubit.state.wallets;
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
              child: Icon(Icons.handshake_outlined,
                  color: Colors.white, size: 28),
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

      // المبلغ
      TextField(
        controller: _lentAmountController,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
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
                  value: w.id,
                  child: Text(w.name),
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
            lastDate:
                DateTime.now().add(const Duration(days: 365 * 5)),
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
              'تاريخ الاسترداد المتوقع: '
              '${_lentReturnDate.day}/${_lentReturnDate.month}/${_lentReturnDate.year}',
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
        subtitle: const Text('سيظهر تذكير شهري',
            style: TextStyle(fontSize: 12)),
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
          onPressed: _isSaving ? null : _saveLent,
          icon: const Icon(Icons.check_rounded),
          label: Text(
            _isSaving ? 'جارٍ الحفظ...' : 'تسجيل السلفة',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ),
    ];
  }

  Future<void> _saveLent() async {
    final name = _lentNameController.text.trim();
    final amount =
        double.tryParse(_lentAmountController.text.trim()) ?? 0;
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
}
