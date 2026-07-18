import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../form/transaction_entry_form.dart';

// ---------------------------------------------------------------------------
// Step 1 of the Budget Income extraction migration (see Decisions Log).
// This screen owns Budget Income specifically — it replaces the
// `initialType: income, initialWithinBudget: true` path that used to live
// inside RecurringTransactionComposerScreen for callers adding/editing an
// income source from the Budget setup/tracking screens.
//
// Behavior is intentionally IDENTICAL to the old path in this step: it still
// delegates to the same TransactionEntryForm and returns the same
// RecurringTransactionComposerResult shape, so every existing caller-side
// derivation of IncomeSourceEntity from the result continues to work
// unchanged. No business logic changes in this step — ownership separation
// only, per the approved migration plan.
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

class IncomeSourceEditorScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isNew = initialRecurring == null;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isNew ? 'إضافة دخل' : 'تعديل دخل'),
      ),
      body: SafeArea(
        child: TransactionEntryForm(
          cubit: cubit,
          recurringMode: true,
          recurringType: TransactionType.income.value,
          initialRecurring: initialRecurring,
          allowDelete: allowDelete,
          onSaved: (entity) {
            Navigator.of(context)
                .pop(IncomeSourceEditorResult.saved(entity));
          },
          onDeleted: () {
            Navigator.of(context)
                .pop(const IncomeSourceEditorResult.deleted());
          },
        ),
      ),
    );
  }
}
