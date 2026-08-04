---
name: Transaction entry form extraction
description: Shared TransactionEntryForm now backs both manual entry and the recurring composer; AddTransactionScreen is a thin StatelessWidget wrapper.
---

`lib/features/transactions/presentation/form/` holds the canonical entry form (`TransactionEntryForm` + `TransactionFormController` + `sections/` + `pickers/` + `_shared/`). `screens/add_transaction_screen.dart` is just a thin wrapper forwarding params to it, and `recurring_transaction_composer_screen.dart` renders `TransactionEntryForm` directly for all non-lent modes.

**Why:** Manual transaction entry and recurring-occurrence entry share one financial entry pipeline per the Domain Bible (Chapter 10 — Transaction Lifecycle / Chapter 9 — Recurring Operations); the old monolithic `AddTransactionScreen` duplicated this logic across two files instead of factoring it out.

**How to apply:** When adding a new field/section to the entry form, add it to `TransactionFormController` + a `sections/` widget + wire it in `transaction_entry_form.dart` — do not touch `add_transaction_screen.dart` (it has no logic left) and do not add transaction-entry fields to `recurring_transaction_composer_screen.dart` (that file should only ever grow the Lent Money flow, which is intentionally a separate, non-recurring domain concept and must not be merged into the shared form).
