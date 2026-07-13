# Phase B — Backend Reconstruction Blueprint

> Status: Planning
>
> Prerequisite:
>
> Phase 0 (Domain Foundation) must be completed and approved before this phase begins.
>
> Objective:
>
> Rebuild the Mezanya backend around the finalized Domain Model.
>
> This phase is not a refactoring effort.
>
> It is a controlled architectural reconstruction.
>
> Every implementation decision must originate from the Domain Bible.
>
> Existing code is treated as a temporary implementation.
>
> The Domain becomes the permanent source of truth.

---

# Mission Statement

The goal of this phase is not to make the code cleaner.

The goal is to make the implementation faithfully represent the Domain.

At the end of this phase there should no longer be a distinction between:

Business Rules

and

Implementation.

The backend should become a direct implementation of the Domain Bible.

---

# Reconstruction Principles

## Principle 1

Business Continuity.

The application must remain usable during reconstruction.

Users must never lose financial data because of architectural changes.

Whenever possible,

new architecture should coexist with old architecture until migration is complete.

---

## Principle 2

Incremental Replacement.

Nothing should be rewritten all at once.

Every subsystem should be replaced independently.

Each replacement must produce a working application before continuing.

---

## Principle 3

Backward Compatibility.

Existing user data must remain readable.

Migration should occur automatically whenever possible.

Breaking compatibility should only happen when technically unavoidable.

---

## Principle 4

No Mixed Architectures.

A subsystem should never permanently contain both:

old execution model

and

new execution model.

Temporary adapters are acceptable.

Permanent hybrid architecture is forbidden.

---

# Reconstruction Strategy

Every subsystem should pass through exactly the same reconstruction stages.

```

```
Current Implementation

↓

Analysis

↓

Domain Mapping

↓

Replacement Design

↓

Compatibility Layer

↓

Implementation

↓

Migration

↓

Verification

↓

Remove Legacy Code

↓

Finalize

```

---

# Step 1 — Dependency Analysis

Before modifying any subsystem,

identify:

Who depends on it?

Who does it depend on?

Which business rules does it own?

Which business rules should be moved?

No code should be deleted before dependency analysis is complete.

---

# Step 2 — Domain Mapping

For every class,

service,

repository,

provider,

controller,

or manager,

determine:

Which Domain Concept does this implement?

If no corresponding Domain Concept exists,

the implementation should be reconsidered.

---

# Step 3 — Replacement Design

Design the replacement before writing code.

The replacement must answer:

What Domain Principle does it implement?

Which Aggregate owns it?

Which Financial Operation uses it?

Which Financial Effects does it produce?

Which Engine executes it?

---

# Step 4 — Compatibility Layer

Whenever replacing an existing subsystem,

temporary adapters may be introduced.

Adapters exist only to keep the application operational.

Adapters should never introduce new business logic.

Their only responsibility is translation.

Compatibility layers are temporary.

Every adapter must eventually be removed.

---

# Step 5 — Implementation

Implementation begins only after:

Domain Mapping

Replacement Design

Compatibility Strategy

have been approved.

Implementation must remain as small as possible.

Whenever business decisions appear,

return to the Domain Bible.

Never solve business questions inside code.

---

# Step 6 — Data Migration

If reconstruction changes persistence,

migration should preserve:

Business Meaning

Current State

History

Relationships

Identifiers

No migration should alter financial reality.

Only storage representation.

---

# Step 7 — Verification

Every reconstructed subsystem must pass three independent verification levels.

Business Verification

Does it behave exactly as defined by the Domain?

Architectural Verification

Does it respect Aggregate boundaries?

Regression Verification

Does it preserve previous functionality?

Only after all three succeed should reconstruction continue.

---

# Step 8 — Legacy Removal

Legacy implementation should never remain indefinitely.

Once replacement is verified,

remove:

Unused Services

Unused Repositories

Duplicate Models

Obsolete Providers

Temporary Adapters

Dead Code

Compatibility layers should disappear progressively.

The final architecture should contain only one implementation.

---

# Reconstruction Order

Subsystems should be reconstructed according to architectural dependency.

Never according to UI order.

Recommended order:

1.

Domain Models

↓

2.

Aggregates

↓

3.

Financial Operations

↓

4.

Financial Effects

↓

5.

Financial Engine

↓

6.

Repositories

↓

7.

Persistence

↓

8.

Synchronization

↓

9.

Read Models

↓

10.

Application Services

↓

11.

Presentation Layer

This order minimizes cascading refactoring.

---

# Safety Rules

During reconstruction,

the following are forbidden.

Introducing business logic into UI.

Introducing business logic into repositories.

Creating feature-specific execution paths.

Duplicating Financial Effects.

Allowing aggregates to modify each other.

Skipping verification.

Implementing before Domain clarification.

---

# Completion Criteria

Phase B is complete only when:

Every Financial Operation executes through the Financial Engine.

Every Aggregate follows its defined boundary.

Every subsystem maps directly to the Domain Bible.

No legacy execution model remains.

No compatibility layer remains.

No duplicated business rules remain.

The backend becomes a faithful implementation of the Mezanya Domain.

---

# Expected Result

After Phase B,

adding a new feature should require:

Adding a new Financial Operation.

Mapping it to Financial Effects.

Passing it through the Financial Engine.

Nothing more.

The architecture should naturally absorb future features without structural redesign.


# Phase B.1 — Execution Roadmap

> Objective:
>
> Define the execution order of the backend reconstruction.
>
> This document is intentionally independent from implementation details.
>
> It answers one question:
>
> "In which order should the existing backend be demolished and rebuilt to minimize risk while keeping the application operational?"

---

# Why This Roadmap Exists

Large architectural reconstructions usually fail for one reason.

Developers know what the final architecture should look like.

But they don't know how to get there.

They begin replacing classes randomly.

Dependencies break.

Features stop working.

Temporary fixes accumulate.

Eventually the new architecture becomes as inconsistent as the old one.

Mezanya should avoid this.

Reconstruction must be deterministic.

---

# Reconstruction Philosophy

The backend should never be rebuilt feature-by-feature.

Instead,

it should be rebuilt layer-by-layer.

Every reconstructed layer becomes the stable foundation of the next layer.

Each layer should be completed before introducing dependencies on it.

---

# Reconstruction Layers

The recommended reconstruction sequence is:

```

Domain

↓

Execution

↓

Persistence

↓

Application

↓

Presentation

```

Each layer depends only on the layers below it.

Never the opposite.

---

# Layer 1 — Domain Layer

Priority:

★★★★★

This layer becomes the permanent foundation of the project.

Nothing above it should be reconstructed before it is complete.

---

## Scope

Domain Models

Aggregate Roots

Entities

Value Objects

Financial Operations

Financial Effects

Domain Rules

Domain Exceptions

Current State Model

Read Model Contracts

---

## Objective

Remove every implementation concern from the Domain.

No Flutter.

No Firebase.

No Hive.

No Isar.

No Repository.

No Provider.

No Riverpod.

No Bloc.

No Database.

Only business concepts.

---

## Deliverables

Pure Domain Layer.

No infrastructure dependencies.

---

# Layer 2 — Financial Engine

Priority:

★★★★★

This is the heart of the backend.

Every financial feature eventually executes here.

---

## Scope

Financial Engine

Execution Pipeline

Validation

Effect Resolution

Atomic Execution

Rollback

Commit

Execution Context

---

## Objective

Replace every feature-specific execution path with one unified engine.

Expense.

Income.

Debt.

Loan.

Jar.

Subscription.

Recurring.

Everything executes here.

---

## Deliverables

Unified execution engine.

---

# Layer 3 — Persistence

Priority:

★★★★☆

Only after the execution model becomes stable.

---

## Scope

Repositories

Local Database

Cloud Synchronization

Backup

Restore

Migration

Versioning

---

## Objective

Persistence becomes a storage concern.

Nothing more.

No business logic.

No calculations.

No financial decisions.

---

## Deliverables

Persistence adapters.

Repository implementations.

Migration strategy.

---

# Layer 4 — Projection Layer

Priority:

★★★★☆

This layer depends on committed domain state.

---

## Scope

Timeline

Dashboard

Reports

Analytics

Charts

Widgets

Notifications

Search

---

## Objective

Generate user-facing read models.

Never business logic.

---

## Deliverables

Projection Builder.

Read Models.

Caching Strategy.

---

# Layer 5 — Application Layer

Priority:

★★★☆☆

Coordinates use cases.

Does not own business rules.

---

## Scope

Use Cases

Commands

Queries

Application Services

Schedulers

Recurring Executors

Import Coordinators

Export Coordinators

---

## Objective

Connect UI to Domain.

Nothing more.

---

# Layer 6 — Presentation Layer

Priority:

★★☆☆☆

UI should become the final consumer.

Never the owner.

---

## Scope

Flutter Screens

Widgets

State Management

Navigation

Localization

Themes

Animations

---

## Objective

Presentation consumes Read Models.

Presentation never executes Financial Rules.

---

# Migration Strategy

Each reconstructed layer follows the same migration lifecycle.

```

Legacy Layer

↓

Analyze

↓

Map To Domain

↓

Design Replacement

↓

Build In Parallel

↓

Verify

↓

Switch

↓

Remove Legacy

```

No layer should be removed before its replacement is verified.

---

# Parallel Execution Rule

During reconstruction,

only one architectural layer should be actively replaced at a time.

Avoid simultaneous reconstruction of multiple layers.

Doing so makes debugging almost impossible.

---

# Verification Gate

A layer is considered complete only if:

Business Rules match the Domain Bible.

Automated tests succeed.

Manual verification succeeds.

Legacy implementation becomes unused.

Temporary adapters are removable.

Only then may the next layer begin.

---

# Forbidden Practices

The following actions are prohibited.

Skipping Domain Mapping.

Implementing before architecture.

Mixing old and new execution engines.

Duplicating Financial Rules.

Adding shortcuts to bypass the Financial Engine.

Leaving temporary adapters permanently.

Allowing Presentation to execute business logic.

Allowing Infrastructure to own business logic.

---

# Milestone Definition

Milestone 1

Pure Domain

Completed

↓

Milestone 2

Financial Engine

Operational

↓

Milestone 3

Persistence

Independent

↓

Milestone 4

Read Models

Operational

↓

Milestone 5

Application Layer

Connected

↓

Milestone 6

Presentation

Fully migrated

↓

Milestone 7

Legacy Code Removed

↓

Project Reconstruction Complete

---

# Expected Outcome

At the end of Phase B,

the backend should no longer resemble the legacy implementation.

Instead,

it should naturally mirror the Domain Bible.

Every class.

Every aggregate.

Every operation.

Every execution path.

Every repository.

Every screen.

Should exist because the Domain requires it.

Not because legacy code happened to evolve that way.
