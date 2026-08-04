# Mezanya Architecture & Product Specification (MAPS)

# Volume 15 --- Glossary, Architectural Decisions & Living Specification

## Purpose

This volume records the permanent architectural decisions (ADR), defines
the official glossary, and establishes how MAPS evolves over time.

------------------------------------------------------------------------

# Architectural Decision Records (ADR)

## ADR-001

Business Model First.

Implementation follows the business model.

------------------------------------------------------------------------

## ADR-002

One Business Concept.

One Owner.

Never duplicate ownership.

------------------------------------------------------------------------

## ADR-003

Financial Truth is separated from Metadata.

Balances are truth.

Distribution is metadata.

------------------------------------------------------------------------

## ADR-004

Application Layer orchestrates.

Domains never orchestrate each other.

------------------------------------------------------------------------

## ADR-005

Unknown is a computed value.

Unknown is never stored.

------------------------------------------------------------------------

## ADR-006

Transactions describe financial history.

Reservations describe intent.

These concepts must never be merged.

------------------------------------------------------------------------

# Official Glossary

## Wallet

Physical storage of money.

## Budget

Monthly financial planning.

## Transaction

Immutable financial event.

## Jar

Reserved money for a purpose.

## Money Distribution

Physical location metadata for reserved money.

## Distribution Entry

One reservation inside one wallet.

## Reservation

Business meaning of a Distribution Entry.

## Unknown

Reserved money whose physical location is currently unspecified.

## Allocation

Planning money into a Jar.

## Cycle

The configured budgeting period.

------------------------------------------------------------------------

# Living Documentation Policy

MAPS is a living specification.

Changes follow this order:

1.  Business decision.
2.  MAPS update.
3.  Architecture review.
4.  Implementation.
5.  Migration (if required).

Never implement first and document later.

------------------------------------------------------------------------

# Backward Compatibility Policy

When changing business behavior:

-   Document the change.
-   Explain why.
-   Define migration.
-   Preserve existing users whenever possible.

------------------------------------------------------------------------

# Change Categories

Minor

-   Documentation
-   Naming
-   Comments

Medium

-   New domain service
-   New workflow
-   New UI

Major

-   Ownership changes
-   Domain boundaries
-   Persistence model
-   Financial behavior

Major changes require a new ADR.

------------------------------------------------------------------------

# Repository Rule

Every contributor must treat MAPS as the contract.

Source code is one implementation of that contract.

------------------------------------------------------------------------

# Future Documentation

Future volumes may include:

-   Debt Domain
-   Subscription Domain
-   Investment Domain
-   Forecasting Domain
-   Synchronization Specification
-   Reporting Specification

They must extend MAPS without contradicting previous architectural
decisions.

------------------------------------------------------------------------

# Final Principle

Architecture should become more explicit over time.

Knowledge should move into documentation.

Complexity should move out of implementation.

MAPS is the permanent memory of Mezanya.

------------------------------------------------------------------------

**END OF VOLUME 15**

**END OF MAPS VERSION 1.0**
