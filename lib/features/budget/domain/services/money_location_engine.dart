import '../entities/budget_setup_entity.dart';
import '../entities/money_location_review_entity.dart';

/// محرك أماكن الفلوس — نقطة الدخول الوحيدة لتحديث walletSources
///
/// ## المسؤولية
/// - تطبيق التغييرات على `walletSources` بشكل آمن
/// - إنشاء عناصر [MoneyLocationReview] عند اكتشاف تعارض بدلاً من الحذف الصامت
/// - حل مراجعات مرتبطة بمعاملة محذوفة
/// - كشف التعارضات في البيانات القديمة (للترحيل)
///
/// ## لا يتعامل مع
/// - رصيد الحصالة (`jar.balance`) — مسؤولية `TransactionProcessor` حصراً
/// - رصيد المحفظة (`wallet.balance`) — مسؤولية `TransactionProcessor` حصراً
/// - حفظ البيانات أو أي I/O
/// - الواجهة
///
/// ## لماذا هذا الملف موجود
/// كان `walletSources` يُحدَّث عبر مسارَيْن مستقلَّيْن:
/// `TransactionProcessor` (عبر `withUpdatedSource`) و`relabelJarWalletSource`
/// (بطفرة مباشرة). هذا الملف يوفّر المسار الوحيد الآمن لتحديث `walletSources`.
class MoneyLocationEngine {
  const MoneyLocationEngine._();

  // ══════════════════════════════════════════════════════════════════════════
  // تطبيق دلتا — المسار الأساسي
  // ══════════════════════════════════════════════════════════════════════════

  /// تطبيق تغيير على مصدر محفظة في حصالة
  ///
  /// - إذا كانت النتيجة موجبة: يحدّث المصدر عبر [LinkedWalletEntity.withUpdatedSource]
  /// - إذا كانت النتيجة صفراً: يحذف المصدر (سلوك `withUpdatedSource` الطبيعي)
  /// - إذا كانت النتيجة سالبة: يُنشئ [MoneyLocationReview] بدلاً من الحذف الصامت
  ///   ويُصفّر المصدر
  ///
  /// لا يُغيّر `jar.balance` — الرصيد المالي خارج مسؤولية هذا المحرك.
  static LinkedWalletEntity applyLocationDelta({
    required LinkedWalletEntity jar,
    required String walletId,
    required double delta,
    String? relatedTransactionId,
  }) {
    if (delta == 0) return jar;

    final existingIdx =
        jar.walletSources.indexWhere((s) => s.walletId == walletId);
    final currentAmount =
        existingIdx == -1 ? 0.0 : jar.walletSources[existingIdx].amount;
    final newAmount = currentAmount + delta;

    if (newAmount < 0) {
      // تجنّب الحذف الصامت — أنشئ مراجعة وصفّر المصدر
      final review = MoneyLocationReview(
        id: 'mlr-${DateTime.now().microsecondsSinceEpoch}-neg',
        amount: newAmount.abs(),
        type: MoneyLocationReviewType.sourceWentNegative.value,
        createdAt: DateTime.now(),
        relatedTransactionId: relatedTransactionId,
        notes: 'أصبح مصدر المحفظة سالباً ($walletId) — يحتاج مراجعة',
      );
      // نُصفّر المصدر (يحذفه withUpdatedSource لأن amount = 0)
      final clearedJar = jar.withUpdatedSource(walletId, 0);
      return clearedJar.copyWith(
        moneyLocationReviews: [
          ...clearedJar.moneyLocationReviews,
          review,
        ],
      );
    }

    return jar.withUpdatedSource(walletId, newAmount);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // مراجعة عدم التطابق — عند الصرف من محفظة غير مدرجة في المصادر
  // ══════════════════════════════════════════════════════════════════════════

  /// إنشاء مراجعة عدم تطابق محفظة الصرف مع مصادر الحصالة
  ///
  /// يُستخدم عندما يُصرف من محفظة غير مدرجة في `walletSources`.
  /// لا يُعدَّل `walletSources` — الرصيد المالي (`jar.balance`) يتغير بشكل
  /// صحيح في `TransactionProcessor`، لكن مكان الفلوس يحتاج مراجعة لاحقاً.
  static LinkedWalletEntity addSpendingMismatchReview({
    required LinkedWalletEntity jar,
    required double amount,
    required String spendingWalletId,
    required String transactionId,
  }) {
    final review = MoneyLocationReview(
      id: 'mlr-${DateTime.now().microsecondsSinceEpoch}-mism',
      amount: amount,
      type: MoneyLocationReviewType.spendingWalletMismatch.value,
      createdAt: DateTime.now(),
      relatedTransactionId: transactionId,
      notes: 'صُرف من محفظة ($spendingWalletId) غير موجودة في مصادر الحصالة',
    );
    return jar.copyWith(
      moneyLocationReviews: [...jar.moneyLocationReviews, review],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // حل المراجعات
  // ══════════════════════════════════════════════════════════════════════════

  /// حل مراجعة بمعرّفها (تجاهل التعارض أو بعد تصحيحه يدوياً)
  static LinkedWalletEntity resolveReview({
    required LinkedWalletEntity jar,
    required String reviewId,
  }) {
    return jar.copyWith(
      moneyLocationReviews:
          jar.moneyLocationReviews.where((r) => r.id != reviewId).toList(),
    );
  }

  /// حل جميع مراجعات عدم التطابق المرتبطة بمعاملة معينة
  ///
  /// يُستخدم عند عكس (حذف) المعاملة التي أدّت لإنشاء مراجعات عدم التطابق.
  static LinkedWalletEntity resolveSpendingMismatchForTransaction({
    required LinkedWalletEntity jar,
    required String transactionId,
  }) {
    return jar.copyWith(
      moneyLocationReviews: jar.moneyLocationReviews
          .where(
            (r) =>
                r.type !=
                    MoneyLocationReviewType.spendingWalletMismatch.value ||
                r.relatedTransactionId != transactionId,
          )
          .toList(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // كشف التعارضات — للترحيل
  // ══════════════════════════════════════════════════════════════════════════

  /// كشف التعارضات الموجودة في بيانات حصالة (يُستخدم للترحيل فقط)
  ///
  /// يُنشئ مراجعات للتعارضات المكتشفة دون تعديل `walletSources`.
  /// نتيجته تُضاف إلى `jar.moneyLocationReviews` من قِبَل المهاجر.
  static List<MoneyLocationReview> detectInconsistencies(
    LinkedWalletEntity jar,
  ) {
    final reviews = <MoneyLocationReview>[];

    final labeled = jar.labeledTotal;
    // إذا تجاوزت التصنيفات الرصيد بهامش أكبر من خطأ تقريب الفاصلة
    if (labeled > jar.balance + 0.01) {
      reviews.add(
        MoneyLocationReview(
          id: 'mlr-mig-${jar.id}-${DateTime.now().microsecondsSinceEpoch}',
          amount: labeled - jar.balance,
          type: MoneyLocationReviewType.labeledExceedsBalance.value,
          createdAt: DateTime.now(),
          notes:
              'مجموع التصنيفات (${labeled.toStringAsFixed(2)}) يتجاوز رصيد '
              'الحصالة (${jar.balance.toStringAsFixed(2)}) بمقدار '
              '${(labeled - jar.balance).toStringAsFixed(2)}',
        ),
      );
    }

    return reviews;
  }
}
