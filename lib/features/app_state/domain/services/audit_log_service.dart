import '../../../logs/domain/entities/log_entry_entity.dart';
import '../../../notifications/domain/entities/notification_entity.dart';
import '../../../../core/constants/transaction_types.dart';

/// نتيجة بناء سجلّ تدقيق (audit log) واحد: تحتوي على السجلّ الجديد وقائمتي
/// الـ logs والـ notifications الجاهزتين (بعد الدمج والتقليم) ليقوم
/// AppCubit بوضعهما مباشرة في `copyWith`.
class AuditLogBuildResult {
  const AuditLogBuildResult({
    required this.log,
    required this.logs,
    required this.notifications,
  });

  final LogEntryEntity log;
  final List<LogEntryEntity> logs;
  final List<NotificationEntity> notifications;
}

/// خدمة مسؤولة حصريًا عن بناء سجلّات التدقيق (audit log) والإشعارات
/// المرتبطة بها، وتوليد عناوين الإشعارات وتصنيفات المعاملات المستخدَمة في
/// نصوص التفاصيل.
///
/// استُخرجت من AppCubit._applyAndLog — لا تغيير في المنطق أو السلوك (نفس
/// حدود التقليم 600/800، نفس صيغة الـ id، نفس شروط العنوان). AppCubit
/// أصبح مسؤولاً فقط عن التنسيق (orchestration): يستدعي هذه الخدمة ثم يضع
/// النتيجة في الحالة الجديدة.
class AuditLogService {
  const AuditLogService._();

  static const int maxLogs = 600;
  static const int maxNotifications = 800;

  static String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  /// يبني [LogEntryEntity] جديد بالإضافة لقائمتي logs/notifications
  /// المحدَّثتين (مدموجتين ومقلَّمتين) استعدادًا لوضعهما في الحالة الجديدة.
  static AuditLogBuildResult build({
    required String action,
    required String entityType,
    required String entityId,
    required String details,
    required String beforeStateJson,
    required String afterStateJson,
    required List<LogEntryEntity> existingLogs,
    required List<NotificationEntity> existingNotifications,
    String? titleOverride,
    bool recordInNotificationHistory = false,
  }) {
    final title = titleOverride ?? notificationTitle(action, entityType);
    final log = LogEntryEntity(
      id: _id('log'),
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: DateTime.now(),
      beforeState: beforeStateJson,
      afterState: afterStateJson,
      isReverted: false,
    );
    final notifications = recordInNotificationHistory
        ? [
            NotificationEntity(
              id: _id('notif'),
              title: title,
              message: details,
              createdAt: DateTime.now(),
              type: entityType,
              relatedLogId: log.id,
              isPendingAction: true,
            ),
            ...existingNotifications,
          ].take(maxNotifications).toList()
        : existingNotifications;

    return AuditLogBuildResult(
      log: log,
      logs: [log, ...existingLogs].take(maxLogs).toList(),
      notifications: notifications,
    );
  }

  static String notificationTitle(String action, String entityType) {
    if (entityType == 'income' || entityType == 'transaction') {
      return 'إشعار معاملة';
    }
    if (entityType == 'budget') {
      return 'إشعار الميزانية';
    }
    if (entityType == 'recurring-transaction') {
      return 'إشعار معاملة متكررة';
    }
    if (entityType == 'goal') {
      return 'إشعار هدف';
    }
    if (action == 'delete') {
      return 'إشعار حذف';
    }
    return 'إشعار جديد';
  }

  static String transactionTypeLabel(String type) {
    if (type == TransactionType.income.value) return 'دخل';
    if (type == TransactionType.expense.value) return 'مصروف';
    if (type == TransactionType.transfer.value) return 'تحويل';
    return type;
  }
}
