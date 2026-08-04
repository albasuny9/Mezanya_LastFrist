# Mezanya Bug Backlog

> This document tracks confirmed bugs, root-cause investigations, and open technical issues.
> Architectural truth belongs in the Domain Bible. Active bugs and temporary project issues belong here.

---

## OPEN BUGS

### BUG-001 — Recurring expense lacks parity with recurring income

**Status:** Open  
**Priority:** High  
**Area:** Recurring Transactions

#### Summary
Recurring income has retroactive prompt and manual registration support. Recurring expense should follow the same recurring-operation concept, but it currently lacks the same behavior.

#### Required investigation
- Verify whether recurring expense can reuse the same recurring-operation flow.
- Confirm whether the missing behavior belongs in composer, screen actions, or recurring engine logic.
- Avoid duplicating logic before identifying the shared business rule.

#### Related questions
- Is the difference only type-specific behavior?
- Which parts are common to recurring income and recurring expense?

---

### BUG-002 — Jar categories are mixed with expense/income categories

**Status:** Open — investigated, verdict NOT PROVEN (see `docs/project/investigations/BUG-002 Jar Category Scope Investigation.md`)  
**Priority:** High  
**Area:** Categories / Jars

#### Summary
Jar-related categories appear in the wrong category sections. The current issue may be caused by incorrect scope handling, incorrect owner handling, or both.

#### Required investigation
Trace the full lifecycle:
1. Creation
2. Saved entity
3. Stored scope
4. Retrieval
5. Filtering
6. Display

#### Rules
- Do not assume this is only a UI filtering problem.
- Separate category scope from category owner.
- A jar-related category should not automatically be treated as an expense category.

---

### BUG-003 — Wallet transfer loses wallet effects after editing notes

**Status:** Fixed — implemented per `docs/project/investigations/BUG-001 Wallet Transfer Investigation.md` and `docs/project/decisions/Transaction Editing Architecture.md`.
**Priority:** Critical  
**Area:** Transfers / Transactions

#### Summary
Editing only the notes of a wallet-to-wallet transfer causes the transfer to remain visible in history while disappearing from the wallets and restoring balances as if the transfer never happened.

#### Root cause (confirmed, not re-investigated)
Same mechanism as BUG-001: editing a `wallet-to-wallet` transfer fell through to the generic `AddTransactionScreen`, whose save handler omits `fromWalletId`/`toWalletId`/`transferType` when reconstructing the transaction, silently dropping the wallet balance effect while the transaction record stayed visible.

#### Fix implemented
Added a dedicated `_openWalletToWalletEditor` in `transaction_details_sheet.dart` (mirrors the existing, already-fixed `_openJarToJarEditor` pattern for jar-to-jar transfers). `_openTransactionEditor` now routes `transferType == 'wallet-to-wallet'` to this editor instead of the generic screen. The editor matches the Wallet Transfer creation UI (`WalletsScreen._openWalletTransferDialog`), preloads source wallet / destination wallet / amount / date / time / notes, and on save always supplies `fromWalletId`, `toWalletId`, and `transferType: 'wallet-to-wallet'` so the transfer's business identity is preserved through any edit. Covered by `test/wallet_to_wallet_transfer_edit_test.dart` (notes-only, amount, date/time, and source/destination wallet edits — all confirmed to preserve correct balances with no duplicate transaction).

#### UX/domain note
A transfer should expose full transaction metadata, including date, time, and notes. (Satisfied by the new editor.)

---

## NEW BUG CANDIDATES (discovered during other investigations — unconfirmed, not yet prioritized)

### NBC-001 — Category breakdown charts miscategorize jar/allocation-owned categories as "uncategorized"

**Discovered while investigating:** BUG-002.  
**Area:** Home / Charts.

#### Summary
`_CategoryBreakdown` and `_IncomeBreakdown` in the Home/Charts screen resolve a transaction's category name by searching only the general category bucket. Transactions categorized under a Jar- or Allocation-owned category fail this lookup and render as uncategorized, even though the same category resolves correctly elsewhere (`getCategoryForTransaction`).

See `docs/project/investigations/NBC-001 Category Breakdown General-Bucket-Only Lookup.md` for full evidence. Distinct from BUG-002 — not to be merged with or used to resolve it.

---

## INVESTIGATING

### BUG-004 — Auto Cloud Backup still needs a real device verification

**Status:** Investigating  
**Priority:** High  
**Area:** Backup / Cloud Sync

#### Summary
Local auto backup works, but cloud auto backup still needs a real device verification after the bridge and lifecycle fixes.

#### Next action
- Run a fresh-device test.
- Trigger a transaction.
- Confirm whether the automatic cloud backup updates without opening backup settings.

---

## CLOSED BUGS

_(Move fixed items here with the resolving commit SHA and a short note.)_
