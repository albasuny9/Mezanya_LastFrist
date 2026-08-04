/// Distribution Entry — وحدة البيانات الأساسية لـ Money Distribution Domain
///
/// ## ما هو
/// يمثّل تخصيصاً واحداً لمبلغ معين من حصالة معينة لمحفظة فيزيائية معينة.
///
/// ```
/// Jar  ─→  Wallet  ─→  Amount
/// ```
///
/// ## ما ليس عليه
/// - ليس معاملة (Transaction)
/// - ليس سجلاً مالياً
/// - لا يُغيّر رصيد أي محفظة
/// - لا يُغيّر رصيد أي حصالة
///
/// ## علاقته بـ JarWalletSource
/// [DistributionEntry] هو النموذج الجديد الذي سيحلّ محلّ [JarWalletSource]
/// في المراحل القادمة. في المرحلة الحالية يتعايشان:
/// - [JarWalletSource] هو وسيلة التخزين الحالية داخل [LinkedWalletEntity]
/// - [DistributionEntry] هو النموذج المرجعي للبناء عليه مستقبلاً
///
/// ## التخزين
/// في المرحلة الحالية، التخصيصات مخزّنة داخل
/// `LinkedWalletEntity.walletSources` كقائمة من [JarWalletSource].
/// استخدام [DistributionEntry] كنموذج مستقل للتحليل والتحقق متاح
/// من خلال [DistributionEntry.fromJarWalletSource].
enum DistributionOrigin {
  /// أُنشئ تلقائياً بعد انتهاء عملية مالية في طبقة التطبيق.
  automatic,

  /// أُنشئ يدوياً من قِبَل المستخدم.
  manual,

  /// أُنشئ من نقل يدوي بين محافظ.
  transfer,

  /// أُنشئ أثناء ترحيل البيانات القديمة
  migration,

  /// أُنشئ أثناء استرداد بيانات غير مكتملة.
  recovery,
}

DistributionOrigin distributionOriginFromValue(String? value) {
  for (final origin in DistributionOrigin.values) {
    if (origin.name == value) return origin;
  }
  return DistributionOrigin.manual;
}

class DistributionEntry {
  const DistributionEntry({
    required this.id,
    required this.jarId,
    required this.walletId,
    required this.amount,
    required this.origin,
    required this.createdAt,
    this.linkedTransactionId,
    this.updatedAt,
  });

  /// معرّف فريد للتخصيص
  final String id;

  /// معرّف الحصالة (Jar) التي تحتوي هذا المبلغ
  final String jarId;

  /// معرّف المحفظة الفيزيائية التي أتى منها هذا المبلغ
  final String walletId;

  /// المبلغ المُخصَّص — يجب أن يكون > 0 دائماً
  final double amount;

  /// مصدر إنشاء هذا التخصيص
  final DistributionOrigin origin;

  /// تاريخ الإنشاء
  final DateTime createdAt;

  /// تاريخ آخر تعديل (null = لم يُعدَّل)
  final DateTime? updatedAt;

  /// معرّف المعاملة المرتبطة (للتخصيصات التلقائية)
  final String? linkedTransactionId;

  /// يُنشئ [DistributionEntry] مؤقتاً من بيانات [JarWalletSource] الحالية
  /// بغرض التحليل والتحقق فقط — لا يُستخدم للتخزين.
  factory DistributionEntry.fromWalletSource({
    required String jarId,
    required String walletId,
    required double amount,
  }) =>
      DistributionEntry(
        id: 'tmp-$jarId-$walletId',
        jarId: jarId,
        walletId: walletId,
        amount: amount,
        origin: DistributionOrigin.automatic,
        createdAt: DateTime(2000),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'jarId': jarId,
        'walletId': walletId,
        'amount': amount,
        'origin': origin.name,
        'linkedTransactionId': linkedTransactionId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory DistributionEntry.fromMap(Map<String, dynamic> map) =>
      DistributionEntry(
        id: map['id'] as String? ?? '',
        jarId: map['jarId'] as String? ?? '',
        walletId: map['walletId'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        origin: distributionOriginFromValue(map['origin'] as String?),
        linkedTransactionId: map['linkedTransactionId'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? ''),
      );

  DistributionEntry copyWith({
    String? id,
    String? jarId,
    String? walletId,
    double? amount,
    DistributionOrigin? origin,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? linkedTransactionId,
  }) =>
      DistributionEntry(
        id: id ?? this.id,
        jarId: jarId ?? this.jarId,
        walletId: walletId ?? this.walletId,
        amount: amount ?? this.amount,
        origin: origin ?? this.origin,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      );

  @override
  String toString() =>
      'DistributionEntry(jar=$jarId, wallet=$walletId, amount=$amount, '
      'origin=${origin.name})';
}
