# Mezanya — Mandatory Agent Workflow

Every AI agent working on this repository must follow this order. No step may be skipped.

```
STEP 1  Read .agents/README.md
          ↓
STEP 2  Read .agents/PROJECT_INDEX.md
          ↓
STEP 3  Read the Domain Bible chapters relevant to the task
        (docs/architecture/Mezanya Domain Bible/)
          ↓
STEP 4  Read related ADRs
        (docs/architecture/adr/)
          ↓
STEP 5  Inspect source code
          ↓
STEP 6  Read implementation documents only if needed
        (docs/architecture/maps/, feature-refactors/, .agents/memory/)
          ↓
STEP 7  Begin implementation
```

## Notes on each step

- **Step 1–2** orient the agent: what exists, where it lives, what it's worth trusting.
- **Step 3** establishes ground truth for business rules before any logic is touched. If the relevant Domain Bible chapter is one of the currently-empty ones (04–08), that is a documented gap (see `.agents/PROJECT_INDEX.md`) — do not invent content to fill it; proceed carefully using source code plus explicit uncertainty, and flag the gap.
- **Step 4** checks whether an architectural decision already exists (even if only Proposed) for the area being touched, so the agent doesn't quietly re-decide something already under review.
- **Step 5** is mandatory even when documentation seems to answer everything — code is ground truth for current behavior, documentation is not guaranteed current.
- **Step 6** is opt-in and scoped: only read the specific implementation doc or memory file relevant to the task at hand, not the whole tree.
- **Step 7** — before implementing, also check whether the project currently has an active operating-protocol restriction in `replit.md` → "User preferences" (e.g. investigation-only mode). That protocol can restrict or redirect Step 7 entirely (e.g. "produce an investigation document instead of a code change"). This workflow defines *documentation reading order*; `replit.md`'s user preferences define *what you're allowed to do* with what you learn. Follow both — if you are not authorized to implement, stop after Step 6 and report findings using whatever format the active protocol specifies (e.g. `docs/project/investigations/`).

No agent should ever skip these steps, reorder them, or substitute a document read at one step for the document required at another (e.g. reading `.agents/memory/` instead of the Domain Bible at Step 3 is not a valid substitution, even if the memory file happens to mention the same topic).
