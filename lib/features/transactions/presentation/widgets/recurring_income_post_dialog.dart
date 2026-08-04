import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecurringIncomePostDialogResult {
  const RecurringIncomePostDialogResult({
    required this.approved,
    required this.occurrenceDate,
    required this.amount,
  });

  final bool approved;
  final DateTime occurrenceDate;
  final double amount;
}

class RecurringIncomePostDialog extends StatefulWidget {
  const RecurringIncomePostDialog({
    super.key,
    required this.name,
    required this.defaultAmount,
    required this.occurrence,
    required this.allowVariableAmount,
    this.isRetroactivePrompt = false,
    this.isExpense = false,
  });

  final String name;
  final double defaultAmount;
  final DateTime occurrence;
  final bool allowVariableAmount;
  final bool isRetroactivePrompt;

  /// When true, the dialog renders expense-flavored copy and accent color
  /// while reusing the exact same manual-posting flow used for income.
  final bool isExpense;

  static Future<RecurringIncomePostDialogResult?> show(
    BuildContext context, {
    required String name,
    required double defaultAmount,
    required DateTime occurrence,
    required bool allowVariableAmount,
    bool isRetroactivePrompt = false,
    bool isExpense = false,
  }) {
    return showDialog<RecurringIncomePostDialogResult>(
      context: context,
      builder: (context) => RecurringIncomePostDialog(
        name: name,
        defaultAmount: defaultAmount,
        occurrence: occurrence,
        allowVariableAmount: allowVariableAmount,
        isRetroactivePrompt: isRetroactivePrompt,
        isExpense: isExpense,
      ),
    );
  }

  @override
  State<RecurringIncomePostDialog> createState() =>
      _RecurringIncomePostDialogState();
}

class _RecurringIncomePostDialogState extends State<RecurringIncomePostDialog> {
  late DateTime _selectedDate;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.occurrence.year,
      widget.occurrence.month,
      widget.occurrence.day,
    );
    _amountController = TextEditingController(
      text: widget.defaultAmount > 0
          ? widget.defaultAmount.toStringAsFixed(
              widget.defaultAmount.truncateToDouble() == widget.defaultAmount
                  ? 0
                  : 2,
            )
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'تاريخ المعاملة',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل مبلغًا صحيحًا')),
      );
      return;
    }
    Navigator.of(context).pop(
      RecurringIncomePostDialogResult(
        approved: true,
        occurrenceDate: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          12,
        ),
        amount: amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = widget.isExpense
        ? const Color(0xFFC65D2E)
        : const Color(0xFF2F6F5E);
    final kindLabel = widget.isExpense ? 'المصروف' : 'الدخل';
    final dateLabel = DateFormat('EEEE d MMMM yyyy', 'ar').format(_selectedDate);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(
        widget.isRetroactivePrompt
            ? 'تسجيل دفعة سابقة؟'
            : 'تسجيل معاملة $kindLabel',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.isRetroactivePrompt
                  ? 'يوجد استحقاق سابق لـ "${widget.name}" لم يُسجّل بعد. هل تريد إنشاء المعاملة بتاريخ يمكنك تعديله؟'
                  : 'سجّل معاملة لهذا $kindLabel المتكرر وعدّل التاريخ إذا احتجت.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            if (widget.allowVariableAmount || widget.defaultAmount <= 0) ...[
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'المبلغ',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_month_outlined),
              label: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  dateLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            RecurringIncomePostDialogResult(
              approved: false,
              occurrenceDate: _selectedDate,
              amount: widget.defaultAmount,
            ),
          ),
          child: Text(widget.isRetroactivePrompt ? 'لاحقًا' : 'إلغاء'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: Text(widget.isRetroactivePrompt ? 'نعم، سجّل' : 'تسجيل'),
        ),
      ],
    );
  }
}
