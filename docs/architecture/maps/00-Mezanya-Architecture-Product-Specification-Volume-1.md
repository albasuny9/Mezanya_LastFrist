# Mezanya Architecture & Product Specification (MAPS)

**Version:** 1.0 (Living Document)

**Status:** Reference — Superseded as source of truth by the Domain Bible (`docs/architecture/Mezanya Domain Bible/`). See `.agents/DOCUMENTATION_MAP.md` for the current documentation authority hierarchy.

------------------------------------------------------------------------

# PREFACE

This document was originally written as the single source of truth for the Mezanya project, before the Domain Bible existed. It has since been superseded: the Domain Bible (`docs/architecture/Mezanya Domain Bible/`) is now the sole source of truth for business rules, per `.agents/DOCUMENTATION_MAP.md`. This document remains valuable as reference/implementation-angle material.

It is intentionally written before implementation.

The software exists to implement this document.

This document does **NOT** exist to describe the software.

Whenever implementation and this specification disagree, the
implementation is wrong.

The implementation must evolve.

The product philosophy must remain stable.

------------------------------------------------------------------------

# WHY THIS DOCUMENT EXISTS

Large software projects slowly become difficult to evolve.

This rarely happens because developers write bad code.

It usually happens because nobody remembers the original model.

Developers start fixing bugs.

Then they add workarounds.

Then another developer fixes the workaround.

Eventually the implementation becomes the documentation.

That must never happen in Mezanya.

The business model comes first.

The implementation comes second.

------------------------------------------------------------------------

# WHAT IS MEZANYA

Mezanya is **NOT**:

-   Expense Tracker
-   Wallet Manager
-   Budget App
-   Personal Finance Spreadsheet
-   Accounting Software

Those applications answer questions like:

-   "How much did I spend?"
-   "How much money is inside this wallet?"

Mezanya answers a completely different question.

------------------------------------------------------------------------

# THE QUESTION MEZANYA ANSWERS

> "Where is every unit of my money, why does it exist, and what is its
> purpose?"

That difference changes everything.

------------------------------------------------------------------------

# THE REAL WORLD

Imagine the following situation.

You receive your monthly salary.

12000 EGP.

You place all cash inside your wallet.

Now nothing is organized.

You decide:

-   2000 for Food
-   1500 for Housing
-   3000 for Emergency
-   4000 for Savings
-   1500 for Personal Spending

Did you move the money?

No.

Did your wallet balance change?

No.

Only your intention changed.

That is the entire philosophy behind Mezanya.

------------------------------------------------------------------------

# DIGITAL ENVELOPES

Real life:

People use envelopes.

-   Food
-   Housing
-   Emergency
-   Savings

Every envelope contains money.

But physically the money still exists.

Sometimes inside one wallet.

Sometimes inside several wallets.

Sometimes partly inside Cash, partly inside Bank, partly inside Vodafone
Cash.

The physical location and the financial purpose are different concepts.

Mezanya models both.

------------------------------------------------------------------------

# FIRST PRINCIPLE

Every unit of money has TWO identities.

## Physical Identity

Where is it physically?

-   Cash
-   Bank
-   Vodafone Cash
-   Credit
-   etc.

## Financial Identity

Why does it exist?

-   Food
-   Housing
-   Emergency
-   Savings
-   Travel
-   Rent
-   Insurance
-   etc.

These identities must NEVER be merged.

------------------------------------------------------------------------

# SECOND PRINCIPLE

Physical movement is different from financial planning.

Example:

Salary arrives.

Wallet increases.

Budget increases.

Distribution created.

These are independent business events.

Never merge them.

------------------------------------------------------------------------

# THIRD PRINCIPLE

A Transaction is history.

A Distribution is metadata.

A Budget is planning.

A Wallet is storage.

A Jar is reservation.

Every concept has exactly one responsibility.

------------------------------------------------------------------------

# THE MOST IMPORTANT RULE

One business concept.

One owner.

Never two.

Examples:

Wallet Balance → Wallet

Monthly Allocation → Budget

Reserved Money → Jar

Physical Location of Reserved Money → Money Distribution

------------------------------------------------------------------------

# PRODUCT PHILOSOPHY

Users do NOT think in tables.

Users do NOT think in entities.

Users do NOT think in repositories.

Users think like this:

-   "My salary arrived."
-   "I want to reserve money for rent."
-   "I moved the reserved money from Bank to Cash."
-   "I spent the rent."

The software must model the user's thinking.

Never force the user to think like the database.

------------------------------------------------------------------------

# DESIGN PHILOSOPHY

The UI is never the source of truth.

The database is never the source of truth.

The implementation is never the source of truth.

The business model is always the source of truth.

Everything else exists only to implement it.

------------------------------------------------------------------------

# THE GOLDEN RULE

Whenever you write code, ask one question first.

> "What business concept does this code belong to?"

If the answer is:

> "More than one"

The architecture is wrong.

Refactor before continuing.

Never solve architecture problems by adding conditions.

Never move problems.

Remove them.

------------------------------------------------------------------------

**END OF VOLUME 1**
