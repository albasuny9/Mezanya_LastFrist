# Mezanya — Documentation Authority Map

This document exists to answer one question whenever two documents disagree: **which one wins, and why.** It does not rewrite or migrate anything — see `DOCUMENTATION_AUDIT_REPORT.md` for the full inventory this map is based on.

## Authority order (highest to lowest)

1. **Domain Bible** — `docs/architecture/Mezanya Domain Bible/` — permanent business rules.
2. **ADRs** — `docs/architecture/adr/` — architecture decisions (check status: most are currently Proposed/Partial, not final).
3. **Architecture reference/implementation docs** — `docs/architecture/maps/`, `docs/architecture/feature-refactors/`, root-level `docs/architecture/*.md` audits.
4. **Project tracking docs** — `docs/project/` (bugs, decisions log, investigations, task plan).
5. **Legacy** — `docs/architecture/legacy/` — historical only.
6. **Agent Memory** — `.agents/memory/` — lowest; temporary implementation notes.

This mirrors and extends the hierarchy already declared in `docs/architecture/README.md` ("Domain Bible > maps > feature-refactors > project > legacy"), adding ADRs (between Domain Bible and maps) and Agent Memory (below legacy) since the original hierarchy predates both.

`replit.md` sits outside this ladder: it is Canonical for environment, run instructions, and the currently active agent operating protocol (see its "User preferences"). It governs *permission to act*; this ladder governs *which content to trust*.

## Known authority conflicts (unresolved — do not silently pick a side)

1. **Domain Bible vs. MAPS self-declared authority.** `docs/architecture/README.md` states the Domain Bible is "the primary architectural source of truth." But `docs/architecture/maps/00-Mezanya-Architecture-Product-Specification-Volume-1.md` opens with "**Status:** Authoritative Source of Truth" for itself. These two claims directly conflict. **Resolution used by this governance layer:** Domain Bible wins, because it is explicitly the top of the hierarchy stated in the folder's own index and matches the project owner's stated intent ("Domain Bible must become the ONLY source of truth for permanent business knowledge"). MAPS should be reference material describing the same domain from an audit/implementation angle. **This conflict is not resolved in the source documents themselves** — flagged for project-owner decision.
2. **Money Distribution ownership.** ADR-0004 documents an existing, unresolved architectural contradiction between two separate entities that both claim to own "where money is": the older Money Location Engine (`docs/architecture/legacy/money_location_engine_v2.md` / `docs/architecture/money_location_engine_v2.md`, and `.agents/memory/money-location-engine.md`) and the newer Money Distribution domain (`.agents/memory/money-distribution-domain.md`). ADR-0004 itself is the authoritative record that this is unresolved — do not treat either memory file as settling it.

## Documents that supersede others

- `docs/project/Bug_Backlog.md` is the active, richer bug tracker (has an "OPEN BUGS" section, matches `replit.md`'s required pre-read). `docs/project/Bug Backlog.md` (with a space, shorter/stub content) appears superseded by it — verify with the project owner before treating the space-named file as dead, since neither file states this explicitly.
- `docs/architecture/money_location_engine_v2.md` (root) and `docs/architecture/legacy/money_location_engine_v2.md` are byte-identical; the legacy copy is redundant given the root copy exists outside `legacy/`.
- `docs/architecture/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` (root) and its `legacy/` copy are byte-identical — same redundancy.
- `docs/architecture/feature-refactors/*.md` (6 files) are each byte-identical to a same-named file directly under `docs/architecture/`. The `feature-refactors/` copies are the ones indexed by `docs/architecture/README.md`'s stated folder structure — treat those as canonical location, the root-level copies as redundant.

## Documents that duplicate information (without being identical)

- `docs/architecture/jar_money_location_architecture.md` vs. `docs/architecture/legacy/jar_money_location_architecture.md` — same title, **different content** (diverged over time). Do not assume the legacy one is a pure subset; check both if the topic matters.
- `docs/architecture/text-parsing-business-logic-inventory.md` vs. `docs/architecture/maps/text-parsing-business-logic-inventory.md` — same title, **different content**. Same caution applies.
- `docs/project/Bug Backlog.md` vs. `docs/project/Bug_Backlog.md` — same subject, different content/maturity.

## Documents that should never be used as a source of truth

- `README.md` (repo root) — describes an app called "Korassa," not Mezanya. Stale/mislabeled; do not use for any current understanding of the project.
- `FLUTTER_AI_HANDOFF_AR.md` — a pre-implementation greenfield rebuild brief. Useful only as historical intent, never as a description of current behavior.
- Any empty file — `docs/architecture/Mezanya Domain Bible/04 - Financial Engine .md` through `08 - Development Constitution.md`, `docs/project/Reconstruction Progress.md`, `docs/project/Technical Debt.md`. These exist as placeholders only; treat their absence of content as "not yet documented," never as "confirmed nothing to know."
- `.agents/memory/*.md` for anything business/domain-permanent. If a memory file reads like a business rule rather than an implementation quirk, that is a filing error to flag, not a source to cite (see `DOCUMENTATION_RULES.md` and the migration candidates in `DOCUMENTATION_AUDIT_REPORT.md`).
