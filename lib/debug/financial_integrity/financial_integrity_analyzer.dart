import 'dart:math';

import '../../core/constants/transaction_types.dart';
import '../../features/app_state/domain/entities/app_state_entity.dart';
import '../../features/transactions/domain/entities/transaction_entity.dart';
import '../../features/transactions/domain/services/transaction_processor.dart';

enum FinancialIntegrityStatus {
  healthy,
  warning,
  corrupted,
}

enum FinancialIntegritySeverity {
  info,
  warning,
  error,
  critical,
}

enum FinancialIntegrityConfidence {
  proven,
  likely,
  unknown,
}

enum FinancialBalanceKind {
  wallet,
  jar,
  allocation,
}

class FinancialIntegrityAnalyzer {
  const FinancialIntegrityAnalyzer._();

  static FinancialIntegrityReport analyze(
    AppStateEntity state, {
    double tolerance = 0.01,
  }) {
    final context = _IntegrityContext(state, tolerance);
    final violations = <FinancialIntegrityViolation>[];
    final warnings = <FinancialIntegrityViolation>[];
    final evidence = <FinancialIntegrityEvidence>[];

    _inspectTransactions(context, violations, warnings);
    _inspectRecurringTransactions(context, violations, warnings);
    _inspectMoneyLocations(context, violations, warnings);

    final replayed = _replayRoots(state);
    evidence.add(
      FinancialIntegrityEvidence(
        message:
            'Replayed ${context.rootTransactions.length} root transactions '
            'from a zero-balance clone using TransactionProcessor.',
        confidence: FinancialIntegrityConfidence.proven,
        relatedTransactionIds:
            context.rootTransactions.map((tx) => tx.id).toList(),
      ),
    );

    final walletResults = _walletChecks(
      state: state,
      expected: replayed,
      context: context,
      violations: violations,
    );
    final jarResults = _jarChecks(
      state: state,
      expected: replayed,
      context: context,
      violations: violations,
    );
    final allocationResults = _allocationChecks(
      state: state,
      expected: replayed,
      context: context,
      violations: violations,
    );

    final firstDivergence = _firstDivergence(
      context,
      [...violations, ...warnings],
      [...walletResults, ...jarResults, ...allocationResults],
    );

    final score = _score(violations, warnings);
    final status = violations.any(
      (item) =>
          item.severity == FinancialIntegritySeverity.critical ||
          item.severity == FinancialIntegritySeverity.error,
    )
        ? FinancialIntegrityStatus.corrupted
        : warnings.isNotEmpty
            ? FinancialIntegrityStatus.warning
            : FinancialIntegrityStatus.healthy;

    return FinancialIntegrityReport(
      status: status,
      score: score,
      walletResults: walletResults,
      jarResults: jarResults,
      allocationResults: allocationResults,
      violations: violations,
      warnings: warnings,
      evidence: evidence,
      firstDivergence: firstDivergence,
    );
  }

  static AppStateEntity _replayRoots(AppStateEntity state) {
    var replayed = _zeroBalanceClone(state);
    final indexed = state.transactions
        .asMap()
        .entries
        .where((entry) => entry.value.parentId == null)
        .toList()
      ..sort((a, b) {
        final byDate = a.value.createdAt.compareTo(b.value.createdAt);
        if (byDate != 0) return byDate;
        return a.key.compareTo(b.key);
      });

    for (final entry in indexed) {
      replayed = TransactionProcessor.apply(replayed, entry.value);
    }
    return replayed;
  }

  static AppStateEntity _zeroBalanceClone(AppStateEntity state) {
    return state.copyWith(
      wallets: state.wallets
          .map((wallet) => wallet.copyWith(balance: 0))
          .toList(growable: false),
      transactions: const <TransactionEntity>[],
      moneyDistributions: const [],
      budgetSetup: state.budgetSetup.copyWith(
        linkedWallets: state.budgetSetup.linkedWallets
            .map(
              (jar) => jar.copyWith(
                balance: 0,
                walletBalances: const {},
                walletSources: const [],
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
                pendingDistributionSnoozedUntil: '',
                moneyLocationReviews: const [],
              ),
            )
            .toList(growable: false),
        allocations: state.budgetSetup.allocations
            .map(
              (allocation) => allocation.copyWith(
                balance: 0,
                walletBalances: const {},
                pendingDistribution: 0,
                pendingDistributionWalletId: '',
                pendingDistributionSourceId: '',
                pendingDistributionSnoozedUntil: '',
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  static void _inspectTransactions(
    _IntegrityContext context,
    List<FinancialIntegrityViolation> violations,
    List<FinancialIntegrityViolation> warnings,
  ) {
    for (final entry in context.transactionsById.entries) {
      if (entry.value.length <= 1) continue;
      violations.add(
        FinancialIntegrityViolation(
          code: 'duplicate-transaction-id',
          severity: FinancialIntegritySeverity.critical,
          confidence: FinancialIntegrityConfidence.proven,
          explanation: 'Multiple persisted transactions share id ${entry.key}.',
          relatedTransactionIds: entry.value.map((tx) => tx.id).toList(),
          evidence: ['count=${entry.value.length}'],
        ),
      );
    }

    for (final tx in context.state.transactions) {
      if (tx.amount <= 0) {
        warnings.add(
          FinancialIntegrityViolation(
            code: 'non-positive-transaction-amount',
            severity: FinancialIntegritySeverity.warning,
            confidence: FinancialIntegrityConfidence.likely,
            explanation:
                'Transaction ${tx.id} has a non-positive amount (${tx.amount}).',
            relatedTransactionIds: [tx.id],
          ),
        );
      }

      final parentId = tx.parentId;
      if (parentId != null && parentId.isNotEmpty) {
        if (!context.transactionsById.containsKey(parentId)) {
          violations.add(
            FinancialIntegrityViolation(
              code: 'missing-parent',
              severity: FinancialIntegritySeverity.error,
              confidence: FinancialIntegrityConfidence.proven,
              explanation:
                  'Sub-transaction ${tx.id} references missing parent $parentId.',
              relatedTransactionIds: [tx.id, parentId],
            ),
          );
          violations.add(
            FinancialIntegrityViolation(
              code: 'orphan-subtransaction',
              severity: FinancialIntegritySeverity.error,
              confidence: FinancialIntegrityConfidence.proven,
              explanation:
                  'Sub-transaction ${tx.id} cannot be tied to a root transaction.',
              relatedTransactionIds: [tx.id, parentId],
            ),
          );
        } else if (parentId == tx.id || _hasParentCycle(tx, context)) {
          violations.add(
            FinancialIntegrityViolation(
              code: 'impossible-parent-chain',
              severity: FinancialIntegritySeverity.critical,
              confidence: FinancialIntegrityConfidence.proven,
              explanation:
                  'Transaction ${tx.id} participates in a cyclic parent chain.',
              relatedTransactionIds: [tx.id],
            ),
          );
        }
      }

      _inspectTransactionReferences(context, tx, violations, warnings);
    }
  }

  static bool _hasParentCycle(TransactionEntity tx, _IntegrityContext context) {
    final seen = <String>{tx.id};
    var current = tx.parentId;
    while (current != null && current.isNotEmpty) {
      if (!seen.add(current)) return true;
      final next = context.transactionsById[current]?.first.parentId;
      current = next;
    }
    return false;
  }

  static void _inspectTransactionReferences(
    _IntegrityContext context,
    TransactionEntity tx,
    List<FinancialIntegrityViolation> violations,
    List<FinancialIntegrityViolation> warnings,
  ) {
    final type = TransactionType.fromValue(tx.type);
    if (type == null) {
      warnings.add(
        FinancialIntegrityViolation(
          code: 'unknown-transaction-type',
          severity: FinancialIntegritySeverity.warning,
          confidence: FinancialIntegrityConfidence.proven,
          explanation: 'Transaction ${tx.id} has unknown type ${tx.type}.',
          relatedTransactionIds: [tx.id],
        ),
      );
      return;
    }

    if (type == TransactionType.income || type == TransactionType.expense) {
      _requireWallet(context, tx.walletId, tx, violations);
    }

    if (tx.incomeSourceId != null &&
        !context.incomeSourceIds.contains(tx.incomeSourceId)) {
      warnings.add(
        FinancialIntegrityViolation(
          code: 'missing-income-source-reference',
          severity: FinancialIntegritySeverity.warning,
          confidence: FinancialIntegrityConfidence.likely,
          explanation: 'Transaction ${tx.id} references deleted income source '
              '${tx.incomeSourceId}.',
          relatedIds: [tx.incomeSourceId!],
          relatedTransactionIds: [tx.id],
        ),
      );
    }

    if (tx.allocationId != null &&
        !context.allocationIds.contains(tx.allocationId)) {
      violations.add(
        FinancialIntegrityViolation(
          code: 'missing-allocation-reference',
          severity: FinancialIntegritySeverity.error,
          confidence: FinancialIntegrityConfidence.proven,
          explanation: 'Transaction ${tx.id} references deleted allocation '
              '${tx.allocationId}.',
          relatedIds: [tx.allocationId!],
          relatedTransactionIds: [tx.id],
        ),
      );
    }

    if (tx.toAllocationId != null &&
        !context.allocationIds.contains(tx.toAllocationId)) {
      violations.add(
        FinancialIntegrityViolation(
          code: 'missing-allocation-reference',
          severity: FinancialIntegritySeverity.error,
          confidence: FinancialIntegrityConfidence.proven,
          explanation:
              'Transaction ${tx.id} references deleted target allocation '
              '${tx.toAllocationId}.',
          relatedIds: [tx.toAllocationId!],
          relatedTransactionIds: [tx.id],
        ),
      );
    }

    if (type == TransactionType.transfer) {
      _inspectTransferReferences(context, tx, violations);
    } else if (tx.toWalletId != null) {
      _requireAnyFinancialEntity(context, tx.toWalletId!, tx, violations);
    }
  }

  static void _inspectTransferReferences(
    _IntegrityContext context,
    TransactionEntity tx,
    List<FinancialIntegrityViolation> violations,
  ) {
    final from = tx.fromWalletId ?? tx.walletId;
    if (from != null && from.isNotEmpty) {
      _requireAnyFinancialEntity(context, from, tx, violations);
    }
    if (tx.toWalletId != null && tx.toWalletId!.isNotEmpty) {
      _requireAnyFinancialEntity(context, tx.toWalletId!, tx, violations);
    }
  }

  static void _requireWallet(
    _IntegrityContext context,
    String? id,
    TransactionEntity tx,
    List<FinancialIntegrityViolation> violations,
  ) {
    if (id == null || id.isEmpty) {
      violations.add(
        FinancialIntegrityViolation(
          code: 'missing-wallet-reference',
          severity: FinancialIntegritySeverity.error,
          confidence: FinancialIntegrityConfidence.proven,
          explanation: 'Transaction ${tx.id} does not specify a wallet.',
          relatedTransactionIds: [tx.id],
        ),
      );
      return;
    }
    if (!context.walletIds.contains(id)) {
      violations.add(
        FinancialIntegrityViolation(
          code: 'missing-wallet-reference',
          severity: FinancialIntegritySeverity.error,
          confidence: FinancialIntegrityConfidence.proven,
          explanation: 'Transaction ${tx.id} references deleted wallet $id.',
          relatedIds: [id],
          relatedTransactionIds: [tx.id],
        ),
      );
    }
  }

  static void _requireAnyFinancialEntity(
    _IntegrityContext context,
    String id,
    TransactionEntity tx,
    List<FinancialIntegrityViolation> violations,
  ) {
    if (context.walletIds.contains(id) ||
        context.jarIds.contains(id) ||
        context.allocationIds.contains(id)) {
      return;
    }
    violations.add(
      FinancialIntegrityViolation(
        code: 'missing-financial-entity-reference',
        severity: FinancialIntegritySeverity.error,
        confidence: FinancialIntegrityConfidence.proven,
        explanation:
            'Transaction ${tx.id} references deleted financial entity $id.',
        relatedIds: [id],
        relatedTransactionIds: [tx.id],
      ),
    );
  }

  static void _inspectRecurringTransactions(
    _IntegrityContext context,
    List<FinancialIntegrityViolation> violations,
    List<FinancialIntegrityViolation> warnings,
  ) {
    for (final recurring in context.state.recurringTransactions) {
      if (!context.walletIds.contains(recurring.walletId)) {
        violations.add(
          FinancialIntegrityViolation(
            code: 'recurring-missing-wallet-reference',
            severity: FinancialIntegritySeverity.error,
            confidence: FinancialIntegrityConfidence.proven,
            explanation:
                'Recurring operation ${recurring.id} references deleted '
                'wallet ${recurring.walletId}.',
            relatedIds: [recurring.walletId],
          ),
        );
      }
      if (recurring.targetJarId != null &&
          !context.jarIds.contains(recurring.targetJarId)) {
        violations.add(
          FinancialIntegrityViolation(
            code: 'recurring-missing-jar-reference',
            severity: FinancialIntegritySeverity.error,
            confidence: FinancialIntegrityConfidence.proven,
            explanation:
                'Recurring operation ${recurring.id} references deleted '
                'jar ${recurring.targetJarId}.',
            relatedIds: [recurring.targetJarId!],
          ),
        );
      }
      if (recurring.allocationId != null &&
          !context.allocationIds.contains(recurring.allocationId)) {
        violations.add(
          FinancialIntegrityViolation(
            code: 'recurring-missing-allocation-reference',
            severity: FinancialIntegritySeverity.error,
            confidence: FinancialIntegrityConfidence.proven,
            explanation:
                'Recurring operation ${recurring.id} references deleted '
                'allocation ${recurring.allocationId}.',
            relatedIds: [recurring.allocationId!],
          ),
        );
      }
      if (recurring.incomeSourceId != null &&
          !context.incomeSourceIds.contains(recurring.incomeSourceId)) {
        warnings.add(
          FinancialIntegrityViolation(
            code: 'recurring-missing-income-source-reference',
            severity: FinancialIntegritySeverity.warning,
            confidence: FinancialIntegrityConfidence.likely,
            explanation:
                'Recurring operation ${recurring.id} references deleted '
                'income source ${recurring.incomeSourceId}.',
            relatedIds: [recurring.incomeSourceId!],
          ),
        );
      }
    }
  }

  static void _inspectMoneyLocations(
    _IntegrityContext context,
    List<FinancialIntegrityViolation> violations,
    List<FinancialIntegrityViolation> warnings,
  ) {
    for (final jar in context.state.budgetSetup.linkedWallets) {
      final walletBalanceTotal =
          jar.walletBalances.values.fold(0.0, (sum, amount) => sum + amount);
      final walletSourceTotal =
          jar.walletSources.fold(0.0, (sum, source) => sum + source.amount);
      final distributionTotal = context.state.moneyDistributions
          .where((entry) => entry.jarId == jar.id)
          .fold(0.0, (sum, entry) => sum + entry.amount);

      if (walletBalanceTotal - jar.balance > context.tolerance) {
        violations.add(
          FinancialIntegrityViolation(
            code: 'jar-wallet-balance-overallocated',
            severity: FinancialIntegritySeverity.error,
            confidence: FinancialIntegrityConfidence.proven,
            explanation:
                'Jar ${jar.id} has walletBalances total $walletBalanceTotal '
                'above stored balance ${jar.balance}.',
            relatedIds: [jar.id],
          ),
        );
      }
      if (distributionTotal - jar.balance > context.tolerance) {
        violations.add(
          FinancialIntegrityViolation(
            code: 'jar-distribution-overallocated',
            severity: FinancialIntegritySeverity.error,
            confidence: FinancialIntegrityConfidence.proven,
            explanation: 'Jar ${jar.id} has money distribution total '
                '$distributionTotal above stored balance ${jar.balance}.',
            relatedIds: [jar.id],
          ),
        );
      }
      if ((walletSourceTotal - walletBalanceTotal).abs() > context.tolerance &&
          walletSourceTotal > context.tolerance &&
          walletBalanceTotal > context.tolerance) {
        warnings.add(
          FinancialIntegrityViolation(
            code: 'legacy-wallet-source-mismatch',
            severity: FinancialIntegritySeverity.warning,
            confidence: FinancialIntegrityConfidence.likely,
            explanation:
                'Jar ${jar.id} legacy walletSources total $walletSourceTotal '
                'differs from walletBalances total $walletBalanceTotal.',
            relatedIds: [jar.id],
          ),
        );
      }
      _inspectPendingDistribution(
        ownerId: jar.id,
        pendingDistribution: jar.pendingDistribution,
        pendingWalletId: jar.pendingDistributionWalletId,
        pendingSourceId: jar.pendingDistributionSourceId,
        context: context,
        violations: violations,
        warnings: warnings,
      );
    }

    for (final allocation in context.state.budgetSetup.allocations) {
      final walletBalanceTotal = allocation.walletBalances.values
          .fold(0.0, (sum, amount) => sum + amount);
      if (walletBalanceTotal - allocation.balance > context.tolerance) {
        violations.add(
          FinancialIntegrityViolation(
            code: 'allocation-wallet-balance-overallocated',
            severity: FinancialIntegritySeverity.error,
            confidence: FinancialIntegrityConfidence.proven,
            explanation: 'Allocation ${allocation.id} has walletBalances total '
                '$walletBalanceTotal above stored balance ${allocation.balance}.',
            relatedIds: [allocation.id],
          ),
        );
      }
      _inspectPendingDistribution(
        ownerId: allocation.id,
        pendingDistribution: allocation.pendingDistribution,
        pendingWalletId: allocation.pendingDistributionWalletId,
        pendingSourceId: allocation.pendingDistributionSourceId,
        context: context,
        violations: violations,
        warnings: warnings,
      );
    }
  }

  static void _inspectPendingDistribution({
    required String ownerId,
    required double pendingDistribution,
    required String pendingWalletId,
    required String pendingSourceId,
    required _IntegrityContext context,
    required List<FinancialIntegrityViolation> violations,
    required List<FinancialIntegrityViolation> warnings,
  }) {
    if (pendingDistribution < -context.tolerance) {
      violations.add(
        FinancialIntegrityViolation(
          code: 'invalid-pending-distribution',
          severity: FinancialIntegritySeverity.error,
          confidence: FinancialIntegrityConfidence.proven,
          explanation:
              '$ownerId has negative pending distribution $pendingDistribution.',
          relatedIds: [ownerId],
        ),
      );
    }
    if (pendingDistribution > context.tolerance &&
        pendingWalletId.isNotEmpty &&
        !context.walletIds.contains(pendingWalletId)) {
      warnings.add(
        FinancialIntegrityViolation(
          code: 'pending-distribution-missing-wallet',
          severity: FinancialIntegritySeverity.warning,
          confidence: FinancialIntegrityConfidence.likely,
          explanation: '$ownerId has pending distribution from deleted wallet '
              '$pendingWalletId.',
          relatedIds: [ownerId, pendingWalletId],
        ),
      );
    }
    if (pendingDistribution > context.tolerance &&
        pendingSourceId.isNotEmpty &&
        !context.incomeSourceIds.contains(pendingSourceId)) {
      warnings.add(
        FinancialIntegrityViolation(
          code: 'pending-distribution-missing-source',
          severity: FinancialIntegritySeverity.warning,
          confidence: FinancialIntegrityConfidence.likely,
          explanation:
              '$ownerId has pending distribution from deleted income source '
              '$pendingSourceId.',
          relatedIds: [ownerId, pendingSourceId],
        ),
      );
    }
  }

  static List<FinancialBalanceCheck> _walletChecks({
    required AppStateEntity state,
    required AppStateEntity expected,
    required _IntegrityContext context,
    required List<FinancialIntegrityViolation> violations,
  }) {
    final expectedById = {
      for (final wallet in expected.wallets) wallet.id: wallet.balance,
    };
    return state.wallets.map((wallet) {
      final check = FinancialBalanceCheck(
        id: wallet.id,
        name: wallet.name,
        kind: FinancialBalanceKind.wallet,
        storedBalance: wallet.balance,
        expectedBalance: expectedById[wallet.id],
        confidence: context.hasReplayHazards
            ? FinancialIntegrityConfidence.likely
            : FinancialIntegrityConfidence.proven,
      );
      _addBalanceMismatchViolation(check, context, violations);
      return check;
    }).toList(growable: false);
  }

  static List<FinancialBalanceCheck> _jarChecks({
    required AppStateEntity state,
    required AppStateEntity expected,
    required _IntegrityContext context,
    required List<FinancialIntegrityViolation> violations,
  }) {
    final expectedById = {
      for (final jar in expected.budgetSetup.linkedWallets) jar.id: jar.balance,
    };
    return state.budgetSetup.linkedWallets.map((jar) {
      final check = FinancialBalanceCheck(
        id: jar.id,
        name: jar.name,
        kind: FinancialBalanceKind.jar,
        storedBalance: jar.balance,
        expectedBalance: expectedById[jar.id],
        confidence: context.hasReplayHazards
            ? FinancialIntegrityConfidence.likely
            : FinancialIntegrityConfidence.proven,
      );
      _addBalanceMismatchViolation(check, context, violations);
      return check;
    }).toList(growable: false);
  }

  static List<FinancialBalanceCheck> _allocationChecks({
    required AppStateEntity state,
    required AppStateEntity expected,
    required _IntegrityContext context,
    required List<FinancialIntegrityViolation> violations,
  }) {
    final expectedById = {
      for (final allocation in expected.budgetSetup.allocations)
        allocation.id: allocation.balance,
    };
    return state.budgetSetup.allocations.map((allocation) {
      final check = FinancialBalanceCheck(
        id: allocation.id,
        name: allocation.name,
        kind: FinancialBalanceKind.allocation,
        storedBalance: allocation.balance,
        expectedBalance: expectedById[allocation.id],
        confidence: context.hasReplayHazards
            ? FinancialIntegrityConfidence.likely
            : FinancialIntegrityConfidence.proven,
      );
      _addBalanceMismatchViolation(check, context, violations);
      return check;
    }).toList(growable: false);
  }

  static void _addBalanceMismatchViolation(
    FinancialBalanceCheck check,
    _IntegrityContext context,
    List<FinancialIntegrityViolation> violations,
  ) {
    if (!check.isMismatch(context.tolerance)) return;
    violations.add(
      FinancialIntegrityViolation(
        code: 'stored-balance-mismatch',
        severity: FinancialIntegritySeverity.error,
        confidence: check.confidence,
        explanation: '${check.kind.name} ${check.id} stored balance '
            '${check.storedBalance} differs from replayed expected balance '
            '${check.expectedBalance}.',
        relatedIds: [check.id],
        evidence: ['difference=${check.difference}'],
      ),
    );
  }

  static FinancialFirstDivergence _firstDivergence(
    _IntegrityContext context,
    List<FinancialIntegrityViolation> findings,
    List<FinancialBalanceCheck> checks,
  ) {
    for (final tx in context.transactionsChronological) {
      final hasFinding = findings.any(
        (finding) => finding.relatedTransactionIds.contains(tx.id),
      );
      if (hasFinding) {
        return FinancialFirstDivergence(
          transactionId: tx.id,
          transactionIndex: context.state.transactions.indexOf(tx),
          confidence: FinancialIntegrityConfidence.likely,
          message: 'Earliest structural finding is attached to ${tx.id}.',
        );
      }
    }
    if (checks.any((check) => check.isMismatch(context.tolerance))) {
      return const FinancialFirstDivergence(
        confidence: FinancialIntegrityConfidence.unknown,
        message: 'First divergence unknown: stored final balances differ from '
            'history replay, but no earlier checkpoint snapshot exists.',
      );
    }
    return const FinancialFirstDivergence(
      confidence: FinancialIntegrityConfidence.proven,
      message: 'No divergence detected.',
    );
  }

  static int _score(
    List<FinancialIntegrityViolation> violations,
    List<FinancialIntegrityViolation> warnings,
  ) {
    var score = 100;
    for (final finding in [...violations, ...warnings]) {
      score -= switch (finding.severity) {
        FinancialIntegritySeverity.critical => 30,
        FinancialIntegritySeverity.error => 15,
        FinancialIntegritySeverity.warning => 5,
        FinancialIntegritySeverity.info => 1,
      };
    }
    return max(0, min(100, score));
  }
}

class FinancialIntegrityReport {
  const FinancialIntegrityReport({
    required this.status,
    required this.score,
    required this.walletResults,
    required this.jarResults,
    required this.allocationResults,
    required this.violations,
    required this.warnings,
    required this.evidence,
    required this.firstDivergence,
  });

  final FinancialIntegrityStatus status;
  final int score;
  final List<FinancialBalanceCheck> walletResults;
  final List<FinancialBalanceCheck> jarResults;
  final List<FinancialBalanceCheck> allocationResults;
  final List<FinancialIntegrityViolation> violations;
  final List<FinancialIntegrityViolation> warnings;
  final List<FinancialIntegrityEvidence> evidence;
  final FinancialFirstDivergence firstDivergence;

  bool get isHealthy => status == FinancialIntegrityStatus.healthy;

  bool hasViolation(String code) =>
      violations.any((violation) => violation.code == code);

  bool hasWarning(String code) =>
      warnings.any((warning) => warning.code == code);
}

class FinancialBalanceCheck {
  const FinancialBalanceCheck({
    required this.id,
    required this.name,
    required this.kind,
    required this.storedBalance,
    required this.expectedBalance,
    required this.confidence,
  });

  final String id;
  final String name;
  final FinancialBalanceKind kind;
  final double storedBalance;
  final double? expectedBalance;
  final FinancialIntegrityConfidence confidence;

  double? get difference =>
      expectedBalance == null ? null : storedBalance - expectedBalance!;

  bool isMismatch(double tolerance) {
    final diff = difference;
    return diff != null && diff.abs() > tolerance;
  }
}

class FinancialIntegrityViolation {
  const FinancialIntegrityViolation({
    required this.code,
    required this.severity,
    required this.confidence,
    required this.explanation,
    this.relatedIds = const [],
    this.relatedTransactionIds = const [],
    this.evidence = const [],
  });

  final String code;
  final FinancialIntegritySeverity severity;
  final FinancialIntegrityConfidence confidence;
  final String explanation;
  final List<String> relatedIds;
  final List<String> relatedTransactionIds;
  final List<String> evidence;
}

class FinancialIntegrityEvidence {
  const FinancialIntegrityEvidence({
    required this.message,
    required this.confidence,
    this.relatedIds = const [],
    this.relatedTransactionIds = const [],
  });

  final String message;
  final FinancialIntegrityConfidence confidence;
  final List<String> relatedIds;
  final List<String> relatedTransactionIds;
}

class FinancialFirstDivergence {
  const FinancialFirstDivergence({
    required this.confidence,
    required this.message,
    this.transactionId,
    this.transactionIndex,
  });

  final String? transactionId;
  final int? transactionIndex;
  final FinancialIntegrityConfidence confidence;
  final String message;
}

class _IntegrityContext {
  _IntegrityContext(this.state, this.tolerance)
      : walletIds = state.wallets.map((wallet) => wallet.id).toSet(),
        jarIds = state.budgetSetup.linkedWallets.map((jar) => jar.id).toSet(),
        allocationIds = state.budgetSetup.allocations
            .map((allocation) => allocation.id)
            .toSet(),
        incomeSourceIds =
            state.budgetSetup.incomeSources.map((source) => source.id).toSet(),
        transactionsById = _groupTransactionsById(state.transactions),
        rootTransactions = state.transactions
            .where((transaction) => transaction.parentId == null)
            .toList(growable: false),
        transactionsChronological = _chronological(state.transactions);

  final AppStateEntity state;
  final double tolerance;
  final Set<String> walletIds;
  final Set<String> jarIds;
  final Set<String> allocationIds;
  final Set<String> incomeSourceIds;
  final Map<String, List<TransactionEntity>> transactionsById;
  final List<TransactionEntity> rootTransactions;
  final List<TransactionEntity> transactionsChronological;

  bool get hasReplayHazards =>
      transactionsById.values.any((items) => items.length > 1) ||
      state.transactions.any(
        (tx) =>
            tx.parentId != null && !transactionsById.containsKey(tx.parentId),
      );

  static Map<String, List<TransactionEntity>> _groupTransactionsById(
    List<TransactionEntity> transactions,
  ) {
    final grouped = <String, List<TransactionEntity>>{};
    for (final transaction in transactions) {
      grouped.putIfAbsent(transaction.id, () => []).add(transaction);
    }
    return grouped;
  }

  static List<TransactionEntity> _chronological(
    List<TransactionEntity> transactions,
  ) {
    final indexed = transactions.asMap().entries.toList()
      ..sort((a, b) {
        final byDate = a.value.createdAt.compareTo(b.value.createdAt);
        if (byDate != 0) return byDate;
        return a.key.compareTo(b.key);
      });
    return indexed.map((entry) => entry.value).toList(growable: false);
  }
}
