<!--
Status: Canonical
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# ADR-0004: Money Distribution Ownership

**الحالة:** يوثّق تناقضًا موجودًا فعليًا في توثيق المشروع — يحتاج حسمًا.
**تاريخ:** مبني على `.agents/memory/money-location-engine.md`،
`.agents/memory/money-distribution-domain.md`، وتاريخ commits حقيقي
(`c7d183a`, `e541a85`) في هذه السلسلة من المحادثات.

---

## Context

المشروع فيه كيانان منفصلان معماريًا يتعاملان مع "مكان الفلوس":

- **`DistributionEngine`** (`money_distribution` feature): يحسب
  Known/Unknown، ملخصات الحصالة/المحفظة. **لا يُعدِّل** `jar.balance` أو
  `wallet.balance` أبدًا — قاعدة موثّقة ومؤكَّدة بالكود.
- **`MoneyLocationEngine`** (`budget` feature): يدير `walletSources`
  (label metadata) و`moneyLocationReviews` على `LinkedWalletEntity`. أيضًا
  **لا يُعدِّل** `jar.balance`/`wallet.balance` — نفس القاعدة.

## Problem

**يوجد تناقض صريح ومباشر بين مستندين موثَّقين في نفس المشروع:**

> `.agents/memory/money-location-engine.md`:
> *"The engine is called from TransactionProcessor only; AppCubit routes
> through addTransaction."*

مقابل:

> `.agents/memory/money-distribution-domain.md`:
> *"TransactionProcessor must NEVER call DistributionEngine or
> MoneyLocationEngine."*

هذا مش خلاف نظري — **حصل فعليًا وأدى لمخالفة حقيقية في هذه السلسلة من
المحادثات:**

1. **Commit `c7d183a`** أضاف استدعاء `MoneyLocationEngine.addSpendingMismatchReview`
   مباشرة من `app_cubit.dart` (**ليس** من `TransactionProcessor`)، مع
   تحديث `walletSources` عبر `updateBudgetSetup` مباشرة — بدون أن يكون
   الاستدعاء معلَّقًا على transaction قابلة للعكس.
2. هذا كان يخالف قاعدة `money-location-engine.md` نفسها (يجب أن يُستدعى
   الـ engine من `TransactionProcessor` فقط) — لكنه كان **متسقًا** مع
   قاعدة `money-distribution-domain.md` (يمنع `TransactionProcessor` من
   استدعاء أي محرّك على الإطلاق)!
3. النتيجة العملية: `walletSources`/`moneyLocationReviews` أُنشئت بدون
   ربط بمعاملة قابلة للعكس، فلما تُحذف المعاملة الأصلية، الـ review يفضل
   **يتيمًا** (orphaned) يشير لمعاملة غير موجودة.
4. **Commit `e541a85`** أصلح جزءًا من الأثر (تنظيف الـ review اليتيم عند
   حذف المعاملة) — لكن **لم يحسم** أي من القاعدتين المتناقضتين هي الصحيحة؛
   هو إصلاح للأثر الجانبي، لا للسبب الجذري.

**السبب الجذري لم يُحسَم بعد**، وأي كود جديد يُبنى على أي من القاعدتين
معرَّض لنفس النوع من المخالفة.

## Decision

**لم يُحسَم بعد — هذا الـ ADR يوثّق التناقض صراحة لطرحه على محمد، وليس
حلاً نهائيًا.** الخياران المتاحان (تفصيل تحت في Alternatives) كلاهما
قابل للتطبيق تقنيًا؛ الاختيار بينهما قرار معماري يخص محمد.

## Alternatives considered

### الخيار أ: الـ Engine يُستدعى من `TransactionProcessor` فقط (كما في `money-location-engine.md`)

- **الميزة:** كل تعديل على `walletSources` مرتبط تلقائيًا بمعاملة —
  لا حاجة لإصلاحات يدوية لاحقة زي `e541a85`؛ العكس (reverse) يتعامل مع
  كل حاجة في مكان واحد.
- **العيب:** يخالف مباشرة قاعدة `money-distribution-domain.md`
  ("`TransactionProcessor` must NEVER call ... `MoneyLocationEngine`")،
  وهي قاعدة موجودة لسبب — على الأرجح لإبقاء `TransactionProcessor` طبقة
  حسابية بحتة (balance فقط) بدون معرفة بطبقات metadata أعلى منه. يحتاج
  فهم السبب الأصلي وراء هذه القاعدة قبل نقضها.

### الخيار ب: الـ Engine يُستدعى من `AppCubit` (`addTransaction`) بعد نجاح `TransactionProcessor.apply`، لكن **معلَّقًا على نفس الـ transaction id**

- هذا فعليًا النمط اللي حصل في `c7d183a` (استدعاء بعد `_applyAndLog`)،
  **لكن مع** ربط صريح لكل review/label بمعاملة قابلة للعكس (بدل تحديث
  `updateBudgetSetup` منفصل).
- **الميزة:** يحافظ على فصل `TransactionProcessor` كطبقة حسابية بحتة
  (متسق مع `money-distribution-domain.md`).
- **العيب:** يتطلب انضباطًا يدويًا من كل مطوّر/أداة (Claude/Codex/Replit)
  لضمان الربط الصحيح بمعاملة في كل استدعاء مستقبلي — لا يوجد إنفاذ
  (enforcement) على مستوى الكومبايلر يمنع الخطأ نفسه من التكرار.

### الخيار ج: توحيد المستندين المتناقضين نفسيهما أولاً (بدون قرار تصميم جديد)

- بدل اختيار أ أو ب، يُراجَع السبب الأصلي وراء كل قاعدة (لماذا كُتبت كل
  واحدة في وقتها) قبل الحسم — **لم يُنفَّذ هذا الفحص التاريخي بعد** في هذه
  المحادثة؛ قد يكشف إن إحدى القاعدتين كانت خطأ كتابي أو تراجعًا لم يُوثَّق
  بشكل كافٍ.

## Consequences

- **بدون حسم هذا الـ ADR، أي عمل مستقبلي على `MoneyLocationEngine` أو
  `TransactionProcessor` معرَّض لتكرار نفس المخالفة**، لأن كلا القاعدتين
  موثَّقتان بنفس القوة في مكانين مختلفين، وأي أداة (بشرية أو AI) قد تتبع
  أيًّا منهما بحسن نية.
- تأجيل القرار له كلفة تراكمية: كل commit جديد يلمس `walletSources` بدون
  حسم هذا التناقض يزيد سطح المشكلة (أماكن أكتر تحتاج مراجعة لاحقًا).

## Migration strategy

غير قابل للتحديد قبل اختيار محمد بين الخيارات أعلاه. عند الحسم:

1. تحديث المستند المخالف (أيًّا كان) في `.agents/memory/` ليعكس القرار
   النهائي — إزالة التناقض من مصدره، لا فقط توثيق قرار جديد فوقه.
2. مراجعة `c7d183a` نفسه: هل يحتاج إعادة هيكلة ليتوافق مع القرار النهائي،
   أم أن إصلاح `e541a85` كافٍ عمليًا؟ (قرار منفصل يحتاج تقييم بعد الحسم.)

**ملاحظة صريحة:** هذا الـ ADR توثيقي بالكامل. لم يُعدَّل أي كود.
