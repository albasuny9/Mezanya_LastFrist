# Mezanya Decisions Log

> يوثّق هذا الملف قرارات محمد بخصوص نطاق العمل، الأولويات، وتصنيف الـ Issues — لا قرارات معمارية تفصيلية (تلك في Domain Bible).

---

## DEC-001 — تجميد Issues #3–#14 كـ "Needs Review / Legacy Architecture"

تاريخ: يوليو 2026
الحالة: نشط

### السياق

أثناء مراجعة الـ 18 issue المفتوحة على GitHub (`albasuny9/Mezanya_LastFrist`)، تبيّن إن 11 منهم (#3 إلى #14) يصفون معمارية غير موجودة في الكود الفعلي على `release_1.0.2` إطلاقًا:
`AppCubitBridge`, `WorkspaceMutations`, `TransactionMutationService`, `WorkspaceCommitService`, `WorkspaceIdGenerator`, `BudgetCubit`/`GoalsCubit` منفصلين.

تحقق بالكود: صفر نتيجة `grep` لأي من هذه الأسماء في المشروع كله. `app_cubit.dart` (الـ Cubit الواحد الفعلي) نشط ومُعدَّل حديثًا (يوليو 2026)، يعني معمارية الـ Cubit الواحد لا تزال هي الواقع الحالي، لا شيء استُبدل بالخطة الموصوفة في هذه الـ issues.

### القرار

- **لا تُغلَق** issues #3–#14.
- **لا تُنفَّذ** حرفيًا كما هي مكتوبة (لأنها تفترض معمارية غير موجودة).
- تُنقَل لمجموعة منفصلة: **"Needs Review / Legacy Architecture"** لحين قرار لاحق: إغلاق، أم إعادة صياغة لتطابق الكود الفعلي.
- ملاحظة تقنية: التوكن الحالي المتاح لـ Claude ما عندوش صلاحية `Issues` على GitHub (Contents فقط)، فمقدرش يتحط label فعلي على الـ issues نفسها من غير توكن جديد بصلاحيات أوسع. هذا الملف هو التتبّع البديل لحد ما يتوفر توكن مناسب.

### القائمة (Needs Review / Legacy Architecture)

- #3 — Final 100% audit roadmap
- #4 — Cursor full audit mission
- #5 — budget_tracking phase BT-1 decomposition execution map
- #6 — mezanya master stabilization roadmap
- #8 — MEZANYA REBUILD MASTER EXECUTION SPEC V2
- #9 — Phase 2 Architecture Fix Plan (AppCubitBridge)
- #10 — Phase 3 Deep Audit
- #11 — Phase 4 Migration Roadmap
- #12 — Phase 5 Hardening Roadmap
- #13 — Phase 6 Data Integrity Roadmap
- #14 — Refactor Phase 1: AppCubit extensions

---

## DEC-002 — Issue #19 يُعامَل كباگ مستقل، لا كنتيجة تلقائية لـ #17/#18

تاريخ: يوليو 2026
الحالة: نشط

لا يُفترَض إن إصلاح #17/#18 (إعادة هيكلة شاشة المعاملة المتكررة) هيحل #19
(فقدان حالة الفئة/الحصالة عند التبديل بين دخل/مصروف) تلقائيًا. بعد
اكتمال #17/#18، يجب **إعادة اختبار #19 من الصفر**. لو المشكلة لسه موجودة،
تُفحص كباگ منفصل بأدلة كود خاصة بيه، لا كعرَض جانبي مفترَض.

---

## DEC-003 — قاعدة إلزامية: لا تنفيذ لأي Issue يمسّ الـ Domain إلا بعد مراجعة Domain Bible

تاريخ: يوليو 2026
الحالة: نشط — إلزامي لكل الأدوات (Claude، Replit، Codex، أي Agent)

**القاعدة:** أي Issue أو مهمة تمسّ تعريف كيان دومين (Transaction, Transfer,
Allocation, Jar, Wallet, Budget) أو العلاقات بينهم، لازم تُراجَع مقابل
`docs/architecture/Mezanya Domain Bible/` **قبل** أي تنفيذ — مش بعده.

**السبب:** الـ Domain Bible لسه بيتأسس (فصول جديدة بتتضاف باستمرار —
Allocation، Persistence، إلخ). لو أداة نفّذت Issue قديم بمفاهيم سابقة
للـ Bible (خصوصًا #7 والـ Transfer domain)، النتيجة هتكون كود بيطبّق
مفهوم دومين قديم/متجاوَز جوه جزء من النظام لسه بيتحدد. هذا بالظبط النمط
اللي أدى لمشكلة DEC-001 (issues بتصف معمارية اتجاوزت الواقع).

**التطبيق العملي:** أي Issue فيه كلمة "Transfer" أو بيمسّ العلاقة بين
Wallet/Jar/Allocation — يُراجَع مقابل `03 - Transfers.md` (وأي فصل لاحق
مرتبط) قبل فتح أي ملف كود.

---

## DEC-004 — ترتيب التنفيذ المعتمد (محمد)

تاريخ: يوليو 2026
الحالة: نشط

**Phase A — توحيد الفورم (أولوية قبل أي حاجة تانية، بما فيها #15
السهلة):**
1. #17 + #18 معًا — نفس Concept شاشة المعاملة العادية، بدون أي تغيير
   Business Logic.
2. اختبار كامل.
3. إعادة اختبار #19 (لا افتراض حل تلقائي — DEC-002). لو اختفت → تُغلَق.
   لو استمرت → تحقيق جذر مستقل.

**السبب المعلَن لبدء Phase A بدل #15 رغم سهولة الأخيرة:** #17/#18 بيغيّروا
أكبر Form في التطبيق، وممكن يكشفوا بَگز جديدة (زي #19) — الأفضل يتثبّت
الفورم الأساسي الأول قبل أي حاجة تانية.

**Phase B:** #15 (تنسيق العملة) — UI فقط.

**Phase C:** #20 — Claude يحدد مصدر الأرقام الصحيح ويثبّت الحسابات أولًا،
بعدين Replit يغيّر الـ UI لمقياس شهري.

**Phase D:** #7 (Transfer Domain) — **بعد اكتمال Domain Bible بالكامل**،
لا قبله (متسق مع DEC-003).

**Needs Review / Legacy Architecture (#3–#14):** تفضل مفتوحة زي ما هي —
لا إغلاق حتى المراجعة اللاحقة (تأكيد DEC-001).
