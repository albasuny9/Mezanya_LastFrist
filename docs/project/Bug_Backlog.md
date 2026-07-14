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

**Status:** Open  
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

**Status:** Open  
**Priority:** Critical  
**Area:** Transfers / Transactions

#### Summary
Editing only the notes of a wallet-to-wallet transfer causes the transfer to remain visible in history while disappearing from the wallets and restoring balances as if the transfer never happened.

#### Required investigation
- Check whether notes are incorrectly used in transfer identity or reconstruction.
- Verify whether transfer editing rebuilds the operation from notes.
- Confirm the true source of the reversal bug before patching.

#### UX/domain note
A transfer should expose full transaction metadata, including date, time, and notes.

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
