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
  /// أُنشئ تلقائياً عند معالجة معاملة (income / jarFunding / etc.)
  automatic,

  /// أُنشئ يدوياً من قِبَل المستخدم عبر [relabelJarWalletSource]
  manual,

  /// أُنشئ أثناء ترحيل البيانات القديمة
  migration,
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
    this.notes,
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

  /// ملاحظة اختيارية
  final String? notes;

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

  DistributionEntry copyWith({
    String? id,
    String? jarId,
    String? walletId,
    double? amount,
    DistributionOrigin? origin,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? linkedTransactionId,
    String? notes,
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
        notes: notes ?? this.notes,
      );

  @override
  String toString() =>
      'DistributionEntry(jar=$jarId, wallet=$walletId, amount=$amount, '
      'origin=${origin.name})';
}
