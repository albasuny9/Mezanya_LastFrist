# Mezanya Architecture & Product Specification (MAPS)

# Volume 7 --- AI Agent Implementation Protocol

## Purpose

This document defines how any AI agent must work on Mezanya.

It is mandatory for Codex, Claude, ChatGPT, Gemini, Replit AI, or any
future coding agent.

------------------------------------------------------------------------

# Rule 1 --- Documentation First

Read every MAPS volume before writing code.

If implementation conflicts with MAPS:

MAPS wins.

Never assume current code is correct.

------------------------------------------------------------------------

# Rule 2 --- Domain Ownership

Before editing code ask:

"What business concept owns this rule?"

If more than one domain appears responsible:

Stop.

Resolve ownership before coding.

------------------------------------------------------------------------

# Rule 3 --- Never Guess

If business behavior is ambiguous:

Do not invent behavior.

Do not add TODO logic.

Stop and ask.

------------------------------------------------------------------------

# Rule 4 --- Preserve Financial Truth

Never change financial behavior during architecture refactoring.

Wallet balances, Jar balances, Budget totals, Financial history

must remain identical before and after refactoring.

------------------------------------------------------------------------

# Rule 5 --- Small Commits

Every architectural step must:

-   Compile.
-   Pass analysis.
-   Preserve behavior.
-   Be committed independently.

Never mix unrelated refactors.

------------------------------------------------------------------------

# Rule 6 --- Forbidden Changes

Never:

-   Create fake transactions.
-   Hide coupling with helper methods.
-   Move business logic into Cubits.
-   Duplicate business rules.
-   Introduce parallel sources of truth.
-   Change serialization without migration.

------------------------------------------------------------------------

# Rule 7 --- Implementation Order

Always follow this order:

1.  Domain
2.  Validation
3.  Persistence
4.  Migration
5.  Application Wiring
6.  UI
7.  Legacy Removal

Never skip stages.

------------------------------------------------------------------------

# Rule 8 --- Architecture Review Checklist

Before every commit verify:

-   One owner per business concept.
-   No forbidden dependencies.
-   No direct cross-domain mutation.
-   Unknown remains computed.
-   Distribution remains metadata.
-   Transactions remain financial history.

------------------------------------------------------------------------

# Rule 9 --- Pull Request Checklist

Every implementation should answer:

What changed?

Why?

Which domain owns it?

What legacy was preserved?

What migration exists?

What invariants were verified?

------------------------------------------------------------------------

# Rule 10 --- Long-Term Vision

The goal is not merely a working application.

The goal is a system whose architecture remains understandable years
later.

Every line of code should make the domain model clearer.

Never trade architecture for short-term convenience.

------------------------------------------------------------------------

# AI Stop Conditions

Immediately stop and request clarification if:

-   A rule conflicts with MAPS.
-   Two domains appear to own the same concept.
-   A change requires modifying financial truth and metadata
    simultaneously.
-   A workaround seems necessary.

Architecture problems must be solved, not hidden.

------------------------------------------------------------------------

# Success Criteria

A successful implementation is one where:

-   Business concepts remain independent.
-   Future developers can identify ownership immediately.
-   Financial behavior is stable.
-   Documentation and implementation remain aligned.

------------------------------------------------------------------------

**END OF VOLUME 7**
