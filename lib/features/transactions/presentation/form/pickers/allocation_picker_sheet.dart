import 'package:flutter/material.dart';

import '../../../../../core/constants/transaction_types.dart';
import '../../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../../budget/domain/entities/budget_setup_entity.dart';
import '../_shared/allocation_option_card.dart';
import '../_shared/sheet_section_label.dart';

/// Shows the expense allocation / jar picker sheet.
/// [onSelected] is called with (targetId, budgetScope).
void showAllocationPickerSheet(
  BuildContext context, {
  required BudgetSetupEntity budget,
  required String selectedTargetId,
  required void Function(String targetId, String budgetScope) onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetCtx) => SizedBox(
      height: MediaQuery.of(sheetCtx).size.height * 0.84,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text(
            'اختر المخصص',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 14),

          // Outside budget
          AllocationOptionCard(
            isSelected: selectedTargetId.isEmpty,
            onTap: () {
              onSelected('', BudgetScope.outsideBudget.value);
              Navigator.pop(sheetCtx);
            },
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6F2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.public_off_rounded,
                      color: Color(0xFF2F6F5E)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'خارج الميزانية',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                if (selectedTargetId.isEmpty)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF1E7F5C)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Allocations section
          if (budget.allocations.isNotEmpty ||
              budget.unallocatedAmount > 0)
            const SheetSectionLabel(label: 'المخصصات'),

          // Unallocated
          if (budget.unallocatedAmount > 0) ...[
            const SizedBox(height: 8),
            AllocationOptionCard(
              isSelected: selectedTargetId == 'unallocated',
              onTap: () {
                onSelected('unallocated', BudgetScope.withinBudget.value);
                Navigator.pop(sheetCtx);
              },
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.category_outlined,
                        color: Color(0xFF2F6F5E)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('غير المخصص',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  Text(
                    budget.unallocatedAmount.toStringAsFixed(2),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (selectedTargetId == 'unallocated') ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF1E7F5C)),
                  ],
                ],
              ),
            ),
          ],

          // Allocations
          ...budget.allocations.map((a) {
            final id = 'alloc:${a.id}';
            final remaining = a.balance;
            final planned =
                a.funding.fold<double>(0, (s, f) => s + f.plannedAmount);
            final ratio = planned <= 0
                ? 0.0
                : (remaining / planned).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AllocationOptionCard(
                isSelected: selectedTargetId == id,
                onTap: () {
                  onSelected(id, BudgetScope.withinBudget.value);
                  Navigator.pop(sheetCtx);
                },
                child: _AllocationProgressRow(
                  icon: AppIconPickerDialog.iconDataForName(a.icon),
                  iconColor: _parseColor(a.iconColor),
                  name: a.name,
                  progressLabel:
                      '${planned.toStringAsFixed(2)} مخطط',
                  ratio: ratio,
                  isSelected: selectedTargetId == id,
                ),
              ),
            );
          }),

          // Jars section
          if (budget.linkedWallets.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SheetSectionLabel(label: 'الحصالات'),
            ...budget.linkedWallets.map((jar) {
              final id = 'jar:${jar.id}';
              final isJarSelected = selectedTargetId == id;
              final jarAccent = jar.iconColor.isNotEmpty
                  ? _parseColor(jar.iconColor)
                  : const Color(0xFF8B5A2B);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AllocationOptionCard(
                  isSelected: isJarSelected,
                  onTap: () {
                    // Jars are NOT part of the budget — outside-budget.
                    onSelected(id, BudgetScope.outsideBudget.value);
                    Navigator.pop(sheetCtx);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              jarAccent.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Center(
                          child: AppIconPickerDialog.iconWidgetForName(
                            jar.icon.isNotEmpty ? jar.icon : 'savings',
                            color: jarAccent,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(jar.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                            const SizedBox(height: 3),
                            Text(
                              '${jar.balance.toStringAsFixed(2)} رصيد',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: jarAccent.withValues(alpha: 0.78),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isJarSelected)
                        Icon(Icons.check_circle_rounded,
                            color: jarAccent, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    ),
  );
}

// ── Allocation row with progress bar ───────────────────────────────────────
class _AllocationProgressRow extends StatelessWidget {
  const _AllocationProgressRow({
    required this.icon,
    required this.iconColor,
    required this.name,
    required this.progressLabel,
    required this.ratio,
    required this.isSelected,
  });

  final IconData icon;
  final Color iconColor;
  final String name;
  final String progressLabel;
  final double ratio;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final progressValue =
        ratio.isFinite ? ratio.clamp(0.0, 1.0).toDouble() : 0.0;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF1E7F5C), size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                progressLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor:
                      iconColor.withValues(alpha: 0.12),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(iconColor),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Color _parseColor(String hex) {
  final v =
      int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0x165b47;
  return Color(0xFF000000 | v);
}
