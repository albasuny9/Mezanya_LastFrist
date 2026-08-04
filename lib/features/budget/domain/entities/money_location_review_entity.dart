/// أنواع مراجعة مكان الفلوس
///
/// كل نوع يمثّل سبباً مختلفاً لعدم اليقين في مكان فلوس الحصالة.
/// لا يحجب أيٌّ منها إنشاء المعاملات — المستخدم يراجعها لاحقاً.
enum MoneyLocationReviewType {
  /// صُرف من محفظة غير مدرجة في مصادر الحصالة
  spendingWalletMismatch('spending-wallet-mismatch'),

  /// أصبح مصدر محفظة سالباً بعد عملية عكس أو تعديل
  sourceWentNegative('source-went-negative'),

  /// مجموع التصنيفات (labeledTotal) يتجاوز رصيد الحصالة — كُشف أثناء الترحيل
  labeledExceedsBalance('labeled-exceeds-balance');

  const MoneyLocationReviewType(this.value);

  final String value;

  static MoneyLocationReviewType? fromValue(String? value) {
    for (final t in MoneyLocationReviewType.values) {
      if (t.value == value) return t;
    }
    return null;
  }
}

/// عنصر مراجعة مكان فلوس معلّق
///
/// يُنشأ عند اكتشاف تعارض في مكان الفلوس بدلاً من الحذف الصامت.
/// يُخزَّن داخل [LinkedWalletEntity.moneyLocationReviews].
///
/// لا يحتوي على منطق عمل — بيانات فقط.
/// لا يُعدَّل walletSources أو jar.balance عند إنشائه.
class MoneyLocationReview {
  const MoneyLocationReview({
    required this.id,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.relatedTransactionId,
    this.notes,
  });

  /// معرّف فريد للمراجعة
  final String id;

  /// المبلغ محل المراجعة
  final double amount;

  /// نوع المراجعة — [MoneyLocationReviewType.value]
  final String type;

  /// تاريخ إنشاء المراجعة
  final DateTime createdAt;

  /// معرّف المعاملة التي أدّت لإنشاء هذه المراجعة (اختياري)
  final String? relatedTransactionId;

  /// وصف مختصر للتعارض (للعرض)
  final String? notes;

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'relatedTransactionId': relatedTransactionId,
        'notes': notes,
      };

  factory MoneyLocationReview.fromMap(Map<String, dynamic> map) =>
      MoneyLocationReview(
        id: map['id'] as String? ?? '',
        amount: (map['amount'] as num?)?.toDouble() ?? 0,
        type: map['type'] as String? ??
            MoneyLocationReviewType.spendingWalletMismatch.value,
        createdAt:
            DateTime.tryParse(map['createdAt'] as String? ?? '') ??
                DateTime.now(),
        relatedTransactionId: map['relatedTransactionId'] as String?,
        notes: map['notes'] as String?,
      );

  MoneyLocationReview copyWith({
    String? id,
    double? amount,
    String? type,
    DateTime? createdAt,
    String? relatedTransactionId,
    String? notes,
  }) =>
      MoneyLocationReview(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        relatedTransactionId:
            relatedTransactionId ?? this.relatedTransactionId,
        notes: notes ?? this.notes,
      );
}
