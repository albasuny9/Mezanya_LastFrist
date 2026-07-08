---
name: Money Distribution Domain Foundation
description: Architecture decisions and non-obvious constraints for the Money Distribution domain and its relationship with Transaction/Budget domains.
---

## Core Rule

TransactionProcessor must NEVER call DistributionEngine or MoneyLocationEngine. The Transaction domain and Distribution domain are independent. walletSources updates via withUpdatedSource in TransactionProcessor are a known violation being phased out in Phase 2.

**Why:** Coupling them caused Problems 3 and 4 (see Domain Bible §5) and made it impossible to fix distribution logic without changing transaction processing.

## DistributionEngine Contract

- `applyDelta` throws `DistributionNegativeAmountException` on negative result — it does NOT clamp silently.
- `upsert` replaces (new id/timestamps), not in-place update — acceptable for Phase 1, Phase 2+ needs a proper `update` when entry identity matters.
- Engine never touches wallet.balance, jar.balance, or TransactionEntity.

**Why:** Engine must be a pure function. The caller (AppCubit) decides what to do on negative-delta failures — creating a MoneyLocationReview is the caller's job.

## Known Violations (documented in Domain Bible §5)

- Violation A: TransactionProcessor calls withUpdatedSource → Problems 3 (spending wallet mismatch) and 4 (silent source removal at ≤0). Fix in Phase 2.
- Violation B: walletSources stored on LinkedWalletEntity (Budget domain). Fix in Phase 2+.
- Violation C: Fixed — relabelJarWalletSource now routes entirely through addTransaction.

## Domain Bible Location

`docs/architecture/00-Mezanya-Domain-Bible.md` is the primary source of truth. If code and Bible disagree, fix both to match — never let them drift.

## Storage Layer (Phase 1)

walletSources data lives in `LinkedWalletEntity.walletSources` (list of JarWalletSource). DistributionEntry is the Phase 2+ replacement model. DistributionValidator.fromWalletSources() is a bridge helper for analysis.

## MoneyLocationEngine

Stays in `budget/domain/services/` for now. Only called from AppCubit (migration + resolveReview). Moving it to money_distribution/ is Phase 2 work.
