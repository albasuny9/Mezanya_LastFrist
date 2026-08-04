# Mezanya Architecture & Product Specification (MAPS)

# Volume 14 --- Repository Governance & Development Workflow

## Purpose

This volume defines how the Mezanya repository must be maintained so the
architecture remains consistent over time.

------------------------------------------------------------------------

# Repository Philosophy

The repository is a long-term product asset.

Every change must improve one or more of:

-   Architecture
-   Readability
-   Maintainability
-   Testability
-   Documentation

Never optimize for speed at the expense of structure.

------------------------------------------------------------------------

# Development Workflow

Every feature follows this lifecycle:

1.  Business requirement
2.  Architecture review
3.  Documentation update
4.  Domain implementation
5.  Application wiring
6.  UI integration
7.  Tests
8.  Review
9.  Merge

------------------------------------------------------------------------

# Branch Strategy

Recommended branches:

-   main
-   develop
-   feature/\*
-   refactor/\*
-   hotfix/\*

Never develop directly on main.

------------------------------------------------------------------------

# Commit Standards

Each commit must represent one logical change.

Good examples:

-   Introduce Distribution Aggregate
-   Add Distribution Validator
-   Migrate Reservation Storage
-   Implement Jar Distribution UI

Avoid generic messages such as:

-   Fix
-   Update
-   Changes

------------------------------------------------------------------------

# Pull Request Requirements

Every PR should explain:

-   Business motivation
-   Affected domain
-   Architectural impact
-   Migration impact
-   Backward compatibility
-   Test coverage

------------------------------------------------------------------------

# Documentation Rules

Before changing architecture:

Update MAPS first.

Implementation follows documentation.

Never let code become the only documentation.

------------------------------------------------------------------------

# Code Review Checklist

Verify:

-   Domain ownership respected.
-   No forbidden dependencies.
-   No duplicated business rules.
-   UI contains no business logic.
-   Financial behavior preserved.
-   Documentation updated.

------------------------------------------------------------------------

# Testing Policy

Minimum required:

-   Unit tests for domain logic.
-   Integration tests for workflows.
-   Migration validation tests.
-   Serialization tests.

------------------------------------------------------------------------

# Release Readiness

A release is ready only if:

-   Builds successfully.
-   Analysis passes.
-   Tests pass.
-   Documentation matches implementation.
-   No unresolved migration remains.

------------------------------------------------------------------------

# Maintenance Principles

When fixing bugs:

Fix the root architectural cause.

Do not stack workarounds.

If a workaround is unavoidable:

Document it and schedule removal.

------------------------------------------------------------------------

# Knowledge Transfer

A new developer should be able to understand the project using:

-   MAPS
-   Source code
-   Tests

Nothing else should be required.

------------------------------------------------------------------------

# Repository Health

Healthy repository characteristics:

-   Clear ownership
-   Small commits
-   Consistent terminology
-   Predictable workflows
-   Minimal coupling

------------------------------------------------------------------------

# Final Principle

Every contribution should leave the repository easier to evolve than
before.

------------------------------------------------------------------------

**END OF VOLUME 14**
