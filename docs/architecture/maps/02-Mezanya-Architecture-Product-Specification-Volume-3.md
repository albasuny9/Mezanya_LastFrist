# Mezanya Architecture & Product Specification (MAPS)

# Volume 3 --- Domain Architecture & Dependency Rules

## Purpose

This volume defines how every business domain interacts with every other
domain.

The goal is strict separation of responsibilities.

------------------------------------------------------------------------

# High-Level Architecture

``` text
                UI
                 │
                 ▼
        Application Layer
                 │
   ┌─────────────┼─────────────┐
   ▼             ▼             ▼
 Wallet       Transaction    Budget
   │              │             │
   └──────┐       │       ┌─────┘
          ▼       ▼
             Jar
              │
              ▼
     Money Distribution
```

Business flows downward through explicit orchestration.

Domains never reach sideways into each other.

------------------------------------------------------------------------

# Layer Definitions

## Presentation

Owns:

-   Widgets
-   Screens
-   Navigation
-   User interaction

Never owns:

-   Business rules
-   Financial calculations

------------------------------------------------------------------------

## Application Layer

Owns:

-   Workflow orchestration
-   Calling domain services
-   Persisting AppState
-   Emitting UI state

Never owns:

-   Domain rules
-   Balance calculations
-   Distribution logic

------------------------------------------------------------------------

## Domain Layer

Owns business rules.

Every rule must have exactly one owner.

------------------------------------------------------------------------

## Persistence Layer

Owns serialization only.

Never contains business decisions.

------------------------------------------------------------------------

# Dependency Graph

Allowed:

Presentation → Application

Application → Domain

Application → Persistence

Domain → Domain Entities of the SAME domain

Forbidden:

Wallet → Budget

Budget → Wallet

Transaction → Distribution

Distribution → Transaction

Jar → Wallet

Wallet → Jar

Budget → Distribution

Distribution → Budget

No circular dependency is allowed.

------------------------------------------------------------------------

# Domain Responsibilities

## Wallet

Responsible for:

-   Physical balances
-   Wallet CRUD
-   Wallet identity

Must never know:

-   Budget
-   Reservation metadata
-   Monthly allocations

------------------------------------------------------------------------

## Transaction

Responsible for:

-   Applying financial operations
-   Reversing operations
-   Producing financial history

Must never:

-   Create reservations
-   Edit distribution
-   Decide physical reservation location

------------------------------------------------------------------------

## Budget

Responsible for:

-   Monthly planning
-   Allocation rules
-   Income planning

Must never:

-   Change wallet balances directly
-   Store reservation locations

------------------------------------------------------------------------

## Jar

Responsible for:

-   Reserved balance
-   Saving goals
-   Jar lifecycle

Must never:

-   Own wallet balances
-   Own distribution metadata

------------------------------------------------------------------------

## Money Distribution

Responsible for:

-   Reservation metadata
-   Wallet location of reserved money
-   Validation of distribution totals

Must never:

-   Change balances
-   Create transactions
-   Reverse transactions
-   Modify budget

------------------------------------------------------------------------

# Application Workflow

A complete operation follows this pattern:

User Action

↓

Application Layer

↓

Domain Service

↓

Updated Domain State

↓

Persistence

↓

UI Refresh

No domain may directly call another domain's internal logic.

------------------------------------------------------------------------

# Future Orchestrator

A future orchestration service may exist.

Example:

FinancialWorkflowCoordinator

Its responsibility:

-   Execute multiple domain operations
-   Preserve ordering
-   Coordinate workflows

It is NOT a business domain.

------------------------------------------------------------------------

# Architectural Invariants

Always true:

-   One concept has one owner.
-   Distribution is metadata.
-   Transactions are history.
-   Wallet balances are authoritative.
-   Jar balances are authoritative.
-   Unknown is computed.
-   Domains communicate through orchestration, not direct mutation.

------------------------------------------------------------------------

# Forbidden Patterns

Never:

-   Put business logic in Cubit.
-   Fix architecture with helper methods.
-   Duplicate business rules.
-   Mutate another domain's internal state.
-   Hide coupling behind utility functions.
-   Let implementation become documentation.

------------------------------------------------------------------------

# Refactoring Principle

When code violates ownership:

Do not move the code.

Move the responsibility to the correct owner.

If ownership is unclear, stop and document the ambiguity before
implementing.

------------------------------------------------------------------------

**END OF VOLUME 3**
