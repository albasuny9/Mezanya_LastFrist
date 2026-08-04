import 'package:flutter/material.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../domain/entities/recurring_transaction_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../form/transaction_entry_form.dart';

// ---------------------------------------------------------------------------
// AddTransactionScreen — thin wrapper.
//
// Historically this file held the full monolithic form implementation. It
// now only forwards its constructor parameters to the canonical
// TransactionEntryForm (shared by manual entry and the recurring composer).
// Kept as its own widget/class (rather than inlining TransactionEntryForm at
// call sites) so existing callers and imports across the app do not need to
// change.
// ---------------------------------------------------------------------------
class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({
    super.key,
    required this.cubit,
    this.initialTransaction,
    this.recurringMode = false,
    this.recurringType,
    this.initialRecurring,
    this.subscriptionOnlyMode = false,
    this.debtOnlyMode = false,
    this.initialExpensePlanKind,
    this.allowDelete = false,
    this.onSaved,
    this.onDeleted,
  });

  final AppCubit cubit;
  final TransactionEntity? initialTransaction;
  final bool recurringMode;
  final String? recurringType;
  final RecurringTransactionEntity? initialRecurring;
  final bool subscriptionOnlyMode;
  final bool debtOnlyMode;
  final String? initialExpensePlanKind;
  final bool allowDelete;
  // Called instead of cubit + pop when set (returnOnSave pattern).
  final void Function(RecurringTransactionEntity recurring)? onSaved;
  // Called instead of cubit + pop on delete when set.
  final void Function()? onDeleted;

  @override
  Widget build(BuildContext context) {
    return TransactionEntryForm(
      cubit: cubit,
      initialTransaction: initialTransaction,
      recurringMode: recurringMode,
      recurringType: recurringType,
      initialRecurring: initialRecurring,
      subscriptionOnlyMode: subscriptionOnlyMode,
      debtOnlyMode: debtOnlyMode,
      initialExpensePlanKind: initialExpensePlanKind,
      allowDelete: allowDelete,
      onSaved: onSaved,
      onDeleted: onDeleted,
    );
  }
}
