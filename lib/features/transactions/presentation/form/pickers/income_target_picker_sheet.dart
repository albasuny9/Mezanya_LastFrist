import 'package:flutter/material.dart';

import '../../../../../core/constants/transaction_types.dart';
import '../../../../budget/domain/entities/budget_setup_entity.dart';
import '../_shared/allocation_option_card.dart';
import '../_shared/sheet_section_label.dart';

/// Shows the income target picker (wallet-only / income source / jar).
/// [onSelected] is called with (incomeBudgetScope, incomeSourceId, incomeJarId).
void showIncomeTargetPickerSheet(
  BuildContext context, {
  required BudgetSetupEntity budget,
  required String walletName,
  required String currentIncomeBudgetScope,
  required String currentIncomeSourceId,
  required String currentIncomeJarId,
  required void Function(
    String incomeBudgetScope,
    String incomeSourceId,
    String incomeJarId,
  ) onSelected,
}) {
  final jars = budget.linkedWallets;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetCtx) => SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Wallet-only option
          AllocationOptionCard(
            isSelected: currentIncomeBudgetScope ==
                    BudgetScope.outsideBudget.value &&
                currentIncomeSourceId == 'wallet-only' &&
                currentIncomeJarId.isEmpty,
            onTap: () {
              onSelected(
                BudgetScope.outsideBudget.value,
                'wallet-only',
                '',
              );
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
                  child: const Icon(Icons.download_for_offline_rounded,
                      color: Color(0xFF2F6F5E)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إيداع للمحفظة فقط',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الإيداع يذهب إلى محفظة $walletName فقط.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(sheetCtx)
                              .colorScheme
                              .onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (currentIncomeBudgetScope ==
                        BudgetScope.outsideBudget.value &&
                    currentIncomeSourceId == 'wallet-only' &&
                    currentIncomeJarId.isEmpty)
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF1E7F5C)),
              ],
            ),
          ),

          // Income sources
          if (budget.incomeSources.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SheetSectionLabel(label: 'مصادر الدخل'),
            const SizedBox(height: 10),
            ...budget.incomeSources.map((source) {
              final selected =
                  currentIncomeBudgetScope ==
                          BudgetScope.withinBudget.value &&
                      currentIncomeJarId.isEmpty &&
                      currentIncomeSourceId == source.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AllocationOptionCard(
                  isSelected: selected,
                  onTap: () {
                    onSelected(
                      BudgetScope.withinBudget.value,
                      source.id,
                      '',
                    );
                    Navigator.pop(sheetCtx);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFF1E7F5C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(source.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                )),
                            const SizedBox(height: 4),
                            Text(
                              source.isVariable
                                  ? 'مصدر دخل متغير داخل الميزانية'
                                  : 'مخطط ${source.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(sheetCtx)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF1E7F5C)),
                    ],
                  ),
                ),
              );
            }),
          ],

          // Jars
          if (jars.isNotEmpty) ...[
            const SizedBox(height: 14),
            const SheetSectionLabel(label: 'الحصالات'),
            const SizedBox(height: 10),
            ...jars.map((jar) {
              final selected =
                  currentIncomeBudgetScope ==
                          BudgetScope.withinBudget.value &&
                      currentIncomeJarId == jar.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AllocationOptionCard(
                  isSelected: selected,
                  onTap: () {
                    onSelected(
                      BudgetScope.withinBudget.value,
                      'wallet-only',
                      jar.id,
                    );
                    Navigator.pop(sheetCtx);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F4F1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.monetization_on_rounded,
                            color: Color(0xFF2F6F5E)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(jar.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                )),
                            const SizedBox(height: 4),
                            Text(
                              'الرصيد ${jar.balance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(sheetCtx)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF1E7F5C)),
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
