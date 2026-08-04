# Mezanya Architecture & Product Specification (MAPS)

# Volume 12 --- Complete AI Implementation Playbook

## Purpose

This volume defines the mandatory execution process for any AI agent
working on Mezanya.

It complements the architectural volumes by defining *how work must be
executed*, not merely *what the architecture is*.

------------------------------------------------------------------------

# Before Writing Code

An AI agent must always complete this checklist:

-   Read every MAPS volume.
-   Read the current implementation.
-   Identify the owning domain.
-   Identify affected domains.
-   Verify architectural boundaries.
-   Verify whether migration is required.

If any of these steps are skipped, implementation must not begin.

------------------------------------------------------------------------

# Required Workflow

1.  Understand the business problem.
2.  Map it to one business concept.
3.  Find the owning domain.
4.  Verify no other domain already owns it.
5.  Design the smallest valid change.
6.  Implement incrementally.
7.  Compile.
8.  Run analysis.
9.  Review architectural impact.
10. Commit independently.

------------------------------------------------------------------------

# Decision Tree

Question 1

Does this feature introduce a new business concept?

YES

→ New domain or extension.

NO

→ Extend the existing owner.

------------------------------------------------------------------------

Question 2

Does this feature modify financial truth?

YES

Never implement inside UI.

Never implement inside Cubit.

Use the correct domain.

NO

Continue.

------------------------------------------------------------------------

Question 3

Does this feature modify only metadata?

YES

Never create financial transactions.

Never modify balances.

------------------------------------------------------------------------

# AI Review Checklist

Before finishing any task verify:

-   Business ownership preserved.
-   No duplicate rules.
-   No hidden coupling.
-   No direct cross-domain mutation.
-   Existing financial behaviour unchanged.
-   Documentation still valid.

------------------------------------------------------------------------

# Forbidden AI Behaviors

Never:

-   Guess business rules.
-   Invent workflows.
-   Rename concepts without updating MAPS.
-   Introduce helper methods that hide architectural problems.
-   Add convenience logic inside AppCubit.
-   Let Widgets contain business decisions.

------------------------------------------------------------------------

# Incremental Refactoring

Every refactor must leave the repository in a working state.

Never leave:

-   broken compilation
-   failing analysis
-   half-complete migrations
-   inconsistent serialization

------------------------------------------------------------------------

# Migration Discipline

When replacing legacy code:

1.  Introduce the new implementation.
2.  Validate.
3.  Switch reads.
4.  Switch writes.
5.  Remove legacy.

Never reverse this order.

------------------------------------------------------------------------

# Commit Discipline

Each commit should represent one architectural step only.

Good examples:

-   Introduce Distribution Entity
-   Add Distribution Validator
-   Migrate Storage
-   Wire Application Layer
-   Replace Legacy UI

Bad examples:

-   Massive mixed refactor
-   UI + Domain + Migration + Cleanup together

------------------------------------------------------------------------

# Architectural Questions

Whenever uncertain, ask:

Who owns this?

Who should NOT know this?

Can this responsibility move to its rightful owner?

Is this metadata or financial truth?

Am I changing behaviour or only implementation?

------------------------------------------------------------------------

# Long-Term Objective

The project should eventually become understandable without chat
history.

A future AI should only need:

-   MAPS
-   Source code

Nothing else.

The repository itself must become the documentation.

------------------------------------------------------------------------

**END OF VOLUME 12**
