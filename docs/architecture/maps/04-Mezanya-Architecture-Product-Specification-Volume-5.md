# Mezanya Architecture & Product Specification (MAPS)

# Volume 5 --- Money Distribution Domain Specification

## Purpose

This document defines the complete Money Distribution domain.

Its responsibility is to describe **where Jar money exists physically**.

It never owns financial truth.

It owns reservation metadata only.

------------------------------------------------------------------------

# Domain Mission

Money Distribution answers one question:

> Where is the money reserved by this Jar physically located?

Nothing more.

------------------------------------------------------------------------

# Mental Model

Real life:

Salary arrives in a Bank account.

You reserve 1,500 EGP for Housing.

The money is still inside the Bank.

Later you withdraw that cash.

The Housing reservation now exists physically inside Cash.

The reservation changed.

The financial history did not.

------------------------------------------------------------------------

# Domain Ownership

Owns:

-   Distribution Entries
-   Reservation metadata
-   Validation
-   Reservation movement
-   Unknown calculation support

Never owns:

-   Wallet balances
-   Jar balances
-   Budget allocations
-   Financial transactions

------------------------------------------------------------------------

# Aggregate

MoneyDistribution

contains

-   jarId
-   entries\[\]

Each Jar owns one Distribution Aggregate.

------------------------------------------------------------------------

# Distribution Entry

Each entry represents:

Jar ↓

Wallet ↓

Reserved Amount

Fields:

-   id
-   jarId
-   walletId
-   amount
-   origin
-   linkedTransactionId (optional)
-   createdAt
-   updatedAt

------------------------------------------------------------------------

# Unknown

Unknown is computed.

Unknown =

Jar Balance

minus

Sum(All Distribution Entries)

It is never stored independently.

It is never edited directly.

------------------------------------------------------------------------

# Entry Origins

Possible origins:

-   Automatic Allocation
-   Manual Addition
-   Manual Transfer
-   Migration
-   Recovery

Origin is informational only.

------------------------------------------------------------------------

# Domain Operations

## Add Reservation

Input:

Wallet

Amount

Result:

New Distribution Entry.

No balances change.

------------------------------------------------------------------------

## Remove Reservation

Input:

Wallet

Amount

Result:

Reservation decreases.

Unknown increases automatically.

------------------------------------------------------------------------

## Transfer Reservation

Input:

From Wallet

To Wallet

Amount

Result:

Entry moves.

No balances change.

------------------------------------------------------------------------

## Edit Reservation

User may change:

-   Wallet
-   Amount

Only metadata changes.

------------------------------------------------------------------------

## Delete Reservation

Deletes metadata only.

Never deletes financial history.

------------------------------------------------------------------------

# Validation Rules

Must reject:

-   Negative reservation
-   Invalid wallet
-   Amount greater than reserved amount
-   Known Distribution \> Jar Balance

Validation never repairs data automatically.

------------------------------------------------------------------------

# Automatic Creation

Automatic allocations may create reservation entries.

Financial operation finishes first.

Distribution metadata is created afterward.

------------------------------------------------------------------------

# Migration

Legacy:

jar.walletSources

↓

Convert

↓

Distribution Entries

↓

Persist

↓

Use Distribution Entries only

Legacy data exists only for migration.

------------------------------------------------------------------------

# User Interface

Collapsed View

Shows:

-   Wallet Name
-   Reserved Amount

Example:

Bank 2100

Cash 500

Unknown 700

No editing.

------------------------------------------------------------------------

# Wallet Details

Selecting a wallet opens a Bottom Sheet.

Displays Reservation Entries only.

Example:

Housing 1500

Emergency 300

Manual 200

Actions are available after selecting an entry.

------------------------------------------------------------------------

# Management Sheet

Single Bottom Sheet.

Segmented options:

-   Add
-   Remove
-   Transfer

Fields:

Wallet

Amount

Transfer additionally requires:

From Wallet

To Wallet

Amount

No notes.

No analytics.

No duplicated information.

------------------------------------------------------------------------

# Business Examples

Example 1

Jar Balance

5000

Distribution

Bank 3000

Cash 1000

Unknown 1000

Valid.

------------------------------------------------------------------------

Example 2

Transfer

Bank

↓

Cash

1000

Only reservation metadata changes.

------------------------------------------------------------------------

Example 3

Remove

Cash

700

Result:

Cash reservation decreases.

Unknown increases by 700.

------------------------------------------------------------------------

# Forbidden

Never:

-   Create transactions.
-   Change balances.
-   Reverse financial history.
-   Store Unknown.
-   Depend on TransactionProcessor.
-   Depend on Wallet internals.

------------------------------------------------------------------------

# Future Extensions

Possible additions:

-   Reservation history
-   Audit trail
-   Analytics
-   Synchronization
-   Conflict resolution

These extensions must not change the ownership rules defined above.

------------------------------------------------------------------------

**END OF VOLUME 5**
