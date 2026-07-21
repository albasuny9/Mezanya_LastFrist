import '../../../money_distribution/domain/entities/distribution_entry.dart';
import '../entities/app_state_entity.dart';

/// خدمة مسؤولة حصريًا عن حساب/إعادة بناء [AppStateEntity.moneyDistributions]
/// (توزيعات الأموال) وتنظيف walletSources القديمة في الحصالات المرتبطة
/// بعد أي تعديل على التوزيعات.
///
/// استُخرجت من AppCubit — لا تغيير في المنطق أو السلوك، فقط نقل موقع
/// التعريف. AppCubit مسؤول فقط عن استدعائها.
class MoneyDistributionService {
  const MoneyDistributionService._();

  /// يبني نسخة جديدة من [source] بتوزيعات أموال محدَّثة: يُبقي فقط
  /// الإدخالات الموجبة، ويصفّر `walletSources` القديمة في كل الحصالات
  /// المرتبطة (لأن التوزيعات الجديدة هي مصدر الحقيقة الوحيد بعد الترحيل).
  static AppStateEntity withMoneyDistributions(
    AppStateEntity source,
    List<DistributionEntry> entries,
  ) {
    final positiveEntries = entries.where((entry) => entry.amount > 0).toList();
    final jars = source.budgetSetup.linkedWallets
        .map((jar) => jar.copyWith(walletSources: const []))
        .toList();
    return source.copyWith(
      moneyDistributions: positiveEntries,
      budgetSetup: source.budgetSetup.copyWith(linkedWallets: jars),
    );
  }
}
