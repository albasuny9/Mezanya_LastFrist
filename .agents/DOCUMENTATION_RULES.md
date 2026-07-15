# Mezanya — Permanent Documentation Policy

These rules govern how documentation is created and maintained in this repository. They apply to every AI agent and are meant to survive across sessions.

## Core rules

1. **Business knowledge belongs ONLY in the Domain Bible.** (`docs/architecture/Mezanya Domain Bible/`). If a piece of information describes a permanent rule about how the business/domain works (e.g. what a "jar" means, how a financial cycle boundary is computed), it must live there — not in an audit doc, not in memory, not in a refactor plan.

2. **ADRs store architectural decisions only.** (`docs/architecture/adr/`). An ADR records a decision about *how the system is structured* (e.g. what field pattern to use for cross-entity references) — not a business rule, and not an implementation log of what was done.

3. **Agent Memory stores implementation notes only.** (`.agents/memory/`). Non-obvious code quirks, environment gotchas, and decisions a future agent should stay consistent with for a *specific implementation area*. Never a home for business rules or architecture decisions — if a memory file is doing that job, it should be flagged as a migration candidate (see `.agents/DOCUMENTATION_MIGRATION_PLAN.md`), not treated as settled.

4. **Architecture docs explain implementation.** (`docs/architecture/maps/`, `docs/architecture/feature-refactors/`, root-level architecture audits). These describe how the current code works, what's inconsistent, and how to refactor it. They are reference material — never a substitute for the Domain Bible or an ADR.

5. **Never duplicate permanent knowledge.** If the same business rule, decision, or fact needs to be visible in two places, one of them should be a pointer/reference to the other, not a second copy that can drift. (This repository currently has several drifted duplicates — see the audit report. They are not to be merged or deleted as part of this governance pass, only flagged.)

6. **Never create a new document when an existing canonical document should be updated.** If a task surfaces new business knowledge, the answer is to propose an update to the relevant Domain Bible chapter (subject to the project's current edit-authorization protocol) — not to write a new standalone `.md` file that will need to be reconciled later.

7. **Never move implementation details into the Domain Bible.** The Domain Bible describes business meaning independent of how it's coded. Function names, file paths, data structures, and refactor status belong in architecture/implementation docs or memory, not in the Bible.

8. **Every status label must be one of exactly five values:** `Canonical`, `Reference`, `Implementation`, `Historical`, `Temporary`. Do not invent new status labels when classifying or referencing a document — use `.agents/DOCUMENTATION_MAP.md` and `.agents/PROJECT_INDEX.md` as the classification precedent. (`Canonical` is reserved for the Domain Bible and `replit.md`; all other documentation must resolve to one of the remaining four — see `.agents/DOCUMENTATION_MAP.md` §Authority Resolution.)

9. **A documentation conflict is reported, not resolved silently.** If an agent finds two documents disagreeing that are not already listed in `.agents/DOCUMENTATION_MAP.md` → "Known conflicts," it must record the new conflict (in the audit report, or a new investigation doc per the active operating protocol) rather than pick one and proceed as if there were no conflict.

10. **Empty files are gaps, not answers.** A `0`-line file (e.g. Domain Bible chapters 04–08) means "not yet written," never "nothing applies here."

## Knowledge categories

Every piece of documentation content falls into exactly one of the four categories below. When creating or updating documentation, identify which category the content is before deciding where it goes.

### Permanent Knowledge
- **Where it belongs:** `docs/architecture/Mezanya Domain Bible/` only.
- **What qualifies:** Business rules and domain meaning that hold regardless of implementation — what a jar is, how a financial cycle is bounded, what "outside budget" means. If it would still be true after a full rewrite of the app in a different framework, it's Permanent Knowledge.
- **Who owns it:** Project owner (Mohammed). Authorship/approval required — agents propose, they do not unilaterally finalize Bible content.
- **When it should be updated:** Only when a business rule genuinely changes or is clarified, and only with explicit authorization under the project's active operating protocol. Never updated opportunistically as a side effect of an unrelated task.

### Implementation Knowledge
- **Where it belongs:** `docs/architecture/maps/`, `docs/architecture/feature-refactors/`, root-level `docs/architecture/*.md` audits, ADRs (`docs/architecture/adr/`) for the decision layer specifically, and `.agents/memory/` for the narrowest/most transient implementation quirks.
- **What qualifies:** How the current code is structured, what's inconsistent, what a refactor plan looks like, what non-obvious gotcha a past agent hit. If it would change with a rewrite, it's Implementation Knowledge, not Permanent Knowledge.
- **Who owns it:** Whichever agent (human or AI) performed the audit, refactor plan, or fix — reviewed by the project owner before being treated as settled.
- **When it should be updated:** Whenever the implementation it describes changes materially (a refactor completes, a decision's status moves from Proposed to Accepted, a quirk is fixed and no longer applies). Stale implementation docs should be flagged Historical rather than silently left as if current.

### Temporary Knowledge
- **Where it belongs:** `docs/project/` — bug backlog, decisions log, investigations, task plan, technical debt.
- **What qualifies:** Working state of the project right now — open bugs, an in-progress investigation, current task priorities. Not meant to outlive the situation it describes.
- **Who owns it:** Project owner for priority/decisions; investigation agents for the investigation write-ups themselves.
- **When it should be updated:** Continuously, as bugs are found/fixed and priorities shift. When a Temporary document's subject is resolved (bug fixed, investigation concluded), it should be marked resolved/closed rather than deleted, so the history remains auditable.

### Historical Knowledge
- **Where it belongs:** `docs/architecture/legacy/`, or any document explicitly flagged Historical in `.agents/DOCUMENTATION_MAP.md` (e.g. the root `README.md`, `FLUTTER_AI_HANDOFF_AR.md`, `docs/project/Bug Backlog.md`).
- **What qualifies:** Anything superseded, stale, or describing an app/architecture state that no longer matches reality, but worth keeping for context on how a decision or design evolved.
- **Who owns it:** No active owner — historical documents are retained, not maintained.
- **When it should be updated:** Never rewritten to match current reality (that would destroy its historical value). If a Historical document is causing confusion, the fix is a clearer flag/pointer to the current replacement (in `.agents/DOCUMENTATION_MAP.md`), not an edit to the historical content itself.
