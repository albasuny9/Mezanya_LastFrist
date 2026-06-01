import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../core/widgets/app_icon_picker_dialog.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import 'transaction_details_sheet.dart';

class SharedTransactionCard extends StatelessWidget {
  const SharedTransactionCard({
    super.key,
    required this.transaction,
    required this.appState,
    required this.onTap,
  });

  final TransactionEntity transaction;
  final AppStateEntity appState;
  final VoidCallback onTap;

  CategoryEntity? get _category =>
      getCategoryForTransaction(appState, transaction.categoryId);

  String _typeLabel() {
    if (transaction.type == 'income') return 'دخل';
    if (transaction.type == 'expense') return 'مصروف';
    return 'تحويل';
  }

  Color _typeColor() {
    if (transaction.type == 'income') return const Color(0xFF16A34A);
    if (transaction.type == 'expense') return const Color(0xFFDC2626);
    return const Color(0xFF2563EB); // Transfer
  }

  IconData _fallbackIcon() {
    if (transaction.type == 'income') return Icons.arrow_downward_rounded;
    if (transaction.type == 'expense') return Icons.arrow_upward_rounded;
    return Icons.swap_horiz_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cat = _category;
    // User requested the card and icon colors to always reflect income/expense,
    // not the specific custom category color.
    final color = _typeColor();

    final isNegative = transaction.type == 'expense' ||
        transaction.transferType == 'jar-funding-physical' ||
        transaction.transferType == 'jar-allocation-cancel' ||
        transaction.transferType == 'jar-allocation-spend';

    final targetJarName = transaction.toWalletId == null
        ? null
        : appState.budgetSetup.linkedWallets
            .where((jar) => jar.id == transaction.toWalletId)
            .map((jar) => jar.name)
            .cast<String?>()
            .firstWhere((_) => true, orElse: () => null);

    final label = switch (transaction.transferType) {
      'jar-allocation' => 'تخصيص للحصالة',
      'jar-allocation-cancel' => 'إلغاء تخصيص',
      'jar-allocation-spend' => 'سحب من المحجوز',
      'jar-funding' => 'حجز لحصالة ${targetJarName ?? 'التوفير'}',
      'wallet-to-wallet' => 'تحويل بين المحافظ',
      'jar-funding-physical' => 'خصم لحصالة ${targetJarName ?? 'التوفير'}',
      _ => transaction.notes ?? _typeLabel(),
    };

    final displayTitle = cat?.name ?? label;

    final catColor = cat != null
        ? Color(
            0xFF000000 | int.parse(cat.color.replaceFirst('#', ''), radix: 16))
        : color;

    // Resolve Wallet
    String? walletName;
    Color? walletColor;
    if (transaction.walletId != null) {
      try {
        final w =
            appState.wallets.firstWhere((w) => w.id == transaction.walletId);
        walletName = w.name;
        walletColor = Color(0xFF000000 |
            int.parse((w.iconColor ?? '#165B47').replaceFirst('#', ''),
                radix: 16));
      } catch (_) {}
    }

    // Resolve Allocation
    String allocationName = 'خارج الميزانية';
    if (transaction.allocationId != null) {
      try {
        final alloc = appState.budgetSetup.allocations
            .firstWhere((a) => a.id == transaction.allocationId);
        allocationName = alloc.name;
      } catch (_) {}
    }

    // Formatting date and time
    final dateStr =
        DateFormat('d MMM yyyy • HH:mm', 'ar').format(transaction.createdAt);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Right Side (Start in RTL): Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: cat != null
                  ? Center(
                      child: AppIconPickerDialog.iconWidgetForName(
                        cat.icon,
                        color: catColor,
                        size: 24,
                      ),
                    )
                  : Icon(_fallbackIcon(), color: color, size: 24),
            ),
            const SizedBox(width: 14),

            // Middle: Title, Notes, Tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (transaction.notes != null &&
                      transaction.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      transaction.notes!.trim(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF7A725F),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (walletName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: walletColor?.withValues(alpha: 0.1) ??
                                const Color(0xFFF3EEDF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            walletName,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: walletColor ?? const Color(0xFF7D7461),
                            ),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EEDF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          allocationName,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7D7461),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Left Side (End in RTL): Amount and Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${isNegative ? '-' : '+'}${transaction.amount.toStringAsFixed(2)}',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: _typeColor(),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Color(0xFF9A9181),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
