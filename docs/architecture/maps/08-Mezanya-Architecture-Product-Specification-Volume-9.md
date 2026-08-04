# Mezanya Architecture & Product Specification (MAPS)

# Volume 9 --- User Experience & Interface Philosophy

## Purpose

This volume defines how the architecture is expressed through the user
interface.

The UI must expose the business model clearly without leaking
implementation details.

------------------------------------------------------------------------

# Core Philosophy

The interface exists to explain money, not to expose the database.

Every screen must answer one business question.

Never mix multiple mental models on the same screen.

------------------------------------------------------------------------

# Visual Hierarchy

Priority order:

1.  Financial truth
2.  User intention
3.  Metadata
4.  Historical details

Do not reverse this order.

------------------------------------------------------------------------

# Jar Details Screen

The Jar is the center of the reservation model.

Display:

-   Jar Name
-   Reserved Balance
-   Goal (optional)
-   Progress (optional)

Below that:

Money Location

Collapsed by default.

------------------------------------------------------------------------

# Money Location Section

Collapsed state shows only a summary.

Example:

Bank ........ 2,100

Cash .......... 500

Unknown ...... 700

No edit controls.

No transaction history.

No charts.

No analytics.

------------------------------------------------------------------------

# Wallet Detail Sheet

Selecting a wallet opens a Bottom Sheet.

Contents:

Wallet Name

Reserved Total

Reservation Entries

Example

Housing ...... 1500

Emergency ... 300

Manual ......... 200

Actions appear only after selecting an entry.

------------------------------------------------------------------------

# Entry Actions

Available actions:

-   Move
-   Edit Amount
-   Delete

Never execute financial transactions.

Only metadata changes.

------------------------------------------------------------------------

# Distribution Management

Separate Bottom Sheet.

Purpose:

Manual metadata operations.

Modes:

-   Add
-   Remove
-   Transfer

No dashboard.

No duplicated summaries.

No analytics.

No notes field.

------------------------------------------------------------------------

# Form Design

Follow the application's existing design language.

Requirements:

-   Floating labels
-   Rounded inputs
-   Olive primary color
-   Paper background
-   Consistent spacing
-   Existing typography

Never introduce a second design system.

------------------------------------------------------------------------

# Wallet Picker

Each wallet displays:

Wallet Name

Available Balance

Example

Bank

12,500

Cash

3,200

Vodafone Cash

850

The available balance helps users choose the correct physical location.

------------------------------------------------------------------------

# Unknown

Display Unknown exactly like a wallet row.

It is informational.

Never highlight it as an error.

Never require user action.

------------------------------------------------------------------------

# Interaction Rules

Collapsed → Summary only.

Expanded → Reservation details.

Management → Manual operations.

Each interaction level has a single responsibility.

------------------------------------------------------------------------

# Empty States

If no reservation exists:

Show a simple empty state.

Invite the user to add a reservation.

Do not fabricate sample data.

------------------------------------------------------------------------

# Error States

Validation errors must:

-   Explain the business rule.
-   Preserve entered data.
-   Never modify balances automatically.

------------------------------------------------------------------------

# Accessibility

Use consistent terminology.

Avoid technical implementation terms.

Users should never see:

-   DistributionEntry
-   Aggregate
-   Metadata
-   Serialization

Translate domain concepts into user language.

------------------------------------------------------------------------

# UX Principles

The interface should always feel:

-   Calm
-   Minimal
-   Predictable
-   Fast
-   Explainable

Every tap should have one obvious outcome.

------------------------------------------------------------------------

# UI Anti-Patterns

Never:

-   Duplicate information across sheets.
-   Show accounting data inside Distribution.
-   Expose implementation details.
-   Mix reservation metadata with transaction history.
-   Overload a single dialog with unrelated actions.

------------------------------------------------------------------------

# Definition of Good UI

A first-time user should understand:

-   Where the money is.
-   Why it is reserved.
-   How to move its reservation.

Without needing to understand how the application is implemented.

------------------------------------------------------------------------

**END OF VOLUME 9**
