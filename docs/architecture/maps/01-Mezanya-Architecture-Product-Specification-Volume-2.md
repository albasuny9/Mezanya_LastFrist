# Mezanya Architecture & Product Specification (MAPS)

# Volume 2 --- Ubiquitous Language & Core Business Concepts

## Purpose

Every business term in Mezanya has exactly one meaning.

No term may have multiple interpretations.

The same word must always describe the same business concept across:

-   UI
-   Domain
-   Storage
-   Services
-   Documentation
-   Tests

------------------------------------------------------------------------

# Wallet

## Definition

A Wallet represents the physical location of money.

Examples:

-   Cash
-   Bank Account
-   Vodafone Cash
-   Credit Wallet

A wallet answers only one question:

> Where is the money physically stored?

### Wallet owns

-   Physical balance
-   Wallet metadata
-   Wallet identity

### Wallet never owns

-   Budget
-   Jars
-   Distribution
-   Financial planning

------------------------------------------------------------------------

# Budget

## Definition

A Budget is the monthly financial plan.

It answers:

> Why will money be used this cycle?

Budget owns:

-   Categories
-   Monthly allocations
-   Income plan
-   Recurring planning

Budget never owns:

-   Wallet balances
-   Physical money
-   Distribution metadata

------------------------------------------------------------------------

# Transaction

## Definition

A Transaction is immutable financial history.

It represents something that actually happened.

Examples:

-   Expense
-   Income
-   Transfer
-   Deposit
-   Withdrawal

Transaction owns:

-   Financial history
-   Balance effects
-   Reversal logic

Transaction never owns:

-   Distribution
-   Reservations
-   Planning

------------------------------------------------------------------------

# Jar

## Definition

A Jar is a financial reservation.

A Jar reserves money for a specific purpose.

Examples:

-   Rent
-   Housing
-   Food
-   Emergency
-   Travel

Jar answers:

> How much money is reserved for this purpose?

Jar owns:

-   Reserved balance
-   Jar metadata
-   Goal information

Jar never owns:

-   Wallet balances
-   Physical locations

------------------------------------------------------------------------

# Money Distribution

## Definition

Money Distribution describes where Jar money exists physically.

It is metadata only.

It never changes balances.

It never creates transactions.

It never represents accounting.

It answers:

> Which wallet currently contains the money reserved by this Jar?

------------------------------------------------------------------------

# Distribution Entry

A Distribution Entry links:

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

It is metadata.

It is NOT a transaction.

------------------------------------------------------------------------

# Reservation

Reservation is the business meaning of a Distribution Entry.

A reservation says:

"This amount of this wallet belongs to this Jar."

Nothing more.

------------------------------------------------------------------------

# Unknown

Unknown is a valid state.

Unknown means:

"The Jar owns this money, but its physical wallet is currently not
tracked."

Unknown is never an error.

Unknown is always computed.

Unknown =

Jar Balance

minus

Known Distributed Amount

It should never be stored independently.

------------------------------------------------------------------------

# Allocation

Allocation moves money from Budget into a Jar conceptually.

Allocation is planning.

Allocation is not physical movement.

------------------------------------------------------------------------

# Physical Movement

Physical movement changes wallets.

Example:

Cash → Bank

This belongs to Wallet and Transaction.

It is unrelated to Distribution.

------------------------------------------------------------------------

# Distribution Movement

Distribution movement changes only metadata.

Example:

Housing Reservation

Bank → Cash

Wallet balances remain unchanged.

Jar balance remains unchanged.

Budget remains unchanged.

Only metadata changes.

------------------------------------------------------------------------

# Business Ownership Matrix

  Concept                         Owner
  ------------------------------- --------------------
  Wallet Balance                  Wallet
  Budget Planning                 Budget
  Financial History               Transaction
  Reserved Balance                Jar
  Physical Reservation Location   Money Distribution

------------------------------------------------------------------------

# Naming Rules

Always use consistent terminology.

Use:

-   Wallet
-   Jar
-   Budget
-   Transaction
-   Money Distribution
-   Distribution Entry
-   Reservation
-   Unknown

Never invent alternate names for the same concept.

------------------------------------------------------------------------

**END OF VOLUME 2**
