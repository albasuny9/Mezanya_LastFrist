import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mezanya_app/core/constants/transaction_types.dart';

import '../../../../core/utils/transaction_display_format.dart';
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
    this.onLongPress,
    this.viewingContextId,
    this.grouped = false,
  });

  final TransactionEntity transaction;
  final AppStateEntity appState;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool grouped;

  final String? viewingContextId;

  CategoryEntity? get _category =>
      getCategoryForTransaction(appState, transaction.categoryId);

  String _typeLabel() {
    if (transaction.type == TransactionType.income.value) return 'دخل';
    if (transaction.type == TransactionType.expense.value) return 'مصروف';
    if (transaction.type == TransactionType.balanceAdjustment.value) {
      return 'تسوية رصيد';
    }
    return 'تحويل';
  }

  Color _typeColor() {
    if (transaction.type == TransactionType.balanceAdjustment.value) {
      return const Color(0xFF7C3AED);
    }
    if (transaction.transferType == TransferType.jarToJar.value &&
        viewingContextId != null) {
      if (transaction.fromWalletId == viewingContextId) {
        return const Color(0xFFDC2626);
      }
      if (transaction.toWalletId == viewingContextId) {
        return const Color(0xFF16A34A);
      }
    }

    if (transaction.transferType == TransferType.jarFundingPhysical.value) {
      if (viewingContextId != null &&
          transaction.walletId == viewingContextId) {
        return const Color(0xFFDC2626);
      }
      return const Color(0xFF2563EB);
    }

    if (transaction.transferType == TransferType.jarFunding.value) {
      return const Color(0xFF2563EB);
    }
    if (transaction.type == TransactionType.income.value) {
      return const Color(0xFF16A34A);
    }
    if (transaction.type == TransactionType.expense.value) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF2563EB);
  }

  bool _isNegative() {
    return transaction.transferType ==
            TransferType.jarBalanceAdjustmentDecrease.value ||
        transaction.type == TransactionType.expense.value ||
        transaction.transferType == TransferType.jarFundingPhysical.value ||
        transaction.transferType == TransferType.jarAllocationCancel.value ||
        transaction.transferType == TransferType.jarAllocationSpend.value ||
        (transaction.transferType == TransferType.jarToJar.value &&
            viewingContextId != null &&
            transaction.fromWalletId == viewingContextId);
  }

  IconData _fallbackIcon() {
    if (transaction.type == TransactionType.balanceAdjustment.value) {
      return Icons.tune_rounded;
    }
    if (transaction.transferType == TransferType.jarFunding.value ||
        transaction.transferType == TransferType.jarFundingPhysical.value) {
      return Icons.monetization_on_rounded;
    }
    if (transaction.transferType == TransferType.jarToJar.value) {
      return Icons.compare_arrows_rounded;
    }
    if (transaction.type == TransactionType.income.value) {
      return Icons.arrow_downward_rounded;
    }
    if (transaction.type == TransactionType.expense.value) {
      return Icons.arrow_upward_rounded;
    }
    return Icons.swap_horiz_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final typeColor = _typeColor();
    final isNegative = _isNegative();
    final accent = category != null
        ? _parseHexColor(category.color, fallback: typeColor)
        : typeColor;
    final icon = category != null
        ? AppIconPickerDialog.iconDataForName(category.icon)
        : _fallbackIcon();
    final title = transaction.notes?.trim().isNotEmpty == true
        ? transaction.notes!.trim()
        : category?.name ?? _transferLabel();
    final subtitle = _subtitle();
    final amountColor =
        isNegative ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final barColor = isNegative ? const Color(0xFFDC2626) : typeColor;

    final content = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: Color.lerp(accent, Colors.black, 0.20),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
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
                        '${isNegative ? '-' : '+'}${transaction.amount.toStringAsFixed(2)}',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatTransactionDateTime(transaction.createdAt),
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
          Container(width: 3, color: barColor),
        ],
      ),
    );

    final child = grouped
        ? content
        : Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3EDE4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: content,
          );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  String _subtitle() {
    final parts = <String>[];
    final walletName = _walletName(transaction.walletId);
    if (walletName != null) parts.add(walletName);

    final counterpartName = _counterpartJarName();
    if (counterpartName != null) parts.add(counterpartName);

    final allocationName = _allocationName(transaction.allocationId);
    if (allocationName != null) parts.add(allocationName);

    return parts.join(' | ');
  }

  String? _walletName(String? walletId) {
    if (walletId == null) return null;
    for (final wallet in appState.wallets) {
      if (wallet.id == walletId) return wallet.name;
    }
    return null;
  }

  String? _jarName(String? jarId) {
    if (jarId == null) return null;
    for (final jar in appState.budgetSetup.linkedWallets) {
      if (jar.id == jarId) return jar.name;
    }
    return null;
  }

  String? _allocationName(String? allocationId) {
    if (allocationId == null) return null;
    for (final allocation in appState.budgetSetup.allocations) {
      if (allocation.id == allocationId) return allocation.name;
    }
    return null;
  }

  String _transferLabel() {
    if (transaction.transferType == TransferType.jarAllocation.value) {
      return 'تخصيص للحصالة';
    }
    if (transaction.transferType == TransferType.jarAllocationCancel.value) {
      return 'إلغاء تخصيص';
    }
    if (transaction.transferType == TransferType.jarAllocationSpend.value) {
      return 'سحب من المحجوز';
    }
    if (transaction.transferType == TransferType.jarFundingPhysical.value) {
      return 'خصم لحصالة';
    }
    if (transaction.transferType == TransferType.jarFunding.value) {
      return 'تحويل من الميزانية';
    }
    if (transaction.transferType == TransferType.jarToJar.value) {
      if (viewingContextId != null &&
          transaction.fromWalletId == viewingContextId) {
        return 'تحويل مخصوم';
      }
      if (viewingContextId != null &&
          transaction.toWalletId == viewingContextId) {
        return 'تحويل إضافي';
      }
      return 'تحويل بين حصالتين';
    }
    if (transaction.transferType == TransferType.walletToWallet.value) {
      return 'تحويل بين المحافظ';
    }
    return _typeLabel();
  }

  String? _counterpartJarName() {
    if (transaction.transferType != TransferType.jarToJar.value) return null;
    if (viewingContextId != null &&
        transaction.fromWalletId == viewingContextId) {
      return _jarName(transaction.toWalletId);
    }
    if (viewingContextId != null &&
        transaction.toWalletId == viewingContextId) {
      return _jarName(transaction.fromWalletId);
    }
    return _jarName(transaction.toWalletId) ??
        _jarName(transaction.fromWalletId);
  }

  Color _parseHexColor(String hex, {required Color fallback}) {
    final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    if (value == null) return fallback;
    return Color(0xFF000000 | value);
  }
}

class SharedTransactionDayGroups extends StatelessWidget {
  const SharedTransactionDayGroups({
    super.key,
    required this.transactions,
    required this.appState,
    required this.onTap,
    this.onLongPress,
    this.viewingContextId,
  });

  final List<TransactionEntity> transactions;
  final AppStateEntity appState;
  final void Function(TransactionEntity transaction) onTap;
  final void Function(TransactionEntity transaction)? onLongPress;
  final String? viewingContextId;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox.shrink();

    final grouped = <DateTime, List<TransactionEntity>>{};
    for (final transaction in transactions) {
      final day = DateTime(
        transaction.createdAt.year,
        transaction.createdAt.month,
        transaction.createdAt.day,
      );
      grouped.putIfAbsent(day, () => <TransactionEntity>[]).add(transaction);
    }

    return Column(
      children: [
        for (final entry in grouped.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _dateLabel(entry.key),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A7F72),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFCF8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3EDE4)),
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
                      for (var i = 0; i < entry.value.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFF3EDE4),
                            indent: 16,
                            endIndent: 16,
                          ),
                        SharedTransactionCard(
                          transaction: entry.value[i],
                          appState: appState,
                          viewingContextId: viewingContextId,
                          grouped: true,
                          onTap: () => onTap(entry.value[i]),
                          onLongPress: onLongPress == null
                              ? null
                              : () => onLongPress!(entry.value[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(date.year, date.month, date.day);
    final datePart = DateFormat('d MMMM', 'ar').format(date);
    if (day == today) return 'اليوم • $datePart';
    if (day == yesterday) return 'أمس • $datePart';
    return datePart;
  }
}
