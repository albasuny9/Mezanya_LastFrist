# Mezanya Architecture & Product Specification (MAPS)

# Volume 13 --- Complete Domain Interaction Matrix & Sequence Diagrams

## Purpose

This volume defines exactly how domains collaborate while preserving
ownership boundaries.

No domain may bypass these interaction contracts.

------------------------------------------------------------------------

# Master Dependency Matrix

  From                 To                   Allowed   Reason
  -------------------- -------------------- --------- ----------------------------
  UI                   Application          ✔         User interaction
  Application          Wallet               ✔         Orchestration
  Application          Budget               ✔         Orchestration
  Application          Transaction          ✔         Orchestration
  Application          Jar                  ✔         Orchestration
  Application          Money Distribution   ✔         Orchestration
  Wallet               Transaction          ✘         Forbidden
  Wallet               Budget               ✘         Forbidden
  Wallet               Jar                  ✘         Forbidden
  Wallet               Money Distribution   ✘         Forbidden
  Budget               Wallet               ✘         Forbidden
  Budget               Transaction          ✘         Forbidden
  Budget               Jar                  ✘         Forbidden
  Budget               Money Distribution   ✘         Forbidden
  Transaction          Wallet               ✘         Direct ownership violation
  Transaction          Jar                  ✘         Direct ownership violation
  Transaction          Money Distribution   ✘         Direct ownership violation
  Jar                  Wallet               ✘         Direct ownership violation
  Jar                  Transaction          ✘         Direct ownership violation
  Jar                  Budget               ✘         Direct ownership violation
  Jar                  Money Distribution   ✘         Direct ownership violation
  Money Distribution   Wallet               ✘         No balance ownership
  Money Distribution   Transaction          ✘         No financial ownership
  Money Distribution   Budget               ✘         No planning ownership
  Money Distribution   Jar                  ✘         No balance ownership

Only the Application Layer coordinates domains.

------------------------------------------------------------------------

# Sequence --- Salary

``` text
User
 │
 ▼
Application
 │
 ├────────► Transaction
 │            Apply income
 │
 ├────────► Wallet
 │            Balance updated
 │
 ├────────► Budget
 │            Monthly income updated
 │
 └────────► Money Distribution
              Optional reservation metadata
```

------------------------------------------------------------------------

# Sequence --- Expense

``` text
User
 │
 ▼
Application
 │
 ├────────► Transaction
 │
 ├────────► Wallet
 │
 ├────────► Jar (if linked)
 │
 └────────► Distribution validation
```

Distribution never creates the expense.

------------------------------------------------------------------------

# Sequence --- Reservation Transfer

``` text
User
 │
 ▼
Application
 │
 ▼
Money Distribution
 │
 ├── Remove reservation from Wallet A
 └── Add reservation to Wallet B
```

No balance changes occur.

------------------------------------------------------------------------

# Sequence --- Manual Add

``` text
User
 │
 ▼
Application
 │
 ▼
Money Distribution
 │
 ▼
Persist
```

No transaction exists.

------------------------------------------------------------------------

# Sequence --- Manual Remove

Reservation decreases.

Unknown increases automatically.

No balance changes.

------------------------------------------------------------------------

# Sequence --- Delete Reservation

Delete metadata only.

Financial history remains intact.

------------------------------------------------------------------------

# State Ownership

Wallet State → Wallet

Budget State → Budget

Transaction History → Transaction

Jar State → Jar

Reservation Metadata → Money Distribution

------------------------------------------------------------------------

# Cross-Domain Communication

Domains never call each other.

Application orchestrates.

Future coordinators belong only to the Application Layer.

------------------------------------------------------------------------

# Architectural Smells

Immediate refactor required if you see:

-   Transaction editing reservation metadata.
-   Wallet storing planning information.
-   Budget storing wallet locations.
-   Jar changing wallet balances.
-   Distribution changing financial balances.

------------------------------------------------------------------------

# Review Questions

Before merging any feature ask:

1.  Which domain owns this?
2.  Which domains are only consumers?
3.  Is orchestration occurring in the Application Layer?
4.  Is financial truth separated from metadata?
5.  Did any domain gain a second responsibility?

------------------------------------------------------------------------

# Completion Criteria

The architecture is considered healthy when:

-   Every dependency follows this matrix.
-   Every workflow follows the defined sequences.
-   No direct domain-to-domain mutation exists.
-   The Application Layer remains the sole coordinator.

------------------------------------------------------------------------

**END OF VOLUME 13**
