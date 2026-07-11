class WalletEntity {
  const WalletEntity({
    required this.id,
    required this.name,
    required this.balance,
    // ignore: deprecated_member_use_from_same_package
    this.reservedForSavings = 0,
    this.icon,
    this.iconColor,
    this.isHighlighted = false,
  });

  final String id;
  final String name;
  final double balance;

  // TODO(dead-field): `reservedForSavings` غير مستخدم في أي منطق عمل أو
  // UI حاليًا (مؤكَّد بالتدقيق: docs/architecture/financial-domain-model-audit.md،
  // قسم Wallet). لم يُحذف لأنه محفوظ في toMap/fromMap، وقد تحتوي نسخ
  // محلية أو Firestore قديمة على هذا الحقل — حذفه فورًا قد يفقد بيانات
  // مستخدمين قدامى عند فك التسلسل (deserialize) لنسخة قديمة. يُحذف فعليًا
  // فقط بعد تأكيد عدم وجوده في أي نسخة محفوظة نشطة، كخطوة منفصلة.
  @Deprecated(
    'غير مستخدم في أي منطق عمل — محفوظ فقط للتوافق مع بيانات/نسخ قديمة. '
    'راجع docs/architecture/financial-domain-model-audit.md قبل الحذف.',
  )
  final double reservedForSavings;
  final String? icon;
  final String? iconColor;
  final bool isHighlighted;

  WalletEntity copyWith({
    String? id,
    String? name,
    double? balance,
    double? reservedForSavings,
    String? icon,
    String? iconColor,
    bool? isHighlighted,
  }) {
    return WalletEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      // ignore: deprecated_member_use_from_same_package
      reservedForSavings: reservedForSavings ?? this.reservedForSavings,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'balance': balance,
      // ignore: deprecated_member_use_from_same_package
      'reservedForSavings': reservedForSavings,
      'icon': icon,
      'iconColor': iconColor,
      'isHighlighted': isHighlighted,
    };
  }

  factory WalletEntity.fromMap(Map<String, dynamic> map) {
    return WalletEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      // ignore: deprecated_member_use_from_same_package
      reservedForSavings: (map['reservedForSavings'] as num?)?.toDouble() ?? 0,
      icon: map['icon'] as String?,
      iconColor: map['iconColor'] as String?,
      isHighlighted: map['isHighlighted'] as bool? ?? false,
    );
  }
}
