# Mezanya — Documentation Audit Report

**Scope:** Full inventory and classification of every documentation file under `docs/`, `.agents/memory/`, and repository-root markdown files, produced as part of establishing documentation governance (`.agents/README.md`, `PROJECT_INDEX.md`, `DOCUMENTATION_MAP.md`, `AGENT_WORKFLOW.md`, `DOCUMENTATION_RULES.md`, `DOCUMENTATION_MIGRATION_PLAN.md`).
**Method:** Direct file reads (headers/full content where short) and byte-level `diff` checks between similarly-named files. No code was inspected or modified. No documentation content was rewritten, moved, or deleted.
**Status labels used:** `Canonical`, `Reference`, `Implementation`, `Historical`, `Temporary` (per `.agents/DOCUMENTATION_RULES.md` rule 8). Per `.agents/DOCUMENTATION_MAP.md` §Authority Resolution, `Canonical` is reserved for the Domain Bible and `replit.md`; every other document below resolves to one of the remaining four.

---

## 1. Full inventory and classification

### Domain Bible — `docs/architecture/Mezanya Domain Bible/`
| File | Status | Notes |
|---|---|---|
| `00 - Introduction.md` | Canonical | Populated. |
| `01 - Domain Fundamentals.md` | Canonical | Populated. |
| `02 - Financial Cycle .md` | Canonical | Populated. |
| `03 - Transfers.md` | Canonical | Populated, notes multiple revision passes. |
| `04 - Financial Engine .md` | Temporary (gap) | **Empty file (0 lines).** See migration plan #3. |
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
| `0004-money-distribution-ownership.md` | Reference | Documents an unresolved contradiction — see §3 Known Conflicts. |

### Architecture root-level — `docs/architecture/*.md`
| File | Status | Notes |
|---|---|---|
| `README.md` | Canonical (folder-index only) | Declares the folder's own authority hierarchy; consistent with `.agents/DOCUMENTATION_MAP.md`. |
| `financial-domain-model-audit.md` | Reference | Explicitly states it is not part of the Domain Bible. |
| `jar_money_location_architecture.md` | Reference | **Differs from** `legacy/jar_money_location_architecture.md` — see §2 Duplicates. |
| `money_location_engine_v2.md` | Reference | **Byte-identical duplicate** of `legacy/money_location_engine_v2.md` — see §2. |
| `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | Implementation | **Byte-identical duplicate** of `legacy/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` (987 lines each) — see §2. |
| `REFACTOR_STATUS.md` | Reference | Explicitly scoped as the gap-tracking doc between plan and code; not a duplicate. |
| `text-parsing-business-logic-inventory.md` | Reference | **Differs from** `maps/text-parsing-business-logic-inventory.md` — see §2. |
| `unified-recurring-engine-review.md` | Reference | Status: Phases 1–7 complete, Phase 8 awaiting approval. |
| `refactor-budget-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-budget-feature.md` — see §2. |
| `refactor-home-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-home-feature.md` — see §2. |
| `refactor-notifications-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-notifications-feature.md` — see §2. |
| `refactor-settings-appcubit-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-settings-appcubit-feature.md` — see §2. |
| `refactor-transactions-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-transactions-feature.md` — see §2. |
| `refactor-wallets-feature.md` | Implementation | **Byte-identical duplicate** of `feature-refactors/refactor-wallets-feature.md` — see §2. |

### `docs/architecture/maps/`
| File | Status | Notes |
|---|---|---|
| `00-...-Volume-1.md` through `17-...-Volume-18.md` (18 files) | Reference | Volume 1 self-labels "Authoritative Source of Truth" — **this claim is superseded by the Domain Bible**, per `.agents/DOCUMENTATION_MAP.md` §Authority Resolution. Not read in full depth (large corpus); headers confirm consistent MAPS branding/structure across all 18 volumes. |
| `financial-calculation-map.md` | Reference | Explicitly states it is not part of the Domain Bible. |
| `text-parsing-business-logic-inventory.md` | Reference | **Differs from** `docs/architecture/text-parsing-business-logic-inventory.md` — see §2. |

### `docs/architecture/feature-refactors/`
| File | Status | Notes |
|---|---|---|
| `refactor-budget-feature.md`, `refactor-home-feature.md`, `refactor-notifications-feature.md`, `refactor-settings-appcubit-feature.md`, `refactor-transactions-feature.md`, `refactor-wallets-feature.md` | Implementation | Canonical *location* per `docs/architecture/README.md`'s stated structure; each has a byte-identical stray copy directly under `docs/architecture/` — see §2. |

### `docs/architecture/legacy/`
| File | Status | Notes |
|---|---|---|
| `jar_money_location_architecture.md` | Historical | Diverged from the current root-level file of the same name. |
| `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | Historical | Byte-identical to the root-level copy — fully redundant. |
| `money_location_engine_v2.md` | Historical | Byte-identical to the root-level copy — fully redundant. |

### `docs/project/`
| File | Status | Notes |
|---|---|---|
| `Bug Backlog.md` (space) | Historical | Superseded by `Bug_Backlog.md` per `.agents/DOCUMENTATION_MAP.md` §Known Conflicts #3. Not confirmed to contain zero unique content — see migration plan #5. |
| `Bug_Backlog.md` (underscore) | Temporary | Active tracker with "OPEN BUGS" section; matches `replit.md`'s mandatory pre-read reference. |
| `Decisions Log.md` | Temporary | Project-scope/priority decisions, explicitly distinguished from Domain Bible architectural decisions. |
| `decisions/Transaction Editing Architecture.md` | Temporary | Single decision record. |
| `investigations/BUG-001 Wallet Transfer Investigation.md` | Temporary | Forensic investigation, no fix proposed. |
| `investigations/BUG-002 Jar Category Scope Investigation.md` | Temporary | Forensic investigation, no fix proposed. |
| `investigations/BUG-004 Auto Cloud Backup Investigation.md` | Temporary | Forensic investigation; explicitly notes the required real-device test was not performed. |
| `investigations/NBC-001 Category Breakdown General-Bucket-Only Lookup.md` | Temporary | New bug candidate discovered mid-investigation, correctly filed separately rather than folded into BUG-002. |
| `Reconstruction Progress.md` | Temporary (gap) | **Empty file (0 lines).** |
| `Task Plan - Replit.md` | Temporary | Governs how Replit-based agents should scope work; referenced directly by `replit.md`. |
| `Technical Debt.md` | Temporary (gap) | **Empty file (0 lines).** |

### `.agents/memory/`
See §4 Agent Memory Review for the full classification table (Current Status / Still Useful / Obsolete / Contains Permanent Domain Knowledge / Candidate for Migration).

### Repository root
| File | Status | Notes |
|---|---|---|
| `replit.md` | Canonical | Environment/run instructions + currently active agent operating protocol ("User preferences"). Outside the business-truth ladder — see `.agents/DOCUMENTATION_MAP.md`. |
| `README.md` | Historical | Describes an app named "Korassa" — does not match the current Mezanya project. Stale/mislabeled. See migration plan #11. |
| `project_documentation.md` | Reference | General project overview; overlaps with Domain Bible/MAPS content without being authoritative. |
| `FLUTTER_AI_HANDOFF_AR.md` | Historical | Greenfield rebuild handoff brief (Arabic), predates current implementation state. |
| `TRANSACTION_ARCHITECTURE_AUDIT.md` | Reference | Standalone transaction-system audit; not cross-linked from `docs/architecture/`. Overlap with `financial-domain-model-audit.md` / `unified-recurring-engine-review.md` not yet verified line-by-line — recorded as Unknown extent. |

---

## 2. Duplicate documentation — detailed table

| File | Duplicate Of | Reason | Recommended Action |
|---|---|---|---|
| `docs/architecture/money_location_engine_v2.md` | `docs/architecture/legacy/money_location_engine_v2.md` | Byte-identical content. | **Keep** root copy; **Archive** legacy copy (migration plan #6). |
| `docs/architecture/legacy/money_location_engine_v2.md` | `docs/architecture/money_location_engine_v2.md` | Byte-identical content; sits in the folder explicitly designated Historical. | **Archive** (retain but stop treating as a live reference). |
| `docs/architecture/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | `docs/architecture/legacy/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | Byte-identical, 987 lines each. | **Keep** root copy; **Archive** legacy copy (migration plan #7). |
| `docs/architecture/legacy/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | `docs/architecture/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | Byte-identical. | **Archive.** |
| `docs/architecture/refactor-budget-feature.md` | `docs/architecture/feature-refactors/refactor-budget-feature.md` | Byte-identical content, stray copy outside the folder `docs/architecture/README.md` designates as canonical. | **Keep** `feature-refactors/` copy; **Archive** root copy (migration plan #8). |
| `docs/architecture/refactor-home-feature.md` | `docs/architecture/feature-refactors/refactor-home-feature.md` | Byte-identical, same pattern as above. | **Keep** `feature-refactors/` copy; **Archive** root copy. |
| `docs/architecture/refactor-notifications-feature.md` | `docs/architecture/feature-refactors/refactor-notifications-feature.md` | Byte-identical, same pattern as above. | **Keep** `feature-refactors/` copy; **Archive** root copy. |
| `docs/architecture/refactor-settings-appcubit-feature.md` | `docs/architecture/feature-refactors/refactor-settings-appcubit-feature.md` | Byte-identical, same pattern as above. | **Keep** `feature-refactors/` copy; **Archive** root copy. |
| `docs/architecture/refactor-transactions-feature.md` | `docs/architecture/feature-refactors/refactor-transactions-feature.md` | Byte-identical, same pattern as above. | **Keep** `feature-refactors/` copy; **Archive** root copy. |
| `docs/architecture/refactor-wallets-feature.md` | `docs/architecture/feature-refactors/refactor-wallets-feature.md` | Byte-identical, same pattern as above. | **Keep** `feature-refactors/` copy; **Archive** root copy. |
| `docs/architecture/jar_money_location_architecture.md` | `docs/architecture/legacy/jar_money_location_architecture.md` | Same title, **content has diverged** — not a clean duplicate. | **Merge** (diff-and-reconcile before archiving either — migration plan #9). Do **not** delete either until reconciled. |
| `docs/architecture/legacy/jar_money_location_architecture.md` | `docs/architecture/jar_money_location_architecture.md` | Same title, diverged content, sits in the Historical folder. | **Merge** (see above), then **Archive** whichever version is superseded once reconciled. |
| `docs/architecture/text-parsing-business-logic-inventory.md` | `docs/architecture/maps/text-parsing-business-logic-inventory.md` | Same title, **content has diverged**. | **Merge** (migration plan #10). Do **not** delete either until reconciled. |
| `docs/architecture/maps/text-parsing-business-logic-inventory.md` | `docs/architecture/text-parsing-business-logic-inventory.md` | Same title, diverged content. | **Merge** (see above). |
| `docs/project/Bug Backlog.md` | `docs/project/Bug_Backlog.md` | Same subject, `Bug_Backlog.md` is richer/active (has "OPEN BUGS" section) and matches `replit.md`'s required pre-read; `Bug Backlog.md` is a shorter stub that has diverged. | **Merge-check then Archive**: reconcile line-by-line to confirm no unique bug entries exist only in the space-named file, then Archive it (migration plan #5). **Do not delete outright** until that check is done. |
| `docs/project/Bug_Backlog.md` | `docs/project/Bug Backlog.md` | Active/current version of the same subject. | **Keep** as the canonical active tracker. |

**Authority-claim duplication (not a content duplicate, but a conflicting-claim pair):**

| File | Conflicts With | Reason | Recommended Action |
|---|---|---|---|
| `docs/architecture/maps/00-Mezanya-Architecture-Product-Specification-Volume-1.md` | `docs/architecture/README.md` / the Domain Bible | Self-labels "Authoritative Source of Truth," conflicting with the Domain Bible's status as sole business-truth source. | **Keep** the file (Reference value intact); **the authority claim itself is superseded** — no file edit performed in this pass, resolution recorded in `.agents/DOCUMENTATION_MAP.md`. |

---

## 3. Missing documentation / Known conflicts

- Domain Bible chapters **04–08 are empty** (Financial Engine, Allocation, Read Models, Persistence, Development Constitution) — the five topics most likely to be needed for day-to-day implementation work have no canonical content at all. See migration plan #3.
- `docs/project/Technical Debt.md` and `docs/project/Reconstruction Progress.md` are empty — no active technical-debt register or reconstruction progress tracker exists despite the file placeholders implying one should.
- **Resolved this pass:** Domain Bible vs. MAPS authority conflict — see `.agents/DOCUMENTATION_MAP.md` §Authority Resolution.
- **Not resolved, out of scope for documentation governance:** Money Location Engine vs. Money Distribution domain-ownership conflict (ADR-0004 documents this as open; requires an architecture decision, not a documentation reclassification). See migration plan items #1–#3 for what is blocked on this.

## 4. Agent Memory Review

| File | Current Status | Still Useful | Obsolete | Contains Permanent Domain Knowledge | Candidate for Migration |
|---|---|---|---|---|---|
| `MEMORY.md` | Active index | Yes | No | No (index only) | No — but should be updated to index the 5 currently-unindexed files below (a housekeeping fix, not a content migration). |
| `tp-reverse-bc-fix.md` | Active, indexed | Yes | No | No — describes a specific bug fix (backward-compat double-decrement), tied to a code path, not a standing business rule. | No. |
| `gen-l10n-replit-quirk.md` | Active, indexed | Yes | No | No — pure tooling/environment quirk. | No. |
| `budget-phase1-widget-extraction.md` | Active, **not indexed** | Yes, while `refactor-budget-feature.md` is in progress | No, unless that refactor is confirmed complete | No — implementation/extraction notes only. | Yes, but only for **consolidation** into `feature-refactors/refactor-budget-feature.md`, not into the Domain Bible (migration plan #4). |
| `budget-phase2-constants-extraction.md` | Active, **not indexed** | Same as above | Same as above | No. | Yes — same consolidation target as above (migration plan #4). |
| `budget-phase3-service-extraction.md` | Active, **not indexed** | Same as above | Same as above | No. | Yes — same consolidation target as above (migration plan #4). |
| `money-distribution-domain.md` | Active, **not indexed** | Yes — actively cited as source evidence by ADR-0004 | No | **Yes** — reads as durable domain/architecture knowledge about how money distribution ownership works, not a transient implementation note. | **Yes, but blocked** on ADR-0004's resolution before migrating into `docs/architecture/` (migration plan #2). |
| `money-location-engine.md` | Active, **not indexed** | Yes — actively cited as source evidence by ADR-0004 | No | **Yes** — same reasoning as above, describes the other side of the same architectural question. | **Yes, but blocked** on ADR-0004's resolution before migrating into `docs/architecture/` (migration plan #1). |

**No migration was performed.** This table is classification only, per Task 8 instructions.

## 5. Recommended migrations (full detail in `.agents/DOCUMENTATION_MIGRATION_PLAN.md`)

Summary — see the migration plan for Source/Destination/Section/Reason/Risk/Dependencies/Priority on each:
1–2. `.agents/memory/money-location-engine.md` and `money-distribution-domain.md` → candidate Domain Bible content, **blocked on ADR-0004**.
3. Domain Bible chapter 04 gap-fill — depends on #1–#2 or fresh authoring.
4. Three `budget-phase*-extraction.md` files → consolidate into `feature-refactors/refactor-budget-feature.md`.
5. `docs/project/Bug Backlog.md` → reconcile then archive in favor of `Bug_Backlog.md`.
6–8. Byte-identical duplicate pairs → keep canonical copy, archive redundant copy.
9–10. Diverged same-title pairs (`jar_money_location_architecture.md`, `text-parsing-business-logic-inventory.md`) → merge, don't blindly delete.
11. Root `README.md` → archive as historical, replace with accurate Mezanya content (separate content task).

## 6. Documentation debt summary

- **8 exact-duplicate files** across `docs/architecture/` (root vs. `legacy/`, root vs. `feature-refactors/`).
- **3 same-title/diverged-content duplicate pairs** (including `Bug Backlog.md` vs `Bug_Backlog.md`), higher-risk than exact duplicates because an agent citing "the" file by name may get either version.
- **5 empty Domain Bible chapters** out of 9 total chapter files — the canonical source of truth is roughly half unwritten.
- **2 empty project-tracking placeholders** (`Technical Debt.md`, `Reconstruction Progress.md`).
- **5 of 7 Agent Memory topic files unindexed** in `MEMORY.md`, reducing discoverability of past decisions; 2 of those 5 contain durable domain knowledge that is misfiled as memory.
- **1 authority conflict resolved** this pass (Domain Bible vs. MAPS); **1 authority-adjacent conflict remains open** and out of documentation-governance scope (Money Location Engine vs. Money Distribution domain, per ADR-0004).
- **1 mislabeled root document** (`README.md` describing a different app).

---

## Status

Documentation governance structure (Phase 1 + Phase 2) established: `.agents/README.md`, `.agents/PROJECT_INDEX.md`, `.agents/DOCUMENTATION_MAP.md`, `.agents/AGENT_WORKFLOW.md`, `.agents/DOCUMENTATION_RULES.md`, `.agents/DOCUMENTATION_MIGRATION_PLAN.md`, and this audit report are in place and cross-referenced.

**No content was rewritten, migrated, moved, or deleted.** No Dart code, Flutter UI, tests, or business logic were touched. The Domain Bible and ADRs were not edited. Per the task's explicit instruction, this stops here and awaits approval before any migration or cleanup is performed.
