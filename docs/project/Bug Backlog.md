\# Mezanya Bug Backlog



> This document tracks confirmed bugs only.

> Ideas, feature requests, and domain discussions belong elsewhere.



\---



\# Open Bugs



\## BUG-001 — Auto Cloud Backup never runs



Status: Pending Verification

Priority: Critical

Area: Cloud Backup



\### Symptoms

\- Local Auto Backup works.

\- Manual Cloud Backup works.

\- Auto Cloud Backup never updates.



\### Root Cause Investigation

\- Firebase bridge moved to auto path.

\- Awaiting real device verification.



\### Next Action

\- Test after fresh app launch.



\---



\## BUG-002 — Wallet Transfer breaks after editing Notes



Status: Open

Priority: Critical

Area: Transactions / Wallet Transfers



\### Steps to Reproduce



1\. Create Wallet → Wallet transfer.

2\. Edit only Notes.

3\. Save.



\### Expected



Only Notes change.



\### Actual



\- Transfer disappears from wallets.

\- Wallet balances are restored.

\- Transaction still exists in history.



\### Suspected Cause



Transfer identity appears coupled to generated notes.



\### Root Cause



Not investigated yet.



\---



\## BUG-003 — Transfer screen missing transaction metadata



Status: Open

Priority: Medium

Area: Transactions / UX



\### Missing



\- Date

\- Time

\- Notes



Transfer should expose the same metadata as every Transaction.

