class RecurringTransactionEntity {
  const RecurringTransactionEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.dayOfMonth,
    required this.executionType,
    required this.walletId,
    required this.budgetScope,
    required this.recurrencePattern,
    required this.icon,
    required this.iconColor,
    this.weekday,
    this.weekdays = const [],
    this.monthOfYear,
    this.anchorDate,
    this.scheduledTime,
    this.reminderLeadDays,
    this.allocationId,
    this.targetJarId,
    this.incomeSourceId,
    this.categoryIds = const [],
    this.isVariableIncome = false,
    this.isDebtOrSubscription = false,
    this.expensePlanKind,
    this.debtPrincipalTotal,
    this.installmentCount,
    this.installmentDownPayment,
    this.notes,
    this.snoozedUntil,
    this.lastHandledOccurrenceAt,
    this.handledOccurrenceIds = const [],
    this.postponedOccurrenceIds = const [],
    this.skippedOccurrenceIds = const [],
    this.isActive = true,
    this.isLent = false,
    this.lentPersonName,
    this.lentEntries = const [],
    this.isLentArchived = false,
  });

  final String id;
  final String name;
  final String type;
  final double amount;
  final int dayOfMonth;
  final String executionType;
  final String walletId;
  final String budgetScope;
  final String recurrencePattern;
  final String icon;
  final String iconColor;
  final int? weekday;
  final List<int> weekdays;
  final int? monthOfYear;
  final String? anchorDate;
  final String? scheduledTime;
  final int? reminderLeadDays;
  final String? allocationId;
  final String? targetJarId;
  final String? incomeSourceId;
  final List<String> categoryIds;
  final bool isVariableIncome;
  final bool isDebtOrSubscription;
  final String? expensePlanKind;
  final double? debtPrincipalTotal;
  final int? installmentCount;
  final double? installmentDownPayment;
  final String? notes;
  final String? snoozedUntil;
  final String? lastHandledOccurrenceAt;
  final List<String> handledOccurrenceIds;
  final List<String> postponedOccurrenceIds;
  final List<String> skippedOccurrenceIds;
  final bool isActive;
  final bool isLent;
  final String? lentPersonName;

  /// قائمة السلفات الفردية لهذا الشخص
  /// كل عنصر: { id, amount, lentDate, expectedReturnDate, notes, isSettled }
  final List<Map<String, dynamic>> lentEntries;

  /// هل تم أرشفة هذا الشخص (كل سلفاته انتهت)
  final bool isLentArchived;

  // ── Computed helpers ───────────────────────────────────────────────────────

  /// إجمالي المبالغ غير المستردة
  double get outstandingLentAmount => lentEntries
      .where((e) => e['isSettled'] != true)
      .fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0));

  /// هل هناك سلفات لم تُسدد؟
  bool get hasOutstandingLent => lentEntries.any((e) => e['isSettled'] != true);

  static DateTime _normalizeOccurrence(DateTime occurrence) {
    return DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
      occurrence.hour,
      occurrence.minute,
    );
  }

  /// Returns a deterministic domain identity for a recurring occurrence.
  ///
  /// This identity combines the recurring transaction id with a normalized
  /// occurrence timestamp, making it stable across app restarts and usable
  /// as an idempotency key.
  String occurrenceId(DateTime occurrence) {
    final normalized = _normalizeOccurrence(occurrence);
    return '$id|${normalized.toIso8601String()}';
  }

  /// Returns a deterministic domain identity for a recurring occurrence.
  /// Useful when only the recurring id and occurrence timestamp are available.
  static String occurrenceIdFor(String recurringId, DateTime occurrence) {
    final normalized = _normalizeOccurrence(occurrence);
    return '$recurringId|${normalized.toIso8601String()}';
  }

  List<String> get effectiveHandledOccurrenceIds {
    if (handledOccurrenceIds.isNotEmpty) return handledOccurrenceIds;
    final legacy = _legacyHandledOccurrenceId;
    return legacy == null ? const <String>[] : [legacy];
  }

  String? get _legacyHandledOccurrenceId {
    if (lastHandledOccurrenceAt == null || lastHandledOccurrenceAt!.isEmpty) {
      return null;
    }
    final parsed = DateTime.tryParse(lastHandledOccurrenceAt!);
    if (parsed == null) return null;
    return occurrenceIdFor(id, parsed);
  }

  bool hasHandledOccurrence(DateTime occurrence) {
    final id = occurrenceId(occurrence);
    return effectiveHandledOccurrenceIds.contains(id);
  }

  bool hasPostponedOccurrence(DateTime occurrence) {
    final id = occurrenceId(occurrence);
    return postponedOccurrenceIds.contains(id);
  }

  bool hasSkippedOccurrence(DateTime occurrence) {
    final id = occurrenceId(occurrence);
    return skippedOccurrenceIds.contains(id);
  }

  RecurringTransactionEntity withHandledOccurrence(DateTime occurrence) {
    final id = occurrenceId(occurrence);
    final nextHandled = [...handledOccurrenceIds, if (!handledOccurrenceIds.contains(id)) id];
    final nextPostponed = postponedOccurrenceIds.where((item) => item != id).toList();
    final nextSkipped = skippedOccurrenceIds.where((item) => item != id).toList();
    return copyWith(
      handledOccurrenceIds: nextHandled,
      postponedOccurrenceIds: nextPostponed,
      skippedOccurrenceIds: nextSkipped,
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );
  }

  RecurringTransactionEntity withPostponedOccurrence(
    DateTime occurrence, {
    required String? snoozedUntil,
  }) {
    final id = occurrenceId(occurrence);
    final nextPostponed = [
      ...postponedOccurrenceIds.where((item) => item != id),
      id,
    ];
    final nextHandled = handledOccurrenceIds.where((item) => item != id).toList();
    final nextSkipped = skippedOccurrenceIds.where((item) => item != id).toList();
    return copyWith(
      handledOccurrenceIds: nextHandled,
      postponedOccurrenceIds: nextPostponed,
      skippedOccurrenceIds: nextSkipped,
      snoozedUntil: snoozedUntil,
    );
  }

  RecurringTransactionEntity withSkippedOccurrence(DateTime occurrence) {
    final id = occurrenceId(occurrence);
    final nextSkipped = [
      ...skippedOccurrenceIds.where((item) => item != id),
      id,
    ];
    final nextHandled = handledOccurrenceIds.where((item) => item != id).toList();
    final nextPostponed = postponedOccurrenceIds.where((item) => item != id).toList();
    return copyWith(
      handledOccurrenceIds: nextHandled,
      postponedOccurrenceIds: nextPostponed,
      skippedOccurrenceIds: nextSkipped,
      lastHandledOccurrenceAt: occurrence.toIso8601String(),
      snoozedUntil: '',
    );
  }

  RecurringTransactionEntity withClearedPostponedOccurrence(DateTime occurrence) {
    final id = occurrenceId(occurrence);
    final nextPostponed = postponedOccurrenceIds.where((item) => item != id).toList();
    return copyWith(
      postponedOccurrenceIds: nextPostponed,
      snoozedUntil: '',
    );
  }

  RecurringTransactionEntity copyWith({
    String? id,
    String? name,
    String? type,
    double? amount,
    int? dayOfMonth,
    String? executionType,
    String? walletId,
    String? budgetScope,
    String? recurrencePattern,
    String? icon,
    String? iconColor,
    int? weekday,
    List<int>? weekdays,
    int? monthOfYear,
    String? anchorDate,
    String? scheduledTime,
    int? reminderLeadDays,
    String? allocationId,
    String? targetJarId,
    String? incomeSourceId,
    List<String>? categoryIds,
    bool? isVariableIncome,
    bool? isDebtOrSubscription,
    String? expensePlanKind,
    double? debtPrincipalTotal,
    int? installmentCount,
    double? installmentDownPayment,
    String? notes,
    String? snoozedUntil,
    String? lastHandledOccurrenceAt,
    List<String>? handledOccurrenceIds,
    List<String>? postponedOccurrenceIds,
    List<String>? skippedOccurrenceIds,
    bool? isActive,
    bool? isLent,
    String? lentPersonName,
    List<Map<String, dynamic>>? lentEntries,
    bool? isLentArchived,
  }) {
    return RecurringTransactionEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      executionType: executionType ?? this.executionType,
      walletId: walletId ?? this.walletId,
      budgetScope: budgetScope ?? this.budgetScope,
      recurrencePattern: recurrencePattern ?? this.recurrencePattern,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      weekday: weekday ?? this.weekday,
      weekdays: weekdays ?? this.weekdays,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      anchorDate: anchorDate ?? this.anchorDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      reminderLeadDays: reminderLeadDays ?? this.reminderLeadDays,
      allocationId: allocationId ?? this.allocationId,
      targetJarId: targetJarId ?? this.targetJarId,
      incomeSourceId: incomeSourceId ?? this.incomeSourceId,
      categoryIds: categoryIds ?? this.categoryIds,
      isVariableIncome: isVariableIncome ?? this.isVariableIncome,
      isDebtOrSubscription: isDebtOrSubscription ?? this.isDebtOrSubscription,
      expensePlanKind: expensePlanKind ?? this.expensePlanKind,
      debtPrincipalTotal: debtPrincipalTotal ?? this.debtPrincipalTotal,
      installmentCount: installmentCount ?? this.installmentCount,
      installmentDownPayment:
          installmentDownPayment ?? this.installmentDownPayment,
      notes: notes ?? this.notes,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      lastHandledOccurrenceAt:
          lastHandledOccurrenceAt ?? this.lastHandledOccurrenceAt,
      handledOccurrenceIds: handledOccurrenceIds ?? this.handledOccurrenceIds,
      postponedOccurrenceIds:
          postponedOccurrenceIds ?? this.postponedOccurrenceIds,
      skippedOccurrenceIds: skippedOccurrenceIds ?? this.skippedOccurrenceIds,
      isActive: isActive ?? this.isActive,
      isLent: isLent ?? this.isLent,
      lentPersonName: lentPersonName ?? this.lentPersonName,
      lentEntries: lentEntries ?? this.lentEntries,
      isLentArchived: isLentArchived ?? this.isLentArchived,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'amount': amount,
      'dayOfMonth': dayOfMonth,
      'executionType': executionType,
      'walletId': walletId,
      'budgetScope': budgetScope,
      'recurrencePattern': recurrencePattern,
      'icon': icon,
      'iconColor': iconColor,
      'weekday': weekday,
      'weekdays': weekdays,
      'monthOfYear': monthOfYear,
      'anchorDate': anchorDate,
      'scheduledTime': scheduledTime,
      'reminderLeadDays': reminderLeadDays,
      'allocationId': allocationId,
      'targetJarId': targetJarId,
      'incomeSourceId': incomeSourceId,
      'categoryIds': categoryIds,
      'isVariableIncome': isVariableIncome,
      'isDebtOrSubscription': isDebtOrSubscription,
      'expensePlanKind': expensePlanKind,
      'debtPrincipalTotal': debtPrincipalTotal,
      'installmentCount': installmentCount,
      'installmentDownPayment': installmentDownPayment,
      'notes': notes,
      'snoozedUntil': snoozedUntil,
      'lastHandledOccurrenceAt': lastHandledOccurrenceAt,
      'handledOccurrenceIds': handledOccurrenceIds,
      'postponedOccurrenceIds': postponedOccurrenceIds,
      'skippedOccurrenceIds': skippedOccurrenceIds,
      'isActive': isActive,
      'isLent': isLent,
      'lentPersonName': lentPersonName,
      'lentEntries': lentEntries,
      'isLentArchived': isLentArchived,
    };
  }

  factory RecurringTransactionEntity.fromMap(Map<String, dynamic> map) {
    final handledOccurrenceIds = (map['handledOccurrenceIds'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item as String)
        .toList();
    final legacyHandledAt = map['lastHandledOccurrenceAt'] as String?;
    final normalizedHandledOccurrenceIds = handledOccurrenceIds.isEmpty &&
            legacyHandledAt != null &&
            legacyHandledAt.isNotEmpty
        ? [
            RecurringTransactionEntity.occurrenceIdFor(
              map['id'] as String? ?? '',
              DateTime.parse(legacyHandledAt),
            ),
          ]
        : handledOccurrenceIds;

    return RecurringTransactionEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: map['type'] as String? ?? 'expense',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      dayOfMonth: (map['dayOfMonth'] as int? ?? 1).clamp(1, 31),
      executionType: map['executionType'] as String? ?? 'confirm',
      walletId: map['walletId'] as String? ?? '',
      budgetScope: map['budgetScope'] as String? ?? 'outside-budget',
      recurrencePattern: map['recurrencePattern'] as String? ?? 'monthly',
      icon: map['icon'] as String? ?? 'category',
      iconColor: map['iconColor'] as String? ?? '#165b47',
      weekday: map['weekday'] as int?,
      weekdays: (map['weekdays'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as int)
          .toList(),
      monthOfYear: map['monthOfYear'] as int?,
      anchorDate: map['anchorDate'] as String?,
      scheduledTime: map['scheduledTime'] as String?,
      reminderLeadDays: map['reminderLeadDays'] as int?,
      allocationId: map['allocationId'] as String?,
      targetJarId: map['targetJarId'] as String?,
      incomeSourceId: map['incomeSourceId'] as String?,
      categoryIds: (map['categoryIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as String)
          .toList(),
      isVariableIncome: map['isVariableIncome'] as bool? ?? false,
      isDebtOrSubscription: map['isDebtOrSubscription'] as bool? ?? false,
      expensePlanKind: map['expensePlanKind'] as String?,
      debtPrincipalTotal: (map['debtPrincipalTotal'] as num?)?.toDouble(),
      installmentCount: map['installmentCount'] as int?,
      installmentDownPayment: (map['installmentDownPayment'] as num?)
          ?.toDouble(),
      notes: map['notes'] as String?,
      snoozedUntil: map['snoozedUntil'] as String?,
      lastHandledOccurrenceAt: legacyHandledAt,
      handledOccurrenceIds: normalizedHandledOccurrenceIds,
      postponedOccurrenceIds: (map['postponedOccurrenceIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as String)
          .toList(),
      skippedOccurrenceIds: (map['skippedOccurrenceIds'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as String)
          .toList(),
      isActive: map['isActive'] as bool? ?? true,
      isLent: map['isLent'] as bool? ?? false,
      lentPersonName: map['lentPersonName'] as String?,
      lentEntries: (map['lentEntries'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      isLentArchived: map['isLentArchived'] as bool? ?? false,
    );
  }
}
