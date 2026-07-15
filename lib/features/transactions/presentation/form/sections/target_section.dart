import 'package:flutter/material.dart';

import '../../../../../core/constants/transaction_types.dart';
import '../_shared/row_card.dart';

/// Allocation row (expense) or income-target row (income).
class TargetSection extends StatelessWidget {
  const TargetSection({
    super.key,
    required this.type,
    required this.allocationName,
    required this.incomeTargetLabel,
    required this.onOpenAllocationPicker,
    required this.onOpenIncomeTargetPicker,
  });

  final String type;
  final String allocationName;
  final String incomeTargetLabel;
  final VoidCallback onOpenAllocationPicker;
  final VoidCallback onOpenIncomeTargetPicker;

  @override
  Widget build(BuildContext context) {
    if (type == TransactionType.expense.value) {
      return FormRowCard(
        label: 'المخصص',
        value: allocationName,
        icon: Icons.pie_chart_outline_rounded,
        onTap: onOpenAllocationPicker,
      );
    }
    // income
    return FormRowCard(
      label: 'هدف الإيداع',
      value: incomeTargetLabel,
      icon: Icons.download_for_offline_rounded,
      onTap: onOpenIncomeTargetPicker,
    );
  }
}
