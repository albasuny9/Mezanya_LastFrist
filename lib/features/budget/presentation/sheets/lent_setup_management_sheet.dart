import 'package:flutter/material.dart';

import '../../../transactions/domain/entities/recurring_transaction_entity.dart';
import '../utils/budget_setup_display_helpers.dart';

Future<void> showLentSetupManagementSheet(
  BuildContext context, {
  required RecurringTransactionEntity record,
  required Future<void> Function() onSettle,
  required Future<void> Function(DateTime picked) onPostpone,
  required Future<void> Function() onWriteOff,
  required Future<void> Function() onDelete,
}) async {
  final personName = record.lentPersonName ?? record.name;
  final returnDate =
      record.anchorDate != null ? DateTime.tryParse(record.anchorDate!) : null;
  final isOverdue = returnDate != null &&
      DateTime(returnDate.year, returnDate.month, returnDate.day).isBefore(
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetCtx) {
      return StatefulBuilder(
        builder: (ctx, setSt) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1a7a4a).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        color: Color(0xFF1a7a4a),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            personName,
                            style: Theme.of(ctx)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            '${record.amount.toStringAsFixed(2)}'
                            '${returnDate != null ? ' • ${returnDate.day}/${returnDate.month}/${returnDate.year}' : ''}'
                            '${isOverdue ? ' ⚠️ متأخر' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isOverdue
                                  ? const Color(0xFFC65D2E)
                                  : Theme.of(ctx).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('تأكيد الاسترداد'),
                          content: Text(
                            'هل استردّيت السلفة من $personName؟\nسيتم إضافة المبلغ لمحفظتك.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dCtx, false),
                              child: const Text('إلغاء'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('تم الاسترداد'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await onSettle();
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('تم الاسترداد'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: const Color(0xFF1a7a4a),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetCtx).pop();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: returnDate ??
                                DateTime.now().add(const Duration(days: 7)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 5)),
                            helpText: 'اختر تاريخ الاسترداد الجديد',
                          );
                          if (picked != null) {
                            await onPostpone(picked);
                          }
                        },
                        icon: const Icon(Icons.schedule_rounded),
                        label: const Text('تأجيل'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(sheetCtx).pop();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: const Text('تنازل عن السلفة'),
                              content: Text(
                                'هل متأكد إنك هتتنازل عن ${record.amount.toStringAsFixed(2)} من $personName؟\n\nلن يُضاف المبلغ لمحفظتك.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx, false),
                                  child: const Text('إلغاء'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF7B4FBF),
                                  ),
                                  child: const Text('تنازل'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await onWriteOff();
                          }
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Color(0xFF7B4FBF),
                        ),
                        label: const Text(
                          'تنازل',
                          style: TextStyle(color: Color(0xFF7B4FBF)),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          side: const BorderSide(
                            color: Color(0xFF7B4FBF),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetCtx).pop();
                      final confirmed = await confirmBudgetDeletion(
                        context,
                        title: 'حذف السلفة',
                        message:
                            'سيتم حذف سلفة "$personName" نهائيًا بدون تسجيل. هل تريد المتابعة؟',
                      );
                      if (confirmed) {
                        await onDelete();
                      }
                    },
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: Theme.of(ctx).colorScheme.error,
                    ),
                    label: Text(
                      'حذف',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: BorderSide(
                        color: Theme.of(ctx)
                            .colorScheme
                            .error
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
