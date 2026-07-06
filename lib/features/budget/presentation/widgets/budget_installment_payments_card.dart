// BudgetInstallmentPaymentsCard
//
// Purpose: An expandable card showing the current and next installment payment
// rows for a debt inside the debt details bottom sheet. Allows the user to
// pay each installment via action buttons.
//
// Responsibility: UI with local expand/collapse state. Payment actions are
// delegated to the screen via [onPayCurrent] and [onPayNext] callbacks.
// No business logic, no financial calculations, no Cubit calls.
//
// Dependencies: Flutter Material, DebtEntity, RecurringTransactionEntity, intl.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_InstallmentPaymentsCard) to reduce file size and isolate this UI section.
//
// Must never: Modify installment logic, rewrite payment order, change
// financial values, or call Cubit methods directly.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/budget_setup_entity.dart';

class BudgetInstallmentPaymentsCard extends StatefulWidget {
  const BudgetInstallmentPaymentsCard({
    super.key,
    required this.theme,
    required this.debt,
    required this.recurring,
    required this.installmentAmt,
    required this.currentPaid,
    required this.nextPaid,
    required this.showNextPayment,
    required this.dueDate,
    required this.onPayCurrent,
    required this.onPayNext,
  });

  final ThemeData theme;
  final DebtEntity debt;
  final RecurringTransactionEntity recurring;
  final double installmentAmt;
  final bool currentPaid;
  final bool nextPaid;
  final bool showNextPayment;
  final DateTime dueDate;
  final VoidCallback onPayCurrent;
  final VoidCallback onPayNext;

  @override
  State<BudgetInstallmentPaymentsCard> createState() =>
      _BudgetInstallmentPaymentsCardState();
}

class _BudgetInstallmentPaymentsCardState
    extends State<BudgetInstallmentPaymentsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    const accent = Color(0xFFC65D2E);
    final now = DateTime.now();
    final nextMonth = DateTime(
      now.year,
      now.month + 1,
      widget.debt.executionDay.clamp(1, 28),
    );

    return Container(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          // رأس القسم
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.credit_card_rounded,
                        color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'دفعات هذه الدورة',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // المحتوى القابل للتوسع
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _expandedContent(theme, accent, nextMonth),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _expandedContent(
      ThemeData theme, Color accent, DateTime nextMonth) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── الدفعة الحالية ─────────────────────────────────────
          _paymentRow(
            theme: theme,
            label: widget.showNextPayment ? 'الدفعة الحالية' : 'دفعة واحدة',
            date: DateFormat('d MMMM yyyy', 'ar').format(widget.dueDate),
            amount: widget.installmentAmt,
            isPaid: widget.currentPaid,
            buttonLabel: 'دفع الآن',
            onPay: widget.currentPaid ? null : widget.onPayCurrent,
          ),
          if (widget.showNextPayment) ...[
            const SizedBox(height: 10),
            _paymentRow(
              theme: theme,
              label: 'الدفعة القادمة',
              date: DateFormat('d MMMM yyyy', 'ar').format(nextMonth),
              amount: widget.installmentAmt,
              isPaid: widget.nextPaid,
              buttonLabel: 'تسديد الآن',
              onPay: widget.nextPaid ? null : widget.onPayNext,
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentRow({
    required ThemeData theme,
    required String label,
    required String date,
    required double amount,
    required bool isPaid,
    required String buttonLabel,
    required VoidCallback? onPay,
  }) {
    const accent = Color(0xFFC65D2E);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPaid
            ? Colors.green.withValues(alpha: 0.07)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid
              ? Colors.green.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPaid
                  ? Colors.green.withValues(alpha: 0.12)
                  : accent.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPaid
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isPaid ? Colors.green : accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount.toStringAsFixed(2),
            style:
                const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          if (!isPaid && onPay != null) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onPay,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800),
              ),
              child: Text(buttonLabel),
            ),
          ] else if (isPaid) ...[
            const SizedBox(width: 8),
            Text(
              'مدفوعة ✓',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
