# Mezanya — Project Documentation Index

Navigation map of every documentation location in this repository. Read `.agents/README.md` first. This file tells you *where* to go for a given need; `.agents/DOCUMENTATION_MAP.md` tells you *how the entries relate* (authority, conflicts, duplicates); `.agents/DOCUMENTATION_MIGRATION_PLAN.md` tells you what a future cleanup would do.

Every entry below states: Purpose, Authority, Owner, Read When, Dependencies, Related Documents. Where a value is not knowable from the repository as it stands, it is marked `Unknown` rather than guessed.

---

## Domain Bible
**Location:** `docs/architecture/Mezanya Domain Bible/`
**Purpose:** Permanent business rules — the ubiquitous language of the domain (wallets, jars, financial cycle, transfers, allocation, read models, persistence).
**Authority:** Sole permanent source of truth for business rules (see `.agents/DOCUMENTATION_MAP.md` §Authority Resolution).
**Owner:** Project owner (Mohammed), by direct authorship/review.
**Read When:** Always, before any business-logic work (Workflow Step 4).
**Dependencies:** None — this is the root of the documentation tree.
**Related Documents:** ADRs (`docs/architecture/adr/`) may propose changes affecting Bible content; `Reconstruction Master Plan.md` (same folder) is the active plan to complete/stabilize it.
**Permanent or temporary:** Permanent. **Gap:** chapters `04 - Financial Engine`, `05 - Allocation`, `06 - Read Models`, `07 - Persistence`, `08 - Development Constitution` are currently empty files — treat as missing, not as "no rules."
**Files:** `00 - Introduction.md`, `01 - Domain Fundamentals.md`, `02 - Financial Cycle .md`, `03 - Transfers.md`, `04–08` (empty), `Reconstruction Master Plan.md`.

---

## ADR (Architecture Decision Records)
**Location:** `docs/architecture/adr/`
**Purpose:** Architecture decisions, each built on direct code audit with a referenced commit.
**Authority:** Second only to the Domain Bible; binding once a decision's status is accepted, advisory while Proposed.
**Owner:** Project owner, decisions raised via audit-driven agent work.
**Read When:** After the Domain Bible, whenever the task touches transaction references, financial-calculation ownership, backup/versioning, or money-distribution ownership (Workflow Step 5).
**Dependencies:** `docs/architecture/maps/financial-calculation-map.md`, `docs/architecture/maps/text-parsing-business-logic-inventory.md`, and `.agents/memory/money-location-engine.md` / `money-distribution-domain.md` are cited as source evidence by these ADRs.
**Related Documents:** `docs/architecture/REFACTOR_STATUS.md` (referenced by the ADR index as related source material).
**Permanent or temporary:** Permanent once accepted; currently all four ADRs are Proposed / Partially Implemented / undecided — check the status line at the top of each before treating it as settled.
**Files:** `README.md` (index), `0001-generic-transaction-references.md`, `0002-single-source-of-truth-financial-calculations.md`, `0003-backup-versioning-overwrite-protection.md`, `0004-money-distribution-ownership.md`.

---

## Architecture Docs (Reference / Implementation)
**Location:** `docs/architecture/` (root-level files) and `docs/architecture/maps/`
**Purpose:** Technical audits, architecture maps, and implementation references — how the system works today, where it's inconsistent, and what a refactor should look like.
**Authority:** Reference only — explicitly superseded by the Domain Bible where content overlaps (see `.agents/DOCUMENTATION_MAP.md` §Authority Resolution). `maps/` Volume 1 self-labels "Authoritative Source of Truth"; that self-claim is superseded, not honored.
**Owner:** Investigation/audit agents, reviewed by project owner.
**Read When:** When implementing or auditing a specific area (financial calculations, money distribution, recurring engine, text-parsing business logic) (Workflow Step 7).
**Dependencies:** Assumes the Domain Bible and ADRs as the ground truth they audit against; several files here directly informed ADR-0001 through ADR-0004.
**Related Documents:** `docs/architecture/feature-refactors/` (structural refactor plans derived from the Strict Architectural Refactor Specification housed here); `docs/architecture/legacy/` (superseded prior versions of some of these files).
**Permanent or temporary:** Reference material, kept indefinitely, but describes a point-in-time audit — verify against current code before trusting specifics.
**Files:** `README.md` (index/hierarchy statement), `financial-domain-model-audit.md`, `jar_money_location_architecture.md`, `money_location_engine_v2.md`, `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md`, `REFACTOR_STATUS.md`, `text-parsing-business-logic-inventory.md`, `unified-recurring-engine-review.md`, plus `refactor-*.md` (6 files — exact duplicates of `feature-refactors/`, see audit report); `maps/00-17` (MAPS Volumes 1–18), `maps/financial-calculation-map.md`, `maps/text-parsing-business-logic-inventory.md`.

---

## Feature Refactor Plans
**Location:** `docs/architecture/feature-refactors/`
**Purpose:** Per-feature structural refactor plans (budget, home, notifications, settings/AppCubit, transactions, wallets) under the Strict Architectural Refactor Specification. Zero-behavior-change decomposition plans, not business rules.
**Authority:** Implementation reference only.
**Owner:** Refactor-planning agents, reviewed by project owner.
**Read When:** When implementing or continuing a specific feature's structural refactor (Workflow Step 7). Cross-check against `docs/architecture/REFACTOR_STATUS.md` for actual progress.
**Dependencies:** `docs/architecture/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` (the governing spec these plans implement).
**Related Documents:** `.agents/memory/budget-phase1-widget-extraction.md`, `budget-phase2-constants-extraction.md`, `budget-phase3-service-extraction.md` (implementation notes from executing `refactor-budget-feature.md`).
**Permanent or temporary:** Temporary — each plan is superseded once its refactor is completed and should eventually be retired or marked Historical.
**Files:** `refactor-budget-feature.md`, `refactor-home-feature.md`, `refactor-notifications-feature.md`, `refactor-settings-appcubit-feature.md`, `refactor-transactions-feature.md`, `refactor-wallets-feature.md`.

---

## Legacy Architecture Docs
**Location:** `docs/architecture/legacy/`
**Purpose:** Historical documents kept only for reference; superseded by newer audits or by the Domain Bible.
**Authority:** Historical — never treat as current truth.
**Owner:** Unknown (no author/reviewer attribution recorded in the files).
**Read When:** Only if explicitly researching the history of a decision.
**Dependencies:** None inbound; these are terminal/archival nodes.
**Related Documents:** Root-level `docs/architecture/*.md` files of the same name (`money_location_engine_v2.md` and `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` are byte-identical duplicates of these; `jar_money_location_architecture.md` has diverged content — see audit report).
**Permanent or temporary:** Permanent as historical record, but content is not to be trusted as current.
**Files:** `jar_money_location_architecture.md` (differs from the current root-level file of the same name — see audit report), `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` (exact duplicate of the root-level file), `money_location_engine_v2.md` (exact duplicate of the root-level file).

---

## Project Tracking Docs
**Location:** `docs/project/`
**Purpose:** Active, working project-management documents — bugs, decisions about scope/priority, investigations, task planning, technical debt.
**Authority:** Reference for project state; not a source of business/architecture truth (that stays in the Domain Bible / ADRs even when a decision is *logged* here).
**Owner:** Project owner + investigation agents.
**Read When:** Before starting any bug investigation or prioritization task (Workflow Step 3 for `Task Plan - Replit.md` specifically); **mandatory pre-read per `replit.md`:** `Task Plan - Replit.md` and `Bug_Backlog.md` before every task under the current operating protocol.
**Dependencies:** `Task Plan - Replit.md` depends on `Bug_Backlog.md` for its prioritized queue; `investigations/*.md` depend on whichever Bug Backlog entry triggered them.
**Related Documents:** `docs/architecture/` for any architecture context an investigation needed; `replit.md` (defines when these must be read).
**Permanent or temporary:** Mixed — `Bug_Backlog.md`, `Task Plan - Replit.md`, `Decisions Log.md` are living/permanent; `investigations/*.md` are temporary snapshots; `Reconstruction Progress.md` and `Technical Debt.md` are currently empty stubs.
**Files:** `Bug_Backlog.md` (current/active — see audit report re: duplicate `Bug Backlog.md`), `Bug Backlog.md` (stale duplicate, needs review), `Decisions Log.md`, `decisions/Transaction Editing Architecture.md`, `investigations/BUG-001 Wallet Transfer Investigation.md`, `investigations/BUG-002 Jar Category Scope Investigation.md`, `investigations/BUG-004 Auto Cloud Backup Investigation.md`, `investigations/NBC-001 Category Breakdown General-Bucket-Only Lookup.md`, `Reconstruction Progress.md` (empty), `Task Plan - Replit.md`, `Technical Debt.md` (empty).

---

## Agent Memory
**Location:** `.agents/memory/`
**Purpose:** Temporary, cross-session implementation knowledge for AI agents — non-obvious quirks, past bug fixes, extraction decisions. Not business knowledge.
**Authority:** Lowest of all documentation in this repository.
**Owner:** AI agents (self-maintained), per the auto-memory system.
**Read When:** Only when working on the specific implementation area a memory file names (Workflow Step 8 — "only if required").
**Dependencies:** None formally, but ADR-0004 cites `money-location-engine.md` and `money-distribution-domain.md` as source evidence, creating an informal dependency from architecture docs back onto memory — flagged as a filing concern in the audit report.
**Related Documents:** See `.agents/DOCUMENTATION_MIGRATION_PLAN.md` for proposed (not yet executed) migrations of specific memory files into `docs/architecture/`.
**Permanent or temporary:** Temporary by design, though in practice some entries document durable domain concepts that arguably belong in the Domain Bible/architecture docs instead (see audit report §Agent Memory Review).
**Files:** `MEMORY.md` (index — currently indexes only 2 of the 7 topic files present, see audit report), `tp-reverse-bc-fix.md`, `gen-l10n-replit-quirk.md`, `budget-phase1-widget-extraction.md`, `budget-phase2-constants-extraction.md`, `budget-phase3-service-extraction.md`, `money-distribution-domain.md`, `money-location-engine.md`.

---

## Root-Level Documents (uncategorized, pre-governance)
**Location:** repository root
**Purpose:** Mixed — environment/run instructions, an early project overview, a greenfield rebuild brief, and a standalone audit.
**Authority:** `replit.md` is Canonical for environment/workflow/run instructions and currently holds the active agent operating protocol (see its "User preferences") — always in effect regardless of this index. The others are not authoritative for business or architecture truth.
**Owner:** Mixed/Unknown origins — no consistent attribution across these files.
**Read When:** `replit.md` always (Replit loads it automatically). The rest only if specifically relevant.
**Dependencies:** `replit.md`'s "User preferences" section references `docs/project/Task Plan - Replit.md` and `docs/project/Bug_Backlog.md` directly.
**Related Documents:** `project_documentation.md` overlaps with `docs/architecture/Mezanya Domain Bible/` and `docs/architecture/maps/` content; `TRANSACTION_ARCHITECTURE_AUDIT.md` overlaps with `docs/architecture/financial-domain-model-audit.md` and `docs/architecture/unified-recurring-engine-review.md` (not cross-linked; overlap not yet verified line-by-line — flagged as Unknown extent of duplication).
**Permanent or temporary:** `replit.md` permanent/living. `README.md` — Historical (describes a different app name, "Korassa"; stale). `project_documentation.md` — Reference (overlaps with Domain Bible/MAPS; not authoritative). `FLUTTER_AI_HANDOFF_AR.md` — Historical (greenfield handoff brief). `TRANSACTION_ARCHITECTURE_AUDIT.md` — Reference (standalone investigation, not integrated into `docs/`).
**Files:** `replit.md`, `README.md`, `project_documentation.md`, `FLUTTER_AI_HANDOFF_AR.md`, `TRANSACTION_ARCHITECTURE_AUDIT.md`.
