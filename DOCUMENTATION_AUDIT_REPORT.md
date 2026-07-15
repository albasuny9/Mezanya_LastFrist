# Mezanya — Documentation Audit Report

**Scope:** Full inventory and classification of every documentation file under `docs/`, `.agents/memory/`, and repository-root markdown files, produced as part of establishing documentation governance (`.agents/README.md`, `PROJECT_INDEX.md`, `DOCUMENTATION_MAP.md`, `AGENT_WORKFLOW.md`, `DOCUMENTATION_RULES.md`).
**Method:** Direct file reads (headers/full content where short) and byte-level `diff` checks between similarly-named files. No code was inspected or modified. No documentation content was rewritten, moved, or deleted.
**Status labels used:** `Canonical`, `Reference`, `Implementation`, `Historical`, `Temporary` (per `.agents/DOCUMENTATION_RULES.md` rule 8).

---

## 1. Full inventory and classification

### Domain Bible — `docs/architecture/Mezanya Domain Bible/`
| File | Status | Notes |
|---|---|---|
| `00 - Introduction.md` | Canonical | Populated. |
| `01 - Domain Fundamentals.md` | Canonical | Populated. |
| `02 - Financial Cycle .md` | Canonical | Populated. |
| `03 - Transfers.md` | Canonical | Populated, notes multiple revision passes. |
| `04 - Financial Engine .md` | Temporary (gap) | **Empty file (0 lines).** |
| `05 - Allocation.md` | Temporary (gap) | **Empty file (0 lines).** |
| `06 - Read Models.md` | Temporary (gap) | **Empty file (0 lines).** |
| `07 - Persistence.md` | Temporary (gap) | **Empty file (0 lines).** |
| `08 - Development Constitution.md` | Temporary (gap) | **Empty file (0 lines).** |
| `Reconstruction Master Plan.md` | Canonical | Populated planning document for domain stabilization. |

### ADRs — `docs/architecture/adr/`
| File | Status | Notes |
|---|---|---|
| `README.md` | Reference | Index of ADRs + stated status per ADR. |
| `0001-generic-transaction-references.md` | Reference | Status: Proposed. |
| `0002-single-source-of-truth-financial-calculations.md` | Reference | Status: Partially Implemented. |
| `0003-backup-versioning-overwrite-protection.md` | Reference | Status: Proposed, undecided. |
| `0004-money-distribution-ownership.md` | Reference | Documents an unresolved contradiction (see §2). |

### Architecture root-level — `docs/architecture/*.md`
| File | Status | Notes |
|---|---|---|
| `README.md` | Canonical | Declares the folder's own authority hierarchy. |
| `financial-domain-model-audit.md` | Reference | Explicitly states it is not part of the Domain Bible. |
| `jar_money_location_architecture.md` | Reference | **Differs from** `legacy/jar_money_location_architecture.md` (same title, diverged content — see §2). |
| `money_location_engine_v2.md` | Reference | **Byte-identical duplicate** of `legacy/money_location_engine_v2.md`. |
| `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | Reference | **Byte-identical duplicate** of `legacy/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` (987 lines each). |
| `REFACTOR_STATUS.md` | Reference | Explicitly scoped as the gap-tracking doc between plan and code; not a duplicate. |
| `text-parsing-business-logic-inventory.md` | Reference | **Differs from** `maps/text-parsing-business-logic-inventory.md` (same title, diverged content — see §2). |
| `unified-recurring-engine-review.md` | Reference | Status: Phases 1–7 complete, Phase 8 awaiting approval. |
| `refactor-budget-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-budget-feature.md`. |
| `refactor-home-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-home-feature.md`. |
| `refactor-notifications-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-notifications-feature.md`. |
| `refactor-settings-appcubit-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-settings-appcubit-feature.md`. |
| `refactor-transactions-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-transactions-feature.md`. |
| `refactor-wallets-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-wallets-feature.md`. |

### `docs/architecture/maps/`
| File | Status | Notes |
|---|---|---|
| `00-...-Volume-1.md` through `17-...-Volume-18.md` (18 files) | Reference | Volume 1 self-labels "Authoritative Source of Truth" — conflicts with `docs/architecture/README.md`'s hierarchy (see §2). Not read in full depth (large corpus); headers confirm consistent MAPS branding/structure across all 18 volumes. |
| `financial-calculation-map.md` | Reference | Explicitly states it is not part of the Domain Bible. |
| `text-parsing-business-logic-inventory.md` | Reference | **Differs from** `docs/architecture/text-parsing-business-logic-inventory.md` (see §2). |

### `docs/architecture/feature-refactors/`
| File | Status | Notes |
|---|---|---|
| `refactor-budget-feature.md`, `refactor-home-feature.md`, `refactor-notifications-feature.md`, `refactor-settings-appcubit-feature.md`, `refactor-transactions-feature.md`, `refactor-wallets-feature.md` | Implementation | Canonical *location* per `docs/architecture/README.md`'s stated structure; each has a byte-identical stray copy directly under `docs/architecture/` (see §2). |

### `docs/architecture/legacy/`
| File | Status | Notes |
|---|---|---|
| `jar_money_location_architecture.md` | Historical | Diverged from the current root-level file of the same name. |
| `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | Historical | Byte-identical to the root-level copy — fully redundant. |
| `money_location_engine_v2.md` | Historical | Byte-identical to the root-level copy — fully redundant. |

### `docs/project/`
| File | Status | Notes |
|---|---|---|
| `Bug Backlog.md` (space) | Historical (likely stale) | Shorter/stub content; diverged from `Bug_Backlog.md`. Not confirmed dead by either file — flagged for owner review, not deleted. |
| `Bug_Backlog.md` (underscore) | Temporary | Active tracker with "OPEN BUGS" section; matches `replit.md`'s mandatory pre-read reference. |
| `Decisions Log.md` | Reference | Project-scope/priority decisions, explicitly distinguished from Domain Bible architectural decisions. |
| `decisions/Transaction Editing Architecture.md` | Reference | Single decision record. |
| `investigations/BUG-001 Wallet Transfer Investigation.md` | Temporary | Forensic investigation, no fix proposed. |
| `investigations/BUG-002 Jar Category Scope Investigation.md` | Temporary | Forensic investigation, no fix proposed. |
| `investigations/BUG-004 Auto Cloud Backup Investigation.md` | Temporary | Forensic investigation; explicitly notes the required real-device test was not performed. |
| `investigations/NBC-001 Category Breakdown General-Bucket-Only Lookup.md` | Temporary | New bug candidate discovered mid-investigation, correctly filed separately rather than folded into BUG-002. |
| `Reconstruction Progress.md` | Temporary (gap) | **Empty file (0 lines).** |
| `Task Plan - Replit.md` | Reference | Governs how Replit-based agents should scope work; referenced directly by `replit.md`. |
| `Technical Debt.md` | Temporary (gap) | **Empty file (0 lines).** |

### `.agents/memory/`
| File | Status | Notes |
|---|---|---|
| `MEMORY.md` | Implementation | Index file. **Only indexes 2 of the 7 topic files present** (see §2). |
| `tp-reverse-bc-fix.md` | Implementation | Indexed in MEMORY.md. |
| `gen-l10n-replit-quirk.md` | Implementation | Indexed in MEMORY.md. |
| `budget-phase1-widget-extraction.md` | Implementation | **Not indexed** in MEMORY.md. |
| `budget-phase2-constants-extraction.md` | Implementation | **Not indexed** in MEMORY.md. |
| `budget-phase3-service-extraction.md` | Implementation | **Not indexed** in MEMORY.md. |
| `money-distribution-domain.md` | Implementation (migration candidate) | **Not indexed** in MEMORY.md; content reads as durable domain architecture, not an implementation quirk (see §3). |
| `money-location-engine.md` | Implementation (migration candidate) | **Not indexed** in MEMORY.md; content reads as durable domain architecture, not an implementation quirk (see §3). |

### Repository root
| File | Status | Notes |
|---|---|---|
| `replit.md` | Canonical | Environment/run instructions + currently active agent operating protocol ("User preferences"). |
| `README.md` | Historical | Describes an app named "Korassa" — does not match the current Mezanya project. Stale/mislabeled. |
| `project_documentation.md` | Reference | General project overview; overlaps with Domain Bible/MAPS content without being authoritative. |
| `FLUTTER_AI_HANDOFF_AR.md` | Historical | Greenfield rebuild handoff brief (Arabic), predates current implementation state. |
| `TRANSACTION_ARCHITECTURE_AUDIT.md` | Reference | Standalone transaction-system audit; not cross-linked from `docs/architecture/`. |

---

## 2. Duplicate documentation

**Exact (byte-identical) duplicates:**
- `docs/architecture/money_location_engine_v2.md` ≡ `docs/architecture/legacy/money_location_engine_v2.md`
- `docs/architecture/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` ≡ `docs/architecture/legacy/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` (987 lines)
- `docs/architecture/refactor-budget-feature.md` ≡ `docs/architecture/feature-refactors/refactor-budget-feature.md`
- `docs/architecture/refactor-home-feature.md` ≡ `docs/architecture/feature-refactors/refactor-home-feature.md`
- `docs/architecture/refactor-notifications-feature.md` ≡ `docs/architecture/feature-refactors/refactor-notifications-feature.md`
- `docs/architecture/refactor-settings-appcubit-feature.md` ≡ `docs/architecture/feature-refactors/refactor-settings-appcubit-feature.md`
- `docs/architecture/refactor-transactions-feature.md` ≡ `docs/architecture/feature-refactors/refactor-transactions-feature.md`
- `docs/architecture/refactor-wallets-feature.md` ≡ `docs/architecture/feature-refactors/refactor-wallets-feature.md`

**Same-title, diverged-content duplicates (worse — risk of citing the wrong/outdated version):**
- `docs/architecture/jar_money_location_architecture.md` vs. `docs/architecture/legacy/jar_money_location_architecture.md`
- `docs/architecture/text-parsing-business-logic-inventory.md` vs. `docs/architecture/maps/text-parsing-business-logic-inventory.md`
- `docs/project/Bug Backlog.md` vs. `docs/project/Bug_Backlog.md`

**Authority-claim duplication:**
- `docs/architecture/README.md` and `docs/architecture/maps/00-...-Volume-1.md` each claim to be (or house) the authoritative source of truth, in direct tension.

## 3. Missing documentation

- Domain Bible chapters **04–08 are empty** (Financial Engine, Allocation, Read Models, Persistence, Development Constitution) — the five topics most likely to be needed for day-to-day implementation work have no canonical content at all.
- `docs/project/Technical Debt.md` and `docs/project/Reconstruction Progress.md` are empty — no active technical-debt register or reconstruction progress tracker exists despite the file placeholders implying one should.
- No document explicitly resolves the Domain Bible vs. MAPS authority conflict, or the Money Location Engine vs. Money Distribution domain-ownership conflict (ADR-0004 documents the latter as open, not resolved).

## 4. Obsolete documentation

- `README.md` (repo root) — describes a different, unrelated app ("Korassa"). Obsolete/mislabeled relative to the current Mezanya project.
- `docs/project/Bug Backlog.md` (space-named) — appears superseded by `Bug_Backlog.md`; not confirmed dead by either document.
- The 8 exact-duplicate files listed in §2 are redundant copies rather than content that is wrong, but each pair is a maintenance liability (edits to one will silently not apply to the other).

## 5. Recommended migrations (candidates only — no migration performed)

- `.agents/memory/money-location-engine.md` and `.agents/memory/money-distribution-domain.md` read as durable domain/architecture knowledge (they are already cited as sources by ADR-0004) rather than transient implementation quirks. Per `replit.md`'s own standing instruction ("Do not rely on agent persistent memory for project architecture knowledge... durable architectural findings must be written [to docs], not only in memory"), these are strong candidates for migration into `docs/architecture/` (or the Domain Bible, once ADR-0004's underlying conflict is resolved) — **not migrated in this pass, per instructions.**
- The three `budget-phase*-extraction.md` memory files could be consolidated into a single `docs/architecture/feature-refactors/refactor-budget-feature.md` "progress log" section once that refactor is confirmed complete, rather than living as three separate, unindexed memory files.

## 6. Documentation debt summary

- **8 exact-duplicate files** across `docs/architecture/` (root vs. `legacy/`, root vs. `feature-refactors/`).
- **3 same-title/diverged-content duplicate pairs**, which are higher-risk than exact duplicates because an agent citing "the" file by name may get either version.
- **5 empty Domain Bible chapters** out of 9 total chapter files — the canonical source of truth is roughly half unwritten.
- **2 empty project-tracking placeholders** (`Technical Debt.md`, `Reconstruction Progress.md`).
- **5 of 7 Agent Memory topic files unindexed** in `MEMORY.md`, reducing discoverability of past decisions.
- **2 unresolved authority conflicts** (Domain Bible vs. MAPS; Money Location Engine vs. Money Distribution domain).
- **1 mislabeled root document** (`README.md` describing a different app).

---

## Status

Documentation governance structure established: `.agents/README.md`, `.agents/PROJECT_INDEX.md`, `.agents/DOCUMENTATION_MAP.md`, `.agents/AGENT_WORKFLOW.md`, `.agents/DOCUMENTATION_RULES.md`, and this audit report are in place.

**No content was rewritten, migrated, moved, or deleted.** No Dart code, Flutter UI, tests, or business logic were touched. Per the task's explicit instruction, this stops here and awaits approval before any migration or cleanup is performed.
