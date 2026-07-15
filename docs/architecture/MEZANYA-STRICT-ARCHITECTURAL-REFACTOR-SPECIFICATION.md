<!--
Status: Implementation
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# MEZANYA — STRICT ARCHITECTURAL REFACTOR SPECIFICATION (PRODUCTION SAFE)

## Mission

You are refactoring a **large production-grade Flutter financial management application**.

This is **NOT** a feature request.

This is **NOT** a bug fixing task.

This is **NOT** a performance optimization task.

This is **NOT** a redesign task.

Your only responsibility is to improve the architecture, modularity, maintainability, readability, and long-term scalability of the codebase **without changing any runtime behavior**.

This project already works in production.

Treat every existing behavior as intentional unless explicitly instructed otherwise.

If architecture quality conflicts with preserving behavior:

> **Behavior preservation ALWAYS wins.**

---

# PRIMARY OBJECTIVE

Transform the project into a clean, scalable architecture while guaranteeing:

* identical UI
* identical business logic
* identical calculations
* identical financial behavior
* identical database behavior
* identical navigation
* identical animations
* identical runtime output

The application after refactoring must be visually and functionally indistinguishable from the original.

---

# ZERO BEHAVIOR CHANGE POLICY

This is the most important rule.

The first refactoring phase MUST introduce **ZERO behavior changes**.

No bug fixes.

No logic fixes.

No UX improvements.

No design improvements.

No performance optimizations.

No "better implementation".

No cleanup that changes execution.

Move code only.

---

# ABSOLUTE NON-NEGOTIABLE RULES

Never:

* Fix bugs
* Improve algorithms
* Improve calculations
* Improve architecture by changing behavior
* Rewrite business logic
* Rewrite financial logic
* Rewrite conditions
* Rewrite filtering
* Rewrite loops
* Rewrite execution order
* Rewrite state management
* Optimize code
* Simplify logic
* Introduce clever solutions
* Change naming conventions
* Rename public APIs
* Modify serialization
* Modify Firestore
* Modify repositories
* Modify Cubits
* Modify processors
* Modify side effects
* Modify calculations
* Modify ordering
* Modify navigation
* Modify widget hierarchy
* Modify animations
* Modify spacing
* Modify typography
* Modify colors
* Modify icons
* Modify layouts

Even if the existing implementation appears incorrect.

Current implementation is the source of truth.

---

# EXISTING IMPLEMENTATION IS AUTHORITATIVE

Never assume business rules.

Never redesign financial workflows.

Never infer missing logic.

Never "improve" unclear code.

Never replace old implementations with modern alternatives.

If something looks strange:

Preserve it exactly.

Move it only.

---

# FINANCIAL SAFETY

This is a financial application.

Financial correctness is more important than architecture.

Never modify any financial rule.

Financial behavior must remain byte-for-byte identical.

---

# FINANCIAL COMPONENTS THAT MUST NEVER CHANGE

Wallet balances

Savings jar balances

Budget balances

Allocation balances

Monthly summaries

Remaining income calculations

Recurring transactions

Debt calculations

Installment calculations

Subscriptions

Transaction processing

Budget processing

Wallet processing

Jar processing

Reverse transaction logic

Apply transaction logic

Notification generation

History generation

Any arithmetic operation

Any condition affecting balances

Any execution order

---

# TRANSACTION PROCESSOR

TransactionProcessor is core financial infrastructure.

Allowed:

Move methods

Split file

Extract helper methods

Extract documentation

Forbidden:

Changing logic

Changing order

Changing conditions

Changing arithmetic

Changing wallet updates

Changing jar updates

Changing budget updates

Changing recurring updates

Changing side effects

---

# APPCUBIT

Do NOT redesign AppCubit.

Do NOT replace AppCubit.

Do NOT migrate to another state management solution.

Allowed:

Extract methods into dedicated services.

Extract widgets.

Extract helpers.

Extract models.

Keep the public API identical.

---

# FIRESTORE

Never modify:

Collections

Documents

Field names

Serialization

Deserialization

Repositories

Queries

Indexes

Structure

Database behavior

---

# ALLOWED OPERATIONS

Only these operations are allowed.

Extract Widget

Extract Service

Extract Helper

Extract Utility

Extract Formatter

Extract Constants

Extract Models

Extract Domain Classes

Extract Validation

Split Files

Group Related Code

Improve Folder Organization

Add Documentation

Nothing else.

---

# PROJECT ARCHITECTURE

Every feature should gradually become:

```
feature/

domain/

entities/

models/

services/

utils/

presentation/

screens/

widgets/

controllers/
```

Controllers are optional.

Services must contain business logic.

Widgets must contain UI only.

Screens must orchestrate only.

---

# SCREEN RESPONSIBILITIES

Screens should ONLY:

Build widgets

Navigation

Dialogs

Bottom sheets

Dependency wiring

State observation

User interaction

Screens must NEVER:

Calculate totals

Filter transactions

Calculate statistics

Build business models

Transform entities

Implement business rules

Perform financial calculations

---

# WIDGET RULES

Widgets are presentation only.

Widgets must not know business rules.

Maximum preferred size:

150–300 lines.

Split only by responsibility.

Do not redesign UI.

Do not combine widgets.

Keep identical widget tree.

---

# SERVICE RULES

Every service must have exactly one responsibility.

Examples:

BudgetMetricsService

BudgetTransactionFilter

WalletStatisticsService

BudgetCycleService

RecurringService

Bad examples:

Helper

Utils

Manager

EverythingService

CommonService

GlobalService

---

# MODEL RULES

Models must be immutable.

No side effects.

No calculations.

No business rules.

Represent data only.

---

# CONSTANTS

Extract:

Magic numbers

Magic durations

Magic colors

Magic padding

Magic radius

Magic strings

Repeated values

Never change values.

Only relocate them.

---

# UTILITIES

Utilities are allowed only for:

Formatting

Date formatting

Currency formatting

String formatting

Color helpers

Never move business rules into utilities.

---

# BUSINESS RULES

Business rules belong ONLY inside domain services.

Never inside:

Widgets

Screens

Helpers

Utilities

Models

---

# EXECUTION ORDER

Execution order is part of business logic.

Never reorder:

if statements

switch cases

method calls

balance updates

database writes

notification creation

history creation

reverse/apply order

---

# SIDE EFFECTS

Never remove

Never reorder

Never delay

Never merge

Any side effect.

Especially:

wallet updates

jar updates

budget updates

notifications

history

---

# DUPLICATED CODE

Do NOT remove duplicated code immediately.

Some duplication is intentional.

Merge duplicates ONLY if:

Same input

Same output

Same side effects

Same execution order

Same behavior

Otherwise preserve both copies.

---

# NO SMART OPTIMIZATIONS

Never:

Replace loops

Replace fold()

Replace reduce()

Replace conditions

Use caching

Use memoization

Use lazy evaluation

Replace imperative code with functional code

Rewrite expressions

Simplify branching

Optimize performance

---

# DEPENDENCIES

Do NOT introduce:

Riverpod

Provider

Redux

MobX

GetX

Bloc replacement

Dependency Injection frameworks

Reflection

Macros

Code generators

Build Runner generated architecture

Keep current technology stack.

---

# FILE SIZE TARGETS

Preferred targets:

Widget

150–300 lines

Screen

300–600 lines

Service

100–300 lines

Model

Under 150 lines

Utility

Under 200 lines

Never create another giant file.

---

# REFACTOR STRATEGY

Work FEATURE by FEATURE.

Never refactor the entire project at once.

Example order:

Budget

Wallets

Transactions

Notifications

Home

Settings

More

Complete one feature entirely before starting another.

---

# WITHIN EACH FEATURE

Phase 1

Extract Widgets only.

No logic movement.

Compile.

Verify.

Commit.

---

Phase 2

Extract Models.

Compile.

Verify.

Commit.

---

Phase 3

Extract Services.

Move code exactly.

Compile.

Verify.

Commit.

---

Phase 4

Extract Helpers.

Compile.

Verify.

Commit.

---

Phase 5

Remove duplication.

Only after verification.

Compile.

Verify.

Commit.

---

# COMPILATION POLICY

After EVERY logical change:

flutter analyze

must succeed.

Project must compile.

Application must launch.

No runtime exceptions.

No analyzer errors.

No warnings introduced.

---

# COMMIT POLICY

Exactly ONE logical responsibility per commit.

Examples:

Extract Hero Summary Widget

Extract Month Bar

Extract Allocation Section

Extract Budget Metrics Service

Extract Wallet Details Widget

Extract Notification Tile

Never combine unrelated changes.

---

# DOCUMENTATION

Every new file must contain documentation explaining:

Purpose

Responsibility

Dependencies

Why this file exists

What it must never do

---

# FINANCIAL SAFETY CHECK

If any financial behavior is unclear:

STOP.

Do NOT guess.

Do NOT redesign.

Do NOT optimize.

Preserve the implementation exactly.

Document uncertainty.

Continue only with structural refactoring.

---

# CODE EXTRACTION POLICY

Extraction means:

Move existing implementation.

NOT rewrite implementation.

Keep:

same variables

same conditions

same arithmetic

same loops

same ordering

same side effects

same output

---

# UI SAFETY

The following must remain visually identical:

Spacing

Padding

Margins

Fonts

Icons

Animations

Transitions

Layouts

Scroll behavior

Dialogs

Bottom sheets

Navigation

Widget tree

Do not redesign anything.

---

# OUTPUT AFTER EVERY COMPLETED STEP

Always provide:

Files Created

Files Modified

Responsibilities Extracted

Commits Recommended

Remaining Work

Verification Performed

Behavior Changes

Behavior Changes must always be:

NONE

---

# FINAL VALIDATION CHECKLIST

Before considering the refactor complete, verify:

✓ Project compiles

✓ flutter analyze passes

✓ No runtime exceptions

✓ No new warnings

✓ Every screen looks identical

✓ Every interaction behaves identically

✓ Every animation behaves identically

✓ Every calculation returns identical values

✓ Every transaction behaves identically

✓ Every wallet balance is identical

✓ Every jar balance is identical

✓ Every budget value is identical

✓ Every notification behaves identically

✓ Every recurring transaction behaves identically

✓ Every Firestore document remains identical

✓ Every serialization output remains identical

✓ Every Cubit behaves identically

✓ Every public API remains identical

If ANY of the above changes, the refactor has FAILED.

---

# IMPORTANT MEZANYA-SPECIFIC REQUIREMENTS

This project contains complex financial workflows.

Some business logic may appear duplicated intentionally.

Some execution order may appear unusual intentionally.

Some financial methods may appear overly verbose intentionally.

DO NOT simplify them.

DO NOT redesign them.

DO NOT merge them.

DO NOT replace them.

Financial correctness always overrides architectural elegance.

Architecture exists to serve the financial system—not the other way around.

If there is ever uncertainty, preserve the existing implementation exactly and move it only.

**Your success is measured by structural improvement alone. Any behavioral change, however small, is considered a failure.**
