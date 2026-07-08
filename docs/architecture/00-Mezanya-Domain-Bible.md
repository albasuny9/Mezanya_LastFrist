# Mezanya Domain Bible (Architecture Foundation)

Version: 0.1

## Vision

Mezanya is not an expense tracker. It is a personal financial
organization platform.

Its purpose is to mirror how people organize real money.

------------------------------------------------------------------------

## Product Philosophy

The application separates four independent questions:

1.  How much money do I own?
2.  Where is that money physically?
3.  Why am I keeping it?
4.  How is my monthly financial plan progressing?

These concerns must remain independent.

------------------------------------------------------------------------

## Core Domains

### Wallet

Physical storage of money.

### Budget

Monthly planning.

### Jar

Reserved money for one purpose.

### Transaction

Financial history.

### Money Distribution

Maps Jar money to physical Wallets.

It is metadata, not financial history.

------------------------------------------------------------------------

## Fundamental Rules

-   Wallet stores money.
-   Jar reserves money.
-   Budget plans money.
-   Transaction moves money.
-   Distribution describes location.

Never merge responsibilities.

------------------------------------------------------------------------

## Automatic Distribution

Whenever the system knows the source wallet, Distribution is generated
automatically.

------------------------------------------------------------------------

## Unknown Distribution

Unknown Distribution is valid.

It means the Jar owns money whose physical location has not been
assigned.

------------------------------------------------------------------------

## Manual Distribution

Only for:

-   historical corrections
-   deleted transactions
-   migration
-   manual cash organization

------------------------------------------------------------------------

## UI Philosophy

Jar

↓

Distribution Summary

↓

Wallet

↓

Distribution Entries

↓

Manual Management

Management is a maintenance tool, not a dashboard.

------------------------------------------------------------------------

## Planned Chapters

-   Financial Language
-   Money Lifecycle
-   Budget Engine
-   Wallet Engine
-   Jar Engine
-   Distribution Engine
-   Business Rules
-   Edge Cases
-   Technical Mapping
-   Data Model
