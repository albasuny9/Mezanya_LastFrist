import 'package:flutter/material.dart';

import '../transaction_form_controller.dart';

/// Amount input area.
/// In normal mode: large centered amount field.
/// In recurring installment mode: principal + count + down-payment + installment
/// amount (with riba warning).
class AmountSection extends StatelessWidget {
  const AmountSection({
    super.key,
    required this.ctrl,
    required this.recurringMode,
  });

  final TransactionFormController ctrl;
  final bool recurringMode;

  @override
  Widget build(BuildContext context) {
    if (!recurringMode || ctrl.showAmount) {
      if (!recurringMode || !ctrl.isExpenseInstallment) {
        return _AmountField(controller: ctrl.amountController);
      }
    }

    if (recurringMode && ctrl.isExpenseInstallment) {
      return _InstallmentFields(ctrl: ctrl);
    }

    return const SizedBox.shrink();
  }
}

// ── Large centred amount field ─────────────────────────────────────────────
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
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
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

// ── Installment fields block ───────────────────────────────────────────────
class _InstallmentFields extends StatelessWidget {
  const _InstallmentFields({required this.ctrl});
  final TransactionFormController ctrl;

  @override
  Widget build(BuildContext context) {
    final calcInstallment = ctrl.calculatedInstallment;
    final hasCalc = calcInstallment > 0;
    final riba = ctrl.ribaAmount;
    final hasRiba = riba > 0.005;

    return Column(
      children: [
        TextField(
          controller: ctrl.debtPrincipalController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'المبلغ الإجمالي',
            helperText: 'السعر الأصلي للمنتج أو قيمة الدين الكامل',
            prefixIcon: Icon(Icons.account_balance_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl.installmentCountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'عدد الأقساط',
            prefixIcon: Icon(Icons.format_list_numbered_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl.downPaymentController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'المقدم',
            prefixIcon: Icon(Icons.monetization_on_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl.amountController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'القسط الشهري',
            helperText: hasCalc
                ? 'المحسوب: ${calcInstallment.toStringAsFixed(2)}'
                : 'أدخل المبلغ الإجمالي والعدد أولاً',
            prefixIcon: const Icon(Icons.payments_rounded),
            suffixIcon: hasCalc
                ? Builder(builder: (ctx) {
                    return IconButton(
                      icon: const Icon(Icons.calculate_rounded, size: 18),
                      tooltip: 'تطبيق المبلغ المحسوب',
                      onPressed: () {
                        ctrl.amountController.text =
                            calcInstallment.toStringAsFixed(2);
                      },
                    );
                  })
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
                    ' (${(riba * ctrl.installmentCount).toStringAsFixed(2)} إجمالي)',
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
  }
}
