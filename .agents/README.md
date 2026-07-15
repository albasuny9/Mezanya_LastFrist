# Mezanya — AI Agent Operating Manual

**This file is the mandatory entry point for every AI agent working in this repository.**
Do not start reading random markdown files. Read this file first, then follow `.agents/AGENT_WORKFLOW.md` exactly.

This is an operating manual, not a project description. For a plain description of the app, see `replit.md` (environment/run instructions) and the Domain Bible (business rules).

---

## Golden Rules

Short, strict, non-negotiable. If any instruction elsewhere in this repository conflicts with a Golden Rule, the Golden Rule wins.

- **The Domain Bible is the ONLY source of truth for business rules.** No other document — not MAPS, not an audit, not a memory file — may be cited as settling a business rule. See `.agents/DOCUMENTATION_MAP.md`.
- **Never duplicate business logic.** If it already exists in code or in the Domain Bible, reuse or reference it — do not re-derive or re-describe it in a new place.
- **Never implement a second pipeline.** If a flow already exists (transaction processing, budget calculation, recurring generation, etc.), extend it. Do not build a parallel path that produces the same outcome a different way.
- **Never redesign architecture without approval.** Architecture decisions belong in ADRs and require explicit sign-off before being treated as settled — see `docs/architecture/adr/`.
- **Always search existing implementations before creating new ones.** Assume the capability you need may already exist under a different name; verify against source code before writing new code or new documentation.
- **One Domain.** A single ubiquitous language, defined once, in the Domain Bible.
- **One Pipeline.** A single execution path per business flow.
- **One Source of Truth.** Per fact, exactly one canonical document or code location — everything else is reference, implementation detail, or history.

---

## 1. What this repository is

Mezanya (الميزانية) is a Flutter personal-finance app (wallets, budget jars, recurring transactions, debts) with a feature-first Clean Architecture and a single centralized `AppCubit` state. It is a live, evolving codebase with a large amount of accumulated documentation from multiple past audits, refactor plans, and investigations — not all of it is current, not all of it agrees, and some of it is empty or duplicated. This documentation governance layer exists to stop that from misleading future agents.

## 2. How AI agents are expected to work

Follow `.agents/AGENT_WORKFLOW.md` step by step, every session, without skipping or reordering. In summary: read this file, read `.agents/PROJECT_INDEX.md`, read the current project task, read the Domain Bible, read related ADRs, inspect the actual source code, read implementation documentation only if the task needs it, consult Agent Memory only if required, then implement.

Also check `replit.md` → "User preferences" for any standing operating protocol the project owner has set (e.g. investigation-only mode, required pre-reads like `docs/project/Task Plan - Replit.md` and `docs/project/Bug_Backlog.md`). That protocol governs *what kind of work* you're allowed to do; this manual governs *which docs to read and trust* while doing it. If the two ever appear to conflict, `replit.md` user preferences win because they are the project owner's direct, explicit instruction.

## 3. Which documentation must be read first

Per `.agents/AGENT_WORKFLOW.md`, in order:
1. `.agents/README.md` (this file)
2. `.agents/PROJECT_INDEX.md`
3. The current project task (task plan / issue / instruction you were given)
4. `docs/architecture/Mezanya Domain Bible/` (chapters relevant to the task)
5. `docs/architecture/adr/` (decisions relevant to the task)

## 4. Which documentation is authoritative

- **Sole permanent source of truth for business rules:** `docs/architecture/Mezanya Domain Bible/`. Nothing else may be cited as settling a business rule, even temporarily. **Caveat (see audit report):** chapters 04–08 are currently empty files. Until they are filled in, chapters 00–03 and the Reconstruction Master Plan are the only populated canonical content — do not assume missing chapters mean "no rules apply"; treat them as an open gap.
- **Architecture decisions:** `docs/architecture/adr/`. Second in authority, but note most current ADRs are status "Proposed" or "Partially Implemented," not yet approved — treat them as the leading candidate decision, not settled fact, until their status says otherwise.
- **Reference / implementation-only:** `docs/architecture/maps/`, `docs/architecture/feature-refactors/`, root-level `docs/architecture/*.md` audits, `docs/project/`. Useful for implementation context, refactor plans, and historical audits. Never treat these as overriding the Domain Bible or an ADR.
  - **Resolved:** `docs/architecture/maps/00-...-Volume-1.md` labels itself "Authoritative Source of Truth." This claim is explicitly **superseded by the Domain Bible** — see `.agents/DOCUMENTATION_MAP.md` §Authority Resolution. MAPS is Reference material only.
- **Lowest authority — temporary implementation knowledge:** `.agents/memory/`. Useful for not repeating past mistakes on a specific implementation detail. Never a source of business or architectural truth — if a memory file contains a durable domain rule, that is a bug in where it was filed (see `.agents/DOCUMENTATION_RULES.md`), not a reason to treat memory as canonical.

## 5. Which documentation is historical

`docs/architecture/legacy/` (explicitly historical per its own README), plus several documents identified as stale/duplicated in `DOCUMENTATION_AUDIT_REPORT.md` — notably the root `README.md` (describes a "Korassa" app, not Mezanya) and `FLUTTER_AI_HANDOFF_AR.md` (pre-implementation greenfield handoff brief). Historical docs may still contain useful context but must never be treated as current truth without checking against the Domain Bible and the actual code.

## 6. Which documentation is implementation-only

`docs/architecture/maps/`, `docs/architecture/feature-refactors/` (and their exact duplicates directly under `docs/architecture/`), `docs/architecture/REFACTOR_STATUS.md`, `docs/architecture/*-audit.md`, `docs/architecture/unified-recurring-engine-review.md`, `docs/project/investigations/`, and `.agents/memory/*.md`. These explain *how* to implement or *what was found* during an investigation — they are not sources of permanent business truth.

## 7. What MUST NEVER be done

- Never treat any document other than the Domain Bible as the source of permanent business knowledge.
- Never skip the read order in `.agents/AGENT_WORKFLOW.md`.
- Never create a new document to record a decision or rule that belongs in an existing canonical document (Domain Bible for business rules, an ADR for architecture decisions) — update the existing one instead (subject to the project's current "no edits without instruction" protocol in `replit.md`, if active).
- Never move implementation details into the Domain Bible, or business rules into `.agents/memory/`.
- Never assume an empty or stub file (e.g. Domain Bible chapters 04–08, `docs/project/Technical Debt.md`, `docs/project/Reconstruction Progress.md`) means "nothing to know" — flag it as a gap instead of inventing content.
- Never resolve a documentation conflict silently. Report it (see `.agents/DOCUMENTATION_MAP.md`) and let the project owner decide.
- Never migrate or delete documentation without explicit approval — see `.agents/DOCUMENTATION_MIGRATION_PLAN.md` for the roadmap of what a future, approved migration would look like. That plan is a proposal, not a license to act.
