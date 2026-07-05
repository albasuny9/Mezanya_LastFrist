import '../../../app_state/domain/entities/app_state_entity.dart';
import '../../../budget/domain/entities/budget_setup_entity.dart';
import '../../../wallets/domain/entities/wallet_entity.dart';
import '../entities/transaction_entity.dart';
import '../../../../core/constants/transaction_types.dart';

/// Pure service — كل logic المالي هنا.
/// لا I/O. لا side effects. بياخد state ويرجع state جديد.
class TransactionProcessor {
  const TransactionProcessor._();

  static String _auditId(String prefix, int count) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-$count';

  // ══════════════════════════════════════════════════════════════════════════
  // APPLY — add a transaction and update all balances
  // ══════════════════════════════════════════════════════════════════════════
  static AppStateEntity apply(
    AppStateEntity current,
    TransactionEntity transaction,
  ) {
    var wallets = List<WalletEntity>.from(current.wallets);
    var linkedWallets =
        List<LinkedWalletEntity>.from(current.budgetSetup.linkedWallets);
    var allocations =
        List<AllocationEntity>.from(current.budgetSetup.allocations);
    var transactions = <TransactionEntity>[
      ...current.transactions,
      transaction,
    ];

    void updateJarSourceOnly({
      required String jarId,
      required String walletId,
      required double delta,
    }) {
      final jarIdx = linkedWallets.indexWhere((j) => j.id == jarId);
      if (jarIdx == -1) return;
      var jar = linkedWallets[jarIdx];
      final nextBalances = Map<String, double>.from(jar.walletBalances);
      nextBalances[walletId] = (nextBalances[walletId] ?? 0) + delta;
      final existingSourceIdx =
          jar.walletSources.indexWhere((s) => s.walletId == walletId);
      final currentSourceAmount = existingSourceIdx == -1
          ? 0.0
          : jar.walletSources[existingSourceIdx].amount;
      jar = jar.withUpdatedSource(walletId, currentSourceAmount + delta);
      linkedWallets[jarIdx] = jar.copyWith(walletBalances: nextBalances);
    }

    void updateVirtualBalance({
      required String id,
      required double delta,
      String? physicalWalletId,
      bool trackWalletSource = true,
    }) {
      final jarIdx = linkedWallets.indexWhere((j) => j.id == id);
      if (jarIdx != -1) {
        var jar = linkedWallets[jarIdx];
        final nextBalances = Map<String, double>.from(jar.walletBalances);
        if (trackWalletSource && physicalWalletId != null) {
          nextBalances[physicalWalletId] =
              (nextBalances[physicalWalletId] ?? 0) + delta;
          final existingSourceIdx = jar.walletSources
              .indexWhere((s) => s.walletId == physicalWalletId);
          double currentSourceAmount = 0;
          if (existingSourceIdx != -1) {
            currentSourceAmount = jar.walletSources[existingSourceIdx].amount;
          }
          jar = jar.withUpdatedSource(
              physicalWalletId, currentSourceAmount + delta);
        }
        linkedWallets[jarIdx] = jar.copyWith(
          balance: jar.balance + delta,
          walletBalances: nextBalances,
        );
        return;
      }
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
      }
    }

    if (transaction.type == TransactionType.transfer.value) {
      if (transaction.transferType == TransferType.jarAllocation.value &&
          transaction.toWalletId != null &&
          (transaction.fromWalletId ?? transaction.walletId) != null) {
        updateJarSourceOnly(
          jarId: transaction.toWalletId!,
          walletId: transaction.fromWalletId ?? transaction.walletId!,
          delta: transaction.amount,
        );
      } else if (transaction.transferType ==
              TransferType.jarAllocationCancel.value &&
          transaction.toWalletId != null &&
          (transaction.fromWalletId ?? transaction.walletId) != null) {
        updateJarSourceOnly(
          jarId: transaction.toWalletId!,
          walletId: transaction.fromWalletId ?? transaction.walletId!,
          delta: -transaction.amount,
        );
      } else {
        final isPhysicalFrom =
            wallets.any((w) => w.id == transaction.fromWalletId);
        final isPhysicalTo = wallets.any((w) => w.id == transaction.toWalletId);

        if (isPhysicalFrom && isPhysicalTo) {
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
            transaction.transferType == TransferType.jarFundingPhysical.value) {
          wallets = wallets.map((w) {
            if (w.id != transaction.fromWalletId) return w;
            return w.copyWith(balance: w.balance - transaction.amount);
          }).toList();
          if (transaction.toWalletId != null) {
            updateVirtualBalance(
              id: transaction.toWalletId!,
              delta: transaction.amount,
              physicalWalletId:
                  transaction.fromWalletId ?? transaction.walletId,
              trackWalletSource: false,
            );
            updateJarSourceOnly(
              jarId: transaction.toWalletId!,
              walletId: transaction.fromWalletId ?? transaction.walletId ?? '',
              delta: transaction.amount,
            );
          }
        } else if (isPhysicalFrom &&
            !isPhysicalTo &&
            transaction.transferType == TransferType.jarFunding.value) {
          // jarFunding فيرشوال: يحدّث jar.balance و walletSources معاً
          // (كان بيحدّث jar.balance بس عبر الـ else العام، لكن walletSources
          // كانت بتفضل قديمة — ده بيخلي "توزيع الفلوس" يعرض قيمة غلط بعد
          // أي تعديل)
          updateVirtualBalance(
            id: transaction.toWalletId!,
            delta: transaction.amount,
            physicalWalletId: transaction.fromWalletId ?? transaction.walletId,
            trackWalletSource: false,
          );
          updateJarSourceOnly(
            jarId: transaction.toWalletId!,
            walletId: transaction.fromWalletId ?? transaction.walletId ?? '',
            delta: transaction.amount,
          );
        } else if (transaction.transferType == TransferType.jarFunding.value &&
            transaction.toWalletId != null) {
          // تمويل فيرشوال من الميزانية للحصالة: نحدّث رصيد الحصالة
          // ونحدّث walletSources عشان لوحة "توزيع الفلوس" تتزامن
          updateVirtualBalance(
            id: transaction.toWalletId!,
            delta: transaction.amount,
            physicalWalletId: transaction.fromWalletId ?? transaction.walletId,
            trackWalletSource: false,
          );
          final sourceWalletId =
              transaction.fromWalletId ?? transaction.walletId;
          if (sourceWalletId != null) {
            updateJarSourceOnly(
              jarId: transaction.toWalletId!,
              walletId: sourceWalletId,
              delta: transaction.amount,
            );
          }
        } else {
          if (transaction.fromWalletId != null) {
            updateVirtualBalance(
              id: transaction.fromWalletId!,
              delta: -transaction.amount,
              physicalWalletId: transaction.walletId,
            );
          }
          if (transaction.toWalletId != null) {
            updateVirtualBalance(
              id: transaction.toWalletId!,
              delta: transaction.amount,
              physicalWalletId: transaction.walletId,
            );
          }
        }
      }
    } else if (transaction.type == TransactionType.income.value) {
      wallets = wallets.map((w) {
        if (w.id != transaction.walletId) return w;
        return w.copyWith(balance: w.balance + transaction.amount);
      }).toList();

      if (transaction.transferType == TransferType.depositWithJarLabel.value &&
          transaction.toWalletId != null) {
        updateVirtualBalance(
          id: transaction.toWalletId!,
          delta: transaction.amount,
          physicalWalletId: transaction.walletId,
          trackWalletSource: false,
        );
        if (transaction.walletId != null) {
          updateJarSourceOnly(
            jarId: transaction.toWalletId!,
            walletId: transaction.walletId!,
            delta: transaction.amount,
          );
          // ملاحظة: لا نضيف معاملة jarAllocation مرافقة هنا — walletSources
          // اتحدثت فوق بـ updateJarSourceOnly، والمعاملة الأصلية
          // (depositWithJarLabel) هي المرجع الوحيد لهذا الحجز.
          // إضافة sub-transaction كانت تسبب ظهور نفس العملية مرتين.
        }
      }

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

          final hasPhysicalFunding = matchingFunding.any((f) => f.isPhysical);

          if (jar.automationType == AutomationType.auto.value) {
            updateVirtualBalance(
              id: jar.id,
              delta: transferAmount,
              physicalWalletId: transaction.walletId,
              trackWalletSource: false,
            );
            if (hasPhysicalFunding && transaction.walletId != null) {
              final wIdx =
                  wallets.indexWhere((w) => w.id == transaction.walletId);
              if (wIdx != -1) {
                wallets[wIdx] = wallets[wIdx]
                    .copyWith(balance: wallets[wIdx].balance - transferAmount);
              }
            }
            if (!hasPhysicalFunding && transaction.walletId != null) {
              updateJarSourceOnly(
                jarId: jar.id,
                walletId: transaction.walletId!,
                delta: transferAmount,
              );
            }
            transactions.add(
              TransactionEntity(
                id: _auditId('txn', transactions.length),
                parentId: transaction.id, // ربط بالمعاملة الأم
                walletId: transaction.walletId,
                fromWalletId: hasPhysicalFunding ? null : transaction.walletId,
                toWalletId: jar.id,
                budgetScope: BudgetScope.withinBudget.value,
                incomeSourceId: sourceId,
                amount: transferAmount,
                type: hasPhysicalFunding
                    ? TransactionType.expense.value
                    : TransactionType.transfer.value,
                transferType: hasPhysicalFunding
                    ? TransferType.jarFundingPhysical.value
                    : TransferType.jarFunding.value,
                notes: null,
                createdAt: transaction.createdAt,
              ),
            );
            if (!hasPhysicalFunding && transaction.walletId != null) {
              transactions.add(
                TransactionEntity(
                  id: _auditId('txn', transactions.length),
                  parentId: transaction.id,
                  walletId: transaction.walletId,
                  fromWalletId: transaction.walletId,
                  toWalletId: jar.id,
                  budgetScope: BudgetScope.withinBudget.value,
                  incomeSourceId: sourceId,
                  amount: transferAmount,
                  type: TransactionType.transfer.value,
                  transferType: TransferType.jarAllocation.value,
                  notes: null,
                  createdAt: transaction.createdAt,
                ),
              );
            }
          } else if (jar.automationType == AutomationType.confirm.value) {
            linkedWallets[i] = jar.copyWith(
              pendingDistribution: jar.pendingDistribution + transferAmount,
              pendingDistributionWalletId: transaction.walletId ?? '',
              pendingDistributionSourceId: sourceId,
              pendingDistributionSnoozedUntil: '',
            );
          }
        }

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

          if (alloc.automationType == AutomationType.auto.value) {
            final nextBalances = Map<String, double>.from(alloc.walletBalances);
            if (transaction.walletId != null) {
              nextBalances[transaction.walletId!] =
                  (nextBalances[transaction.walletId!] ?? 0) + transferAmount;
            }
            allocations[i] = alloc.copyWith(
              balance: alloc.balance + transferAmount,
              walletBalances: nextBalances,
            );
          } else if (alloc.automationType == AutomationType.confirm.value) {
            allocations[i] = alloc.copyWith(
              pendingDistribution: alloc.pendingDistribution + transferAmount,
              pendingDistributionWalletId: '',
              pendingDistributionSourceId: sourceId,
              pendingDistributionSnoozedUntil: '',
            );
          }
        }
      }
    } else if (transaction.type == TransactionType.expense.value) {
      wallets = wallets.map((w) {
        if (w.id != transaction.walletId) return w;
        return w.copyWith(balance: w.balance - transaction.amount);
      }).toList();

      if (transaction.transferType == TransferType.jarFundingPhysical.value &&
          transaction.toWalletId != null) {
        updateVirtualBalance(
          id: transaction.toWalletId!,
          delta: transaction.amount,
          physicalWalletId: transaction.walletId,
          trackWalletSource: false,
        );
      } else {
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
    }

    return current.copyWith(
      wallets: wallets,
      budgetSetup: current.budgetSetup.copyWith(
        linkedWallets: linkedWallets,
        allocations: allocations,
      ),
      transactions: transactions,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REVERSE — undo a transaction (exact mirror of apply)
  // ══════════════════════════════════════════════════════════════════════════
  static AppStateEntity reverse(
    AppStateEntity current,
    TransactionEntity transaction,
  ) {
    var wallets = List<WalletEntity>.from(current.wallets);
    var linkedWallets =
        List<LinkedWalletEntity>.from(current.budgetSetup.linkedWallets);
    var allocations =
        List<AllocationEntity>.from(current.budgetSetup.allocations);

    void reverseVirtualBalance({
      required String id,
      required double delta,
      String? physicalWalletId,
      bool trackWalletSource = true,
    }) {
      final jarIdx = linkedWallets.indexWhere((j) => j.id == id);
      if (jarIdx != -1) {
        var jar = linkedWallets[jarIdx];
        final nextBalances = Map<String, double>.from(jar.walletBalances);
        if (trackWalletSource && physicalWalletId != null) {
          nextBalances[physicalWalletId] =
              (nextBalances[physicalWalletId] ?? 0) - delta;
          final existingSourceIdx = jar.walletSources
              .indexWhere((s) => s.walletId == physicalWalletId);
          final currentSourceAmount = existingSourceIdx == -1
              ? 0.0
              : jar.walletSources[existingSourceIdx].amount;
          jar = jar.withUpdatedSource(
            physicalWalletId,
            currentSourceAmount - delta,
          );
        }
        linkedWallets[jarIdx] = jar.copyWith(
          balance: jar.balance - delta,
          walletBalances: nextBalances,
        );
        return;
      }
      final allocIdx = allocations.indexWhere((a) => a.id == id);
      if (allocIdx != -1) {
        final alloc = allocations[allocIdx];
        final nextBalances = Map<String, double>.from(alloc.walletBalances);
        if (physicalWalletId != null) {
          nextBalances[physicalWalletId] =
              (nextBalances[physicalWalletId] ?? 0) - delta;
        }
        allocations[allocIdx] = alloc.copyWith(
          balance: alloc.balance - delta,
          walletBalances: nextBalances,
        );
      }
    }

    void reverseJarSourceOnly({
      required String jarId,
      required String walletId,
      required double delta,
    }) {
      final jarIdx = linkedWallets.indexWhere((j) => j.id == jarId);
      if (jarIdx == -1) return;
      var jar = linkedWallets[jarIdx];
      final nextBalances = Map<String, double>.from(jar.walletBalances);
      nextBalances[walletId] = (nextBalances[walletId] ?? 0) - delta;
      final existingSourceIdx =
          jar.walletSources.indexWhere((s) => s.walletId == walletId);
      final currentSourceAmount = existingSourceIdx == -1
          ? 0.0
          : jar.walletSources[existingSourceIdx].amount;
      jar = jar.withUpdatedSource(walletId, currentSourceAmount - delta);
      linkedWallets[jarIdx] = jar.copyWith(walletBalances: nextBalances);
    }

    if (transaction.type == TransactionType.transfer.value) {
      if (transaction.transferType == TransferType.jarAllocation.value &&
          transaction.toWalletId != null &&
          (transaction.fromWalletId ?? transaction.walletId) != null) {
        reverseJarSourceOnly(
          jarId: transaction.toWalletId!,
          walletId: transaction.fromWalletId ?? transaction.walletId!,
          delta: transaction.amount,
        );
      } else if (transaction.transferType ==
              TransferType.jarAllocationCancel.value &&
          transaction.toWalletId != null &&
          (transaction.fromWalletId ?? transaction.walletId) != null) {
        reverseJarSourceOnly(
          jarId: transaction.toWalletId!,
          walletId: transaction.fromWalletId ?? transaction.walletId!,
          delta: -transaction.amount,
        );
      } else {
        final isPhysicalFrom =
            wallets.any((w) => w.id == transaction.fromWalletId);
        final isPhysicalTo = wallets.any((w) => w.id == transaction.toWalletId);

        if (isPhysicalFrom && isPhysicalTo) {
          wallets = wallets.map((w) {
            if (w.id == transaction.fromWalletId) {
              return w.copyWith(balance: w.balance + transaction.amount);
            }
            if (w.id == transaction.toWalletId) {
              return w.copyWith(balance: w.balance - transaction.amount);
            }
            return w;
          }).toList();
        } else if (isPhysicalFrom &&
            !isPhysicalTo &&
            transaction.transferType == TransferType.jarFundingPhysical.value) {
          wallets = wallets.map((w) {
            if (w.id != transaction.fromWalletId) return w;
            return w.copyWith(balance: w.balance + transaction.amount);
          }).toList();
          if (transaction.toWalletId != null) {
            reverseVirtualBalance(
              id: transaction.toWalletId!,
              delta: transaction.amount,
              physicalWalletId:
                  transaction.fromWalletId ?? transaction.walletId,
              trackWalletSource: false,
            );
            final sourceWalletId =
                transaction.fromWalletId ?? transaction.walletId;
            if (sourceWalletId != null) {
              reverseJarSourceOnly(
                jarId: transaction.toWalletId!,
                walletId: sourceWalletId,
                delta: transaction.amount,
              );
            }
          }
        } else if (transaction.transferType == TransferType.jarFunding.value &&
            transaction.toWalletId != null) {
          // عكس تمويل فيرشوال: نعكس رصيد الحصالة ونعكس walletSources
          reverseVirtualBalance(
            id: transaction.toWalletId!,
            delta: transaction.amount,
            physicalWalletId: transaction.fromWalletId ?? transaction.walletId,
            trackWalletSource: false,
          );
          final sourceWalletId =
              transaction.fromWalletId ?? transaction.walletId;
          if (sourceWalletId != null) {
            reverseJarSourceOnly(
              jarId: transaction.toWalletId!,
              walletId: sourceWalletId,
              delta: transaction.amount,
            );
          }
        } else {
          if (transaction.fromWalletId != null) {
            reverseVirtualBalance(
              id: transaction.fromWalletId!,
              delta: -transaction.amount,
              physicalWalletId: transaction.walletId,
            );
          }
          if (transaction.toWalletId != null) {
            reverseVirtualBalance(
              id: transaction.toWalletId!,
              delta: transaction.amount,
              physicalWalletId: transaction.walletId,
            );
          }
        }
      }
    } else if (transaction.type == TransactionType.income.value) {
      // 1. عكس رصيد المحفظة
      wallets = wallets.map((w) {
        if (w.id != transaction.walletId) return w;
        return w.copyWith(balance: w.balance - transaction.amount);
      }).toList();

      final hasSourceChild = current.transactions.any((t) =>
          t.parentId == transaction.id &&
          t.transferType == TransferType.jarAllocation.value);

      if (transaction.transferType == TransferType.depositWithJarLabel.value &&
          transaction.toWalletId != null) {
        reverseVirtualBalance(
          id: transaction.toWalletId!,
          delta: transaction.amount,
          physicalWalletId: transaction.walletId,
          trackWalletSource: !hasSourceChild,
        );
      }

      // 2. إيجاد وعكس كل الـ sub-transactions المرتبطة بالأم
      //    أ) بالـ parentId (المعاملات الجديدة)
      //    ب) بالـ createdAt + incomeSourceId + walletId (backward compat للقديمة)
      final subTxns = current.transactions.where((t) {
        if (t.id == transaction.id) return false;
        if (t.parentId != null) return t.parentId == transaction.id;
        // Backward compat: sub-transactions قديمة بدون parentId
        return (t.transferType == TransferType.jarFunding.value ||
                t.transferType == TransferType.jarAllocation.value ||
                t.transferType == TransferType.jarAllocationCancel.value ||
                t.transferType == TransferType.jarFundingPhysical.value) &&
            t.incomeSourceId == transaction.incomeSourceId &&
            t.walletId == transaction.walletId &&
            t.createdAt == transaction.createdAt;
      }).toList();

      for (final sub in subTxns) {
        if (sub.transferType == TransferType.jarFunding.value) {
          final hasMatchingSourceChild = sub.parentId == null
              ? false
              : current.transactions.any((t) =>
                  t.parentId == sub.parentId &&
                  t.transferType == TransferType.jarAllocation.value &&
                  t.toWalletId == sub.toWalletId &&
                  (t.fromWalletId ?? t.walletId) == sub.walletId);
          if (sub.toWalletId != null) {
            reverseVirtualBalance(
              id: sub.toWalletId!,
              delta: sub.amount,
              physicalWalletId: sub.walletId,
              trackWalletSource: !hasMatchingSourceChild,
            );
          }
        } else if (sub.transferType == TransferType.jarFundingPhysical.value) {
          // Physical: نرجع الفلوس للمحفظة + نخصم من الحصالة
          wallets = wallets.map((w) {
            if (w.id != sub.walletId) return w;
            return w.copyWith(balance: w.balance + sub.amount);
          }).toList();
          if (sub.toWalletId != null) {
            reverseVirtualBalance(
              id: sub.toWalletId!,
              delta: sub.amount,
              physicalWalletId: sub.walletId,
              trackWalletSource: false,
            );
          }
        } else if (sub.transferType == TransferType.jarAllocation.value &&
            sub.toWalletId != null &&
            (sub.fromWalletId ?? sub.walletId) != null) {
          reverseJarSourceOnly(
            jarId: sub.toWalletId!,
            walletId: sub.fromWalletId ?? sub.walletId!,
            delta: sub.amount,
          );
        } else if (sub.transferType == TransferType.jarAllocationCancel.value &&
            sub.toWalletId != null &&
            (sub.fromWalletId ?? sub.walletId) != null) {
          reverseJarSourceOnly(
            jarId: sub.toWalletId!,
            walletId: sub.fromWalletId ?? sub.walletId!,
            delta: -sub.amount,
          );
        }
      }
    } else if (transaction.type == TransactionType.expense.value) {
      wallets = wallets.map((w) {
        if (w.id != transaction.walletId) return w;
        return w.copyWith(balance: w.balance + transaction.amount);
      }).toList();

      if (transaction.transferType == TransferType.jarFundingPhysical.value &&
          transaction.toWalletId != null) {
        reverseVirtualBalance(
          id: transaction.toWalletId!,
          delta: transaction.amount,
          physicalWalletId: transaction.walletId,
          trackWalletSource: false,
        );
      } else {
        final virtualTargetId =
            transaction.allocationId ?? transaction.toWalletId;
        if (virtualTargetId != null) {
          reverseVirtualBalance(
            id: virtualTargetId,
            delta: -transaction.amount,
            physicalWalletId: transaction.walletId,
          );
        }
      }
    }

    return current.copyWith(
      wallets: wallets,
      budgetSetup: current.budgetSetup.copyWith(
        linkedWallets: linkedWallets,
        allocations: allocations,
      ),
      transactions: current.transactions.where((t) {
        if (t.id == transaction.id) return false;
        // احذف الـ sub-transactions المرتبطة بالأم
        if (t.parentId != null && t.parentId == transaction.id) return false;
        // Backward compat: sub-transactions قديمة بدون parentId
        if (transaction.type == TransactionType.income.value &&
            (t.transferType == TransferType.jarFunding.value ||
                t.transferType == TransferType.jarAllocation.value ||
                t.transferType == TransferType.jarAllocationCancel.value ||
                t.transferType == TransferType.jarFundingPhysical.value) &&
            t.incomeSourceId == transaction.incomeSourceId &&
            t.walletId == transaction.walletId &&
            t.createdAt == transaction.createdAt) {
          return false;
        }
        return true;
      }).toList(),
    );
  }
}
