# Mezanya Architecture & Product Specification (MAPS)

# Volume 18 --- Appendix B: Reference Implementation Principles

## Purpose

This appendix bridges the gap between the business architecture and the
future source code.

It defines implementation principles without prescribing a specific
framework.

------------------------------------------------------------------------

# Architectural Intent

The implementation is expected to evolve.

The architecture is expected to remain stable.

Code is replaceable.

Business concepts are not.

------------------------------------------------------------------------

# Framework Independence

MAPS is independent from:

-   Flutter
-   Dart
-   Bloc
-   Cubit
-   Riverpod
-   Firebase
-   SQLite
-   Hive

Any technology may be replaced without changing the business model.

------------------------------------------------------------------------

# Entity Principles

Entities represent business concepts only.

Entities never:

-   Call repositories.
-   Perform UI logic.
-   Access persistence.
-   Depend on framework code.

------------------------------------------------------------------------

# Service Principles

Domain Services:

-   implement business rules
-   validate invariants
-   return deterministic results

They never:

-   show dialogs
-   navigate
-   write widgets
-   perform presentation logic

------------------------------------------------------------------------

# Repository Principles

Repositories only:

-   load state
-   save state
-   expose persistence APIs

Repositories never decide business behavior.

------------------------------------------------------------------------

# Application Layer Principles

The Application Layer coordinates domains.

Typical responsibilities:

-   execute workflows
-   invoke domain services
-   persist results
-   publish UI state

It never becomes another business domain.

------------------------------------------------------------------------

# UI Principles

UI observes state.

UI requests actions.

UI never decides business outcomes.

------------------------------------------------------------------------

# Testing Pyramid

Priority:

1.  Domain tests
2.  Workflow integration tests
3.  Serialization tests
4.  Widget tests
5.  End-to-end tests

Business correctness is verified closest to the Domain layer.

------------------------------------------------------------------------

# Architectural Drift

Signs of architectural drift include:

-   duplicated calculations
-   duplicated validation
-   helper methods hiding ownership
-   cross-domain mutations
-   growing Cubits
-   business logic inside widgets

Whenever drift is detected:

Stop feature work.

Correct the architecture first.

------------------------------------------------------------------------

# Long-Term Objective

The ideal future repository should allow a new engineer to understand:

-   the product
-   the domains
-   the workflows
-   the ownership model

by reading MAPS before reading source code.

------------------------------------------------------------------------

# Final Statement

MAPS is the constitutional document of Mezanya.

Every implementation, refactor, migration, optimization and future
feature must preserve the principles defined across all volumes.

Architecture is a product feature.

Maintain it with the same discipline as financial correctness.

------------------------------------------------------------------------

**END OF VOLUME 18**

**END OF MAPS**
