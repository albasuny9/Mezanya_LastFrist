import 'package:flutter/material.dart';

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../domain/entities/budget_setup_entity.dart';
import '../utils/budget_setup_display_helpers.dart';

class BudgetIncomePlanTile extends StatelessWidget {
  const BudgetIncomePlanTile({
    super.key,
    required this.income,
    required this.iconName,
    required this.iconColorHex,
    required this.onTap,
  });

  final IncomeSourceEntity income;
  final String iconName;
  final String iconColorHex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = budgetSetupColorFromHex(iconColorHex);
    final meta = income.isVariable
        ? 'دخل متغير • يدوي'
        : 'يوم ${income.date} • ${budgetIncomeTypeLabel(income.type)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: tint.withValues(alpha: 0.14),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BudgetSetupIconBadge(
                iconName: iconName,
                colorHex: iconColorHex,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      income.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: FittedBox(
                            alignment: AlignmentDirectional.centerStart,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              income.isVariable
                                  ? 'متغير'
                                  : income.amount.toStringAsFixed(2),
                              maxLines: 1,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF165B47),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              income.isVariable
                                  ? 'غير ثابت'
                                  : 'يوم ${income.date}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meta,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BudgetSetupIconBadge extends StatelessWidget {
  const BudgetSetupIconBadge({
    super.key,
    required this.iconName,
    required this.colorHex,
    this.size = 48,
  });

  final String iconName;
  final String colorHex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = budgetSetupColorFromHex(colorHex);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Center(
        child: AppIconPickerDialog.iconWidgetForName(
          iconName,
          color: color,
          size: size * 0.48,
        ),
      ),
    );
  }
}

Color budgetSetupColorFromHex(String value) {
  final hex = value.replaceAll('#', '');
  final normalized = hex.length == 6 ? 'FF$hex' : hex;
  final intColor = int.tryParse(normalized, radix: 16) ?? 0xFF165B47;
  return Color(intColor);
}
