import '../entities/distribution_entry.dart';

/// نوع مشكلة السلامة المكتشفة
enum DistributionIssueType {
  /// مجموع التخصيصات للحصالة يتجاوز رصيدها
  totalExceedsJarBalance,

  /// entry بمبلغ صفر أو سالب (لا يجب أن يوجد)
  negativeOrZeroAmount,

  /// entry يُشير لمحفظة غير موجودة
  unknownWallet,

  /// entry يُشير لحصالة غير موجودة
  unknownJar,

  /// entry يُشير لمعاملة محذوفة أو غير موجودة
  orphanedTransaction,

  /// توجد أكثر من entry لنفس (jarId + walletId) — يُخلّ بافتراض المحرك
  duplicateJarWalletPair,
}

/// مشكلة سلامة مكتشفة — بيانات فقط، لا إصلاح
class DistributionIssue {
  const DistributionIssue({
    required this.type,
    required this.jarId,
    this.walletId,
    this.entryId,
    this.description,
    this.excess,
  });

  final DistributionIssueType type;
  final String jarId;
  final String? walletId;
  final String? entryId;
  final String? description;

  /// المبلغ الزائد (لـ totalExceedsJarBalance فقط)
  final double? excess;

  @override
  String toString() =>
      'DistributionIssue(${type.name}, jar=$jarId'
      '${walletId != null ? ', wallet=$walletId' : ''}'
      '${excess != null ? ', excess=$excess' : ''}'
      '${description != null ? ', msg=$description' : ''})';
}

/// Distribution Validator — طبقة التحقق من سلامة التوزيعات
///
/// ## المسؤولية الوحيدة
/// كشف المشاكل في مجموعة [DistributionEntry] وإعادة قائمة بها.
///
/// ## لا تُصلح شيئاً
/// هذه الطبقة تكشف فقط. لا تُعدَّل entries. لا تُنشئ مراجعات.
/// لا تُغيَّر أي أرصدة.
///
/// ## متى تُستخدم
/// - عند استعادة backup
/// - عند migration
/// - عند طلب المستخدم تقرير السلامة
/// - (مستقبلاً) كـ background health check
class DistributionValidator {
  const DistributionValidator._();

  /// تحقق من سلامة مجموعة entries مقارنةً بأرصدة الحصالات والمحافظ
  ///
  /// المعاملات:
  /// - [entries]          — قائمة [DistributionEntry] المراد فحصها
  /// - [jarBalances]      — `{ jarId → balance }` لكل حصالات الحالة
  /// - [knownWalletIds]   — مجموعة معرّفات المحافظ الموجودة فعلياً
  /// - [knownTransactionIds] — مجموعة معرّفات المعاملات الموجودة
  ///   (فارغة = تجاهل فحص الـ orphan)
  static List<DistributionIssue> validate({
    required List<DistributionEntry> entries,
    required Map<String, double> jarBalances,
    required Set<String> knownWalletIds,
    Set<String> knownTransactionIds = const {},
  }) {
    final issues = <DistributionIssue>[];

    // ── فحص كل entry منفرداً ──────────────────────────────────────────────
    for (final entry in entries) {
      // مبلغ صفر أو سالب
      if (entry.amount <= 0) {
        issues.add(DistributionIssue(
          type: DistributionIssueType.negativeOrZeroAmount,
          jarId: entry.jarId,
          walletId: entry.walletId,
          entryId: entry.id,
          description:
              'Entry has invalid amount ${entry.amount} (must be > 0)',
        ));
      }

      // محفظة غير موجودة
      if (!knownWalletIds.contains(entry.walletId)) {
        issues.add(DistributionIssue(
          type: DistributionIssueType.unknownWallet,
          jarId: entry.jarId,
          walletId: entry.walletId,
          entryId: entry.id,
          description: 'Wallet ${entry.walletId} does not exist',
        ));
      }

      // حصالة غير موجودة
      if (!jarBalances.containsKey(entry.jarId)) {
        issues.add(DistributionIssue(
          type: DistributionIssueType.unknownJar,
          jarId: entry.jarId,
          walletId: entry.walletId,
          entryId: entry.id,
          description: 'Jar ${entry.jarId} does not exist',
        ));
      }

      // معاملة يتيمة
      if (entry.linkedTransactionId != null &&
          knownTransactionIds.isNotEmpty &&
          !knownTransactionIds.contains(entry.linkedTransactionId)) {
        issues.add(DistributionIssue(
          type: DistributionIssueType.orphanedTransaction,
          jarId: entry.jarId,
          walletId: entry.walletId,
          entryId: entry.id,
          description:
              'Linked transaction ${entry.linkedTransactionId} not found',
        ));
      }
    }

    // ── فحص التكرار (jarId + walletId) ──────────────────────────────────
    // المحرك يفترض أن كل (jarId, walletId) يُقابله entry واحد فقط.
    // وجود entries مكررة يُخلّ باستدعاءات applyDelta و upsert.
    final seenPairs = <String>{};
    for (final entry in entries) {
      final pairKey = '${entry.jarId}:${entry.walletId}';
      if (!seenPairs.add(pairKey)) {
        issues.add(DistributionIssue(
          type: DistributionIssueType.duplicateJarWalletPair,
          jarId: entry.jarId,
          walletId: entry.walletId,
          entryId: entry.id,
          description:
              'Duplicate entry found for jar=${entry.jarId}, wallet=${entry.walletId}',
        ));
      }
    }

    // ── فحص مجموع التخصيصات لكل حصالة ──────────────────────────────────
    final jarIds = entries.map((e) => e.jarId).toSet();
    for (final jarId in jarIds) {
      final jarBalance = jarBalances[jarId];
      if (jarBalance == null) continue; // مُبلَّغ عنه بالأعلى كـ unknownJar

      final total = entries
          .where((e) => e.jarId == jarId)
          .fold(0.0, (sum, e) => sum + e.amount);

      // هامش 0.01 لتجنب أخطاء floating point
      if (total > jarBalance + 0.01) {
        issues.add(DistributionIssue(
          type: DistributionIssueType.totalExceedsJarBalance,
          jarId: jarId,
          excess: total - jarBalance,
          description:
              'Total distribution ($total) exceeds jar balance ($jarBalance) '
              'by ${total - jarBalance}',
        ));
      }
    }

    return issues;
  }

  /// بناء مجموعة DistributionEntry من walletSources الحالية
  ///
  /// يُستخدم للتحقق من البيانات الحالية المخزّنة كـ JarWalletSource.
  /// هذه helper مؤقتة للمرحلة الحالية — في المرحلة الثانية ستُحذف
  /// عندما تُصبح البيانات مخزّنة كـ DistributionEntry مباشرةً.
  static List<DistributionEntry> fromWalletSources(
    Map<String, List<({String walletId, double amount})>> jarSourceMap,
  ) {
    final entries = <DistributionEntry>[];
    for (final jarEntry in jarSourceMap.entries) {
      for (final source in jarEntry.value) {
        entries.add(DistributionEntry.fromWalletSource(
          jarId: jarEntry.key,
          walletId: source.walletId,
          amount: source.amount,
        ));
      }
    }
    return entries;
  }
}
