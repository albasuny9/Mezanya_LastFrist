# Mezanya — AI Agent Operating Manual

**This file is the mandatory entry point for every AI agent working in this repository.**
Do not start reading random markdown files. Read this file first, then follow the order below.

This is an operating manual, not a project description. For a plain description of the app, see `replit.md` (environment/run instructions) and the Domain Bible (business rules).

---

## 1. What this repository is

Mezanya (الميزانية) is a Flutter personal-finance app (wallets, budget jars, recurring transactions, debts) with a feature-first Clean Architecture and a single centralized `AppCubit` state. It is a live, evolving codebase with a large amount of accumulated documentation from multiple past audits, refactor plans, and investigations — not all of it is current, not all of it agrees, and some of it is empty or duplicated. This documentation governance layer exists to stop that from misleading future agents.

## 2. How AI agents are expected to work

1. Read this file (`.agents/README.md`) first, every session.
2. Read `.agents/PROJECT_INDEX.md` to find the right document for the task.
3. Read the Domain Bible chapters relevant to the task before touching business logic.
4. Read related ADRs (`docs/architecture/adr/`) before making an architectural decision.
5. Inspect the actual source code — documentation describes intent, code is ground truth for current behavior. Where they disagree, treat this as an open discrepancy to report, not something to silently resolve.
6. Read implementation-only docs (`docs/architecture/maps/`, `feature-refactors/`, `.agents/memory/`) only if the task requires that specific implementation context.
7. Only then begin implementation, following `.agents/AGENT_WORKFLOW.md` exactly.

Also check `replit.md` → "User preferences" for any standing operating protocol the project owner has set (e.g. investigation-only mode, required pre-reads like `docs/project/Task Plan - Replit.md` and `docs/project/Bug_Backlog.md`). That protocol governs *what kind of work* you're allowed to do; this manual governs *which docs to read and trust* while doing it. If the two ever appear to conflict, `replit.md` user preferences win because they are the project owner's direct, explicit instruction.

## 3. Which documentation must be read first

In this order, always:
1. `.agents/README.md` (this file)
2. `.agents/PROJECT_INDEX.md`
3. `docs/architecture/Mezanya Domain Bible/` (chapters relevant to the task)
4. `docs/architecture/adr/` (decisions relevant to the task)

## 4. Which documentation is authoritative

- **Highest authority — business/domain knowledge:** `docs/architecture/Mezanya Domain Bible/`. This is meant to be the ONLY source of truth for permanent business rules. **Caveat (see audit report):** chapters 04–08 are currently empty files. Until they are filled in, chapters 00–03 and the Reconstruction Master Plan are the only populated canonical content — do not assume missing chapters mean "no rules apply."
- **Second highest — architecture decisions:** `docs/architecture/adr/`. Note most current ADRs are status "Proposed" or "Partially Implemented," not yet approved — treat them as the leading candidate decision, not settled fact, until their status says otherwise.
- **Reference / implementation-only:** `docs/architecture/maps/`, `docs/architecture/feature-refactors/`, root-level `docs/architecture/*.md` audits, `docs/project/`. Useful for implementation context, refactor plans, and historical audits. Never treat these as overriding the Domain Bible or an ADR.
  - **Known conflict:** `docs/architecture/maps/00-...-Volume-1.md` labels itself "Authoritative Source of Truth," which directly contradicts `docs/architecture/README.md`'s own stated hierarchy (Domain Bible > maps > feature-refactors > project > legacy). Treat the Domain Bible as authoritative until this is explicitly resolved. See `.agents/DOCUMENTATION_MAP.md`.
- **Lowest authority — temporary implementation knowledge:** `.agents/memory/`. Useful for not repeating past mistakes on a specific implementation detail. Never a source of business or architectural truth — if a memory file contains a durable domain rule, that is a bug in where it was filed (see `.agents/DOCUMENTATION_RULES.md`), not a reason to treat memory as canonical.

## 5. Which documentation is historical

`docs/architecture/legacy/` (explicitly historical per its own README), plus several documents identified as stale/duplicated in `DOCUMENTATION_AUDIT_REPORT.md` — notably the root `README.md` (describes a "Korassa" app, not Mezanya) and `FLUTTER_AI_HANDOFF_AR.md` (pre-implementation greenfield handoff brief). Historical docs may still contain useful context but must never be treated as current truth without checking against the Domain Bible and the actual code.

## 6. Which documentation is implementation-only

`docs/architecture/maps/`, `docs/architecture/feature-refactors/` (and their exact duplicates directly under `docs/architecture/`), `docs/architecture/REFACTOR_STATUS.md`, `docs/architecture/*-audit.md`, `docs/architecture/unified-recurring-engine-review.md`, `docs/project/investigations/`, and `.agents/memory/*.md`. These explain *how* to implement or *what was found* during an investigation — they are not sources of permanent business truth.

## 7. What MUST NEVER be done

- Never treat any document other than the Domain Bible as the source of permanent business knowledge.
- Never skip the read order in Section 3 / `.agents/AGENT_WORKFLOW.md`.
- Never create a new document to record a decision or rule that belongs in an existing canonical document (Domain Bible for business rules, an ADR for architecture decisions) — update the existing one instead (subject to the project's current "no edits without instruction" protocol in `replit.md`, if active).
- Never move implementation details into the Domain Bible, or business rules into `.agents/memory/`.
- Never assume an empty or stub file (e.g. Domain Bible chapters 04–08, `docs/project/Technical Debt.md`, `docs/project/Reconstruction Progress.md`) means "nothing to know" — flag it as a gap instead of inventing content.
- Never resolve a documentation conflict silently. Report it (see `.agents/DOCUMENTATION_MAP.md`) and let the project owner decide.
