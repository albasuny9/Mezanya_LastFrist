<!--
Status: Reference
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

- [TransactionProcessor reverse backward-compat bug](tp-reverse-bc-fix.md) — OLD income sub-txns (parentId==null) had hasMatchingSourceChild hardcoded false → double-decrement → distributions wiped to 0.
- [flutter gen-l10n Replit quirk](gen-l10n-replit-quirk.md) — crashes at dart format step (exit 1) but the three generated .dart files are written correctly; ignore the error.
