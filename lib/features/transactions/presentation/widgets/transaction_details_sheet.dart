import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../domain/entities/transaction_entity.dart';
import '../screens/add_transaction_screen.dart';

CategoryEntity? getCategoryForTransaction(
    AppStateEntity state, String? categoryId) {
  if (categoryId == null || categoryId.isEmpty) return null;
  for (final c in state.categories) {
    if (c.id == categoryId) return c;
  }
  for (final alloc in state.budgetSetup.allocations) {
    for (final c in alloc.categories) {
      if (c.id == categoryId) return c;
    }
  }
  for (final jar in state.budgetSetup.linkedWallets) {
    for (final c in jar.categories) {
      if (c.id == categoryId) return c;
    }
  }
  return null;
}

Future<void> openTransactionDetailsSheet(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
}) async {
  final theme = Theme.of(context);
  final rows = _detailRows(cubit, transaction);
  final state = cubit.state;
  final accent = _accentForTransaction(theme, transaction);

  final category = getCategoryForTransaction(state, transaction.categoryId);
  final displayTitle = category?.name ??
      (transaction.notes?.trim().isNotEmpty == true
          ? transaction.notes!.trim()
          : _typeLabel(transaction.type));
  final displayIcon = category != null
      ? parseCategoryIcon(category.icon)
      : _iconForTransaction(transaction);
  final displayColor =
      category != null ? parseCategoryColor(category.color) : accent;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: theme.colorScheme.surface,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: accent.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: displayColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      displayIcon,
                      color: displayColor,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // ملاحظات تفصيلية تحت الاسم لو الاسم من الفئة
                        if (category != null &&
                            transaction.notes?.trim().isNotEmpty == true) ...[
                          Text(
                            transaction.notes!.trim(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          '${_typeLabel(transaction.type)} - ${DateFormat('d MMMM yyyy - HH:mm', 'ar').format(transaction.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    transaction.amount.toStringAsFixed(2),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _DetailsBlock(rows: rows),
            const SizedBox(height: 18),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                if (transaction.transferType == 'jar-funding') {
                  await _openJarReserveEditor(
                    context,
                    cubit: cubit,
                    transaction: transaction,
                  );
                  return;
                }
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => FractionallySizedBox(
                    heightFactor: 0.96,
                    child: AddTransactionScreen(
                      cubit: cubit,
                      initialTransaction: transaction,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('تعديل المعاملة'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: accent,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _openJarReserveEditor(
  BuildContext context, {
  required AppCubit cubit,
  required TransactionEntity transaction,
}) async {
  final amountController =
      TextEditingController(text: transaction.amount.toStringAsFixed(2));
  final notesController = TextEditingController(text: transaction.notes ?? '');
  var selectedWalletId = transaction.fromWalletId ?? transaction.walletId ?? '';
  var selectedDate = transaction.createdAt;
  var selectedTime = TimeOfDay(
    hour: transaction.createdAt.hour,
    minute: transaction.createdAt.minute,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) {
        final wallets = cubit.state.wallets;
        if (selectedWalletId.isEmpty && wallets.isNotEmpty) {
          selectedWalletId = wallets.first.id;
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                'تعديل حجز الحصالة',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ المحجوز'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedWalletId.isEmpty ? null : selectedWalletId,
                decoration: const InputDecoration(labelText: 'محفظة الحجز'),
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem<String>(
                        value: wallet.id,
                        child: Text(wallet.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setSheet(() => selectedWalletId = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2023),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setSheet(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                          DateFormat('d MMM yyyy', 'ar').format(selectedDate)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: sheetContext,
                          initialTime: selectedTime,
                        );
                        if (picked != null) {
                          setSheet(() => selectedTime = picked);
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(selectedTime.format(sheetContext)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: selectedWalletId.isEmpty
                    ? null
                    : () async {
                        final amount =
                            double.tryParse(amountController.text.trim());
                        if (amount == null || amount <= 0) return;
                        final createdAt = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          selectedTime.hour,
                          selectedTime.minute,
                        );
                        await cubit.deleteTransaction(transaction.id);
                        await cubit.addTransaction(
                          walletId: selectedWalletId,
                          fromWalletId: selectedWalletId,
                          toWalletId: transaction.toWalletId,
                          amount: amount,
                          type: 'transfer',
                          budgetScope: transaction.budgetScope,
                          incomeSourceId: transaction.incomeSourceId,
                          transferType: 'jar-funding',
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                          createdAt: createdAt,
                          details:
                              'تم تعديل حجز حصالة بقيمة ${amount.toStringAsFixed(2)}',
                        );
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ الحجز'),
              ),
            ],
          ),
        );
      },
    ),
  );

  amountController.dispose();
  notesController.dispose();
}

List<MapEntry<String, String>> _detailRows(
    AppCubit cubit, TransactionEntity tx) {
  final state = cubit.state;
  String walletName(String? id) =>
      state.wallets
          .where((w) => w.id == id)
          .map((w) => w.name)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => id) ??
      '-';
  String jarName(String? id) =>
      state.budgetSetup.linkedWallets
          .where((j) => j.id == id)
          .map((j) => j.name)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => id) ??
      '-';
  String allocName(String? id) =>
      state.budgetSetup.allocations
          .where((a) => a.id == id)
          .map((a) => a.name)
          .cast<String?>()
          .firstWhere((_) => true, orElse: () => id) ??
      '-';
  String categoryName(String? id) {
    final cat = getCategoryForTransaction(state, id);
    return cat?.name ?? id ?? '-';
  }

  return [
    MapEntry('النوع', _typeLabel(tx.type)),
    MapEntry('المبلغ', tx.amount.toStringAsFixed(2)),
    MapEntry('التاريخ', DateFormat('d MMMM yyyy', 'ar').format(tx.createdAt)),
    MapEntry('الوقت', DateFormat('HH:mm', 'ar').format(tx.createdAt)),
    if (tx.walletId != null) MapEntry('المحفظة', walletName(tx.walletId)),
    if (tx.fromWalletId != null)
      MapEntry('من محفظة', walletName(tx.fromWalletId)),
    if (tx.toWalletId != null) MapEntry('إلى', jarName(tx.toWalletId)),
    if (tx.allocationId != null) MapEntry('المخصص', allocName(tx.allocationId)),
    if (tx.categoryId != null) MapEntry('الفئة', categoryName(tx.categoryId)),
    if (tx.budgetScope != null)
      MapEntry('نطاق الميزانية', _budgetScopeLabel(tx.budgetScope!)),
    if (tx.transferType != null) MapEntry('نوع التحويل', tx.transferType!),
    if (tx.notes?.trim().isNotEmpty == true)
      MapEntry('الملاحظات', tx.notes!.trim()),
  ];
}

String _typeLabel(String type) {
  switch (type) {
    case 'income':
      return 'دخل';
    case 'expense':
      return 'مصروف';
    default:
      return 'تحويل';
  }
}

String _budgetScopeLabel(String value) {
  switch (value) {
    case 'within-budget':
      return 'داخل الميزانية';
    case 'outside-budget':
      return 'خارج الميزانية';
    default:
      return value;
  }
}

IconData _iconForTransaction(TransactionEntity tx) {
  switch (tx.type) {
    case 'income':
      return Icons.south_west_rounded;
    case 'expense':
      return Icons.north_east_rounded;
    default:
      return Icons.swap_horiz_rounded;
  }
}

Color _accentForTransaction(ThemeData theme, TransactionEntity tx) {
  switch (tx.type) {
    case 'income':
      return const Color(0xFF1F8B5F);
    case 'expense':
      return const Color(0xFFC86D2B);
    default:
      return theme.colorScheme.primary;
  }
}

IconData parseCategoryIcon(String name) {
  // Simple mapping, add logic if there's a specific package used for icons
  switch (name) {
    case 'home':
      return Icons.home_rounded;
    case 'shopping_cart':
      return Icons.shopping_cart_rounded;
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'directions_car':
      return Icons.directions_car_rounded;
    case 'medical_services':
      return Icons.medical_services_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'electrical_services':
      return Icons.electrical_services_rounded;
    case 'water_drop':
      return Icons.water_drop_rounded;
    case 'flight':
      return Icons.flight_rounded;
    case 'fitness_center':
      return Icons.fitness_center_rounded;
    case 'category':
      return Icons.category_rounded;
    case 'checkroom':
      return Icons.checkroom_rounded;
    case 'payments':
      return Icons.payments_rounded;
    case 'receipt':
      return Icons.receipt_rounded;
    case 'sports_esports':
      return Icons.sports_esports_rounded;
    default:
      return Icons.category_rounded;
  }
}

Color parseCategoryColor(String hexStr) {
  try {
    final buffer = StringBuffer();
    if (hexStr.length == 6 || hexStr.length == 7) buffer.write('ff');
    buffer.write(hexStr.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  } catch (e) {
    return const Color(0xFF165B47);
  }
}

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      rows[i].key,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      rows[i].value,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
          ],
        ],
      ),
    );
  }
}
