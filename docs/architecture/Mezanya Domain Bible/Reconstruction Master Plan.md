<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Phase A — Domain Stabilization

> Status: Planning
>
> Objective:
>
> Before modifying the backend architecture, the Mezanya Domain Model must be finalized.
>
> The goal of this phase is not to improve the implementation.
> The goal is to eliminate ambiguity from the business domain until every financial feature can be described using a single ubiquitous language.
>
> During this phase, no implementation decisions should drive the domain.
> The domain must drive the implementation.

---

# General Rules

Throughout this phase the following principles are mandatory.

## 1. Domain First

Business meaning always comes before implementation.

Never design entities based on database tables.

Never classify operations based on UI screens.

Never derive business rules from existing code.

Instead:

Business Rules

↓

Domain Model

↓

Architecture

↓

Persistence

↓

Implementation

The codebase is allowed to change.

The domain is the source of truth.

---

## 2. Business Semantics Before Technical Semantics

Financial operations must be classified according to what they mean in the real financial world.

Not according to:

- database schema
- entity names
- participating objects
- UI flow
- existing implementation

Every operation should first answer:

1. Does real money move?

2. Does ownership change?

3. Does budget planning change?

4. Does budget balance change?

5. Which business entities are affected?

6. Are those entities permanent or cycle-scoped?

Only after answering these questions may the persistence model be designed.

Persistence is a consequence of the domain.

Never the opposite.

---

## 3. Single Ubiquitous Language

Every concept must have exactly one definition.

The same term cannot have different meanings in different parts of the system.

For example:

Wallet

must always mean

"The physical location where real money exists."

Allocation

must always mean

"A cycle-scoped planning entity."

Jar

must always mean

"A permanent financial entity independent from the current budget."

Budget

must always mean

"The financial planning model of a single financial cycle."

If two concepts require different meanings, then they require different names.

Ambiguous terminology is not allowed.

---

## 4. Domain Before Features

Features are not domain concepts.

Salary

Debt

Installment

Subscription

Loan

Recurring Transactions

Goals

are all Features.

The Domain must first define the financial concepts.

Features are later implemented by composing those concepts.

No feature is allowed to introduce new architectural rules.

Instead, every feature must reuse the existing domain model.

---

# Ticket A1 — Rebuild Domain Fundamentals

## Goal

Rewrite the Domain Fundamentals chapter from scratch using the finalized domain language.

The document must become the constitutional reference of Mezanya.

It must explain:

- Wallet
- Budget
- Financial Cycle
- Allocation
- Unallocated
- Jar
- Current State
- Financial Operation
- Transaction
- Financial Effect

Each concept should be explained independently.

Definitions must not depend on implementation details.

Each definition should answer:

- What is it?
- Why does it exist?
- What business responsibility does it own?
- What is it NOT?

No technical terminology should appear unless required by the domain.

---

## Expected Deliverables

Rewrite:

01 - Domain Fundamentals.md

Remove outdated concepts.

Remove duplicated explanations.

Remove implementation-driven terminology.

Rewrite every section using the finalized ubiquitous language.

Do not continue to the next ticket until Domain Fundamentals becomes stable.



# Ticket A2 — Define Aggregate Boundaries & Entity Lifecycles

## Goal

Identify the true Aggregate boundaries of the Mezanya domain.

Aggregate design must follow business consistency and lifecycle boundaries.

It must never follow folders, tables, repositories, or existing code.

The objective is to determine which entities own business invariants, which entities are children, and which entities are completely independent.

This ticket is considered complete only when every domain entity belongs to exactly one aggregate.

---

## Why This Matters

Aggregate boundaries determine:

- consistency rules
- transaction boundaries
- ownership
- lifecycle
- business invariants
- future scalability

An incorrect aggregate design will eventually produce duplicated logic, circular dependencies, and inconsistent financial state.

For this reason, no backend restructuring should begin before aggregate boundaries are finalized.

---

## Domain Analysis

The analysis must begin by identifying entity lifecycles.

Every entity should answer the following questions:

- When is it created?
- When does it stop existing?
- Can it exist independently?
- Can it survive a financial cycle?
- Who owns it?
- Who is responsible for protecting its business rules?

Lifecycle comes before ownership.

Ownership comes before persistence.

Persistence comes before implementation.

---

## Candidate Aggregates

The following entities require formal analysis.

### Wallet

Questions:

- Is Wallet completely independent?
- Does Wallet survive multiple financial cycles?
- Does Wallet own its balance?
- Can another aggregate directly modify Wallet?

Expected outcome:

Wallet is likely to become an independent Aggregate Root.

---

### Jar

Questions:

- Is Jar tied to a Budget?
- Is Jar tied to a Financial Cycle?
- Does Jar survive indefinitely?
- Does Jar own its own balance?
- Can multiple cycles interact with the same Jar?

Expected outcome:

Jar is likely to become an independent Aggregate Root.

---

### Budget

Questions:

- Does Budget exist independently?
- Does Budget own Allocations?
- Does Budget own planned income?
- Does Budget own summaries?
- Is Budget itself persistent?
- Does Budget survive after closing a cycle?

This question must be answered purely from domain semantics.

Not from implementation.

---

### Allocation

Questions:

- Can Allocation exist without a Budget?
- Can Allocation survive a new financial cycle?
- Does Allocation have an independent lifecycle?
- Is Allocation recreated every cycle?
- Does Allocation own any business invariants?

Current hypothesis:

Allocation is a child entity belonging to the budgeting context.

This hypothesis must be validated before proceeding.

---

### Financial Cycle

Questions:

- Is the Cycle merely metadata?
- Or is it the true business boundary of planning?

Determine whether the Financial Cycle is:

- an Aggregate Root,
- a Context,
- or simply an identifier.

This decision affects the entire budgeting model.

---

### Debt

Determine whether Debt owns:

- remaining balance
- payment schedule
- settlement status

or whether those belong elsewhere.

---

### Installment

Determine whether Installment belongs to:

Debt

or

Financial Cycle

or

another aggregate entirely.

---

### Subscription

Determine its lifecycle.

Questions:

Can a Subscription survive multiple cycles?

Does it own recurring execution?

Or is it only a recurring template?

---

## Mandatory Rule

Aggregate boundaries must follow lifecycle boundaries.

Example:

Permanent entities should never become children of temporary entities.

Likewise,

cycle-scoped entities should never own permanent entities.

The lifecycle hierarchy must always remain valid.

---

## Deliverables

By the end of this ticket the following must exist:

- Aggregate Diagram

- Ownership Diagram

- Lifecycle Diagram

- Aggregate Responsibilities

- Child Entity Definitions

- Aggregate Invariants

Every entity inside Mezanya must belong to one clearly defined aggregate.

No orphan entities.

No duplicated ownership.

No overlapping responsibilities.

---

## Exit Criteria

Do not continue until every entity satisfies:

- lifecycle is defined

- ownership is defined

- aggregate is defined

- responsibilities are defined

- business invariants are defined

Only after aggregate boundaries become stable may the financial operation model be designed.


# Ticket A3 — Financial Operations Taxonomy

## Goal

Redesign the financial operation model from the domain perspective.

The objective of this ticket is to establish the official taxonomy of every financial operation inside Mezanya.

No operation should be classified according to implementation details, UI screens, repositories, database tables, or participating entities.

Every operation must first be understood according to its business meaning.

Only then may the implementation model be derived.

This ticket becomes the foundation for:

- Transaction Engine
- Financial Engine
- Timeline
- Undo
- Reports
- Analytics
- Future Features

No future financial feature may introduce a new operation category without extending this taxonomy.

---

# Why This Ticket Exists

Historically, financial software often classifies operations by implementation.

Examples:

Wallet Transfer

Jar Transfer

Budget Transfer

Allocation Transfer

Debt Payment

Subscription Payment

Salary

Investment

Loan

This leads to duplicated logic.

Instead, Mezanya should classify operations according to the business event that actually occurred.

The participating entities are merely recipients of the effects.

They should never define the operation itself.

---

# Mandatory Classification Process

Before naming an operation, answer these questions.

## Question 1

Does real money move?

Examples:

Wallet → Wallet

Wallet → Jar

External Income

Expense

Loan Payment

Savings Deposit

---

## Question 2

Does ownership of money change?

Examples:

Paying another person

Receiving money

Settling a debt

Giving a loan

Receiving repayment

Internal wallet transfers do NOT change ownership.

---

## Question 3

Does the financial plan change?

Examples:

Changing allocations

Redistributing planned budget

Editing planned income

Changing monthly planning

---

## Question 4

Does the current budget balance change?

Examples:

Expense

Income

Allocation usage

Budget funding

Budget correction

---

## Question 5

Which aggregates are affected?

Examples:

Wallet

Jar

Budget

Allocation

Debt

Subscription

Installment

Financial Cycle

Statistics

Timeline

---

## Question 6

Are those aggregates:

- Permanent

or

- Cycle Scoped

Lifecycle classification is mandatory before implementation.

---

## Question 7

Is the operation changing reality,

or changing planning,

or correcting history?

This question separates normal financial activity from adjustment operations.

---

# Business Semantics First

The following principle is mandatory.

Never ask:

"What entities participate?"

Instead ask:

"What happened in the financial world?"

Examples:

Money entered the user's financial world.

Money left the user's financial world.

Money changed physical location.

Money changed financial purpose.

The financial plan changed.

The financial state was corrected.

These are business events.

Those business events define the operation.

---

# Candidate Operation Families

The taxonomy should investigate whether every financial operation belongs to one of the following families.

## External Operations

Operations that change the user's total wealth.

Examples:

Income

Expense

Receive Money

Pay Someone

Debt Settlement

Loan Issuing

Loan Repayment

Investment Deposit

Investment Withdrawal

Questions:

Does wealth change?

Does ownership change?

Does budget change?

---

## Internal Money Movement

Operations that move existing money inside the user's financial ecosystem.

Examples:

Wallet → Wallet

Wallet → Jar

Jar → Wallet

Jar → Jar

These operations do not create or destroy money.

They relocate existing money.

---

## Planning Operations

Operations that modify the financial plan.

Examples:

Allocation Distribution

Allocation Redistribution

Planning Income

Budget Configuration

Monthly Planning

These operations may never move real money.

Their effects exist entirely inside the budgeting domain.

---

## Adjustment Operations

Operations that reconcile the system with reality.

Examples:

Wallet Balance Adjustment

Jar Balance Adjustment

Debt Adjustment

Budget Correction

Historical Correction

Migration

Import

Restore

These operations intentionally bypass normal financial flow.

Their purpose is consistency.

Not business activity.

---

# Operation Matrix

Every operation must eventually be classified using a matrix similar to:

| Operation | Real Money | Ownership | Planning | Budget Balance | Permanent | Cycle Scoped |
|------------|------------|-----------|-----------|----------------|------------|--------------|

Every supported operation inside Mezanya must appear exactly once.

No operation may belong to multiple families unless explicitly documented.

---

# Deliverables

By the end of this ticket the following must exist.

- Official Financial Operations Taxonomy

- Financial Operation Matrix

- Business Meaning of every operation

- Domain Classification Rules

- Relationship between Operations and Aggregates

- Relationship between Operations and Financial Engine

- Relationship between Operations and Timeline

- Relationship between Operations and Reporting

---

# Exit Criteria

This ticket is complete only when every financial feature currently supported by Mezanya can be mapped to exactly one operation family.

Examples include:

- Income

- Expense

- Transfer

- Jar Funding

- Allocation Funding

- Debt Payment

- Loan

- Installment

- Subscription

- Recurring Transactions

- Adjustments

- Imports

- Restores

without introducing special-case logic.

Only after the operation taxonomy becomes stable should the Financial Engine be designed.

The engine must execute the taxonomy.

It must never define it.

# Ticket A4 — Financial Engine Architecture

## Goal

Design the Financial Engine as the single execution model responsible for every financial change inside Mezanya.

The Financial Engine is not a feature.

It is not a service.

It is not a repository.

It is the execution core of the financial domain.

Every financial operation must eventually pass through this engine.

No operation is allowed to bypass it.

---

# Why This Ticket Exists

Once the domain language and operation taxonomy become stable, execution must also become unified.

Historically, financial systems evolve by adding feature-specific logic.

Examples:

Expense Engine

Transfer Engine

Debt Engine

Recurring Engine

Subscription Engine

Jar Engine

Over time this creates duplicated rules, inconsistent execution order, and hidden side effects.

Mezanya explicitly rejects this architecture.

Instead, there shall be exactly one Financial Engine.

Different behavior comes from different Financial Operations.

Never from different execution engines.

---

# Architectural Principles

The Financial Engine is responsible for execution.

It is NOT responsible for deciding business meaning.

Business meaning is already determined by the Financial Operation Taxonomy.

The Financial Engine receives a fully classified Financial Operation and executes its effects.

Its responsibility begins after the domain meaning is already known.

---

# Execution Pipeline

Every execution follows exactly the same lifecycle.

No feature may introduce additional execution stages.

```
Financial Operation
        │
        ▼
Resolve Context
        │
        ▼
Validate
        │
        ▼
Resolve Effects
        │
        ▼
Apply Effects
        │
        ▼
Update Affected Entities
        │
        ▼
Persist
        │
        ▼
Commit / Rollback
```

This pipeline is immutable.

Features may extend the data flowing through it.

They may never change its order.

---

# Stage 1 — Resolve Context

Before execution begins, the engine gathers every piece of information required to evaluate the operation.

Examples include:

- Wallets
- Jars
- Budget
- Current Financial Cycle
- Allocations
- Debts
- Installments
- Subscriptions
- User Settings
- Currency Configuration

No state changes are allowed during this stage.

Its purpose is only to build the execution context.

---

# Stage 2 — Validate

Validation ensures that execution is allowed.

Typical validations include:

- Required entities exist
- Amount is valid
- Currency is compatible
- Target entity is active
- Financial Cycle is valid
- Operation type is supported

Validation must never modify state.

Validation either succeeds or fails.

---

# Stage 3 — Resolve Effects

This is the heart of the engine.

The engine translates one Financial Operation into one or more Financial Effects.

Example:

Expense

↓

Wallet Balance -200

Allocation Remaining -200

Statistics Updated

Timeline Entry

The engine still performs no mutations.

It only determines what must happen.

Effects are deterministic.

Given the same operation and the same context, the same effects must always be produced.

---

# Stage 4 — Apply Effects

Once every effect has been resolved, execution begins.

Each Financial Effect is applied according to domain rules.

Execution order must be deterministic.

No effect may depend on side effects produced by another feature.

Effects are applied as part of one atomic execution unit.

---

# Stage 5 — Update Affected Entities

After applying the effects, every affected aggregate updates its own current state.

Examples:

Wallet

Jar

Budget

Allocation

Debt

Subscription

Statistics

Each aggregate updates only its own state.

Aggregates never modify each other directly.

Cross-aggregate coordination belongs exclusively to the Financial Engine.

---

# Stage 6 — Persist

Only after successful execution are the new states persisted.

Persistence includes:

- Updated Aggregates
- Transaction Record
- Timeline
- Metadata
- Audit Information

Persistence records the result of execution.

It never defines execution.

---

# Stage 7 — Commit / Rollback

Execution is atomic.

Either:

Every effect succeeds.

or

Every effect is discarded.

There is no partial execution.

Rollback returns the domain to the exact state it had before execution started.

---

# Financial Effects

The Financial Engine never executes operations directly.

It executes Financial Effects.

Examples include:

Increase Balance

Decrease Balance

Reserve Amount

Release Amount

Increase Planned Budget

Decrease Planned Budget

Create Timeline Record

Update Statistics

Close Debt

Advance Installment

Archive Cycle

Each effect represents one intentional domain mutation.

The Financial Engine executes effects.

Not features.

---

# Aggregate Independence

No aggregate is allowed to modify another aggregate directly.

Examples:

Wallet cannot modify Budget.

Budget cannot modify Jar.

Jar cannot modify Debt.

Debt cannot modify Subscription.

Every interaction flows through the Financial Engine.

This guarantees loose coupling and deterministic execution.

---

# Atomic Execution

A Financial Operation represents one atomic unit.

The following situations are forbidden:

Wallet updated

Budget failed

---

Jar updated

Timeline failed

---

Debt updated

Statistics failed

Every effect succeeds.

Or none of them become visible.

---

# Responsibilities

The Financial Engine owns:

- execution order
- validation flow
- effect resolution
- atomic execution
- persistence coordination
- rollback

It does NOT own:

- UI
- repositories
- feature configuration
- presentation
- reporting

---

# Deliverables

By the end of this ticket the following must exist.

- Financial Engine Specification

- Execution Pipeline

- Financial Effect Model

- Atomic Execution Rules

- Aggregate Coordination Rules

- Rollback Strategy

- Engine Responsibilities

---

# Exit Criteria

The Financial Engine must be capable of executing every financial operation supported by Mezanya without requiring feature-specific execution logic.

Every feature must become a producer of Financial Operations.

Only the Financial Engine may execute them.

No exceptions.


# Ticket A5 — Financial Effects Model

## Goal

Design the internal language used by the Financial Engine to execute every Financial Operation.

The Financial Engine must never execute features directly.

Instead, every Financial Operation must first be translated into a standardized collection of Financial Effects.

Financial Effects become the execution language of Mezanya.

Every financial feature, present or future, must ultimately be expressible using these effects.

---

# Why This Ticket Exists

Different financial operations often produce similar business consequences.

For example:

Expense

↓

Decrease Wallet Balance

Decrease Allocation Balance

Update Statistics

Create Timeline Record

---

Salary

↓

Increase Wallet Balance

Increase Budget Income

Update Statistics

Create Timeline Record

---

Jar Funding

↓

Decrease Wallet Balance

Increase Jar Balance

Create Timeline Record

---

Although these operations are different from a business perspective, they are built from reusable financial effects.

Instead of implementing execution separately for every feature, the engine should execute a common language of effects.

---

# Financial Operation vs Financial Effect

These concepts must never be confused.

A Financial Operation represents:

"What happened?"

Examples:

Expense

Income

Debt Payment

Transfer

Subscription Payment

Loan Repayment

Jar Funding

---

A Financial Effect represents:

"What must change?"

Examples:

Decrease Wallet Balance

Increase Jar Balance

Decrease Allocation Remaining

Increase Debt Paid Amount

Create Timeline Record

Update Statistics

Operations describe business intent.

Effects describe state mutations.

The Financial Engine executes effects.

Never operations.

---

# Characteristics of Financial Effects

Every Financial Effect must satisfy the following properties.

## Atomic

Each effect performs exactly one domain mutation.

One effect.

One responsibility.

---

## Deterministic

The same effect applied to the same context must always produce the same result.

Effects must never contain randomness or hidden side effects.

---

## Independent

Effects should not know why they exist.

They should only know:

- target aggregate
- action
- value
- execution context

An Increase Wallet Balance effect should work identically whether it originated from:

- Income

- Refund

- Debt Settlement

- Transfer

- Salary

The origin is irrelevant.

---

## Reusable

Effects are shared across the entire domain.

New features should reuse existing effects whenever possible.

Creating new effects should be rare.

Creating new Financial Operations should be common.

---

# Candidate Financial Effects

The following list is only a starting point.

The complete catalog must emerge from domain analysis.

## Wallet Effects

Increase Wallet Balance

Decrease Wallet Balance

Freeze Wallet Amount

Release Wallet Amount

Close Wallet

---

## Jar Effects

Increase Jar Balance

Decrease Jar Balance

Archive Jar

Restore Jar

---

## Budget Effects

Increase Planned Income

Decrease Planned Income

Increase Budget Usage

Decrease Budget Usage

Open Budget

Close Budget

---

## Allocation Effects

Increase Allocation Remaining

Decrease Allocation Remaining

Increase Allocation Planned Amount

Decrease Allocation Planned Amount

Reset Allocation

Archive Allocation

---

## Debt Effects

Increase Outstanding Balance

Decrease Outstanding Balance

Mark Debt Paid

Reopen Debt

---

## Installment Effects

Advance Installment

Complete Installment

Reset Installment

---

## Subscription Effects

Advance Billing Period

Pause Subscription

Resume Subscription

Cancel Subscription

---

## Timeline Effects

Create Timeline Entry

Update Timeline Entry

Remove Timeline Entry

---

## Statistics Effects

Update Daily Statistics

Update Monthly Statistics

Update Budget Summary

Update Dashboard Metrics

---

# Effect Resolution

Effect Resolution is the process of translating one Financial Operation into one or more Financial Effects.

Example:

Expense

↓

Decrease Wallet Balance

↓

Decrease Allocation Remaining

↓

Update Statistics

↓

Create Timeline Entry

---

Jar Funding

↓

Decrease Wallet Balance

↓

Increase Jar Balance

↓

Create Timeline Entry

---

Wallet Transfer

↓

Decrease Source Wallet

↓

Increase Destination Wallet

↓

Create Timeline Entry

---

The Financial Operation itself is never executed.

Only its resolved effects are executed.

---

# Effect Ordering

The execution order of effects must be deterministic.

The same Financial Operation must always produce effects in the same order.

Changing execution order may change business results.

Therefore ordering becomes part of the architecture.

Example:

Resolve

↓

Wallet Effects

↓

Budget Effects

↓

Jar Effects

↓

Debt Effects

↓

Statistics

↓

Timeline

This ordering should be documented and protected.

---

# Effect Composition

Complex operations should be composed from multiple reusable effects.

For example:

Debt Payment

↓

Decrease Wallet Balance

↓

Decrease Outstanding Debt

↓

Update Budget Statistics

↓

Create Timeline Entry

No special execution engine is required.

Only a different composition.

---

# Extensibility

When introducing a new financial feature, developers should first ask:

Can this feature be expressed using existing Financial Effects?

If the answer is yes,

reuse the existing effects.

Only if a genuinely new type of domain mutation is introduced should a new Financial Effect be created.

This keeps the execution model small, predictable, and reusable.

---

# Deliverables

By the end of this ticket the following artifacts must exist.

- Financial Effects Catalog

- Effect Definitions

- Effect Responsibilities

- Effect Ordering Rules

- Effect Composition Rules

- Financial Operation → Financial Effect Mapping

- Extension Guidelines

---

# Exit Criteria

Every supported Financial Operation must be fully representable as a composition of Financial Effects.

The Financial Engine should never contain feature-specific execution code.

It should execute Financial Effects only.

This establishes Financial Effects as the universal execution language of Mezanya.


# Ticket A6 — Financial Operation Lifecycle

## Goal

Define the complete lifecycle of a Financial Operation from the moment a user initiates it until it becomes part of the financial history.

The objective of this ticket is to ensure that every operation follows the same lifecycle regardless of its origin.

Whether the operation is:

- Manual
- Recurring
- Scheduled
- Generated automatically
- Imported
- Restored from Backup
- Produced by another feature

the lifecycle must remain identical.

Only the source changes.

The execution model never changes.

---

# Why This Ticket Exists

Many financial systems implement different execution paths depending on where an operation originates.

For example:

Manual Expense

↓

One code path

---

Recurring Expense

↓

Different code path

---

Debt Payment

↓

Third code path

---

Subscription

↓

Fourth code path

Over time these paths diverge.

Business rules become duplicated.

Bug fixes become inconsistent.

Mezanya explicitly rejects this architecture.

There is only one lifecycle.

Only one execution pipeline.

Only one Financial Engine.

---

# Operation Sources

Every Financial Operation must originate from exactly one source.

Examples include:

User Interface

Recurring Scheduler

Installment Engine

Subscription Engine

Debt Engine

Loan Engine

Import Process

Backup Restore

Future Automation

Regardless of origin,

every operation enters the same lifecycle.

---

# Financial Operation Lifecycle

Every operation progresses through the following states.

```
Created

↓

Resolved

↓

Validated

↓

Effects Generated

↓

Executing

↓

Committed

↓

Archived
```

If execution fails:

```
Executing

↓

Rollback

↓

Failed
```

The lifecycle is deterministic.

Operations never skip stages.

---

# Stage 1 — Created

The operation has been requested.

No business logic has executed.

No balances have changed.

No aggregates have been modified.

The operation only contains user intent.

---

# Stage 2 — Context Resolved

The Financial Engine collects every aggregate required.

Examples:

Wallet

Jar

Budget

Financial Cycle

Allocation

Debt

Installment

Subscription

Context becomes immutable for the remainder of execution.

---

# Stage 3 — Validation

The engine verifies that execution is possible.

Examples:

Entity exists.

Cycle is active.

Balance is valid.

Currency matches.

Operation is allowed.

No mutations occur.

---

# Stage 4 — Effect Generation

The operation is translated into Financial Effects.

Nothing is executed.

Only the execution plan is created.

This stage determines:

What will change.

Not how it changes.

---

# Stage 5 — Execution

Financial Effects execute sequentially.

Each effect mutates exactly one aggregate.

No aggregate communicates directly with another.

The Financial Engine coordinates every mutation.

---

# Stage 6 — Persistence

Updated aggregates become persistent.

Transaction history is recorded.

Timeline entries are created.

Metadata is stored.

Execution is still considered incomplete.

---

# Stage 7 — Commit

Commit finalizes execution.

The new financial state becomes official.

Only after Commit may other parts of the system observe the new state.

---

# Stage 8 — Archive

Once committed,

the operation becomes part of immutable financial history.

Historical records should never be modified directly.

Future corrections occur through new Financial Operations.

Not by rewriting history.

---

# Editing Operations

Editing is not a special execution mode.

It is another Financial Operation.

Preferred lifecycle:

Reverse Previous Effects

↓

Generate New Effects

↓

Execute

↓

Commit

This guarantees consistency.

The Financial Engine never performs in-place mutations.

---

# Deleting Operations

Deletion should never directly erase financial consequences.

Instead:

Reverse the Financial Effects.

↓

Persist the reversal.

↓

Mark the original operation appropriately.

Whether the original record is physically removed or logically archived depends on persistence strategy.

Business semantics remain identical.

---

# Undo

Undo is simply another Financial Operation.

Its purpose is to reverse previously committed Financial Effects.

Undo must reuse the same execution pipeline.

No dedicated Undo Engine should exist.

---

# Replay

Replay rebuilds financial state by executing historical Financial Operations again.

Replay should only exist for:

Migration

Recovery

Testing

Verification

Normal application usage should rely on Current State.

Not Replay.

---

# Failure Handling

Every failure must occur before Commit.

If execution fails:

Rollback

↓

Restore previous aggregate state

↓

Record failure if required

↓

Return control to the caller

The user must never observe a partially executed operation.

---

# Deliverables

By the end of this ticket the following artifacts must exist.

- Financial Operation State Machine

- Lifecycle Diagram

- Edit Strategy

- Delete Strategy

- Undo Strategy

- Replay Strategy

- Failure Recovery Rules

- Commit Rules

---

# Exit Criteria

Every financial feature supported by Mezanya must reuse exactly the same lifecycle.

No feature may introduce:

- its own execution flow

- its own undo logic

- its own delete logic

- its own validation flow

The lifecycle becomes part of the domain contract.

Every future feature must comply with it.


# Ticket A7 — Read Models & Projections

## Goal

Separate the Write Model (Domain) from the Read Model (Presentation).

The purpose of this ticket is to ensure that the Financial Domain remains focused on business rules while every user-facing representation is generated as a projection.

The Domain owns business truth.

Read Models own presentation.

The two must never be confused.

---

# Why This Ticket Exists

Many systems gradually mix business logic with presentation logic.

Examples include:

- Timeline generation
- Dashboard calculations
- Reports
- Charts
- Notifications
- Widgets

Over time these become coupled to the domain.

Changing the UI then requires changing business logic.

Mezanya explicitly rejects this architecture.

The Domain should describe reality.

Read Models should describe reality for humans.

---

# Core Principle

The Financial Domain answers:

"What is true?"

The Read Model answers:

"How should that truth be presented?"

The Financial Domain never produces UI.

The UI never determines business truth.

---

# Domain vs Projection

Example

Financial Operation

↓

Expense

↓

Financial Engine

↓

Wallet Balance
-350

Allocation Remaining
-350

Statistics Updated

This is Domain State.

---

Projection Builder

↓

Timeline Card

↓

🍔 Food Expense

350 EGP

Cash Wallet

Today - 2:31 PM

The Timeline Card is not part of the Domain.

It is a human-readable projection.

---

# Read Models

The following components are considered Read Models.

## Timeline

Displays chronological financial activity.

Generated from committed Financial Operations.

Never treated as business truth.

---

## Dashboard

Displays summarized financial information.

Examples:

Remaining Budget

Spent This Month

Savings Progress

Financial Health

These values are projections.

Not domain entities.

---

## Reports

Reports summarize historical information.

Examples:

Monthly Spending

Category Analysis

Cash Flow

Budget Performance

Reports never execute business rules.

They consume domain state.

---

## Charts

Charts visualize existing information.

They never define it.

---

## Search

Search indexes financial information.

Indexes are derived data.

Not business entities.

---

## Notifications

Notifications are generated from domain events.

They are not financial events.

Deleting a notification must never affect the domain.

---

## Widgets

Widgets present simplified read models.

Removing a widget never changes business state.

---

# Projection Builder

A dedicated Projection Builder should transform committed domain state into user-facing representations.

Example

Committed Financial Operation

↓

Projection Builder

↓

Timeline

Dashboard

Reports

Charts

Notifications

Widgets

Search Index

The Projection Builder never modifies the domain.

It only observes committed changes.

---

# Business State vs Analytical State

These concepts must remain separate.

Business State includes:

Wallet Balance

Jar Balance

Remaining Allocation

Outstanding Debt

Budget Remaining

These values define reality.

---

Analytical State includes:

Monthly Spending

Top Categories

Average Daily Expense

Budget Utilization %

Most Used Wallet

These values are derived.

They can always be recalculated.

---

# Persistence

Read Models may be:

Generated on demand,

Cached,

Materialized,

or rebuilt.

Their persistence strategy is an implementation detail.

The Domain must never depend on them.

If every Read Model is deleted,

the Financial Domain must remain fully valid.

Every projection should be reproducible from committed domain state.

---

# Architectural Rules

Read Models:

may observe the domain.

may never modify the domain.

The Financial Engine:

never generates UI.

never formats text.

never creates localized strings.

never decides colors or icons.

Presentation belongs entirely to the Read Model layer.

---

# Deliverables

By the end of this ticket the following artifacts must exist.

- Read Model Architecture

- Projection Builder Design

- Timeline Specification

- Dashboard Specification

- Reporting Model

- Notification Model

- Projection Rules

- Domain vs Presentation Boundaries

---

# Exit Criteria

Every screen inside Mezanya must consume a Read Model.

No screen should directly interpret Financial Operations.

No presentation layer should contain business rules.

The Domain remains independent from every visualization layer.


# Ticket A8 — State Management & Consistency Model

## Goal

Define how Mezanya maintains financial consistency throughout the lifetime of the application.

This ticket establishes the official rules governing:

- Current State
- Historical Transactions
- Editing
- Deleting
- Undo
- Rebuilding
- Synchronization
- Recovery

The objective is to guarantee that the financial state always remains internally consistent regardless of how many features are added in the future.

---

# Why This Ticket Exists

Financial systems eventually face questions such as:

What happens if a transaction is edited?

What happens if it is deleted?

Can balances become inconsistent?

Should balances be recalculated?

Should history be rewritten?

Should current state always be derived?

Without a formal consistency model, every feature starts inventing its own solution.

Mezanya must define these rules once.

Every feature must follow them.

---

# Core Principle

The Current State represents the official financial reality.

Transaction History represents the explanation of how that reality was reached.

These two concepts have different responsibilities.

Current State exists to answer:

"What is true now?"

Transaction History exists to answer:

"How did we get here?"

Neither replaces the other.

---

# Current State

Current State is the operational state of every financial aggregate.

Examples:

Wallet Balance

Jar Balance

Remaining Allocation

Outstanding Debt

Current Installment

Budget Summary

Current Financial Cycle

Every business decision should operate on Current State.

Not by replaying history.

---

# Historical Transactions

Historical Transactions exist for:

Audit

Explanation

Review

Reporting

Timeline

Analytics

History is not optimized for execution.

Current State is.

---

# Updating Current State

The Financial Engine is the only component allowed to modify Current State.

No UI.

No Repository.

No Aggregate.

No Background Process.

No Import Tool.

Every change must originate from a committed Financial Operation.

---

# Editing Operations

Editing should never directly mutate financial state.

Preferred model:

Reverse Previous Financial Effects

↓

Generate New Financial Effects

↓

Execute

↓

Commit

This guarantees deterministic execution.

Every edit becomes another financial operation.

Never an in-place mutation.

---

# Deleting Operations

Deleting a Financial Operation should never leave orphaned financial state.

Preferred model:

Reverse Financial Effects

↓

Commit Reverse Operation

↓

Archive Original Operation

Physical deletion should only occur for technical reasons.

Business history should remain explainable.

---

# Undo

Undo is not a UI feature.

Undo is another Financial Operation.

Its responsibility is:

Generate reverse effects.

Execute them.

Commit them.

Undo must reuse exactly the same Financial Engine.

---

# Replay

Replay exists only for exceptional situations.

Examples:

Migration

Recovery

Verification

Testing

Data Repair

Replay is not part of normal application behavior.

The application should always operate using Current State.

Replay is a maintenance capability.

Not a runtime dependency.

---

# Consistency Rules

Every committed operation must satisfy:

Every affected aggregate updated.

Every Financial Effect completed.

Every persistence step succeeded.

Every projection synchronized.

If any step fails:

Rollback everything.

No partial consistency is allowed.

---

# Reconciliation

Reality may occasionally differ from recorded state.

Examples:

Manual wallet correction.

Imported balances.

Recovered backup.

External adjustments.

These situations should never bypass the Financial Engine.

Instead,

they become Adjustment Financial Operations.

The Domain remains consistent.

---

# State Recovery

If Current State becomes corrupted,

it must be recoverable.

Recovery strategies may include:

Replay

Backup Restore

Consistency Verification

Repair Operations

Recovery mechanisms belong to infrastructure.

Not business logic.

---

# Synchronization

Future synchronization mechanisms must synchronize:

Current State

Committed Operations

Metadata

Synchronization must never execute business logic independently.

Remote changes should always enter the Financial Engine.

Never modify aggregates directly.

---

# Versioning

The domain model will evolve.

Future versions may introduce:

New entities

New Financial Effects

New operation families

Migration rules should preserve business semantics.

Never database structure alone.

---

# Deliverables

By the end of this ticket the following must exist.

- State Management Model

- Current State Rules

- Edit Strategy

- Delete Strategy

- Undo Strategy

- Replay Strategy

- Recovery Strategy

- Synchronization Rules

- Consistency Rules

- Migration Principles

---

# Exit Criteria

Every possible state transition inside Mezanya must be explainable through the same consistency model.

No feature may invent its own edit behavior.

No feature may invent its own delete behavior.

No feature may maintain independent financial state.

Current State remains the single operational truth.

Every committed Financial Operation must leave the domain in a valid and consistent state.


# Ticket A9 — Persistence, Synchronization & Recovery Architecture

## Goal

Design the persistence architecture of Mezanya based on domain semantics rather than storage technology.

Persistence is responsible for preserving the domain.

It must never define the domain.

This ticket establishes the architectural rules governing:

- Local Persistence
- Cloud Synchronization
- Backup
- Restore
- Migration
- Conflict Resolution
- Versioning
- Disaster Recovery

Every infrastructure feature must preserve business meaning without introducing new business rules.

---

# Why This Ticket Exists

Financial applications eventually need to answer difficult questions.

Examples:

What happens if the user restores a backup?

What happens if two devices modify the same wallet?

How should cloud synchronization merge data?

Can historical operations be rewritten?

How should schema migrations behave?

Without formal persistence rules, every infrastructure feature begins making business decisions.

Infrastructure must never own business logic.

The Domain always remains the source of truth.

---

# Core Principle

Persistence records the Domain.

Persistence never defines the Domain.

Database schema,

JSON structures,

Cloud documents,

Indexes,

Caches,

or Backup files

must all be consequences of the domain model.

Never the opposite.

---

# Persistence Responsibilities

Persistence is responsible only for:

Saving

Loading

Versioning

Synchronization

Recovery

Migration

Caching

Replication

Nothing more.

It must never:

calculate balances,

execute Financial Effects,

modify aggregates,

or apply business rules.

---

# Local Persistence

Local storage represents the authoritative copy currently used by the running application.

The application executes exclusively against local domain state.

Cloud storage is never treated as the execution database.

Synchronization always occurs after committed domain changes.

---

# Cloud Synchronization

Cloud synchronization transfers committed domain state between devices.

Synchronization must never execute business logic.

Instead:

Receive Changes

↓

Validate Version

↓

Convert Into Domain Changes

↓

Commit

↓

Project

The synchronization layer never modifies aggregates directly.

Every remote modification must enter the Financial Engine.

---

# Backup

A Backup is a complete snapshot of business state.

It exists for recovery.

Not execution.

A backup should preserve:

Current State

Committed Operations

Configuration

Metadata

User Preferences

Version Information

Backups should never contain implementation-specific assumptions.

---

# Restore

Restore should reconstruct the exact business state that existed when the backup was created.

Restoring data should never bypass domain validation.

If migration is required,

migration occurs before domain activation.

---

# Migration

Every schema migration must preserve business semantics.

Changing storage structure must never change business meaning.

Migration should answer:

What changed in storage?

without changing:

What the financial domain represents.

---

# Conflict Resolution

Future synchronization conflicts should be resolved according to business consistency.

Never according to:

Timestamp alone

Database ordering

Storage format

Conflict resolution belongs to the domain.

Storage merely provides conflicting versions.

---

# Versioning

Every persisted dataset should contain:

Domain Version

Schema Version

Application Version

Migration Version

These versions exist to support future compatibility.

Business meaning must remain stable across versions.

---

# Disaster Recovery

Recovery should support:

Corrupted Local Database

Failed Synchronization

Interrupted Backup

Partial Restore

Migration Failure

The recovery process should restore the last valid business state.

Never an inconsistent one.

---

# Infrastructure Independence

Persistence technology must remain replaceable.

Examples:

SQLite

Hive

Isar

Firestore

Supabase

PostgreSQL

Future Storage Engines

Changing persistence technology must not require changes to the Domain Model.

---

# Deliverables

By the end of this ticket the following artifacts must exist.

- Persistence Architecture

- Backup Model

- Restore Strategy

- Synchronization Model

- Conflict Resolution Strategy

- Migration Strategy

- Versioning Strategy

- Infrastructure Boundaries

---

# Exit Criteria

The Mezanya domain should remain fully operational regardless of:

database technology,

cloud provider,

backup format,

or synchronization mechanism.

Infrastructure becomes an implementation detail.

Business meaning remains unchanged.


# Ticket A10 — Development Constitution

## Goal

Establish the immutable architectural constitution that governs every future modification to Mezanya.

This document is not a coding guideline.

It is not a style guide.

It is not an implementation checklist.

It is the constitutional contract of the project.

Every future feature,

bug fix,

refactoring,

migration,

or architectural change

must comply with these principles.

If implementation and the constitution conflict,

the implementation must change.

The constitution does not.

---

# Why This Ticket Exists

Every successful software system gradually accumulates technical debt.

The primary reason is not poor code.

It is architectural inconsistency.

Developers solve today's problem.

Future developers solve tomorrow's problem differently.

Eventually the system contains multiple execution models,

multiple business languages,

multiple architectural styles,

and duplicated business rules.

Mezanya must prevent this from happening.

The architecture should become harder to break as the project grows.

Not easier.

---

# Constitutional Principles

The following principles are immutable unless the Domain itself changes.

---

## Principle 1

Business Meaning Always Comes First.

Never begin from:

database

API

UI

repository

widget

storage

Always begin from:

Business Problem

↓

Domain Model

↓

Architecture

↓

Persistence

↓

Implementation

---

## Principle 2

The Domain Owns The Business.

Infrastructure never owns business logic.

Repositories never own business logic.

UI never owns business logic.

Persistence never owns business logic.

Only the Domain owns financial rules.

---

## Principle 3

There Is Only One Financial Engine.

Every Financial Operation must execute through exactly one execution engine.

No feature-specific engines are allowed.

Examples that must never exist:

Expense Engine

Debt Engine

Jar Engine

Transfer Engine

Subscription Engine

Recurring Engine

Instead:

One Financial Engine.

Many Financial Operations.

---

## Principle 4

Financial Operations Are The Only Source Of Financial Change.

Every financial modification must originate from a Financial Operation.

No aggregate may change itself spontaneously.

No UI may modify balances.

No repository may mutate business state.

No infrastructure service may bypass the engine.

---

## Principle 5

Financial Effects Are The Execution Language.

Financial Operations describe intent.

Financial Effects describe mutations.

The engine executes Financial Effects.

Never feature-specific logic.

---

## Principle 6

Aggregate Independence.

Aggregates never modify each other.

Cross-aggregate coordination belongs exclusively to the Financial Engine.

Every aggregate protects only its own invariants.

---

## Principle 7

Current State Is Operational Truth.

Current State represents financial reality.

Historical Operations explain reality.

Read Models present reality.

These three responsibilities must remain separate.

---

## Principle 8

Read Models Never Own Business Rules.

Timeline

Dashboard

Reports

Charts

Analytics

Notifications

Widgets

Search

All of them are projections.

Removing them must never affect business behavior.

---

## Principle 9

Persistence Is An Implementation Detail.

Changing storage technology must never change business meaning.

Changing database schema must never require rewriting the Domain.

---

## Principle 10

Every Feature Is Composed.

Salary

Debt

Loan

Installment

Subscription

Recurring Transactions

Goals

Investments

Future Features

None of these should introduce new architectural concepts unless absolutely necessary.

Instead,

they should compose existing domain concepts.

---

## Principle 11

Architecture Before Optimization.

Performance optimizations must never weaken business consistency.

Caching.

Indexes.

Materialized Views.

Read Models.

Synchronization.

All optimizations must preserve domain correctness.

Correctness is always more important than speed.

---

## Principle 12

Business Semantics Before Persistence.

Before designing storage,

always answer:

What happened?

Why did it happen?

What changed?

Which aggregate changed?

What business rule caused the change?

Only afterwards decide:

How should this be stored?

---

## Principle 13

Every Architectural Decision Must Be Explainable.

Every important architectural decision should answer:

Why does this exist?

Which business problem does it solve?

Which principle does it protect?

Which future problem does it prevent?

If these questions cannot be answered,

the decision should be reconsidered.

---

# Architectural Review Checklist

Every Pull Request,

Feature,

or Refactoring

should be evaluated against the following questions.

Does this introduce new business terminology?

Does it duplicate existing concepts?

Does it bypass the Financial Engine?

Does it violate Aggregate boundaries?

Does it introduce feature-specific execution?

Does it weaken Current State?

Does it introduce hidden coupling?

Does it move business logic outside the Domain?

If any answer is Yes,

the change should be rejected until the architecture is reconsidered.

---

# Long-Term Vision

The objective of Mezanya is not only to become a feature-rich finance application.

The objective is to become a financial platform whose architecture remains understandable,

predictable,

and extensible

even after years of continuous development.

Features will evolve.

Technology will evolve.

Storage engines will evolve.

UI frameworks will evolve.

The Domain should remain stable.

This constitution exists to preserve that stability.

---

# Deliverables

By the end of this ticket the following should exist.

- Development Constitution

- Architectural Review Checklist

- Immutable Design Principles

- Contribution Rules

- Future Extension Guidelines

---

# Exit Criteria

Phase A is considered complete only when:

- The ubiquitous language is stable.

- Aggregate boundaries are finalized.

- Financial Operations are fully classified.

- Financial Engine architecture is complete.

- Financial Effects are standardized.

- Operation lifecycle is finalized.

- Read Models are separated from the Domain.

- Persistence follows the Domain.

- Development Constitution is approved.

At this point, the Mezanya Domain Model becomes the official source of truth.

Every subsequent phase should implement the Domain.

No future implementation should redefine it.


Phase 0
Domain Foundation
        │
        ▼
Business Rules
        │
        ▼
Architecture
        │
        ▼
Implementation Plan
        │
        ▼
Backend Reconstruction
        │
        ▼
Frontend Adaptation
        │
        ▼
Testing
        │
        ▼
Release



# Ticket A11 — Money Model & Value Objects

## Goal

Establish the official financial value model used throughout Mezanya.

Every financial calculation performed by the system must rely on the same domain representation of money.

Money is not merely a numeric value.

It represents one of the most fundamental concepts in the financial domain.

Incorrect money modeling eventually leads to:

- inconsistent balances
- rounding errors
- incorrect reports
- synchronization conflicts
- migration issues
- future multi-currency limitations

For this reason, the Money Model must be finalized before backend reconstruction begins.

---

# Why This Ticket Exists

Almost every entity inside Mezanya owns, references, or manipulates money.

Examples:

Wallet

Jar

Allocation

Budget

Debt

Installment

Loan

Subscription

Goal

Income

Expense

Every one of these depends on the same financial value model.

If different parts of the application interpret money differently, the entire domain becomes inconsistent.

---

# Core Principle

Money is a Domain Concept.

It is not:

double

int

String

database column

JSON number

Money exists independently of how it is stored.

Storage formats are implementation details.

---

# Money As A Value Object

Money should be treated as an immutable Value Object.

It represents:

Amount

+

Currency

Two Money values are equal only if both their amount and currency are equal.

Money never owns identity.

Money owns value only.

---

# Candidate Structure

The domain analysis should determine whether Money consists of:

Amount

Currency

Precision

Scale

Rounding Rules

or whether some of these belong elsewhere.

The final structure should be explicitly documented.

---

# Financial Arithmetic

The Money Model must define:

Addition

Subtraction

Comparison

Multiplication

Division

Negation

Absolute Value

Every arithmetic rule should be deterministic.

No implicit conversions.

No hidden rounding.

---

# Currency Model

Determine whether the first version of Mezanya officially supports:

Single Currency

or

Multiple Currencies.

Even if the application initially supports only one currency,

the domain should explicitly document this assumption.

Future support for multiple currencies should not require redesigning the Money Model.

---

# Precision

Determine:

Maximum supported precision.

Storage precision.

Display precision.

Calculation precision.

Financial correctness always takes precedence over display formatting.

---

# Rounding Rules

Every rounding rule must be documented.

Examples include:

Display rounding.

Calculation rounding.

Percentage calculations.

Installment division.

Goal progress.

Reports.

Rounding should never depend on UI.

---

# Zero Money

Determine the semantic meaning of:

Zero Money.

Examples:

Empty Wallet.

Completed Debt.

Unused Allocation.

Closed Goal.

Zero is a valid financial value.

It should never be confused with Null.

---

# Negative Money

Determine whether the following are valid:

Negative Wallet Balance.

Negative Jar Balance.

Negative Allocation.

Negative Debt.

Negative Planned Budget.

Each aggregate may enforce different business rules.

The Money Model itself should remain neutral.

---

# Percentage

Determine whether Percentage is another Value Object.

Examples:

Budget Usage

Savings Progress

Debt Completion

Goal Completion

Percentages should never replace Money.

They describe relationships between Money values.

---

# Candidate Value Objects

This ticket should also identify additional immutable Value Objects.

Possible candidates include:

Money

Currency

Percentage

Financial Period

Date Range

Recurring Pattern

Installment Schedule

Target Amount

Progress

Exchange Rate

The list should be validated through domain analysis.

Not implementation convenience.

---

# Deliverables

By the end of this ticket the following artifacts must exist.

- Money Model

- Currency Model

- Precision Rules

- Arithmetic Rules

- Rounding Rules

- Value Object Catalog

- Equality Rules

- Comparison Rules

---

# Exit Criteria

Every financial calculation performed anywhere inside Mezanya must use the same Money Model.

No aggregate may define its own arithmetic.

No feature may introduce its own financial representation.

Money becomes one of the foundational Value Objects of the Mezanya Domain.


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



# Phase C — Validation & Certification

> Status: Planning
>
> Prerequisite:
>
> Phase 0 (Domain Foundation) completed.
>
> Phase B (Backend Reconstruction) completed.
>
> Objective:
>
> Verify that the final implementation faithfully represents the Domain Bible.
>
> This phase is not about fixing bugs.
>
> It is about certifying architectural correctness.

---

# Mission Statement

A feature is not considered complete because it works.

A feature is complete only when:

- it behaves correctly,
- it follows the Domain,
- it respects the architecture,
- it introduces no architectural debt.

Phase C exists to prove those four conditions.

---

# Why This Phase Exists

Software projects usually stop after implementation.

Testing verifies functionality.

QA verifies user experience.

But nobody verifies architecture.

As a result,

the architecture slowly diverges from the implementation.

Phase C prevents this.

The implementation must continuously prove that it still follows the Domain Bible.

---

# Certification Levels

Every subsystem must pass four certification levels.

---

## Level 1 — Domain Certification

Question:

Does this feature behave exactly as defined by the Domain Bible?

Examples:

Expense

Income

Wallet Transfer

Jar Funding

Debt Payment

Subscription

Installment

Recurring Transaction

Every business rule must match the documented Domain.

---

## Level 2 — Architectural Certification

Question:

Does this feature respect architectural boundaries?

Examples:

Does it bypass the Financial Engine?

Does it violate Aggregate ownership?

Does it duplicate Financial Effects?

Does it introduce feature-specific execution?

Does it modify Current State directly?

If any answer is Yes,

certification fails.

---

## Level 3 — Consistency Certification

Question:

Can this feature ever leave the financial state inconsistent?

Examples:

Partial execution.

Incorrect rollback.

Incorrect synchronization.

Incorrect rebuilding.

Invalid projections.

Missing Financial Effects.

Every execution path must preserve consistency.

---

## Level 4 — Future Compatibility

Question:

Will this implementation naturally support future features?

Examples:

Multi-currency.

Investments.

Shared Wallets.

Cloud Collaboration.

Advanced Reports.

Future Budget Types.

The architecture should absorb future changes.

Not resist them.

---

# Feature Certification

Every financial feature should receive an independent certification report.

Minimum feature list:

Wallets

Budgets

Financial Cycles

Allocations

Jars

Goals

Income

Expenses

Transfers

Recurring Transactions

Debt

Loans

Installments

Subscriptions

Statistics

Timeline

Reports

Dashboard

Backup

Restore

Synchronization

Import

Export

Notifications

Widgets

Search

Every feature must demonstrate compliance.

---

# Certification Checklist

Each feature should answer:

Does it introduce new business terminology?

Does it duplicate existing concepts?

Does it reuse Financial Operations?

Does it reuse Financial Effects?

Does it execute through the Financial Engine?

Does it respect Aggregate boundaries?

Does it preserve Current State?

Does it produce valid Read Models?

Does it remain independent from infrastructure?

Does it follow the Domain Bible?

If any answer is No,

the feature returns to reconstruction.

---

# Architectural Drift Detection

One objective of Phase C is identifying Architectural Drift.

Architectural Drift occurs when implementation slowly diverges from the Domain.

Examples:

Business logic appears inside UI.

Repositories perform calculations.

Widgets modify balances.

Background jobs bypass the Financial Engine.

Infrastructure creates Financial Effects.

These situations should be detected immediately.

---

# Performance Certification

Performance optimization must never violate Domain principles.

Verify:

Caching

Lazy Loading

Materialized Views

Synchronization

Indexes

Batch Operations

Background Processing

Every optimization must preserve business correctness.

---

# Recovery Certification

Verify:

Backup

Restore

Migration

Replay

Undo

Rollback

Conflict Resolution

State Recovery

Every recovery path must preserve financial integrity.

---

# Read Model Certification

Verify:

Timeline

Dashboard

Reports

Charts

Notifications

Widgets

Analytics

Search

Every Read Model must remain a projection.

Never business truth.

---

# Infrastructure Certification

Verify that replacing infrastructure does not affect business behavior.

Example replacements:

SQLite → Isar

Firestore → Supabase

Hive → PostgreSQL

Cloud Provider A → Provider B

Domain behavior must remain identical.

---

# Certification Report

Every subsystem should produce a report containing:

Domain Compliance

Architectural Compliance

Consistency Score

Performance Score

Future Readiness

Known Risks

Outstanding Debt

Recommended Improvements

This report becomes part of the project documentation.

---

# Completion Criteria

Phase C is complete only when:

Every feature passes Domain Certification.

Every subsystem passes Architectural Certification.

No Architectural Drift remains.

No duplicated business rules remain.

Every Financial Operation executes correctly.

Every Aggregate protects its invariants.

Every Read Model is reproducible.

Current State remains consistent.

The implementation faithfully represents the Domain Bible.

---

# Final Certification

The Mezanya project is considered architecturally complete only when:

The Domain Bible defines the business.

The backend implements the Domain.

The frontend consumes the Domain.

The infrastructure preserves the Domain.

The projections visualize the Domain.

Every layer has one responsibility.

Every responsibility has one owner.

Every owner follows the same ubiquitous language.

At this point,

the architecture becomes self-consistent.

Future development becomes evolutionary rather than revolutionary.

The system no longer grows by introducing exceptions.

It grows by extending the Domain.




