class GoalEntity {
  const GoalEntity({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.startDate,
    required this.endDate,
    this.icon = 'savings',
    this.iconColor = '#2f6f5e',
    this.notes,
  });

  final String id;
  final String name;
  final double targetAmount;
  final DateTime startDate;
  final DateTime endDate;
  final String icon;
  final String iconColor;
  final String? notes;

  GoalEntity copyWith({
    String? id,
    String? name,
    double? targetAmount,
    DateTime? startDate,
    DateTime? endDate,
    String? icon,
    String? iconColor,
    String? notes,
  }) {
    return GoalEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'icon': icon,
      'iconColor': iconColor,
      'notes': notes,
    };
  }

  factory GoalEntity.fromMap(Map<String, dynamic> map) {
    return GoalEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0,
      startDate: DateTime.tryParse(map['startDate'] as String? ?? '') ??
          DateTime.now(),
      endDate:
          DateTime.tryParse(map['endDate'] as String? ?? '') ?? DateTime.now(),
      icon: map['icon'] as String? ?? 'savings',
      iconColor: map['iconColor'] as String? ?? '#2f6f5e',
      notes: map['notes'] as String?,
    );
  }
}
