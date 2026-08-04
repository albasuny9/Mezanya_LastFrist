# Transaction Editing Architecture

> Decision record for how Mezanya should edit transactions without breaking business effects.

## Decision

Transactions must be edited through an editor that understands the transaction's business shape.

A generic add screen may be reused for ordinary expense and income edits, but transfer-style transactions must preserve their structural fields during edit:

- `fromWalletId`
- `toWalletId`
- `transferType`
- `walletId`
- `amount`
- `createdAt` / date / time
- `notes`

Editing must update the existing transaction instead of deleting it and recreating it under a malformed shape.

## Why this matters

A wallet-to-wallet transfer is not a normal expense or income form with a different label. It has a distinct structure and must be edited with a UI and save path that preserve its source, destination, and transfer semantics.

The investigation for BUG-001 showed that the current generic edit path can lose transfer fields when a transfer transaction is edited from the notes field only.

## Rules

- Edit means mutate the existing transaction shape.
- Delete means remove the transaction only when the user explicitly requests deletion.
- Transfer editors must not rely on a generic form that omits structural transfer fields.
- The UI should expose the fields that define the business meaning of the transfer.

## Related documents

- `docs/project/investigations/BUG-001 Wallet Transfer Investigation.md`
- `docs/project/Bug_Backlog.md`
