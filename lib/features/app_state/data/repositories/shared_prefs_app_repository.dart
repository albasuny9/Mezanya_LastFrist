import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/shared_prefs_keys.dart';
import '../../../transactions/domain/entities/transaction_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../domain/entities/app_state_entity.dart';
import '../../domain/repositories/app_repository.dart';

class SharedPrefsAppRepository implements AppRepository {
  SharedPrefsAppRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<AppStateEntity> loadState() async {
    final payload = _prefs.getString(SharedPrefsKeys.appState);
    if (payload == null || payload.isEmpty) {
      final initial = AppStateEntity.initial();
      await saveState(initial);
      return initial;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return AppStateEntity.fromMap(decoded);
    } catch (_) {
      final fallback = AppStateEntity.initial();
      await saveState(fallback);
      return fallback;
    }
  }

  @override
  Future<void> saveState(AppStateEntity state) async {
    await _prefs.setString(SharedPrefsKeys.appState, jsonEncode(state.toMap()));
  }

  @override
  Future<AppStateEntity> addWallet(WalletEntity wallet) async {
    final current = await loadState();
    final next =
        current.copyWith(wallets: <WalletEntity>[...current.wallets, wallet]);
    await saveState(next);
    return next;
  }

  @override
  Future<AppStateEntity> addTransaction(TransactionEntity transaction) async {
    final current = await loadState();
    var wallets = List<WalletEntity>.from(current.wallets);
    var linkedWallets =
        List<LinkedWalletEntity>.from(current.budgetSetup.linkedWallets);
    var allocations =
        List<AllocationEntity>.from(current.budgetSetup.allocations);
    var transactions = <TransactionEntity>[
      ...current.transactions,
      transaction
    ];
    String auditTransactionId(String prefix) =>
        '$prefix-${DateTime.now().microsecondsSinceEpoch}-${transactions.length}';

    // Helper to update virtual entity (Jar or Allocation)
    void updateVirtualBalance({
      required String id,
      required double delta,
      String? physicalWalletId,
    }) {
      // Check Jars
      final jarIdx = linkedWallets.indexWhere((j) => j.id == id);
      if (jarIdx != -1) {
        var jar = linkedWallets[jarIdx];
        final nextBalances = Map<String, double>.from(jar.walletBalances);
        if (physicalWalletId != null) {
          nextBalances[physicalWalletId] =
              (nextBalances[physicalWalletId] ?? 0) + delta;

          // Update walletSources as well
          final existingSourceIdx = jar.walletSources
              .indexWhere((s) => s.walletId == physicalWalletId);
          double currentSourceAmount = 0;
          if (existingSourceIdx != -1) {
            currentSourceAmount = jar.walletSources[existingSourceIdx].amount;
          }
          final nextSourceAmount = currentSourceAmount + delta;
          jar = jar.withUpdatedSource(physicalWalletId, nextSourceAmount);
        }
        linkedWallets[jarIdx] = jar.copyWith(
          balance: jar.balance + delta,
          walletBalances: nextBalances,
        );
        return;
      }
      // Check Allocations
      final allocIdx = allocations.indexWhere((a) => a.id == id);
      if (allocIdx != -1) {
        final alloc = allocations[allocIdx];
        final nextBalances = Map<String, double>.from(alloc.walletBalances);
        if (physicalWalletId != null) {
          nextBalances[physicalWalletId] =
              (nextBalances[physicalWalletId] ?? 0) + delta;
        }
        allocations[allocIdx] = alloc.copyWith(
          balance: alloc.balance + delta,
          walletBalances: nextBalances,
        );
        return;
      }
    }

    if (transaction.type == 'transfer') {
      final isPhysicalFrom =
          wallets.any((w) => w.id == transaction.fromWalletId);
      final isPhysicalTo = wallets.any((w) => w.id == transaction.toWalletId);

      if (isPhysicalFrom && isPhysicalTo) {
        // 1. Real money transfer between wallets
        wallets = wallets.map((w) {
          if (w.id == transaction.fromWalletId) {
            return w.copyWith(balance: w.balance - transaction.amount);
          }
          if (w.id == transaction.toWalletId) {
            return w.copyWith(balance: w.balance + transaction.amount);
          }
          return w;
        }).toList();
      } else if (isPhysicalFrom &&
          !isPhysicalTo &&
          transaction.transferType == 'jar-funding-physical') {
        wallets = wallets.map((w) {
          if (w.id != transaction.fromWalletId) return w;
          return w.copyWith(balance: w.balance - transaction.amount);
        }).toList();
        if (transaction.toWalletId != null) {
          updateVirtualBalance(
            id: transaction.toWalletId!,
            delta: transaction.amount,
            physicalWalletId: transaction.fromWalletId,
          );
        }
      } else {
        // 2. Virtual transfer (Internal)
        // Deduct from 'from'
        if (transaction.fromWalletId != null) {
          updateVirtualBalance(
            id: transaction.fromWalletId!,
            delta: -transaction.amount,
            physicalWalletId: transaction.walletId, // Optional physical link
          );
        }
        // Add to 'to'
        if (transaction.toWalletId != null) {
          updateVirtualBalance(
            id: transaction.toWalletId!,
            delta: transaction.amount,
            physicalWalletId: transaction.walletId, // Optional physical link
          );
        }
      }
    } else if (transaction.type == 'income') {
      // 3. Physical Income
      wallets = wallets.map((w) {
        if (w.id != transaction.walletId) return w;
        return w.copyWith(balance: w.balance + transaction.amount);
      }).toList();

      // Handle Distribution to Jars based on automationType and isPhysical
      if (transaction.incomeSourceId != null) {
        final sourceId = transaction.incomeSourceId!;
        var remaining = transaction.amount;

        for (var i = 0; i < linkedWallets.length; i++) {
          final jar = linkedWallets[i];
          final matchingFunding =
              jar.funding.where((f) => f.incomeSourceId == sourceId).toList();
          if (matchingFunding.isEmpty || remaining <= 0) continue;

          final jarPlan =
              matchingFunding.fold<double>(0, (s, f) => s + f.plannedAmount);
          if (jarPlan <= 0) continue;

          final transferAmount = jarPlan <= remaining ? jarPlan : remaining;
          remaining -= transferAmount;

          // هل يوجد مصدر تمويل بـ isPhysical لهذا الدخل؟
          final hasPhysicalFunding = matchingFunding.any((f) => f.isPhysical);

          if (jar.automationType == 'auto') {
            // توزيع فوري
            updateVirtualBalance(
              id: jar.id,
              delta: transferAmount,
              physicalWalletId: transaction.walletId,
            );
            // لو isPhysical: خصم المبلغ فعلياً من المحفظة
            if (hasPhysicalFunding && transaction.walletId != null) {
              final wIdx =
                  wallets.indexWhere((w) => w.id == transaction.walletId);
              if (wIdx != -1) {
                wallets[wIdx] = wallets[wIdx].copyWith(
                  balance: wallets[wIdx].balance - transferAmount,
                );
              }
            }
            transactions.add(
              TransactionEntity(
                id: auditTransactionId('txn'),
                walletId: transaction.walletId,
                fromWalletId: hasPhysicalFunding ? transaction.walletId : null,
                toWalletId: jar.id,
                budgetScope: 'within-budget',
                incomeSourceId: sourceId,
                amount: transferAmount,
                type: 'transfer',
                transferType:
                    hasPhysicalFunding ? 'jar-funding-physical' : 'jar-funding',
                notes: hasPhysicalFunding
                    ? 'خصم فعلي إلى حصالة ${jar.name}'
                    : 'حجز للحصالة ${jar.name}',
                createdAt: transaction.createdAt,
              ),
            );
          } else if (jar.automationType == 'confirm') {
            // معلّق — ينتظر تأكيد اليوزر
            linkedWallets[i] = jar.copyWith(
              pendingDistribution: jar.pendingDistribution + transferAmount,
              pendingDistributionWalletId:
                  hasPhysicalFunding ? (transaction.walletId ?? '') : '',
              pendingDistributionSourceId: sourceId,
            );
          }
          // manual: لا شيء يحدث تلقائياً
        }

        // Handle Distribution to Allocations based on automationType
        for (var i = 0; i < allocations.length; i++) {
          final alloc = allocations[i];
          final matchingFunding =
              alloc.funding.where((f) => f.incomeSourceId == sourceId).toList();
          if (matchingFunding.isEmpty || remaining <= 0) continue;

          final allocPlan =
              matchingFunding.fold<double>(0, (s, f) => s + f.plannedAmount);
          if (allocPlan <= 0) continue;

          final transferAmount = allocPlan <= remaining ? allocPlan : remaining;
          remaining -= transferAmount;

          if (alloc.automationType == 'auto') {
            final nextBalances = Map<String, double>.from(alloc.walletBalances);
            if (transaction.walletId != null) {
              nextBalances[transaction.walletId!] =
                  (nextBalances[transaction.walletId!] ?? 0) + transferAmount;
            }
            allocations[i] = alloc.copyWith(
              balance: alloc.balance + transferAmount,
              walletBalances: nextBalances,
            );
          } else if (alloc.automationType == 'confirm') {
            allocations[i] = alloc.copyWith(
              pendingDistribution: alloc.pendingDistribution + transferAmount,
              // Allocation funding is always virtual; no physical wallet debit
              // should happen when the user confirms the monthly distribution.
              pendingDistributionWalletId: '',
              pendingDistributionSourceId: sourceId,
            );
          }
          // manual: لا شيء يحدث
        }
      }
    } else if (transaction.type == 'expense') {
      // 4. Physical Expense
      wallets = wallets.map((w) {
        if (w.id != transaction.walletId) return w;
        return w.copyWith(balance: w.balance - transaction.amount);
      }).toList();

      // Deduct from Virtual Reservation if linked
      final virtualTargetId =
          transaction.allocationId ?? transaction.toWalletId;
      if (virtualTargetId != null) {
        updateVirtualBalance(
          id: virtualTargetId,
          delta: -transaction.amount,
          physicalWalletId: transaction.walletId,
        );
      }
    }

    final next = current.copyWith(
      wallets: wallets,
      budgetSetup: current.budgetSetup.copyWith(
        linkedWallets: linkedWallets,
        allocations: allocations,
      ),
      transactions: transactions,
    );
    await saveState(next);
    return next;
  }

  @override
  Future<AppStateEntity> updateBudgetSetup(
      BudgetSetupEntity budgetSetup) async {
    final current = await loadState();
    final next = current.copyWith(budgetSetup: budgetSetup);
    await saveState(next);
    return next;
  }
}
