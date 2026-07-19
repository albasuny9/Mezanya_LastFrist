import 'package:flutter/material.dart';
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../domain/entities/budget_setup_entity.dart';
import '../utils/budget_setup_display_helpers.dart';
import '../widgets/budget_details_blocks.dart';
import '../widgets/budget_info_sheet_shell.dart';

Future<void> showAllocationInfoSheet(
  BuildContext context, {
  required AllocationEntity allocation,
  required List<IncomeSourceEntity> incomeSources,
  required VoidCallback onEdit,
}) {
  final planned = allocation.funding.fold<double>(
    0,
    (s, f) => s + f.plannedAmount,
  );
  final categoryCount = allocation.categories.length;
  final rolloverLabel =
      allocation.rolloverBehavior == RolloverBehavior.keep.value
          ? 'يرحل للدورة التالية'
          : 'يرجع للتوفير';

  return showBudgetInfoSheet(
    context: context,
    title: 'تفاصيل المخصص',
    editLabel: 'تعديل المخصص',
    onEdit: onEdit,
    blocks: [
      BudgetDetailsBlock.wide('اسم المخصص', allocation.name),
      BudgetDetailsBlock.narrow(
        'إجمالي المخطط',
        planned.toStringAsFixed(2),
      ),
      BudgetDetailsBlock.narrow('سلوك المتبقي', rolloverLabel),
      BudgetDetailsBlock.wide(
        'مصادر التمويل',
        budgetFundingBreakdownText(
          allocation.funding
              .map((f) => (f.incomeSourceId, f.plannedAmount))
              .toList(),
          incomeSources,
        ),
      ),
      BudgetDetailsBlock.narrow('عدد الفئات', '$categoryCount'),
      BudgetDetailsBlock.wide(
        'الأيقونة واللون',
        '${allocation.icon} • ${allocation.iconColor}',
      ),
    ],
  );
}
