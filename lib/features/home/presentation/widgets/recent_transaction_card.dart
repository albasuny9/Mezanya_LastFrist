import 'package:flutter/material.dart';

import '../../../../core/constants/transaction_types.dart';
import '../../../../core/utils/transaction_display_format.dart';
import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';

const _cardSurface = Color(0xFFFFFCF8);
const _cardBorder = Color(0xFFF3EDE4);
const _dividerColor = Color(0xFFF3EDE4);

class RecentTransactionsGroup extends StatelessWidget {
  const RecentTransactionsGroup({
    super.key,
    required this.transactions,
    required this.cubit,
    this.onTransactionTap,
    this.showDateWithTime = false,
  });

  final List<TransactionEntity> transactions;
  final AppCubit cubit;
  final void Function(TransactionEntity transaction)? onTransactionTap;
  final bool showDateWithTime;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: _cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: _dividerColor,
                indent: 16,
                endIndent: 16,
              ),
            RecentTransactionCard(
              transaction: transactions[i],
              state: cubit.state,
              showDateWithTime: showDateWithTime,
              onTap: () {
                if (onTransactionTap != null) {
                  onTransactionTap!(transactions[i]);
                } else {
                  openTransactionDetailsPage(
                    context,
                    cubit: cubit,
                    transaction: transactions[i],
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class RecentTransactionCard extends StatelessWidget {
  const RecentTransactionCard({
    super.key,
    required this.transaction,
    required this.state,
    required this.onTap,
    this.showDateWithTime = false,
  });

  final TransactionEntity transaction;
  final AppStateEntity state;
  final VoidCallback onTap;
  final bool showDateWithTime;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income.value;
    final isExpense = transaction.type == TransactionType.expense.value;
    final isAdjustment =
        transaction.type == TransactionType.balanceAdjustment.value;
    final isNegativeAdjustment = transaction.transferType ==
        TransferType.jarBalanceAdjustmentDecrease.value;

    final cat = getCategoryForTransaction(state, transaction.categoryId);

    final accent = cat != null
        ? parseCategoryColor(cat.color)
        : isIncome
            ? const Color(0xFF16A34A)
            : isExpense
                ? const Color(0xFFDC2626)
                : isAdjustment
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF2563EB);

    final iconBg = accent.withValues(alpha: 0.14);
    final iconColor = Color.lerp(accent, Colors.black, 0.20)!;

    final amountColor = isExpense
        ? const Color(0xFFDC2626)
        : isIncome
            ? const Color(0xFF16A34A)
            : isAdjustment
                ? const Color(0xFF7C3AED)
                : const Color(0xFF2563EB);

    final accentBarColor = isIncome
        ? const Color(0xFF16A34A)
        : isExpense
            ? const Color(0xFFDC2626)
            : isAdjustment
                ? const Color(0xFF7C3AED)
                : const Color(0xFF2563EB);

    final icon = cat != null
        ? AppIconPickerDialog.iconDataForName(cat.icon)
        : isIncome
            ? Icons.arrow_downward_rounded
            : isExpense
                ? Icons.arrow_upward_rounded
                : isAdjustment
                    ? Icons.tune_rounded
                    : Icons.swap_horiz_rounded;

    final label =
        (transaction.notes?.isNotEmpty == true ? transaction.notes! : null) ??
            cat?.name ??
            (isIncome
                ? 'دخل'
                : isExpense
                    ? 'مصروف'
                    : isAdjustment
                        ? 'تسوية رصيد'
                        : 'تحويل');

    final sign = isIncome
        ? '+'
        : isExpense
            ? '-'
            : isAdjustment
                ? (isNegativeAdjustment ? '-' : '+')
                : '';
    final timeStr = showDateWithTime
        ? formatTransactionDateTime(transaction.createdAt)
        : formatTransactionTime(transaction.createdAt);

    final walletName = transactionWalletLabel(state, transaction);
    final allocationName = transactionAllocationLabel(state, transaction);

    final subtitleParts = <String>[];
    if (walletName != '—') subtitleParts.add(walletName);
    if (allocationName != '—') subtitleParts.add(allocationName);
    final subtitle = subtitleParts.join(' | ');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF8A7F72),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$sign${transaction.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: amountColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A7F72),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 3,
              color: accentBarColor,
            ),
          ],
        ),
      ),
    );
  }
}
