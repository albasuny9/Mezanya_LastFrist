import '../entities/distribution_entry.dart';

/// Distribution Engine — محرك تخصيص أماكن الفلوس
///
/// ## المسؤولية الوحيدة
/// تنفيذ العمليات على [DistributionEntry] بشكل نظيف ومتوقع.
///
/// ## مسموح له فقط
/// - إنشاء entry جديد
/// - تعديل amount لـ entry موجود
/// - حذف entry
/// - نقل مبلغ من entry لآخر (تغيير الحصالة أو المحفظة)
/// - التحقق من صحة مجموعة entries
///
/// ## محظور عليه تماماً
/// - تغيير wallet.balance
/// - تغيير jar.balance
/// - إنشاء TransactionEntity
/// - استدعاء TransactionProcessor
/// - أي I/O
///
/// ## ملاحظة معمارية
/// في المرحلة الحالية، التخصيصات مخزّنة كـ JarWalletSource داخل
/// LinkedWalletEntity. هذا المحرك يعمل على DistributionEntry لأغراض
/// التحليل والتحقق. الربط الكامل مع التخزين يأتي في المرحلة الثانية.
class DistributionEngine {
  const DistributionEngine._();

  // ══════════════════════════════════════════════════════════════════════════
  // إنشاء
  // ══════════════════════════════════════════════════════════════════════════

  /// إنشاء entry جديد أو تحديث موجود لنفس (jarId + walletId)
  ///
  /// - إذا كان entry موجوداً لنفس الحصالة والمحفظة: يُحدَّث amount فقط
  /// - إذا لم يكن موجوداً: يُضاف entry جديد
  /// - إذا كان amount = 0 بعد التحديث: يُحذف
  static List<DistributionEntry> upsert({
    required List<DistributionEntry> entries,
    required String jarId,
    required String walletId,
    required double amount,
    DistributionOrigin origin = DistributionOrigin.manual,
    String? linkedTransactionId,
    String? notes,
  }) {
    assert(amount >= 0, 'Distribution amount must be >= 0');

    final rest = entries
        .where((e) => !(e.jarId == jarId && e.walletId == walletId))
        .toList();

    if (amount <= 0) return rest; // حذف إذا كان صفراً

    return [
      ...rest,
      DistributionEntry(
        id: 'dist-${DateTime.now().microsecondsSinceEpoch}',
        jarId: jarId,
        walletId: walletId,
        amount: amount,
        origin: origin,
        createdAt: DateTime.now(),
        linkedTransactionId: linkedTransactionId,
        notes: notes,
      ),
    ];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // تعديل بالدلتا
  // ══════════════════════════════════════════════════════════════════════════

  /// تطبيق تغيير نسبي (delta) على entry (jarId + walletId)
  ///
  /// - إذا كانت النتيجة موجبة: تُحدَّث الـ entry
  /// - إذا كانت النتيجة صفراً: تُحذف الـ entry
  /// - إذا كانت النتيجة سالبة: **يُرفع استثناء مع وصف المشكلة**
  ///   لأن التوزيع السالب يعني فساداً في البيانات لا يجب إخفاؤه.
  ///   المستدعي يجب أن يتعامل مع هذه الحالة قبل الاستدعاء.
  static List<DistributionEntry> applyDelta({
    required List<DistributionEntry> entries,
    required String jarId,
    required String walletId,
    required double delta,
    DistributionOrigin origin = DistributionOrigin.automatic,
    String? linkedTransactionId,
  }) {
    if (delta == 0) return entries;

    final idx = entries.indexWhere(
      (e) => e.jarId == jarId && e.walletId == walletId,
    );
    final currentAmount = idx == -1 ? 0.0 : entries[idx].amount;
    final newAmount = currentAmount + delta;

    if (newAmount < 0) {
      // لا نُخفي المشكلة — نُبلّغ عنها بوضوح
      throw DistributionNegativeAmountException(
        jarId: jarId,
        walletId: walletId,
        currentAmount: currentAmount,
        delta: delta,
        resultAmount: newAmount,
      );
    }

    final rest = entries
        .where((e) => !(e.jarId == jarId && e.walletId == walletId))
        .toList();

    if (newAmount == 0) return rest; // حذف إذا كان صفراً بالضبط

    final updated = idx == -1
        ? DistributionEntry(
            id: 'dist-${DateTime.now().microsecondsSinceEpoch}',
            jarId: jarId,
            walletId: walletId,
            amount: newAmount,
            origin: origin,
            createdAt: DateTime.now(),
            linkedTransactionId: linkedTransactionId,
          )
        : entries[idx].copyWith(
            amount: newAmount,
            updatedAt: DateTime.now(),
            linkedTransactionId:
                linkedTransactionId ?? entries[idx].linkedTransactionId,
          );

    return [...rest, updated];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // حذف
  // ══════════════════════════════════════════════════════════════════════════

  /// حذف كل entries لحصالة معينة
  static List<DistributionEntry> removeAllForJar({
    required List<DistributionEntry> entries,
    required String jarId,
  }) =>
      entries.where((e) => e.jarId != jarId).toList();

  /// حذف entry واحد بمعرّفه
  static List<DistributionEntry> removeById({
    required List<DistributionEntry> entries,
    required String entryId,
  }) =>
      entries.where((e) => e.id != entryId).toList();

  // ══════════════════════════════════════════════════════════════════════════
  // نقل
  // ══════════════════════════════════════════════════════════════════════════

  /// نقل مبلغ من (jarId + walletId) إلى (newJarId + newWalletId)
  ///
  /// إذا كان الـ entry المصدر لا يملك الكمية الكافية، يُرفع استثناء.
  static List<DistributionEntry> move({
    required List<DistributionEntry> entries,
    required String fromJarId,
    required String fromWalletId,
    required String toJarId,
    required String toWalletId,
    required double amount,
  }) {
    assert(amount > 0, 'Move amount must be > 0');

    // نخصم من المصدر
    final afterDebit = applyDelta(
      entries: entries,
      jarId: fromJarId,
      walletId: fromWalletId,
      delta: -amount,
    );

    // نُضيف للهدف
    return applyDelta(
      entries: afterDebit,
      jarId: toJarId,
      walletId: toWalletId,
      delta: amount,
      origin: DistributionOrigin.manual,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // استعلامات
  // ══════════════════════════════════════════════════════════════════════════

  /// مجموع التخصيصات لحصالة معينة
  static double totalForJar(List<DistributionEntry> entries, String jarId) =>
      entries
          .where((e) => e.jarId == jarId)
          .fold(0.0, (sum, e) => sum + e.amount);

  /// مجموع التخصيصات من محفظة معينة عبر كل الحصالات
  static double totalFromWallet(
    List<DistributionEntry> entries,
    String walletId,
  ) =>
      entries
          .where((e) => e.walletId == walletId)
          .fold(0.0, (sum, e) => sum + e.amount);

  /// entries لحصالة معينة
  static List<DistributionEntry> entriesForJar(
    List<DistributionEntry> entries,
    String jarId,
  ) =>
      entries.where((e) => e.jarId == jarId).toList();
}

// ══════════════════════════════════════════════════════════════════════════
// Exceptions
// ══════════════════════════════════════════════════════════════════════════

/// استثناء يُرفع عندما تُؤدي عملية إلى توزيع سالب
///
/// لا يجوز إخفاء هذا الخطأ — المستدعي يجب أن يتعامل معه صراحةً.
class DistributionNegativeAmountException implements Exception {
  const DistributionNegativeAmountException({
    required this.jarId,
    required this.walletId,
    required this.currentAmount,
    required this.delta,
    required this.resultAmount,
  });

  final String jarId;
  final String walletId;
  final double currentAmount;
  final double delta;
  final double resultAmount;

  @override
  String toString() =>
      'DistributionNegativeAmountException: jar=$jarId, wallet=$walletId, '
      'current=$currentAmount, delta=$delta → result=$resultAmount (negative). '
      'This indicates a domain violation — the caller must handle this case '
      'before calling applyDelta.';
}
