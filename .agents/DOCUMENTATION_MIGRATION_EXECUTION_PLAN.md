# Mezanya — Documentation Migration Execution Plan

**Status: PLAN ONLY. Nothing in this file has been executed.**

This document sequences the migrations already identified in `DOCUMENTATION_AUDIT_REPORT.md` and `.agents/DOCUMENTATION_MIGRATION_PLAN.md` into a concrete, file-by-file execution order. It adds no new findings and performs no new audit — it re-uses the existing inventory/classification. No content has been moved, merged, archived, deleted, or edited. The Domain Bible has not been touched. No source code was inspected or modified to produce this plan.

Every item below still requires explicit project-owner approval before an agent executes it, per `.agents/DOCUMENTATION_RULES.md` and the active protocol in `replit.md`.

---

## A. Migration order table — SAFE migrations

"Safe" means: no open architectural decision blocks it, no diverged content requires a judgment call, and executing it cannot lose information (worst case is a mechanical archive of a verified exact duplicate). These are ready for approval as a batch, in this order (dependency-respecting).

| Order | Source | Destination | Section(s) to Migrate | Section(s) to Archive/Delete Later | Reason | Risk | Dependency | Priority |
|---|---|---|---|---|---|---|---|---|
| 1 | `docs/architecture/legacy/money_location_engine_v2.md` | *(no content moves — file is byte-identical to root copy)* | None — nothing unique to migrate | **Archive** entire file (move to `docs/architecture/legacy/_archived/`, or mark header "Archived — see root copy") | Byte-identical duplicate of `docs/architecture/money_location_engine_v2.md`; root copy is the citable one. | Low — verified byte-identical, no content loss possible. | None | P3 |
| 2 | `docs/architecture/legacy/MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` | *(no content moves — byte-identical to root copy)* | None | **Archive** entire file (987 lines, same treatment as #1) | Byte-identical duplicate of the root-level file. | Low — verified byte-identical. | None | P3 |
| 3 | `docs/architecture/refactor-budget-feature.md` | `docs/architecture/feature-refactors/refactor-budget-feature.md` (already the canonical copy — no new content added) | None — nothing unique to migrate | **Archive** the root-level copy entirely | Byte-identical duplicate; `feature-refactors/` is the canonical location per `docs/architecture/README.md`'s stated structure. | Low — verified byte-identical. | None | P3 |
| 4 | `docs/architecture/refactor-home-feature.md` | `docs/architecture/feature-refactors/refactor-home-feature.md` | None | **Archive** root-level copy entirely | Same pattern as #3. | Low | None | P3 |
| 5 | `docs/architecture/refactor-notifications-feature.md` | `docs/architecture/feature-refactors/refactor-notifications-feature.md` | None | **Archive** root-level copy entirely | Same pattern as #3. | Low | None | P3 |
| 6 | `docs/architecture/refactor-settings-appcubit-feature.md` | `docs/architecture/feature-refactors/refactor-settings-appcubit-feature.md` | None | **Archive** root-level copy entirely | Same pattern as #3. | Low | None | P3 |
| 7 | `docs/architecture/refactor-transactions-feature.md` | `docs/architecture/feature-refactors/refactor-transactions-feature.md` | None | **Archive** root-level copy entirely | Same pattern as #3. | Low | None | P3 |
| 8 | `docs/architecture/refactor-wallets-feature.md` | `docs/architecture/feature-refactors/refactor-wallets-feature.md` | None | **Archive** root-level copy entirely | Same pattern as #3. | Low | None | P3 |
| 9 | `.agents/memory/budget-phase1-widget-extraction.md` | `docs/architecture/feature-refactors/refactor-budget-feature.md` | Full content → appended as new `## Execution Log → Phase 1: Widget Extraction` subsection | **Archive** source file in `.agents/memory/` once appended content is confirmed present at destination (do not delete outright) | Implementation-tier notes about executing this exact refactor plan; consolidating improves discoverability (currently unindexed in `MEMORY.md`). | Low — pure consolidation, no business-rule or authority content. | Confirm `refactor-budget-feature.md` status in `docs/architecture/REFACTOR_STATUS.md` is "complete" first, so the appended log reads as finished, not in-progress. | P2 |
| 10 | `.agents/memory/budget-phase2-constants-extraction.md` | `docs/architecture/feature-refactors/refactor-budget-feature.md` | Full content → appended as `## Execution Log → Phase 2: Constants Extraction` | **Archive** source file after confirmation, same as #9 | Same reasoning as #9. | Low | Same as #9; execute together with #9 and #11 as one consolidation batch. | P2 |
| 11 | `.agents/memory/budget-phase3-service-extraction.md` | `docs/architecture/feature-refactors/refactor-budget-feature.md` | Full content → appended as `## Execution Log → Phase 3: Service Extraction` | **Archive** source file after confirmation, same as #9 | Same reasoning as #9. | Low | Same as #9; execute together with #9 and #10. | P2 |
| 12 | `.agents/memory/MEMORY.md` | `.agents/memory/MEMORY.md` (self — index housekeeping, not a cross-file migration) | Add one index line each for `money-location-engine.md` and `money-distribution-domain.md` (pointing at them in place — see Blocked section B; indexing them does not migrate their content) | Remove the three `budget-phase*-extraction.md` index lines once #9–#11 are archived | Index currently omits 5 of 7 memory topic files, hurting discoverability; this is metadata upkeep, not a content migration. | Low — index-only edit, no source content changes. | Should run after #9–#11 (for the removals) but the two additions for money-location/distribution can happen immediately, independent of ADR-0004. | P2 |

**Note on order:** items 1–8 are independent of each other and of everything else — they can be approved and executed in any order or as a single batch. Items 9–11 must be executed together (all three appended before any are archived) and depend on the `REFACTOR_STATUS.md` check. Item 12 is index bookkeeping and should trail 9–11 for the removal half, but the addition half has no dependency.

---

## B. Blocked migrations

These cannot be executed — and should not even be fully planned at the section level — until a named external condition is met. Listed for visibility only.

| Source | Intended Destination | Section(s) Contemplated | Reason Blocked | Dependency | Priority (once unblocked) |
|---|---|---|---|---|---|
| `.agents/memory/money-location-engine.md` | `docs/architecture/Mezanya Domain Bible/04 - Financial Engine .md` (or a new standalone `docs/architecture/` reference doc — destination itself is undecided) | Full file content, describing the Money Location Engine | Content documents one side of an **unresolved** architectural contradiction (ADR-0004: Money Location Engine vs. Money Distribution domain ownership). Migrating it into the Domain Bible now would encode an unsettled decision as settled — and this task explicitly must not touch Domain Bible content regardless. | ADR-0004 reaching an accepted resolution | P2 |
| `.agents/memory/money-distribution-domain.md` | `docs/architecture/Mezanya Domain Bible/04 - Financial Engine .md` or `05 - Allocation.md` (destination undecided, same reason) | Full file content, describing the Money Distribution domain | Same blocker as above — the other side of the same unresolved contradiction. Must be resolved together with the item above, not separately, to avoid biasing the outcome. | ADR-0004 resolution; must move in lockstep with `money-location-engine.md` | P2 |
| *(gap, not a migration)* `docs/architecture/Mezanya Domain Bible/04 - Financial Engine .md` | — | Would eventually receive content from the two items above, or fresh authoring | Chapter is currently empty; filling it is downstream of the ADR-0004 decision (or requires the project owner to author it directly) | Depends on the two rows above, or explicit owner authoring | P1 (impact), but not actionable yet |

No further detail (exact subsections, risk rating) is meaningful for these until ADR-0004 is resolved — the destination document itself isn't fixed yet.

---

## C. Conflicts needing approval

These require a human decision — either because content has diverged and someone must judge what to keep, or because a document's own claims contradict the Domain Bible's authority and the correction itself needs sign-off before an agent edits it.

| Files in Conflict | Nature of Conflict | Decision Needed | Risk if Mishandled | Priority |
|---|---|---|---|---|
| `docs/architecture/jar_money_location_architecture.md` **vs.** `docs/architecture/legacy/jar_money_location_architecture.md` | Same title, **content has diverged** — not a clean duplicate. | Owner (or a delegated review pass) must diff both and decide which sections of each survive in the single reconciled file. | Medium — naive "keep newer, delete older" could silently drop information that only exists in the other copy. | P2 |
| `docs/architecture/text-parsing-business-logic-inventory.md` **vs.** `docs/architecture/maps/text-parsing-business-logic-inventory.md` | Same title, **content has diverged**. | Same as above — requires a diff-and-merge decision, not a mechanical archive. | Medium — same reasoning. | P2 |
| `docs/project/Bug Backlog.md` **vs.** `docs/project/Bug_Backlog.md` | `Bug_Backlog.md` is the active tracker (matches `replit.md`'s mandatory pre-read); `Bug Backlog.md` is a shorter, diverged stub. Whether it contains any bug entries absent from the active tracker has **not been verified line-by-line** — confirming that would itself be a small reconciliation review, which this plan flags rather than performs (per instruction not to start a new audit). | Owner must approve: (1) that a two-file reconciliation check may be performed, and (2) archive `Bug Backlog.md` once confirmed to have no unique entries. | Medium — if unverified entries are unique to the stub file, archiving it without checking would silently drop tracked bugs. | P1 |
| `README.md` (repo root) | Describes an unrelated app ("Korassa"), not Mezanya — actively contradicts the project's own identity, though it doesn't contradict the Domain Bible's *business-rule* authority per se. | Owner must approve (1) archiving it as historical, and (2) whether an agent is authorized to author replacement root README content, or whether that's a separate content task outside documentation-governance scope. | Low content-loss risk, high confusion risk if left as-is. | P1 |
| `docs/architecture/maps/00-Mezanya-Architecture-Product-Specification-Volume-1.md` | Self-labels **"Status: Authoritative Source of Truth"** in its own header — directly contradicts the Domain Bible's sole-authority status as resolved in `.agents/DOCUMENTATION_MAP.md`. The *classification* conflict is already resolved on paper (see that file), but the false claim still lives inside the MAPS document itself. | Owner must approve editing that one status line (e.g., to "Reference — see Domain Bible for business-rule authority") — this is a documentation *edit*, not a migration, and this plan does not assume standing authorization to make it. | Low content-loss risk (single header line), but leaving it unedited means any agent who opens that file directly (bypassing `.agents/DOCUMENTATION_MAP.md`) sees a false authority claim. | P1 |

---

## Recommended next action

The highest-priority **safe, unblocked** moves are items **1–8** in section A (archiving the eight byte-identical duplicate files — three pairs plus the six root-level refactor-plan copies). They carry no content-loss risk, no architectural dependency, and no judgment call: each is a verified byte-for-byte duplicate where the canonical copy already exists elsewhere. Recommend approving that batch first.

Second priority: the budget-phase memory consolidation (items 9–12 in section A) — slightly more involved (requires appending content and confirming refactor status) but still mechanical and low-risk.

Everything in section B (blocked) should not be scheduled until ADR-0004 is resolved. Everything in section C (conflicts) needs an explicit owner decision per row before any agent acts — none of them are safe to batch-approve as a group.

No migration, deletion, or edit has been performed. Awaiting approval to proceed with any item above.
