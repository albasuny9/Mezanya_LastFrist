# Mezanya Architecture & Product Specification (MAPS)

# Volume 4 --- Financial Lifecycle & Transaction Flow

## Purpose

This volume defines how money moves through Mezanya from the moment it
enters the system until it leaves it.

It specifies business behavior only.

------------------------------------------------------------------------

# Financial Lifecycle

``` text
Income
   │
   ▼
Wallet
   │
   ▼
Budget Cycle
   │
   ├──────────────┐
   ▼              ▼
Categories       Jars
                    │
                    ▼
          Money Distribution
                    │
                    ▼
           Physical Wallets
                    │
                    ▼
               Spending
```

------------------------------------------------------------------------

# Salary Lifecycle

1.  Salary is received.
2.  A financial transaction is created.
3.  Wallet balance increases.
4.  Budget available income increases.
5.  Automatic allocations may execute.
6.  Money Distribution metadata may be created.
7.  No additional financial transaction is created for Distribution.

------------------------------------------------------------------------

# Expense Lifecycle

Expense occurs.

Transaction owns:

-   Financial record
-   Wallet balance reduction

Budget may consume allocation.

Jar may reduce reserved balance if applicable.

Distribution is updated only if reservation metadata must change.

------------------------------------------------------------------------

# Transfer Lifecycle

Wallet A ↓

Transaction

↓

Wallet B

Distribution is unaffected unless the user explicitly changes
reservation locations.

------------------------------------------------------------------------

# Jar Allocation Lifecycle

Allocation means:

Budget reserves money for a Jar.

Allocation does NOT physically move money.

Example:

Salary arrives in Bank.

Budget allocates 1500 to Housing.

Wallet balance: UNCHANGED.

Jar balance: +1500.

Distribution: Bank = 1500.

------------------------------------------------------------------------

# Manual Distribution Lifecycle

User opens:

Money Distribution.

Operations:

-   Add Reservation
-   Remove Reservation
-   Transfer Reservation

These operations:

✔ Update metadata.

They never:

✘ Create transactions.

✘ Change wallet balances.

✘ Change budget.

------------------------------------------------------------------------

# Reservation Transfer

Example:

Housing

Bank 1500

↓

Cash 1500

Result:

Wallet balances: UNCHANGED.

Jar balance: UNCHANGED.

Distribution metadata: UPDATED.

------------------------------------------------------------------------

# Unknown Lifecycle

Unknown is computed.

Formula:

Unknown = Jar Balance - Known Distribution Total

Unknown may become:

-   Larger
-   Smaller
-   Zero

Unknown is never persisted independently.

------------------------------------------------------------------------

# Financial Truth

Authoritative sources:

Wallet Balance ↓

Wallet Domain

Jar Balance ↓

Jar Domain

Budget Allocation ↓

Budget Domain

Financial History ↓

Transaction Domain

Reservation Location ↓

Money Distribution Domain

Each source owns only its own truth.

------------------------------------------------------------------------

# Validation Rules

Always valid:

Known Distribution ≤ Jar Balance

If Known Distribution exceeds Jar Balance:

Reject the operation.

Never auto-correct silently.

------------------------------------------------------------------------

# Application Ordering

Recommended order:

1.  Execute financial operation.
2.  Validate domain results.
3.  Update reservation metadata if required.
4.  Persist AppState.
5.  Refresh UI.

------------------------------------------------------------------------

# Domain Events (Future)

Future events may include:

-   SalaryReceived
-   ExpenseRecorded
-   JarAllocated
-   ReservationMoved
-   ReservationRemoved

Events describe facts.

They do not perform work.

------------------------------------------------------------------------

# Anti-Patterns

Never:

-   Create fake financial transactions for reservation edits.
-   Store reservation history as accounting.
-   Modify balances during metadata edits.
-   Infer business rules from UI state.

------------------------------------------------------------------------

# Business Invariants

The following must always remain true:

-   Wallet balance is authoritative.
-   Jar balance is authoritative.
-   Distribution never changes balances.
-   Budget never stores physical locations.
-   Transactions never own reservation metadata.

------------------------------------------------------------------------

**END OF VOLUME 4**
