# Mezanya — Project Documentation Index

Navigation map of every documentation location in this repository. Read `.agents/README.md` first. This file tells you *where* to go for a given need; `.agents/DOCUMENTATION_MAP.md` tells you *how the entries relate* (authority, conflicts, duplicates).

Authority scale used below: **Highest → Second highest → Reference → Lowest**.

---

## Domain Bible
**Location:** `docs/architecture/Mezanya Domain Bible/`
**Purpose:** Permanent business rules — the ubiquitous language of the domain (wallets, jars, financial cycle, transfers, allocation, read models, persistence).
**Owner:** Project owner (Mohammed), by direct authorship/review.
**Authority:** Highest.
**Read:** Always, before any business-logic work.
**Permanent or temporary:** Permanent. **Gap:** chapters `04 - Financial Engine`, `05 - Allocation`, `06 - Read Models`, `07 - Persistence`, `08 - Development Constitution` are currently empty files — treat as missing, not as "no rules."
**Files:** `00 - Introduction.md`, `01 - Domain Fundamentals.md`, `02 - Financial Cycle .md`, `03 - Transfers.md`, `04–08` (empty), `Reconstruction Master Plan.md`.

---

## ADR (Architecture Decision Records)
**Location:** `docs/architecture/adr/`
**Purpose:** Approved (or proposed) architecture decisions, each built on direct code audit with a referenced commit.
**Owner:** Project owner, decisions raised via audit-driven agent work.
**Authority:** Second highest.
**Read:** After the Domain Bible, whenever the task touches transaction references, financial-calculation ownership, backup/versioning, or money-distribution ownership.
**Permanent or temporary:** Permanent once a decision's status moves from "Proposed" to accepted; currently all four ADRs are Proposed / Partially Implemented / undecided — check the status line at the top of each before treating it as settled.
**Files:** `README.md` (index), `0001-generic-transaction-references.md`, `0002-single-source-of-truth-financial-calculations.md`, `0003-backup-versioning-overwrite-protection.md`, `0004-money-distribution-ownership.md`.

---

## Architecture Docs (Reference / Implementation)
**Location:** `docs/architecture/` (root-level files) and `docs/architecture/maps/`
**Purpose:** Technical audits, architecture maps, and implementation references — how the system works today, where it's inconsistent, and what a refactor should look like.
**Owner:** Investigation/audit agents, reviewed by project owner.
**Authority:** Reference only. `maps/` Volume 1 self-labels "Authoritative Source of Truth," which conflicts with the Domain Bible's higher authority — see `.agents/DOCUMENTATION_MAP.md`.
**Read:** When implementing or auditing a specific area (financial calculations, money distribution, recurring engine, text-parsing business logic).
**Permanent or temporary:** Reference material, kept indefinitely, but describes a point-in-time audit — verify against current code before trusting specifics.
**Files:** `README.md` (index/hierarchy statement), `financial-domain-model-audit.md`, `jar_money_location_architecture.md`, `money_location_engine_v2.md`, `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md`, `REFACTOR_STATUS.md`, `text-parsing-business-logic-inventory.md`, `unified-recurring-engine-review.md`, plus `refactor-*.md` (6 files — exact duplicates of `feature-refactors/`, see audit report); `maps/00-17` (MAPS Volumes 1–18), `maps/financial-calculation-map.md`, `maps/text-parsing-business-logic-inventory.md`.

---

## Feature Refactor Plans
**Location:** `docs/architecture/feature-refactors/`
**Purpose:** Per-feature structural refactor plans (budget, home, notifications, settings/AppCubit, transactions, wallets) under the Strict Architectural Refactor Specification. Zero-behavior-change decomposition plans, not business rules.
**Owner:** Refactor-planning agents, reviewed by project owner.
**Authority:** Implementation reference only.
**Read:** When implementing or continuing a specific feature's structural refactor. Cross-check against `docs/architecture/REFACTOR_STATUS.md` for actual progress.
**Permanent or temporary:** Temporary — each plan is superseded once its refactor is completed and should eventually be retired or marked Historical.
**Files:** `refactor-budget-feature.md`, `refactor-home-feature.md`, `refactor-notifications-feature.md`, `refactor-settings-appcubit-feature.md`, `refactor-transactions-feature.md`, `refactor-wallets-feature.md`.

---

## Legacy Architecture Docs
**Location:** `docs/architecture/legacy/`
**Purpose:** Historical documents kept only for reference; superseded by newer audits or by the Domain Bible.
**Owner:** N/A (retained history).
**Authority:** Historical — never treat as current truth.
**Read:** Only if explicitly researching the history of a decision.
**Permanent or temporary:** Permanent as historical record, but content is not to be trusted as current.
**Files:** `jar_money_location_architecture.md` (differs from the current root-level file of the same name — see audit report), `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` (exact duplicate of the root-level file), `money_location_engine_v2.md` (exact duplicate of the root-level file).

---

## Project Tracking Docs
**Location:** `docs/project/`
**Purpose:** Active, working project-management documents — bugs, decisions about scope/priority, investigations, task planning, technical debt.
**Owner:** Project owner + investigation agents.
**Authority:** Reference for project state; not a source of business/architecture truth (that stays in the Domain Bible / ADRs even when a decision is *logged* here).
**Read:** Before starting any bug investigation or prioritization task; **mandatory pre-read per `replit.md`:** `Task Plan - Replit.md` and `Bug_Backlog.md` before every task under the current operating protocol.
**Permanent or temporary:** Mixed — `Bug_Backlog.md`, `Task Plan - Replit.md`, `Decisions Log.md` are living/permanent; `investigations/*.md` are temporary snapshots; `Reconstruction Progress.md` and `Technical Debt.md` are currently empty stubs.
**Files:** `Bug_Backlog.md` (current/active — see audit report re: duplicate `Bug Backlog.md`), `Bug Backlog.md` (stale duplicate, needs review), `Decisions Log.md`, `decisions/Transaction Editing Architecture.md`, `investigations/BUG-001 Wallet Transfer Investigation.md`, `investigations/BUG-002 Jar Category Scope Investigation.md`, `investigations/BUG-004 Auto Cloud Backup Investigation.md`, `investigations/NBC-001 Category Breakdown General-Bucket-Only Lookup.md`, `Reconstruction Progress.md` (empty), `Task Plan - Replit.md`, `Technical Debt.md` (empty).

---

## Agent Memory
**Location:** `.agents/memory/`
**Purpose:** Temporary, cross-session implementation knowledge for AI agents — non-obvious quirks, past bug fixes, extraction decisions. Not business knowledge.
**Owner:** AI agents (self-maintained), per the auto-memory system.
**Authority:** Lowest.
**Read:** Only when working on the specific implementation area a memory file names.
**Permanent or temporary:** Temporary by design, though in practice some entries document durable domain concepts that arguably belong in the Domain Bible instead (see audit report §Migration Candidates).
**Files:** `MEMORY.md` (index — currently indexes only 2 of the 7 topic files present, see audit report), `tp-reverse-bc-fix.md`, `gen-l10n-replit-quirk.md`, `budget-phase1-widget-extraction.md`, `budget-phase2-constants-extraction.md`, `budget-phase3-service-extraction.md`, `money-distribution-domain.md`, `money-location-engine.md`.

---

## Root-Level Documents (uncategorized, pre-governance)
**Location:** repository root
**Purpose:** Mixed — environment/run instructions, an early project overview, a greenfield rebuild brief, and a standalone audit.
**Owner:** Mixed origins.
**Authority:** `replit.md` is Canonical for environment/workflow/run instructions and currently holds the active agent operating protocol (see its "User preferences" section) — always in effect regardless of this index. The others are not authoritative for business or architecture truth.
**Read:** `replit.md` always (Replit loads it automatically). The rest only if specifically relevant.
**Permanent or temporary:** `replit.md` permanent/living. `README.md` — Historical (describes a different app name, "Korassa"; stale). `project_documentation.md` — Reference (overlaps with Domain Bible/MAPS; not authoritative). `FLUTTER_AI_HANDOFF_AR.md` — Historical (greenfield handoff brief). `TRANSACTION_ARCHITECTURE_AUDIT.md` — Reference (standalone investigation, not integrated into `docs/`).
**Files:** `replit.md`, `README.md`, `project_documentation.md`, `FLUTTER_AI_HANDOFF_AR.md`, `TRANSACTION_ARCHITECTURE_AUDIT.md`.
