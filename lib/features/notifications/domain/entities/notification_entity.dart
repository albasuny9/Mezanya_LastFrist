class NotificationEntity {
  const NotificationEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.type,
    this.relatedLogId,
    this.readAt,
    this.isPendingAction = false,
  });

  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final String type;
  final String? relatedLogId;
  final DateTime? readAt;

  /// إجراء من مركز الإشعارات (تأكيد/تأجيل/تخطي) — يظهر في سجل الإشعارات فقط.
  final bool isPendingAction;

  bool get isRead => readAt != null;

  NotificationEntity copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? createdAt,
    String? type,
    String? relatedLogId,
    DateTime? readAt,
    bool? isPendingAction,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      relatedLogId: relatedLogId ?? this.relatedLogId,
      readAt: readAt ?? this.readAt,
      isPendingAction: isPendingAction ?? this.isPendingAction,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'relatedLogId': relatedLogId,
      'readAt': readAt?.toIso8601String(),
      'isPendingAction': isPendingAction,
    };
  }

  factory NotificationEntity.fromMap(Map<String, dynamic> map) {
    return NotificationEntity(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      type: map['type'] as String? ?? 'general',
      relatedLogId: map['relatedLogId'] as String?,
      readAt: map['readAt'] != null
          ? DateTime.tryParse(map['readAt'] as String)
          : null,
      isPendingAction: map['isPendingAction'] as bool? ?? false,
    );
  }
}
