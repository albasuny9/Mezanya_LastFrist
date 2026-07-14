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
