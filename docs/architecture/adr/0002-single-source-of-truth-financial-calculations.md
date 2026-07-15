<!--
Status: Canonical
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# ADR-0002: Single Source of Truth for Financial Calculations

**الحالة:** جزئيًا منفَّذ (Partially Implemented) — راجع قسم الحالة الحالية.
**تاريخ:** مبني على `financial-calculation-map.md` وتدقيق مباشر لكود
`release_1.0.2` بتاريخ commit `ef2bb9f`.

---

## Context

`financial-calculation-map.md` وثّق حصرًا كاملاً بالدليل: **62 موضع
`.fold()` مالي** في طبقة الـ presentation وحدها، منها **37 موضع (60%)
متركزة في ملفين**: `budget_tracking_screen.dart` (25) و
`budget_setup_screen.dart` (12). التدقيق الهيكلي الكامل لأول ملف كشف
**4 عائلات تكرار حرفي مؤكدة** (نفس الصيغة بالضبط، منسوخة حرفيًا في أكثر
من دالة):

- `planned`/`funded`/`spent`/`remaining`/`ratio` لمخصص واحد — مكررة بين
  `_allocationSummaryTile` و`_openAllocationSheet`.
- `received` لمصدر دخل واحد (+ سلسلة استدعاءات `BudgetIncomeMetricsService`
  المبنية عليها) — مكررة بين دالتين.
- `monthPaid` لدَين واحد — **نفس الصيغة مكررة 3 مرات** في 3 دوال مختلفة.

## Problem

المشروع فيه بالفعل خدمات domain مركزية جزئيًا (`DistributionEngine`,
`BudgetMetricsService`, `BudgetIncomeMetricsService`,
`BudgetRecurringPlanService`) — لكن طبقة الـ presentation لا تلتزم
باستخدامها بشكل متسق. النتيجة: **نفس القيمة المالية تُحسب بصيغ مطابقة في
أكثر من مكان**، وأي تصحيح لباگ في نسخة واحدة قد لا يُطبَّق على النسخ
الأخرى — وهذا بالضبط النمط اللي أدى تاريخيًا لمشاكل "double-accounting"
الموثقة في `.agents/memory/`.

بالإضافة، اكتُشف تكرار **بين خدمتين domain مركزيتين مع بعض**، لا بين
شاشات فقط: `BudgetRecurringPlanService.transactionCountsTowardDebt` و
`budget_income_metrics_service.dart` (سطر 85) يحتويان نفس منطق
`notes.contains(debt.name)` بشكل مستقل — يعني حتى الطبقة "المركزية" نفسها
مش موحّدة بالكامل.

## Decision

**كل قيمة مالية يجب أن يكون لها مالك واحد فقط (Single Owner)** حسب الجدول
الموثّق في `financial-calculation-map.md`:

| المجموعة | المالك |
|---|---|
| Jar Balance (تعديل) | `TransactionProcessor` (فقط) |
| Known/Unknown Distribution | `DistributionEngine` |
| Wallet Reserved/Available | `DistributionEngine` (لـ Reserved؛ مُنفَّذ) |
| Budget Planned/Actual/Remaining | `BudgetCalculationService` (لم يُنشأ بعد — يوسّع `BudgetMetricsService` الموجود) |
| Debt Paid-in-Cycle | `BudgetRecurringPlanService` (يحتاج توسعة بدالة `paidInCycle` تجمع الصيغة المكررة 3 مرات) |

**طبقة الـ presentation (Widgets/Screens) ممنوعة من حساب أي قيمة مالية
مباشرة** (`transactions.fold(...)`, `wallet.balance - ...`, إلخ) — تستقبل
نتيجة جاهزة من الخدمة المناسبة فقط.

## Alternatives considered

1. **ترك كل شاشة تحسب قيمها بنفسها طالما الصيغة متطابقة.** مرفوض — هذا
   الوضع الحالي، وهو السبب المباشر للتكرار الموثّق (4 عائلات تكرار حرفي
   في ملف واحد فقط).
2. **دمج كل الحسابات في `AppCubit` مباشرة بدل خدمات domain منفصلة.**
   مرفوض — `AppCubit` بالفعل عنده 61 دالة عامة (God Cubit موثّق في
   `REFACTOR_STATUS.md` §3)؛ إضافة منطق حسابي إليه يفاقم المشكلة بدل حلها.
3. **خدمة واحدة ضخمة لكل الحسابات المالية.** مرفوض ضمنيًا — الجدول أعلاه
   يوزّع الملكية حسب حدود Bounded Context موجودة بالفعل في المشروع
   (Distribution, Budget, Wallet منفصلين معماريًا).

## Consequences

**إيجابي:**
- تصحيح باگ في مكان واحد يضمن انتشاره لكل نقاط الاستخدام.
- تقليل حجم الشاشات العملاقة تدريجيًا (نقل منطق حسابي، لا UI، خارجها).
- إثبات مبدئي بالفعل نجح: توحيد `Wallet Reserved` في `DistributionEngine`
  (commit `94853f4`) — صفر مخاطرة سلوكية موثّقة، تنفيذ حقيقي لا نظري.

**سلبي / مخاطرة:**
- **حجم العمل الحقيقي كبير:** 37 موضع في ملفين فقط، كل واحد يحتاج نفس
  مستوى التحقق اليدوي (فحص حدود الـ class، فحص اختلاف الفلاتر) اللي
  استغرق وقتًا حقيقيًا حتى لملف واحد صغير نسبيًا (`wallets_screen.dart`).
- **لا توجد اختبارات تغطي `budget_tracking_screen.dart` أو
  `budget_setup_screen.dart`** (موثّق في `REFACTOR_STATUS.md` §6) — نقل
  منطق منهما بدون شبكة أمان اختبارات مخاطرة حقيقية.
- قد يتطلب كشف تفاصيل حالة إضافية عبر `Cubit`/`state` لخدمات الـ domain
  (مثل `monthTx`, `cycleStart/End`) لم تكن مطلوبة سابقًا كباراميترات
  صريحة.

## Migration strategy

**حسب توجيه محمد الصريح: Centralization الفعلي مؤجَّل لمرحلة منفصلة بعد
استقرار الـ Financial Core وبنية الـ Backup بالكامل.** عند البدء:

1. **الأولوية للتكرار الحرفي المؤكد أولاً** (4 عائلات في
   `budget_tracking_screen.dart`) — مخاطرة أقل من نقل منطق فريد
   (single-use)، لأن التحقق من التطابق تم بالفعل.
2. كل نقل = commit منفصل + تحقق يدوي (لا `flutter analyze` متاح في بيئة
   العمل الحالية) + push فوري — نفس نمط `_walletReservedAmount` الناجح.
3. `budget_setup_screen.dart` (12 موضع، أكبر ملف بالمشروع، 4228 سطر) لم
   يُدقَّق هيكليًا بعد بنفس التفصيل — يحتاج جولة تدقيق منفصلة قبل أي نقل.
4. كتابة اختبارات وحدة (unit tests) للخدمة المستهدفة **قبل** نقل أول
   دالة إليها، لا بعدها.

**ملاحظة صريحة:** هذا الـ ADR توثيقي بالكامل. لم يُعدَّل أي كود عدا ما
سبق تنفيذه ونُقل بالفعل (`DistributionEngine.reservationsForWallet`/
`reservedForWallet`، commit `94853f4`).
