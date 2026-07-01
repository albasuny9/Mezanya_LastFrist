import '../../app_state/domain/entities/app_state_entity.dart';
import '../../logs/domain/entities/log_entry_entity.dart';
import '../../transactions/domain/entities/transaction_entity.dart';
import 'entities/notification_entity.dart';

/// بادئات الإجراءات القديمة قبل حقل [NotificationEntity.isPendingAction].
const _legacyPendingActionPrefixes = <String>[
  'تأكيد نزول دخل:',
  'تسجيل دخل مبكر:',
  'تأجيل دخل:',
  'سداد دين:',
  'تخطي هذه المرة:',
  'تأكيد النزول لـ:',
  'تخطي النزول لـ:',
  'تم تأكيد تحويل',
  'تم تأجيل تحويل',
  'تم تأكيد خصم فعلي',
  'تم تأكيد حجز',
  'تخصيص ',
  'تخطي تخصيص ',
  'خصم ',
  'نزل راتب ',
  'تسجيل مبكر لراتب ',
  'تأجيل راتب ',
  'سداد ',
];

TransactionEntity? transactionForHistoryLog(
  AppStateEntity state,
  LogEntryEntity? log,
) {
  if (log == null) return null;

  if (log.entityType == 'transaction') {
    for (final tx in state.transactions) {
      if (tx.id == log.entityId) return tx;
    }
    return null;
  }

  if (log.entityType == 'recurring-expense-handled') {
    final amountMatch =
        RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(log.details);
    final amount = amountMatch == null
        ? null
        : double.tryParse(amountMatch.group(1)!.replaceAll(',', '.'));
    final candidates = state.transactions.where((tx) {
      final delta = tx.createdAt.difference(log.timestamp).abs();
      if (delta.inMinutes > 3) return false;
      if (amount != null && (tx.amount - amount).abs() > 0.01) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return candidates.isEmpty ? null : candidates.first;
  }

  return null;
}

bool isNotificationHistoryEntry(NotificationEntity item) {
  if (item.type == 'revert-system') return false;
  if (item.relatedLogId == null) return false;
  if (item.isPendingAction) return true;

  final message = item.message.trim();
  for (final prefix in _legacyPendingActionPrefixes) {
    if (message.startsWith(prefix)) return true;
  }
  if (message.startsWith('تأجيل ') && message.contains('حتى')) return true;
  if (message.startsWith('تم تأكيد ')) return true;
  return false;
}
