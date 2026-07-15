# Mezanya — Mandatory Agent Workflow

Every AI agent working on this repository must follow this order. No step may be skipped or reordered.

```
STEP 1  Read .agents/README.md
          ↓
STEP 2  Read .agents/PROJECT_INDEX.md
          ↓
STEP 3  Read the current project task
        (the task plan / issue / instruction you were actually given —
         e.g. docs/project/Task Plan - Replit.md when working under that protocol)
          ↓
STEP 4  Read the Domain Bible chapters relevant to the task
        (docs/architecture/Mezanya Domain Bible/)
          ↓
STEP 5  Read related ADRs
        (docs/architecture/adr/)
          ↓
STEP 6  Inspect current source code
          ↓
STEP 7  Read Implementation Documentation
        (docs/architecture/maps/, feature-refactors/, root-level architecture audits,
         docs/project/investigations/)
          ↓
STEP 8  Read Agent Memory — only if required
        (.agents/memory/)
          ↓
STEP 9  Begin implementation
```

No agent should ever skip or reorder these steps.

## Notes on each step

- **Step 1–2** orient the agent: what exists, where it lives, what it's worth trusting.
- **Step 3** grounds the work in what was actually asked — the specific task, bug, or instruction — before any documentation is treated as relevant. This step also surfaces any standing operating-protocol restriction (e.g. `replit.md` → "User preferences" investigation-only mode) that governs what Step 9 is allowed to look like.
- **Step 4** establishes ground truth for business rules before any logic is touched. If the relevant Domain Bible chapter is one of the currently-empty ones (04–08), that is a documented gap (see `.agents/PROJECT_INDEX.md`) — do not invent content to fill it; proceed carefully using source code plus explicit uncertainty, and flag the gap.
- **Step 5** checks whether an architectural decision already exists (even if only Proposed) for the area being touched, so the agent doesn't quietly re-decide something already under review.
- **Step 6** is mandatory even when documentation seems to answer everything — code is ground truth for current behavior, documentation is not guaranteed current.
- **Step 7** is opt-in in depth but not in principle: read only the specific implementation doc relevant to the task, but check whether one exists before assuming there's nothing to reference.
- **Step 8** is the narrowest and lowest-priority read: only consult Agent Memory when the task touches a specific implementation area a memory file already documents. Never substitute Agent Memory for Steps 4–5 — a memory file mentioning a domain concept is not the same as the Domain Bible or an ADR settling it.
- **Step 9** — before implementing, also re-check whether the project's active operating protocol (`replit.md` → "User preferences") restricts or redirects implementation entirely (e.g. "produce an investigation document instead of a code change"). This workflow defines *documentation reading order*; `replit.md`'s user preferences define *what you're allowed to do* with what you learn. Follow both — if you are not authorized to implement, stop after Step 8 and report findings using whatever format the active protocol specifies (e.g. `docs/project/investigations/`).

No agent should ever skip these steps, reorder them, or substitute a document read at one step for the document required at another (e.g. reading `.agents/memory/` instead of the Domain Bible at Step 4 is not a valid substitution, even if the memory file happens to mention the same topic).
