class LogEntryEntity {
  const LogEntryEntity({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.details,
    required this.timestamp,
    required this.beforeState,
    required this.afterState,
    required this.isReverted,
    this.revertedAt,
  });

  final String id;
  final String action;
  final String entityType;
  final String entityId;
  final String details;
  final DateTime timestamp;
  final String beforeState;
  final String afterState;
  final bool isReverted;
  final DateTime? revertedAt;

  LogEntryEntity copyWith({
    bool? isReverted,
    DateTime? revertedAt,
  }) {
    return LogEntryEntity(
      id: id,
      action: action,
      entityType: entityType,
      entityId: entityId,
      details: details,
      timestamp: timestamp,
      beforeState: beforeState,
      afterState: afterState,
      isReverted: isReverted ?? this.isReverted,
      revertedAt: revertedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'action': action,
        'entityType': entityType,
        'entityId': entityId,
        'details': details,
        'timestamp': timestamp.toIso8601String(),
        'beforeState': beforeState,
        'afterState': afterState,
        'isReverted': isReverted,
        'revertedAt': revertedAt?.toIso8601String(),
      };

  factory LogEntryEntity.fromMap(Map<String, dynamic> map) => LogEntryEntity(
        id: map['id'] as String? ?? '',
        action: map['action'] as String? ?? '',
        entityType: map['entityType'] as String? ?? '',
        entityId: map['entityId'] as String? ?? '',
        details: map['details'] as String? ?? '',
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
            DateTime.now(),
        beforeState: map['beforeState'] as String? ?? '{}',
        afterState: map['afterState'] as String? ?? '{}',
        isReverted: map['isReverted'] as bool? ?? false,
        revertedAt: map['revertedAt'] != null
            ? DateTime.tryParse(map['revertedAt'] as String)
            : null,
      );
}
