# Mezanya Architecture & Product Specification (MAPS)

# Volume 6 --- Persistence, Migration & Implementation Roadmap

## Purpose

This volume defines how the architecture evolves safely without breaking
financial behavior.

The objective is to migrate incrementally while preserving existing user
data.

------------------------------------------------------------------------

# Migration Philosophy

Business behavior always has higher priority than implementation.

A refactor is successful only if:

-   Financial results remain identical.
-   Existing user data remains valid.
-   New architecture becomes cleaner.
-   Legacy structures can eventually be removed.

Never perform a "big bang" rewrite.

------------------------------------------------------------------------

# Single Source of Truth

During migration there must always be exactly one authoritative source
for each concept.

Examples:

Wallet Balance → Wallet Domain

Jar Balance → Jar Domain

Distribution Metadata → Money Distribution Domain

Never maintain two permanent sources of truth.

------------------------------------------------------------------------

# Legacy Compatibility

Legacy structures may exist temporarily.

Examples:

-   walletSources
-   legacy serialization fields
-   compatibility adapters

Their only purpose is migration.

No new feature should be built on top of legacy structures.

------------------------------------------------------------------------

# Migration Stages

## Stage 1

Introduce new domain models.

No behavior changes.

## Stage 2

Populate new storage from legacy data.

Validate migration.

## Stage 3

Switch reads to the new models.

Legacy still exists as fallback.

## Stage 4

Switch writes to the new models.

Legacy receives no new updates.

## Stage 5

Verify all workflows.

## Stage 6

Remove legacy implementation.

------------------------------------------------------------------------

# AppState Evolution

AppState owns persistence only.

Responsibilities:

-   Store domain state.
-   Serialize.
-   Deserialize.

It must not become a business domain.

Business decisions belong inside domain services.

------------------------------------------------------------------------

# Application Layer

The Application Layer coordinates workflows.

Responsibilities:

-   Call domain services.
-   Persist state.
-   Refresh UI.

It must never contain duplicated business rules.

Future orchestration may move into:

FinancialWorkflowCoordinator

This is an application concern, not a domain.

------------------------------------------------------------------------

# Data Validation

Every migration step must validate:

-   Wallet balances unchanged.
-   Jar balances unchanged.
-   Budget totals unchanged.
-   Distribution totals valid.
-   Serialization compatible.

Migration must stop immediately if validation fails.

------------------------------------------------------------------------

# Backward Compatibility

Existing saved data must continue to load.

Migration should happen automatically on first load.

The user should never be required to manually migrate data.

------------------------------------------------------------------------

# Testing Strategy

Every migration step requires tests.

Minimum scenarios:

-   Existing user opens app after update.
-   Salary allocation.
-   Expense.
-   Transfer.
-   Manual reservation.
-   Unknown calculation.
-   App restart.
-   Serialization round-trip.

------------------------------------------------------------------------

# Rollback Strategy

If migration fails:

-   Preserve original state.
-   Abort migration.
-   Report validation error.
-   Never partially migrate data.

------------------------------------------------------------------------

# Incremental Delivery

Each implementation phase must:

1.  Compile successfully.
2.  Pass analysis.
3.  Preserve behavior.
4.  Be committed independently.

Avoid combining multiple architectural changes into one commit.

------------------------------------------------------------------------

# Recommended Commit Order

1.  Domain entities.
2.  Domain services.
3.  Persistence.
4.  Migration.
5.  Application wiring.
6.  UI integration.
7.  Legacy removal.

------------------------------------------------------------------------

# Definition of Done

A migration is complete only when:

-   Legacy paths are unused.
-   Financial behavior is unchanged.
-   Domain ownership is respected.
-   Tests pass.
-   Documentation matches implementation.

------------------------------------------------------------------------

# Long-Term Maintenance

Future contributors must:

-   Read MAPS before coding.
-   Respect domain ownership.
-   Extend existing domains instead of creating parallel logic.
-   Document architectural decisions before implementation.

The documentation evolves first.

The implementation follows.

------------------------------------------------------------------------

**END OF VOLUME 6**
