import 'package:flutter/material.dart';

import '../../../../../core/constants/transaction_types.dart';

/// Delete + submit buttons at the bottom of the form.
class ActionsSection extends StatelessWidget {
  const ActionsSection({
    super.key,
    required this.isSaving,
    required this.canSubmit,
    required this.recurringMode,
    required this.hasInitialRecurring,
    required this.hasInitialTransaction,
    required this.allowDelete,
    required this.type,
    required this.onSubmit,
    required this.onDeleteRecurring,
    required this.onDeleteTransaction,
  });

  final bool isSaving;
  final bool canSubmit;
  final bool recurringMode;
  final bool hasInitialRecurring;
  final bool hasInitialTransaction;
  final bool allowDelete;
  final String type;
  final VoidCallback onSubmit;
  final VoidCallback onDeleteRecurring;
  final VoidCallback onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Delete recurring
        if (recurringMode && hasInitialRecurring && allowDelete)
          TextButton.icon(
            onPressed: onDeleteRecurring,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف المعاملة'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),

        // Delete normal transaction
        if (!recurringMode && hasInitialTransaction)
          TextButton(
            onPressed: onDeleteTransaction,
            child: Text(
              'حذف المعاملة',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.error),
            ),
          ),

        // Submit
        FilledButton(
          onPressed: (isSaving || !canSubmit) ? null : onSubmit,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            isSaving
                ? 'جارٍ الحفظ...'
                : recurringMode
                    ? (hasInitialRecurring
                        ? 'تحديث التكرار'
                        : 'حفظ المعاملة المتكررة')
                    : hasInitialTransaction
                        ? 'حفظ التعديل'
                        : (type == TransactionType.income.value
                            ? 'تسجيل الدخل'
                            : 'تسجيل المعاملة'),
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
