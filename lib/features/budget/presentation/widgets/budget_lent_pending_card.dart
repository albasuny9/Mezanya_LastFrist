// BudgetLentPendingCard
//
// Purpose: Displays pending (unsettled) lent entries for a specific person
// inside the lent details bottom sheet, including count, overdue count,
// total pending amount, and a preview of the first three entries.
//
// Responsibility: Pure UI — reads data from [person.lentEntries] and renders
// a styled card. No business logic, no Cubit mutations.
//
// Dependencies: Flutter Material, RecurringTransactionEntity, AppCubit.
//
// Why this file exists: Extracted from budget_tracking_screen.dart
// (_BudgetLentPendingCard) to reduce file size and isolate this UI section.
//
// Must never: Modify lent entries, call financial calculations, change
// serialization, or rewrite the pending/overdue logic.

import 'package:flutter/material.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/recurring_transaction_entity.dart';

class BudgetLentPendingCard extends StatelessWidget {
  const BudgetLentPendingCard({
    super.key,
    required this.theme,
    required this.accent,
    required this.person,
    required this.cubit,
    required this.sheetCtx,
  });

  final ThemeData theme;
  final Color accent;
  final RecurringTransactionEntity person;
  final AppCubit cubit;
  final BuildContext sheetCtx;

  @override
  Widget build(BuildContext context) {
    final pendingEntries = person.lentEntries
        .where((entry) => entry['isSettled'] != true)
        .toList();
    final pendingCount = pendingEntries.length;
    final overdueCount = pendingEntries.where((entry) {
      final date =
          DateTime.tryParse(entry['expectedReturnDate'] as String? ?? '');
      return date != null && date.isBefore(DateTime.now());
    }).length;
    final totalPending = pendingEntries.fold<double>(0, (sum, entry) {
      final amount = entry['amount'];
      if (amount is num) return sum + amount.toDouble();
      if (amount is String) return sum + (double.tryParse(amount) ?? 0);
      return sum;
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'السلفات المعلقة',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (overdueCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFC65D2E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'متأخر $overdueCount',
                    style: const TextStyle(
                      color: Color(0xFFC65D2E),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$pendingCount سلفة معلقة · غير مسترد ${totalPending.toStringAsFixed(2)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (pendingEntries.isNotEmpty) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: pendingEntries.take(3).map((entry) {
                final amount = entry['amount'];
                final amountText = amount is num
                    ? amount.toStringAsFixed(2)
                    : (amount is String ? amount : '0.00');
                final retDate = entry['expectedReturnDate'] as String?;
                final dateText = retDate != null && retDate.isNotEmpty
                    ? 'استحقاق ${retDate.split('T').first}'
                    : 'بدون موعد';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.pending_outlined,
                        size: 18,
                        color: Color(0xFF165B47),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$amountText ج.م · $dateText',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
