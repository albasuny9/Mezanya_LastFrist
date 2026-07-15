# Mezanya — Documentation Authority Map

This document exists to answer one question whenever two documents disagree: **which one wins, and why.** It does not rewrite or migrate anything — see `DOCUMENTATION_AUDIT_REPORT.md` for the full inventory this map is based on, and `.agents/DOCUMENTATION_MIGRATION_PLAN.md` for the (not-yet-executed) plan to fix what's found here.

## Authority Resolution (binding)

**There is exactly ONE permanent business source of truth: the Domain Bible** (`docs/architecture/Mezanya Domain Bible/`).

Every other document in this repository is classified as one of exactly four non-canonical statuses:

| Status | Meaning |
|---|---|
| **Reference** | Describes the system for understanding/auditing purposes; not binding. |
| **Implementation** | Describes how to build or refactor something; not a business rule. |
| **Historical** | Superseded or archival; never current truth. |
| **Temporary** | Working/in-progress project material (bugs, investigations, task tracking). |

Architecture Decision Records (`docs/architecture/adr/`) sit just below the Domain Bible in binding weight for *architecture* (not business-rule) decisions, but they are not a second business source of truth — an ADR that touches business meaning must still trace back to the Domain Bible, and if it doesn't yet, that is a gap for the Bible to close, not a reason to treat the ADR as a business-rule source.

`replit.md` sits outside this ladder entirely: it is Canonical for environment, run instructions, and the currently active agent operating protocol (see its "User preferences"). It governs *permission to act*; the ladder above governs *which content to trust as business truth*.

### Explicit supersession

Any document that currently claims — implicitly or explicitly — to be a or the "source of truth" is **superseded by the Domain Bible** as of this governance pass:

- **`docs/architecture/maps/00-Mezanya-Architecture-Product-Specification-Volume-1.md`** opens with "**Status:** Authoritative Source of Truth." **This claim is superseded.** MAPS is reclassified as **Reference**. It remains useful as an audit/implementation-angle description of the domain, but must never be cited as settling a business rule where it disagrees with, or fills a gap in, the Domain Bible.
- **`docs/architecture/README.md`**'s own stated hierarchy ("Domain Bible > maps > feature-refactors > project > legacy") is **consistent** with this resolution and remains in force for ordering among the non-canonical tiers.

## Full classification (non-canonical documents)

| Location | Status |
|---|---|
| `docs/architecture/adr/` | Reference (architecture-decision weight, not business-rule weight) |
| `docs/architecture/maps/` (all 18 MAPS volumes + 2 inventory docs) | Reference — MAPS Volume 1's self-claim explicitly superseded, see above |
| `docs/architecture/*.md` root-level audits (`financial-domain-model-audit.md`, `jar_money_location_architecture.md`, `money_location_engine_v2.md`, `REFACTOR_STATUS.md`, `text-parsing-business-logic-inventory.md`, `unified-recurring-engine-review.md`) | Reference |
| `docs/architecture/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | Implementation |
| `docs/architecture/feature-refactors/*.md` and their root-level duplicates | Implementation |
| `docs/architecture/legacy/*.md` | Historical |
| `docs/project/Bug_Backlog.md`, `Decisions Log.md`, `Task Plan - Replit.md`, `decisions/Transaction Editing Architecture.md` | Temporary (living project-management material; never a business-rule source even when it records a decision) |
| `docs/project/Bug Backlog.md` | Historical (superseded by `Bug_Backlog.md` — see Known Conflicts) |
| `docs/project/investigations/*.md` | Temporary |
| `docs/project/Reconstruction Progress.md`, `Technical Debt.md` | Temporary (currently empty placeholders) |
| `.agents/memory/*.md` | Implementation (lowest authority; two files flagged as migration candidates — see audit report and migration plan) |
| `README.md` (repo root) | Historical (describes an unrelated app, "Korassa") |
| `FLUTTER_AI_HANDOFF_AR.md` | Historical |
| `project_documentation.md` | Reference |
| `TRANSACTION_ARCHITECTURE_AUDIT.md` | Reference |
| `replit.md` | Canonical, but outside this ladder (environment/protocol, not business truth) |

## Known conflicts and how they are resolved

1. **Domain Bible vs. MAPS self-declared authority.** Resolved above: Domain Bible wins; MAPS Volume 1's self-claim is superseded. This is now settled by this governance pass and should not be re-litigated by future agents — cite this section, not the MAPS file's own header.
2. **Money Distribution ownership.** ADR-0004 documents an existing, unresolved architectural contradiction between two separate entities that both claim to own "where money is": the older Money Location Engine (`docs/architecture/legacy/money_location_engine_v2.md` / `docs/architecture/money_location_engine_v2.md`, and `.agents/memory/money-location-engine.md`) and the newer Money Distribution domain (`.agents/memory/money-distribution-domain.md`). **This conflict is NOT resolved by this governance pass** — it is an architecture-level question requiring project-owner decision, not a documentation-authority question. Flagged in `.agents/DOCUMENTATION_MIGRATION_PLAN.md` as a blocking dependency for migrating either memory file.
3. **`Bug Backlog.md` vs. `Bug_Backlog.md`.** `Bug_Backlog.md` (underscore) is the active tracker referenced by `replit.md` and containing the current "OPEN BUGS" section; `Bug Backlog.md` (space) is shorter/stub content that has diverged. Resolved: `Bug_Backlog.md` is Temporary/active; `Bug Backlog.md` is reclassified **Historical**. Not deleted — see audit report §Duplicates and migration plan.

## Documents that supersede others

- `docs/project/Bug_Backlog.md` supersedes `docs/project/Bug Backlog.md` (see Known Conflicts #3).
- `docs/architecture/money_location_engine_v2.md` (root) and `docs/architecture/legacy/money_location_engine_v2.md` are byte-identical; the legacy copy is redundant given the root copy exists outside `legacy/`. Root copy is the one to cite.
- `docs/architecture/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` (root) and its `legacy/` copy are byte-identical — same redundancy; root copy is the one to cite.
- `docs/architecture/feature-refactors/*.md` (6 files) are each byte-identical to a same-named file directly under `docs/architecture/`. The `feature-refactors/` copies are the ones indexed by `docs/architecture/README.md`'s stated folder structure — treat those as canonical location, the root-level copies as redundant.

## Documents that duplicate information (without being identical)

- `docs/architecture/jar_money_location_architecture.md` vs. `docs/architecture/legacy/jar_money_location_architecture.md` — same title, **different content** (diverged over time). Do not assume the legacy one is a pure subset; check both if the topic matters. Root copy takes precedence as the non-legacy location.
- `docs/architecture/text-parsing-business-logic-inventory.md` vs. `docs/architecture/maps/text-parsing-business-logic-inventory.md` — same title, **different content**. Same caution applies; root copy takes precedence.
- `docs/project/Bug Backlog.md` vs. `docs/project/Bug_Backlog.md` — resolved above.

## Documents that should never be used as a source of truth

- `README.md` (repo root) — describes an app called "Korassa," not Mezanya. Stale/mislabeled; do not use for any current understanding of the project.
- `FLUTTER_AI_HANDOFF_AR.md` — a pre-implementation greenfield rebuild brief. Useful only as historical intent, never as a description of current behavior.
- `docs/architecture/maps/00-...-Volume-1.md`'s self-declared "Authoritative Source of Truth" status — superseded, see Authority Resolution above.
- Any empty file — `docs/architecture/Mezanya Domain Bible/04 - Financial Engine .md` through `08 - Development Constitution.md`, `docs/project/Reconstruction Progress.md`, `docs/project/Technical Debt.md`. These exist as placeholders only; treat their absence of content as "not yet documented," never as "confirmed nothing to know."
- `.agents/memory/*.md` for anything business/domain-permanent. If a memory file reads like a business rule rather than an implementation quirk, that is a filing error to flag, not a source to cite (see `DOCUMENTATION_RULES.md` and `.agents/DOCUMENTATION_MIGRATION_PLAN.md`).
