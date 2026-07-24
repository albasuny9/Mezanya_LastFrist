import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app_state/presentation/cubits/app_cubit.dart';
import '../../../recovery/domain/entities/recovery_entry.dart';
import '../../../transactions/presentation/widgets/transaction_details_sheet.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/notification_action_copy.dart';

Future<void> openNotificationHistoryDetailsSheet(
  BuildContext context, {
  required AppCubit cubit,
  required NotificationEntity item,
  required RecoveryEntry? log,
  required Color accent,
  required IconData icon,
}) async {
  final title = notificationHistoryTitle(
    title: item.title,
    message: item.message,
  );
  final amountLabel = notificationHistoryAmount(
    message: item.message,
    logDetails: log?.details,
  );
  final dateLabel = DateFormat('d MMMM yyyy', 'ar').format(item.createdAt);
  final timeLabel = DateFormat('h:mm a', 'ar').format(item.createdAt);
  final timestampLabel = '$dateLabel، $timeLabel';
  final entityLabel = _entityTypeLabel(log?.entityType ?? item.type);
  final actionLabel = _actionLabel(log?.action);
  final statusLabel = log == null
      ? '—'
      : log.isReverted
          ? 'تم التراجع'
          : 'نشط';

  final isIncome = _looksLikeIncome(item);
  final isExpense = _looksLikeExpense(item);
  final amountColor = isExpense
      ? const Color(0xFFDC2626)
      : isIncome
          ? const Color(0xFF16A34A)
          : accent;
  final heroBg = isIncome
      ? const Color(0xFFE8F8EE)
      : isExpense
          ? const Color(0xFFFDE8E8)
          : accent.withValues(alpha: 0.1);

  final amountValue = amountLabel.replaceAll('جنيه', '').trim();
  final amountSign = isIncome ? '+' : isExpense ? '-' : '';

  await showAppDetailsBottomSheet(
    context,
    title: 'تفاصيل الإشعار',
    children: [
      AppDetailsSummaryCard(
        title: title,
        subtitle: entityLabel,
        amountSign: amountSign,
        amountValue: amountValue.isEmpty ? '0.00' : amountValue,
        currency: amountLabel.contains('جنيه') ? 'جنيه' : '',
        icon: icon,
        iconColor: accent,
        backgroundColor: heroBg,
        amountColor: amountColor,
      ),
      const SizedBox(height: 14),
      AppDetailsGrid(
        date: dateLabel,
        time: timeLabel,
        wallet: entityLabel,
        allocation: actionLabel,
        amountText: amountLabel.isEmpty ? '—' : amountLabel,
        amountValueColor: amountLabel.isEmpty ? null : amountColor,
        paymentMethod: statusLabel,
        createdAtLabel: timestampLabel,
        updatedAtLabel: timestampLabel,
        walletLabel: 'النوع',
        allocationLabel: 'الإجراء',
        paymentMethodLabel: 'الحالة',
        updatedAtLabelText: 'آخر تحديث',
        createdAtLabelText: 'تم الإنشاء في',
      ),
      const SizedBox(height: 12),
      AppDetailsNotesSection(notes: item.message.trim().isEmpty ? null : item.message),
      if (log != null) ...[
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () async {
            final approved = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(log.isReverted ? 'إلغاء التراجع؟' : 'تأكيد التراجع'),
                content: Text(
                  log.isReverted
                      ? 'سيتم إلغاء التراجع وإعادة تطبيق الإجراء السابق.'
                      : 'سيتم التراجع عن هذا الإجراء وتحديث البيانات بناءً على السجل.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: const Text('تأكيد'),
                  ),
                ],
              ),
            );
            if (approved != true) return;
            await cubit.toggleLogRevert(log.sourceLogId!);
            if (context.mounted) Navigator.pop(context);
          },
          icon: Icon(log.isReverted ? Icons.redo_rounded : Icons.undo_rounded),
          label: Text(log.isReverted ? 'إلغاء التراجع' : 'التراجع عن الإجراء'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    ],
  );
}

bool _looksLikeIncome(NotificationEntity item) {
  final text = '${item.title} ${item.message}';
  return text.contains('راتب') ||
      text.contains('دخل') ||
      text.contains('نزل');
}

bool _looksLikeExpense(NotificationEntity item) {
  final text = '${item.title} ${item.message}';
  return text.contains('سداد') ||
      text.contains('دين') ||
      text.contains('خصم') ||
      text.contains('مصروف');
}

String _entityTypeLabel(String entityType) {
  switch (entityType) {
    case 'allocation':
      return 'مخصص';
    case 'jar':
      return 'حصالة';
    case 'transaction':
      return 'معاملة';
    case 'recurring-transaction':
      return 'معاملة متكررة';
    case 'recurring-expense-handled':
      return 'سداد دين';
    case 'income':
      return 'دخل';
    default:
      return 'إشعار';
  }
}

String _actionLabel(String? action) {
  switch (action) {
    case 'add':
      return 'إضافة';
    case 'edit':
      return 'تعديل';
    case 'delete':
      return 'حذف';
    case 'transfer':
      return 'تحويل';
    case 'skip':
      return 'تخطي';
    default:
      return action ?? '—';
  }
}
