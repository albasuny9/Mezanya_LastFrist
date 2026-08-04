import '../../../categories/domain/entities/category_entity.dart';
import '../../../../core/constants/transaction_types.dart';
import 'money_location_review_entity.dart';

class IncomeSourceEntity {
  const IncomeSourceEntity({
    required this.id,
    required this.name,
    required this.amount,
    required this.date,
    required this.type,
    required this.targetWalletId,
    this.isVariable = false,
    this.isDefault = false,
    this.snoozedUntil,
    this.icon,
    this.iconColor,
    this.companyName,
    this.notes,
  });

  final String id;
  final String name;
  final double amount;
  final int date;
  final String type;
  final String targetWalletId;
  final bool isVariable;
  final bool isDefault;

  /// تأجيل مؤقت — ISO string، فارغ = مش مأجل
  final String? snoozedUntil;

  // Identity (Step 2 — schema extension only، لا واجهة بعد):
  final String? icon;
  final String? iconColor;
  final String? companyName;
  final String? notes;

  bool get isSnoozed {
    if (snoozedUntil == null || snoozedUntil!.isEmpty) return false;
    final until = DateTime.tryParse(snoozedUntil!);
    return until != null && DateTime.now().isBefore(until);
  }

  DateTime? get snoozedUntilDate {
    if (snoozedUntil == null || snoozedUntil!.isEmpty) return null;
    return DateTime.tryParse(snoozedUntil!);
  }

  IncomeSourceEntity copyWith({
    String? id,
    String? name,
    double? amount,
    int? date,
    String? type,
    String? targetWalletId,
    bool? isVariable,
    bool? isDefault,
    String? snoozedUntil,
    String? icon,
    String? iconColor,
    String? companyName,
    String? notes,
  }) =>
      IncomeSourceEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        type: type ?? this.type,
        targetWalletId: targetWalletId ?? this.targetWalletId,
        isVariable: isVariable ?? this.isVariable,
        isDefault: isDefault ?? this.isDefault,
        snoozedUntil: snoozedUntil ?? this.snoozedUntil,
        icon: icon ?? this.icon,
        iconColor: iconColor ?? this.iconColor,
        companyName: companyName ?? this.companyName,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'date': date,
        'type': type,
        'targetWalletId': targetWalletId,
        'isVariable': isVariable,
        'isDefault': isDefault,
        'snoozedUntil': snoozedUntil,
        'icon': icon,
        'iconColor': iconColor,
        'companyName': companyName,
        'notes': notes,
      };

  factory IncomeSourceEntity.fromMap(Map<String, dynamic> map) =>
      IncomeSourceEntity(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        date: map['date'] as int? ?? 1,
        type: map['type'] as String? ?? 'confirm',
        targetWalletId: map['targetWalletId'] as String? ?? '',
        isVariable: map['isVariable'] as bool? ?? false,
        isDefault: map['isDefault'] as bool? ?? false,
        snoozedUntil: map['snoozedUntil'] as String?,
        icon: map['icon'] as String?,
        iconColor: map['iconColor'] as String?,
        companyName: map['companyName'] as String?,
        notes: map['notes'] as String?,
      );
}

class AllocationFundingEntity {
  const AllocationFundingEntity({
    required this.id,
    required this.incomeSourceId,
    required this.plannedAmount,
  });

  final String id;
  final String incomeSourceId;
  final double plannedAmount;

  Map<String, dynamic> toMap() => {
        'id': id,
        'incomeSourceId': incomeSourceId,
        'plannedAmount': plannedAmount,
      };

  factory AllocationFundingEntity.fromMap(Map<String, dynamic> map) =>
      AllocationFundingEntity(
        id: map['id'] as String? ?? '',
        incomeSourceId: map['incomeSourceId'] as String? ?? '',
        plannedAmount: (map['plannedAmount'] as num?)?.toDouble() ?? 0,
      );
}

class AllocationEntity {
  const AllocationEntity({
    required this.id,
    required this.name,
    this.balance = 0,
    required this.icon,
    required this.iconColor,
    required this.rolloverBehavior,
    required this.funding,
    required this.categories,
    this.walletBalances = const {},
    this.automationType = 'confirm',
    this.pendingDistribution = 0,
    this.pendingDistributionWalletId = '',
    this.pendingDistributionSourceId = '',
    this.pendingDistributionSnoozedUntil = '',
  });

  final String id;
  final String name;
  final double balance;
  final String icon;
  final String iconColor;
  final String rolloverBehavior;
  final List<AllocationFundingEntity> funding;
  final List<CategoryEntity> categories;
  final Map<String, double> walletBalances;

  /// 'auto' | 'confirm' | 'manual'
  final String automationType;

  /// مبلغ معلّق ينتظر تأكيد اليوزر
  final double pendingDistribution;
  final String pendingDistributionWalletId;
  final String pendingDistributionSourceId;
  final String pendingDistributionSnoozedUntil;

  bool get isPendingDistributionVisible {
    if (pendingDistribution <= 0) return false;
    if (pendingDistributionSnoozedUntil.isEmpty) return true;
    final until = DateTime.tryParse(pendingDistributionSnoozedUntil);
    if (until == null) return true;
    return !DateTime.now().isBefore(until);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'balance': balance,
        'icon': icon,
        'iconColor': iconColor,
        'rolloverBehavior': rolloverBehavior,
        'funding': funding.map((e) => e.toMap()).toList(),
        'categories': categories.map((e) => e.toMap()).toList(),
        'walletBalances': walletBalances,
        'automationType': automationType,
        'pendingDistribution': pendingDistribution,
        'pendingDistributionWalletId': pendingDistributionWalletId,
        'pendingDistributionSourceId': pendingDistributionSourceId,
        'pendingDistributionSnoozedUntil': pendingDistributionSnoozedUntil,
      };

  factory AllocationEntity.fromMap(Map<String, dynamic> map) =>
      AllocationEntity(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        icon: map['icon'] as String? ?? 'category',
        iconColor: map['iconColor'] as String? ?? '#165b47',
        rolloverBehavior: map['rolloverBehavior'] as String? ?? 'to-savings',
        funding: (map['funding'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AllocationFundingEntity.fromMap)
            .toList(),
        categories: (map['categories'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CategoryEntity.fromMap)
            .toList(),
        walletBalances: (map['walletBalances'] as Map<dynamic, dynamic>?)?.map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
            const {},
        automationType: map['automationType'] as String? ?? 'confirm',
        pendingDistribution:
            (map['pendingDistribution'] as num?)?.toDouble() ?? 0,
        pendingDistributionWalletId:
            map['pendingDistributionWalletId'] as String? ?? '',
        pendingDistributionSourceId:
            map['pendingDistributionSourceId'] as String? ?? '',
        pendingDistributionSnoozedUntil:
            map['pendingDistributionSnoozedUntil'] as String? ?? '',
      );

  AllocationEntity copyWith({
    String? id,
    String? name,
    double? balance,
    String? icon,
    String? iconColor,
    String? rolloverBehavior,
    List<AllocationFundingEntity>? funding,
    List<CategoryEntity>? categories,
    Map<String, double>? walletBalances,
    String? automationType,
    double? pendingDistribution,
    String? pendingDistributionWalletId,
    String? pendingDistributionSourceId,
    String? pendingDistributionSnoozedUntil,
  }) {
    return AllocationEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      rolloverBehavior: rolloverBehavior ?? this.rolloverBehavior,
      funding: funding ?? this.funding,
      categories: categories ?? this.categories,
      walletBalances: walletBalances ?? this.walletBalances,
      automationType: automationType ?? this.automationType,
      pendingDistribution: pendingDistribution ?? this.pendingDistribution,
      pendingDistributionWalletId:
          pendingDistributionWalletId ?? this.pendingDistributionWalletId,
      pendingDistributionSourceId:
          pendingDistributionSourceId ?? this.pendingDistributionSourceId,
      pendingDistributionSnoozedUntil: pendingDistributionSnoozedUntil ??
          this.pendingDistributionSnoozedUntil,
    );
  }
}

/// تصنيف مصدر فلوس الحصالة — label فقط بدون transactions فعلية
class JarWalletSource {
  const JarWalletSource({
    required this.walletId,
    required this.amount,
  });

  final String walletId;
  final double amount;

  JarWalletSource copyWith({String? walletId, double? amount}) =>
      JarWalletSource(
        walletId: walletId ?? this.walletId,
        amount: amount ?? this.amount,
      );

  Map<String, dynamic> toMap() => {'walletId': walletId, 'amount': amount};

  factory JarWalletSource.fromMap(Map<String, dynamic> map) => JarWalletSource(
        walletId: map['walletId'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
      );
}

class LinkedWalletEntityFunding {
  const LinkedWalletEntityFunding({
    required this.id,
    required this.incomeSourceId,
    required this.plannedAmount,
    this.isPhysical = false,
  });

  final String id;
  final String incomeSourceId;
  final double plannedAmount;
  final bool isPhysical;

  Map<String, dynamic> toMap() => {
        'id': id,
        'incomeSourceId': incomeSourceId,
        'plannedAmount': plannedAmount,
        'isPhysical': isPhysical,
      };

  factory LinkedWalletEntityFunding.fromMap(Map<String, dynamic> map) =>
      LinkedWalletEntityFunding(
        id: map['id'] as String? ?? '',
        incomeSourceId: map['incomeSourceId'] as String? ?? '',
        plannedAmount: (map['plannedAmount'] as num?)?.toDouble() ?? 0,
        isPhysical: map['isPhysical'] as bool? ?? false,
      );
}

class LinkedWalletEntity {
  const LinkedWalletEntity({
    required this.id,
    required this.name,
    this.balance = 0,
    required this.monthlyAmount,
    required this.executionDay,
    required this.fundingSource,
    required this.funding,
    required this.icon,
    required this.iconColor,
    required this.automationType,
    required this.categories,
    this.walletBalances = const {},
    this.walletSources = const [],
    this.isHighlighted = false,
    this.pendingDistribution = 0,
    this.pendingDistributionWalletId = '',
    this.pendingDistributionSourceId = '',
    this.pendingDistributionSnoozedUntil = '',
    this.moneyLocationReviews = const [],
  });

  final String id;
  final String name;
  final double balance;
  final double monthlyAmount;
  final int executionDay;
  final String fundingSource;
  final List<LinkedWalletEntityFunding> funding;
  final String icon;
  final String iconColor;
  final String automationType;
  final List<CategoryEntity> categories;

  /// legacy field — kept for backward compat
  final Map<String, double> walletBalances;

  /// مصادر الحصالة — label فقط، بدون transactions فعلية
  final List<JarWalletSource> walletSources;

  /// هل الكارت مُلوَّن (شفايفه)
  final bool isHighlighted;

  /// مبلغ معلّق ينتظر تأكيد اليوزر (لحصالات automationType='confirm')
  final double pendingDistribution;

  /// المحفظة التي سيُخصم منها المبلغ المعلّق (لو isPhysical)
  final String pendingDistributionWalletId;

  /// مصدر الدخل الذي أطلق التوزيع المعلّق
  final String pendingDistributionSourceId;

  final String pendingDistributionSnoozedUntil;

  /// مراجعات مكان الفلوس المعلّقة
  /// تُنشأ عند اكتشاف تعارض في مكان الفلوس بدلاً من الحذف الصامت.
  /// لا تحجب إنشاء المعاملات — المستخدم يراجعها لاحقاً في تفاصيل الحصالة.
  final List<MoneyLocationReview> moneyLocationReviews;

  bool get isPendingDistributionVisible {
    if (pendingDistribution <= 0) return false;
    if (pendingDistributionSnoozedUntil.isEmpty) return true;
    final until = DateTime.tryParse(pendingDistributionSnoozedUntil);
    if (until == null) return true;
    return !DateTime.now().isBefore(until);
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// مجموع المبالغ المصنفة من المحافظ
  double get labeledTotal => walletSources.fold(0.0, (s, e) => s + e.amount);

  /// الجزء غير المصنف من رصيد الحصالة
  double get unlabeledAmount => balance - labeledTotal;

  /// تحديث مصدر محفظة معينة (أو إضافته لو مش موجود)
  LinkedWalletEntity withUpdatedSource(String walletId, double amount) {
    final rest = walletSources.where((s) => s.walletId != walletId).toList();
    if (amount > 0) {
      rest.add(JarWalletSource(walletId: walletId, amount: amount));
    }
    return copyWith(walletSources: rest);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'balance': balance,
        'monthlyAmount': monthlyAmount,
        'executionDay': executionDay,
        'fundingSource': fundingSource,
        'funding': funding.map((e) => e.toMap()).toList(),
        'icon': icon,
        'iconColor': iconColor,
        'automationType': automationType,
        'categories': categories.map((e) => e.toMap()).toList(),
        'walletBalances': walletBalances,
        'walletSources': walletSources.map((s) => s.toMap()).toList(),
        'isHighlighted': isHighlighted,
        'pendingDistribution': pendingDistribution,
        'pendingDistributionWalletId': pendingDistributionWalletId,
        'pendingDistributionSourceId': pendingDistributionSourceId,
        'pendingDistributionSnoozedUntil': pendingDistributionSnoozedUntil,
        'moneyLocationReviews':
            moneyLocationReviews.map((r) => r.toMap()).toList(),
      };

  factory LinkedWalletEntity.fromMap(Map<String, dynamic> map) =>
      LinkedWalletEntity(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        balance: (map['balance'] as num?)?.toDouble() ?? 0,
        monthlyAmount: (map['monthlyAmount'] as num?)?.toDouble() ?? 0,
        executionDay: map['executionDay'] as int? ?? 1,
        fundingSource: map['fundingSource'] as String? ?? '',
        funding: (map['funding'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(LinkedWalletEntityFunding.fromMap)
            .toList(),
        icon: map['icon'] as String? ?? 'PiggyBank',
        iconColor: map['iconColor'] as String? ?? '#0f766e',
        automationType: map['automationType'] as String? ?? 'confirm',
        categories: (map['categories'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CategoryEntity.fromMap)
            .toList(),
        walletBalances: (map['walletBalances'] as Map<dynamic, dynamic>?)?.map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
            const {},
        walletSources: (map['walletSources'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(JarWalletSource.fromMap)
            .toList(),
        isHighlighted: map['isHighlighted'] as bool? ?? false,
        pendingDistribution:
            (map['pendingDistribution'] as num?)?.toDouble() ?? 0,
        pendingDistributionWalletId:
            map['pendingDistributionWalletId'] as String? ?? '',
        pendingDistributionSourceId:
            map['pendingDistributionSourceId'] as String? ?? '',
        pendingDistributionSnoozedUntil:
            map['pendingDistributionSnoozedUntil'] as String? ?? '',
        moneyLocationReviews:
            (map['moneyLocationReviews'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(MoneyLocationReview.fromMap)
                .toList(),
      );

  LinkedWalletEntity copyWith({
    String? id,
    String? name,
    double? balance,
    double? monthlyAmount,
    int? executionDay,
    String? fundingSource,
    List<LinkedWalletEntityFunding>? funding,
    String? icon,
    String? iconColor,
    String? automationType,
    List<CategoryEntity>? categories,
    Map<String, double>? walletBalances,
    List<JarWalletSource>? walletSources,
    bool? isHighlighted,
    double? pendingDistribution,
    String? pendingDistributionWalletId,
    String? pendingDistributionSourceId,
    String? pendingDistributionSnoozedUntil,
    List<MoneyLocationReview>? moneyLocationReviews,
  }) {
    return LinkedWalletEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      executionDay: executionDay ?? this.executionDay,
      fundingSource: fundingSource ?? this.fundingSource,
      funding: funding ?? this.funding,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      automationType: automationType ?? this.automationType,
      categories: categories ?? this.categories,
      walletBalances: walletBalances ?? this.walletBalances,
      walletSources: walletSources ?? this.walletSources,
      isHighlighted: isHighlighted ?? this.isHighlighted,
      pendingDistribution: pendingDistribution ?? this.pendingDistribution,
      pendingDistributionWalletId:
          pendingDistributionWalletId ?? this.pendingDistributionWalletId,
      pendingDistributionSourceId:
          pendingDistributionSourceId ?? this.pendingDistributionSourceId,
      pendingDistributionSnoozedUntil: pendingDistributionSnoozedUntil ??
          this.pendingDistributionSnoozedUntil,
      moneyLocationReviews:
          moneyLocationReviews ?? this.moneyLocationReviews,
    );
  }
}

/// kind values:
///   'installment'  — دين/قسط: له أصل كلي [principalTotal] وقسط شهري ثابت [amount]
///   'subscription' — اشتراك: لا أصل له، يتكرر حسب [recurrencePattern]
class DebtEntity {
  const DebtEntity({
    required this.id,
    required this.name,
    required this.amount,
    required this.executionDay,
    required this.type,
    required this.fundingSource,
    this.recurringTransactionId,
    this.kind = 'installment',
    this.principalTotal,
    this.installmentCount,
    this.downPayment,
    this.recurrencePattern = 'monthly',
    this.monthOfYear,
  });

  final String id;
  final String name;

  /// للأقساط: قيمة القسط الشهري.
  /// للاشتراكات: قيمة الدفعة الواحدة حسب [recurrencePattern].
  final double amount;

  final int executionDay;
  final String type;
  final String fundingSource;
  final String? recurringTransactionId;

  /// 'installment' | 'subscription'
  final String kind;

  /// أصل الدين الكلي — يُستخدم فقط لو [kind] == 'installment'
  final double? principalTotal;

  /// عدد الأقساط الكلي — يُستخدم فقط لو [kind] == 'installment'
  final int? installmentCount;

  /// المقدم — يُستخدم فقط لو [kind] == 'installment'
  final double? downPayment;

  /// تكرار الاشتراك — يُستخدم فقط لو [kind] == 'subscription'
  /// قيم: 'weekly' | 'biweekly' | 'every_3_weeks' | 'monthly' |
  ///       'every_2_months' | 'every_3_months' | 'every_6_months' | 'yearly'
  final String recurrencePattern;

  /// شهر الاستحقاق السنوي (1–12) — يُستخدم فقط لو recurrencePattern == 'yearly'
  final int? monthOfYear;

  // ── helpers ──────────────────────────────────────────────────────────────

  bool get isInstallment => kind == 'installment';
  bool get isSubscription => kind == 'subscription';

  /// هل الاشتراك ده هيُستحق في الدورة الحالية؟
  /// [cycleStart] = أول يوم في الدورة الحالية
  /// [cycleEnd]   = آخر يوم في الدورة الحالية
  bool isDueInCycle(DateTime cycleStart, DateTime cycleEnd) {
    if (isInstallment) return true; // الأقساط دايمًا شهرية
    return _hasDueDateInRange(cycleStart, cycleEnd);
  }

  /// عدد المرات اللي الاشتراك بيتكرر فيها في نطاق الدورة
  int occurrencesInCycle(DateTime cycleStart, DateTime cycleEnd) {
    if (isInstallment) return 1;
    var count = 0;
    var cursor = cycleStart;
    while (!cursor.isAfter(cycleEnd)) {
      if (_matchesDay(cursor)) count++;
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  /// إجمالي المبلغ المستحق في الدورة
  double amountDueInCycle(DateTime cycleStart, DateTime cycleEnd) {
    if (isInstallment) return amount;
    return amount * occurrencesInCycle(cycleStart, cycleEnd);
  }

  bool _hasDueDateInRange(DateTime start, DateTime end) {
    var cursor = start;
    while (!cursor.isAfter(end)) {
      if (_matchesDay(cursor)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  bool _matchesDay(DateTime day) {
    if (day.day != executionDay.clamp(1, 28)) return false;
    if (recurrencePattern == RecurrencePattern.monthly.value) return true;
    if (recurrencePattern == RecurrencePattern.yearly.value) {
      return day.month == (monthOfYear ?? executionDay);
    }
    if (recurrencePattern == RecurrencePattern.every2Months.value) {
      return day.month % 2 == executionDay % 2;
    }
    if (recurrencePattern == RecurrencePattern.every3Months.value) {
      return day.month % 3 == 0;
    }
    if (recurrencePattern == RecurrencePattern.every6Months.value) {
      return day.month % 6 == 0;
    }
    return true;
  }

  DebtEntity copyWith({
    String? id,
    String? name,
    double? amount,
    int? executionDay,
    String? type,
    String? fundingSource,
    String? recurringTransactionId,
    String? kind,
    double? principalTotal,
    int? installmentCount,
    double? downPayment,
    String? recurrencePattern,
    int? monthOfYear,
  }) =>
      DebtEntity(
        id: id ?? this.id,
        name: name ?? this.name,
        amount: amount ?? this.amount,
        executionDay: executionDay ?? this.executionDay,
        type: type ?? this.type,
        fundingSource: fundingSource ?? this.fundingSource,
        recurringTransactionId:
            recurringTransactionId ?? this.recurringTransactionId,
        kind: kind ?? this.kind,
        principalTotal: principalTotal ?? this.principalTotal,
        installmentCount: installmentCount ?? this.installmentCount,
        downPayment: downPayment ?? this.downPayment,
        recurrencePattern: recurrencePattern ?? this.recurrencePattern,
        monthOfYear: monthOfYear ?? this.monthOfYear,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'amount': amount,
        'executionDay': executionDay,
        'type': type,
        'fundingSource': fundingSource,
        'recurringTransactionId': recurringTransactionId,
        'kind': kind,
        'principalTotal': principalTotal,
        'installmentCount': installmentCount,
        'downPayment': downPayment,
        'recurrencePattern': recurrencePattern,
        'monthOfYear': monthOfYear,
      };

  factory DebtEntity.fromMap(Map<String, dynamic> map) => DebtEntity(
        id: map['id'] as String? ?? '',
        name: map['name'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        executionDay: map['executionDay'] as int? ?? 1,
        type: map['type'] as String? ?? 'confirm',
        fundingSource: map['fundingSource'] as String? ?? '',
        recurringTransactionId: map['recurringTransactionId'] as String?,
        kind: map['kind'] as String? ?? 'installment',
        principalTotal: (map['principalTotal'] as num?)?.toDouble(),
        installmentCount: map['installmentCount'] as int?,
        downPayment: (map['downPayment'] as num?)?.toDouble(),
        recurrencePattern: map['recurrencePattern'] as String? ?? 'monthly',
        monthOfYear: map['monthOfYear'] as int?,
      );
}

class BudgetSetupEntity {
  const BudgetSetupEntity({
    required this.startDay,
    required this.cycleMode,
    required this.bufferEndBehavior,
    required this.incomeSources,
    required this.allocations,
    required this.linkedWallets,
    required this.debts,
  });

  final int startDay;
  final String cycleMode;
  final String bufferEndBehavior;
  final List<IncomeSourceEntity> incomeSources;
  final List<AllocationEntity> allocations;
  final List<LinkedWalletEntity> linkedWallets;
  final List<DebtEntity> debts;

  /// إجمالي الدخل المخطط من كل مصادر الدخل الثابتة
  double get totalIncome => incomeSources
      .where((source) => !source.isVariable)
      .fold(0.0, (sum, source) => sum + source.amount);

  /// إجمالي المبالغ المخصصة عبر allocations
  double get totalAllocated => allocations.fold(
        0.0,
        (sum, allocation) => allocation.funding.fold(
          sum,
          (innerSum, funding) => innerSum + funding.plannedAmount,
        ),
      );

  /// المبلغ غير المخصص = الدخل الكلي - المخصص
  double get unallocatedAmount =>
      (totalIncome - totalAllocated).clamp(0.0, double.infinity);

  // ── Cycle helpers ────────────────────────────────────────────────────────

  /// بداية الدورة الحالية بناءً على [startDay].
  /// مثال: startDay=5, today=20 أبريل → 5 أبريل
  ///        startDay=5, today=3 أبريل  → 5 مارس
  DateTime cycleStartFor(DateTime now) {
    final thisMonth = DateTime(now.year, now.month, startDay.clamp(1, 28));
    return now.isBefore(thisMonth)
        ? DateTime(now.year, now.month - 1, startDay.clamp(1, 28))
        : thisMonth;
  }

  /// نهاية الدورة = ثانية قبل بداية الدورة الجاية
  DateTime cycleEndFor(DateTime now) {
    final s = cycleStartFor(now);
    return DateTime(s.year, s.month + 1, startDay.clamp(1, 28))
        .subtract(const Duration(seconds: 1));
  }

  /// مفتاح الدورة للـ snapshots  →  "2025-04-05"
  String cycleKeyFor(DateTime now) {
    final s = cycleStartFor(now);
    return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
  }

  /// إجمالي الديون/الاشتراكات المستحقة في نطاق دورة محدد
  double debtsTotalForCycle(DateTime cycleStart, DateTime cycleEnd) =>
      debts.fold<double>(
        0,
        (sum, d) => sum + d.amountDueInCycle(cycleStart, cycleEnd),
      );

  factory BudgetSetupEntity.initial(String walletId) => const BudgetSetupEntity(
        startDay: 1,
        cycleMode: 'confirm',
        bufferEndBehavior: 'to-savings',
        incomeSources: [
          // IncomeSourceEntity(
          //   id: 'salary-default',
          //   name: 'دخل جديد',
          //   amount: 0,
          //   date: 1,
          //   type: 'confirm',
          //   targetWalletId: walletId,
          //   isDefault: true,
          // ),
        ],
        allocations: [],
        linkedWallets: [],
        debts: [],
      );

  BudgetSetupEntity copyWith({
    int? startDay,
    String? cycleMode,
    String? bufferEndBehavior,
    List<IncomeSourceEntity>? incomeSources,
    List<AllocationEntity>? allocations,
    List<LinkedWalletEntity>? linkedWallets,
    List<DebtEntity>? debts,
  }) {
    return BudgetSetupEntity(
      startDay: startDay ?? this.startDay,
      cycleMode: cycleMode ?? this.cycleMode,
      bufferEndBehavior: bufferEndBehavior ?? this.bufferEndBehavior,
      incomeSources: incomeSources ?? this.incomeSources,
      allocations: allocations ?? this.allocations,
      linkedWallets: linkedWallets ?? this.linkedWallets,
      debts: debts ?? this.debts,
    );
  }

  Map<String, dynamic> toMap() => {
        'startDay': startDay,
        'cycleMode': cycleMode,
        'bufferEndBehavior': bufferEndBehavior,
        'incomeSources': incomeSources.map((e) => e.toMap()).toList(),
        'allocations': allocations.map((e) => e.toMap()).toList(),
        'linkedWallets': linkedWallets.map((e) => e.toMap()).toList(),
        'debts': debts.map((e) => e.toMap()).toList(),
      };

  factory BudgetSetupEntity.fromMap(Map<String, dynamic> map) =>
      BudgetSetupEntity(
        startDay: map['startDay'] as int? ?? 1,
        cycleMode: map['cycleMode'] as String? ?? 'confirm',
        bufferEndBehavior: map['bufferEndBehavior'] as String? ?? 'to-savings',
        incomeSources: (map['incomeSources'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(IncomeSourceEntity.fromMap)
            .toList(),
        allocations: (map['allocations'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AllocationEntity.fromMap)
            .toList(),
        linkedWallets: (map['linkedWallets'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(LinkedWalletEntity.fromMap)
            .toList(),
        debts: (map['debts'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DebtEntity.fromMap)
            .toList(),
      );
}
