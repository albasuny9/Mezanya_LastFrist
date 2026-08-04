# Mezanya Architecture & Product Specification (MAPS)

# Volume 10 --- Coding Standards, Invariants & Architectural Guardrails

## Purpose

This volume defines the non-negotiable engineering rules that preserve
the architecture over time.

It complements the business specification by defining implementation
constraints.

------------------------------------------------------------------------

# Architectural Invariants

These statements must always remain true.

-   Wallet balance is owned only by Wallet.
-   Jar balance is owned only by Jar.
-   Budget planning is owned only by Budget.
-   Financial history is owned only by Transaction.
-   Reservation metadata is owned only by Money Distribution.
-   Unknown is always computed.
-   One business concept has exactly one owner.

If any invariant becomes false, the implementation is incorrect.

------------------------------------------------------------------------

# Single Responsibility

Every class must answer one business question.

Every service must implement one business capability.

Every entity represents one business concept.

Never combine unrelated responsibilities.

------------------------------------------------------------------------

# Dependency Rules

Allowed:

Presentation → Application

Application → Domain

Application → Persistence

Forbidden:

Domain → Presentation

Persistence → UI

Wallet → Budget

Budget → Wallet

Transaction → Distribution

Distribution → Transaction

Jar → Wallet

Wallet → Jar

Circular dependencies are forbidden.

------------------------------------------------------------------------

# Business Logic Placement

Business rules belong only inside Domain Services.

Never place business rules inside:

-   Cubits
-   Widgets
-   Repositories
-   Serialization
-   DTOs
-   Utility classes

Application layer orchestrates.

Domain layer decides.

------------------------------------------------------------------------

# Persistence Rules

Persistence stores state.

Persistence never decides state.

Serialization must never contain business logic.

Migration code must be isolated and removable.

------------------------------------------------------------------------

# Validation Rules

Validation must reject invalid operations.

Validation must never silently repair data.

Every rejection must explain which business rule failed.

------------------------------------------------------------------------

# Error Handling

If an operation cannot preserve architectural invariants:

Abort.

Never partially apply business changes.

Never leave domains inconsistent.

------------------------------------------------------------------------

# Refactoring Rules

Before moving code ask:

Who owns this business concept?

Move responsibility, not implementation.

Never move coupling from one class to another.

Remove the coupling.

------------------------------------------------------------------------

# Naming Standards

Names must express business concepts.

Preferred:

Wallet

Jar

Budget

Money Distribution

Reservation

Distribution Entry

Unknown

Avoid implementation-driven names.

------------------------------------------------------------------------

# Testing Expectations

Every business rule must be independently testable.

Unit tests should verify:

-   Ownership
-   Validation
-   State transitions
-   Invariants

Integration tests verify workflows.

------------------------------------------------------------------------

# Performance

Never sacrifice architectural correctness for premature optimization.

Optimize only after correctness.

------------------------------------------------------------------------

# Documentation

Architecture documentation evolves before implementation.

If implementation changes business behavior:

Documentation must be updated first.

------------------------------------------------------------------------

# Code Review Checklist

Before merging verify:

-   No duplicated business rules.
-   No forbidden dependencies.
-   No business logic inside Cubits.
-   No fake transactions.
-   Unknown remains computed.
-   Distribution remains metadata.
-   Financial behavior unchanged.

------------------------------------------------------------------------

# Long-Term Goal

The architecture should become easier to understand after every feature.

Complexity should move toward documentation, not into code.

------------------------------------------------------------------------

**END OF VOLUME 10**
