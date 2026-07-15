# Mezanya — Permanent Documentation Policy

These rules govern how documentation is created and maintained in this repository. They apply to every AI agent and are meant to survive across sessions.

1. **Business knowledge belongs ONLY in the Domain Bible.** (`docs/architecture/Mezanya Domain Bible/`). If a piece of information describes a permanent rule about how the business/domain works (e.g. what a "jar" means, how a financial cycle boundary is computed), it must live there — not in an audit doc, not in memory, not in a refactor plan.

2. **ADRs store architectural decisions only.** (`docs/architecture/adr/`). An ADR records a decision about *how the system is structured* (e.g. what field pattern to use for cross-entity references) — not a business rule, and not an implementation log of what was done.

3. **Agent Memory stores implementation notes only.** (`.agents/memory/`). Non-obvious code quirks, environment gotchas, and decisions a future agent should stay consistent with for a *specific implementation area*. Never a home for business rules or architecture decisions — if a memory file is doing that job, it should be flagged as a migration candidate (see `DOCUMENTATION_AUDIT_REPORT.md`), not treated as settled.

4. **Architecture docs explain implementation.** (`docs/architecture/maps/`, `docs/architecture/feature-refactors/`, root-level architecture audits). These describe how the current code works, what's inconsistent, and how to refactor it. They are reference material — never a substitute for the Domain Bible or an ADR.

5. **Never duplicate permanent knowledge.** If the same business rule, decision, or fact needs to be visible in two places, one of them should be a pointer/reference to the other, not a second copy that can drift. (This repository currently has several drifted duplicates — see the audit report. They are not to be merged or deleted as part of this governance pass, only flagged.)

6. **Never create a new document when an existing canonical document should be updated.** If a task surfaces new business knowledge, the answer is to propose an update to the relevant Domain Bible chapter (subject to the project's current edit-authorization protocol) — not to write a new standalone `.md` file that will need to be reconciled later.

7. **Never move implementation details into the Domain Bible.** The Domain Bible describes business meaning independent of how it's coded. Function names, file paths, data structures, and refactor status belong in architecture/implementation docs or memory, not in the Bible.

8. **Every status label must be one of exactly five values:** `Canonical`, `Reference`, `Implementation`, `Historical`, `Temporary`. Do not invent new status labels when classifying or referencing a document — use `DOCUMENTATION_MAP.md` and `PROJECT_INDEX.md` as the classification precedent.

9. **A documentation conflict is reported, not resolved silently.** If an agent finds two documents disagreeing (see `DOCUMENTATION_MAP.md` → "Known authority conflicts"), it must record the conflict (in the audit report, or a new investigation doc per the active operating protocol) rather than pick one and proceed as if there were no conflict.

10. **Empty files are gaps, not answers.** A `0`-line file (e.g. Domain Bible chapters 04–08) means "not yet written," never "nothing applies here."
