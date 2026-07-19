import 'package:flutter/material.dart';

import '../../domain/entities/budget_setup_entity.dart';
import '../utils/budget_setup_display_helpers.dart';
import '../widgets/budget_details_blocks.dart';
import '../widgets/budget_info_sheet_shell.dart';

Future<void> showJarInfoSheet(
  BuildContext context, {
  required LinkedWalletEntity jar,
  required List<IncomeSourceEntity> incomeSources,
  required VoidCallback onEdit,
}) {
  final fundingText = budgetFundingBreakdownText(
    jar.funding.map((f) => (f.incomeSourceId, f.plannedAmount)).toList(),
    incomeSources,
  );
  final automationLabel = budgetIncomeTypeLabel(jar.automationType);

  return showBudgetInfoSheet(
    context: context,
    title: 'تفاصيل الحصالة',
    editLabel: 'تعديل الحصالة',
    onEdit: onEdit,
    blocks: [
      BudgetDetailsBlock.wide('اسم الحصالة', jar.name),
      BudgetDetailsBlock.narrow(
        'الرصيد الحالي',
        jar.balance.toStringAsFixed(2),
      ),
      BudgetDetailsBlock.narrow(
        'المخصص الشهري',
        jar.monthlyAmount.toStringAsFixed(2),
      ),
      BudgetDetailsBlock.narrow('يوم التحويل', '${jar.executionDay}'),
      BudgetDetailsBlock.narrow('نوع التنفيذ', automationLabel),
      BudgetDetailsBlock.wide('مصادر التمويل', fundingText),
    ],
  );
}
