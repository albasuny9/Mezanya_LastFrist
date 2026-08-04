# Replit Task Plan

> Use Replit only for short, targeted investigations. Do not let it modify code unless explicitly asked.

## Replit should do

1. Investigate one bug at a time.
2. Verify root cause with code evidence.
3. Write the result into `docs/project/investigations/`.
4. Stop after the investigation.

## Replit should not do

- Do not refactor code.
- Do not apply fixes.
- Do not redesign architecture.
- Do not duplicate work already confirmed in the Bible or Decisions.

## Current priorities

### P0 — BUG-001 Wallet Transfer edit path

Investigate and document the exact edit/save path for wallet-to-wallet transfers. Confirm whether the edit screen preserves transfer fields or loses them before any fix is attempted.

### P1 — BUG-002 Jar categories scope vs owner

Investigate whether the category issue is caused by incorrect stored scope, incorrect filtering, or both.

### P2 — BUG-004 Auto Cloud Backup

Only after the transfer and category investigations are stable, verify the real-device cloud backup behavior.
