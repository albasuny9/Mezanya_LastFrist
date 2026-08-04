<!--
Status: Reference
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Architecture Decision Records — Mezanya

سجل قرارات معمارية مبنية على تدقيق مباشر للكود، لا تصور نظري. كل ADR
مستقل ومؤرَّخ بـ commit مرجعي.

| # | العنوان | الحالة |
|---|---|---|
| [0001](0001-generic-transaction-references.md) | Generic Transaction References (`referenceType`/`referenceId`) | مقترح |
| [0002](0002-single-source-of-truth-financial-calculations.md) | Single Source of Truth for Financial Calculations | جزئيًا منفَّذ |
| [0003](0003-backup-versioning-overwrite-protection.md) | Backup Versioning and Overwrite Protection | مقترح — قرار غير محسوم |
| [0004](0004-money-distribution-ownership.md) | Money Distribution Ownership | يوثّق تناقضًا غير محسوم |

راجع أيضًا: `../REFACTOR_STATUS.md`، `../financial-calculation-map.md`،
`../text-parsing-business-logic-inventory.md` — المصادر اللي بُنيت عليها
هذه القرارات.
