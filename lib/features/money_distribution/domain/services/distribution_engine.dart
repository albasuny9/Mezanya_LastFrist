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

  static String _entryId() => 'dist-${DateTime.now().microsecondsSinceEpoch}';

  static List<DistributionEntry> addReservation({
    required List<DistributionEntry> entries,
    required String jarId,
    required String walletId,
    required double amount,
    required double jarBalance,
    required Set<String> knownWalletIds,
    DistributionOrigin origin = DistributionOrigin.manual,
    String? linkedTransactionId,
  }) {
    _validateWallet(walletId, knownWalletIds);
    _validatePositiveAmount(amount);
    _validateKnownTotal(
      entries: entries,
      jarId: jarId,
      jarBalance: jarBalance,
      delta: amount,
    );

    return [
      ...entries,
      DistributionEntry(
        id: _entryId(),
        jarId: jarId,
        walletId: walletId,
        amount: amount,
        origin: origin,
        createdAt: DateTime.now(),
        linkedTransactionId: linkedTransactionId,
      ),
    ];
  }

  static List<DistributionEntry> removeReservation({
    required List<DistributionEntry> entries,
    required String jarId,
    required String walletId,
    required double amount,
    required Set<String> knownWalletIds,
  }) {
    _validateWallet(walletId, knownWalletIds);
    _validatePositiveAmount(amount);
    final current = totalFromWalletForJar(entries, jarId, walletId);
    if (amount > current + 0.01) {
      throw const DistributionValidationException(
        'لا يمكن إزالة مبلغ أكبر من الحجز المعروف في هذه المحفظة.',
      );
    }

    var remaining = amount;
    final next = <DistributionEntry>[];
    for (final entry in entries) {
      if (entry.jarId != jarId ||
          entry.walletId != walletId ||
          remaining <= 0) {
        next.add(entry);
        continue;
      }
      if (entry.amount <= remaining + 0.01) {
        remaining -= entry.amount;
      } else {
        next.add(entry.copyWith(
          amount: entry.amount - remaining,
          updatedAt: DateTime.now(),
        ));
        remaining = 0;
      }
    }
    return next;
  }

  static List<DistributionEntry> transferReservation({
    required List<DistributionEntry> entries,
    required String jarId,
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required double jarBalance,
    required Set<String> knownWalletIds,
  }) {
    _validateWallet(fromWalletId, knownWalletIds);
    _validateWallet(toWalletId, knownWalletIds);
    _validatePositiveAmount(amount);
    if (fromWalletId == toWalletId) {
      throw const DistributionValidationException(
        'لا يمكن نقل الحجز إلى نفس المحفظة.',
      );
    }
    final removed = removeReservation(
      entries: entries,
      jarId: jarId,
      walletId: fromWalletId,
      amount: amount,
      knownWalletIds: knownWalletIds,
    );
    return addReservation(
      entries: removed,
      jarId: jarId,
      walletId: toWalletId,
      amount: amount,
      jarBalance: jarBalance,
      knownWalletIds: knownWalletIds,
      origin: DistributionOrigin.transfer,
    );
  }

  static List<DistributionEntry> moveEntry({
    required List<DistributionEntry> entries,
    required String entryId,
    required String toWalletId,
    required Set<String> knownWalletIds,
  }) {
    _validateWallet(toWalletId, knownWalletIds);
    final matches = entries.where((e) => e.id == entryId).toList();
    if (matches.isEmpty) {
      throw const DistributionValidationException('الحجز غير موجود.');
    }
    final entry = matches.first;
    if (entry.walletId == toWalletId) {
      throw const DistributionValidationException(
        'لا يمكن نقل الحجز إلى نفس المحفظة.',
      );
    }
    return entries
        .map((e) => e.id == entryId
            ? e.copyWith(walletId: toWalletId, updatedAt: DateTime.now())
            : e)
        .toList();
  }

  static List<DistributionEntry> editEntryAmount({
    required List<DistributionEntry> entries,
    required String entryId,
    required double amount,
    required double jarBalance,
  }) {
    _validatePositiveAmount(amount);
    final matches = entries.where((e) => e.id == entryId).toList();
    if (matches.isEmpty) {
      throw const DistributionValidationException('الحجز غير موجود.');
    }
    final entry = matches.first;
    _validateKnownTotal(
      entries: entries,
      jarId: entry.jarId,
      jarBalance: jarBalance,
      delta: amount - entry.amount,
    );
    return entries
        .map((e) => e.id == entryId
            ? e.copyWith(amount: amount, updatedAt: DateTime.now())
            : e)
        .toList();
  }

  static List<DistributionEntry> deleteEntry({
    required List<DistributionEntry> entries,
    required String entryId,
  }) {
    final exists = entries.any((entry) => entry.id == entryId);
    if (!exists) {
      throw const DistributionValidationException('الحجز غير موجود.');
    }
    return removeById(entries: entries, entryId: entryId);
  }

  static Map<String, double> summaryForJar(
    List<DistributionEntry> entries,
    String jarId,
  ) {
    final result = <String, double>{};
    for (final entry in entries.where((e) => e.jarId == jarId)) {
      result[entry.walletId] = (result[entry.walletId] ?? 0) + entry.amount;
    }
    return result;
  }

  static double totalFromWalletForJar(
    List<DistributionEntry> entries,
    String jarId,
    String walletId,
  ) =>
      entries
          .where((e) => e.jarId == jarId && e.walletId == walletId)
          .fold(0.0, (sum, e) => sum + e.amount);

  static double unknownForJar({
    required List<DistributionEntry> entries,
    required String jarId,
    required double jarBalance,
  }) {
    final unknown = jarBalance - totalForJar(entries, jarId);
    return unknown > 0 ? unknown : 0;
  }

  static void _validatePositiveAmount(double amount) {
    if (amount <= 0) {
      throw const DistributionValidationException(
        'المبلغ يجب أن يكون أكبر من صفر.',
      );
    }
  }

  static void _validateWallet(String walletId, Set<String> knownWalletIds) {
    if (!knownWalletIds.contains(walletId)) {
      throw const DistributionValidationException('المحفظة غير موجودة.');
    }
  }

  static void _validateKnownTotal({
    required List<DistributionEntry> entries,
    required String jarId,
    required double jarBalance,
    required double delta,
  }) {
    final nextTotal = totalForJar(entries, jarId) + delta;
    if (nextTotal > jarBalance + 0.01) {
      throw const DistributionValidationException(
        'إجمالي أماكن الفلوس لا يمكن أن يتجاوز رصيد الحصالة.',
      );
    }
  }

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

class DistributionValidationException implements Exception {
  const DistributionValidationException(this.message);

  final String message;

  @override
  String toString() => message;
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
