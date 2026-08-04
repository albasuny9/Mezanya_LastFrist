# Mezanya Architecture & Product Specification (MAPS)

# Volume 17 --- Appendix A: Canonical Business Rules

## Purpose

This appendix captures the immutable business rules that every
implementation must obey.

These rules override implementation convenience.

------------------------------------------------------------------------

# Financial Rules

FR-001

Wallet balance represents physical money only.

------------------------------------------------------------------------

FR-002

Jar balance represents reserved money only.

------------------------------------------------------------------------

FR-003

Budget represents planning only.

------------------------------------------------------------------------

FR-004

Transaction represents financial history only.

------------------------------------------------------------------------

FR-005

Money Distribution represents reservation metadata only.

------------------------------------------------------------------------

# Reservation Rules

RR-001

Every Distribution Entry belongs to exactly one Jar.

------------------------------------------------------------------------

RR-002

Every Distribution Entry references exactly one Wallet.

------------------------------------------------------------------------

RR-003

Unknown is calculated.

Unknown =

Jar Balance

-   

Sum(Distribution Entries)

------------------------------------------------------------------------

RR-004

Unknown may legitimately equal zero.

------------------------------------------------------------------------

RR-005

Unknown may legitimately equal the entire Jar balance.

------------------------------------------------------------------------

RR-006

Unknown is never persisted independently.

------------------------------------------------------------------------

# Validation Rules

VR-001

Known Distribution must never exceed Jar Balance.

------------------------------------------------------------------------

VR-002

Negative reservation amounts are invalid.

------------------------------------------------------------------------

VR-003

Reservations referencing deleted wallets are invalid.

------------------------------------------------------------------------

VR-004

Financial balances are never repaired automatically.

------------------------------------------------------------------------

# Transaction Rules

TR-001

Editing reservation metadata never creates a transaction.

------------------------------------------------------------------------

TR-002

Deleting reservation metadata never deletes financial history.

------------------------------------------------------------------------

TR-003

Moving reservations never changes wallet balances.

------------------------------------------------------------------------

TR-004

Transfers move money.

Reservations move metadata.

These are different operations.

------------------------------------------------------------------------

# Ownership Rules

OR-001

One business concept has exactly one owner.

------------------------------------------------------------------------

OR-002

Application orchestrates.

Domains decide.

------------------------------------------------------------------------

OR-003

Domains never mutate each other's internal state.

------------------------------------------------------------------------

OR-004

Business rules never belong inside UI.

------------------------------------------------------------------------

# Migration Rules

MR-001

Migration must preserve financial truth.

------------------------------------------------------------------------

MR-002

Migration must be reversible until validation succeeds.

------------------------------------------------------------------------

MR-003

Legacy code exists only to support migration.

------------------------------------------------------------------------

# Documentation Rules

DR-001

Documentation changes before implementation.

------------------------------------------------------------------------

DR-002

Architecture documentation is part of the product.

------------------------------------------------------------------------

DR-003

Every architectural decision must remain discoverable from MAPS.

------------------------------------------------------------------------

# Completion Checklist

A feature is complete only if:

-   Business rules are preserved.
-   Domain ownership remains correct.
-   Validation passes.
-   Documentation remains accurate.
-   Financial behavior is unchanged.
-   Migration (if needed) is complete.
-   Tests cover the new behavior.

------------------------------------------------------------------------

# Closing Statement

MAPS is not a snapshot of the codebase.

MAPS defines the intended architecture.

The implementation is expected to evolve toward MAPS over time.

Whenever uncertainty exists, choose the solution that preserves business
ownership, financial correctness, and architectural simplicity.

------------------------------------------------------------------------

**END OF VOLUME 17**

**END OF MEZANYA ARCHITECTURE & PRODUCT SPECIFICATION (MAPS)**
