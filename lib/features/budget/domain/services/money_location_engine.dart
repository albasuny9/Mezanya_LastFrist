import '../../../money_distribution/domain/services/distribution_engine.dart';
import '../entities/budget_setup_entity.dart';
import '../entities/money_location_review_entity.dart';

/// Review-only engine for Money Location.
///
/// It never owns or mutates money values. Jar balances are owned by
/// TransactionProcessor, and distributions are owned by DistributionEngine.
class MoneyLocationEngine {
  const MoneyLocationEngine._();

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
      notes: 'صرف غير مغطى بالكامل من توزيع أماكن الفلوس ($spendingWalletId)',
    );
    return jar.copyWith(
      moneyLocationReviews: [...jar.moneyLocationReviews, review],
    );
  }

  static LinkedWalletEntity resolveReview({
    required LinkedWalletEntity jar,
    required String reviewId,
  }) {
    return jar.copyWith(
      moneyLocationReviews:
          jar.moneyLocationReviews.where((r) => r.id != reviewId).toList(),
    );
  }

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

  static List<MoneyLocationReview> detectInconsistencies({
    required LinkedWalletEntity jar,
    required MoneyLocationSnapshot snapshot,
  }) {
    if (!snapshot.knownExceedsBalance) return const [];

    return [
      MoneyLocationReview(
        id: 'mlr-mig-${jar.id}-${DateTime.now().microsecondsSinceEpoch}',
        amount: snapshot.known - jar.balance,
        type: MoneyLocationReviewType.labeledExceedsBalance.value,
        createdAt: DateTime.now(),
        notes:
            'مجموع أماكن الفلوس (${snapshot.known.toStringAsFixed(2)}) يتجاوز رصيد '
            'الحصالة (${jar.balance.toStringAsFixed(2)}) بمقدار '
            '${(snapshot.known - jar.balance).toStringAsFixed(2)}',
      ),
    ];
  }
}
