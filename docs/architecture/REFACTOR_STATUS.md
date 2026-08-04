<!--
Status: Temporary
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Mezanya — Refactor Status & Gap Report

> هذا الملف لا يكرر `MEZANYA-STRICT-ARCHITECTURAL-REFACTOR-SPECIFICATION.md` ولا
> `feature-refactors/*.md` — كلاهما موجود وشامل بالفعل. هذا الملف يوثّق **الفجوة
> الحقيقية بين الخطة والكود الفعلي حاليًا**، ويحدد نقطة البداية.
>
> آخر تحديث: مبني على فحص مباشر لكود `release_1.0.2` بتاريخ commit `c7d183a`.

---

## 1. الحقيقة الأولى: التوثيق موجود، التنفيذ لأ

المشروع فيه خطة معمارية صارمة (987 سطر) + 6 خطط refactor لكل feature + 18
مجلد "Architecture Maps" + Domain Bible. **المشكلة مش نقص توثيق.** المشكلة إن
حجم الملفات الفعلي لسه بعيد جدًا عن الأهداف المكتوبة في نفس المستندات دي.

## 2. أكبر 10 ملفات — الواقع مقابل الهدف

الهدف الموثّق (Screen): 300–600 سطر. الهدف (Service): 100–300 سطر.

| الملف | السطور الحالية | الهدف | الفجوة | حالة الخطة |
|---|---:|---:|---:|---|
| `budget_setup_screen.dart` | 4228 | 600 | ×7 | **لم تبدأ إطلاقًا** — تُرك عمدًا خارج Phase 2 |
| `budget_tracking_screen.dart` | 2925 | 600 | ×4.9 | Phase 1–3 منفذة جزئيًا (كان 3207) |
| `wallets_screen.dart` | 2713 | 600 | ×4.5 | خطة مكتوبة بالكامل — **0% تنفيذ** |
| `recurring_transaction_composer_screen.dart` | 2668 | 600 | ×4.4 | خطة مكتوبة — لم تبدأ |
| `debts_and_subscriptions_screen.dart` | 2453 | 600 | ×4.1 | لا توجد خطة مخصصة |
| `add_transaction_screen.dart` | 2449 | 600 | ×4.1 | لا توجد خطة مخصصة |
| `app_cubit.dart` | 2297 | — (God Object) | — | خطة مكتوبة (`refactor-settings-appcubit-feature.md`) — لم تبدأ |
| `logs_screen.dart` | 1746 | 600 | ×2.9 | لا توجد خطة |
| `goals_screen.dart` | 1699 | 600 | ×2.8 | لا توجد خطة |
| `jar_details_sheet.dart` | 1618 | 300 (widget) | ×5.4 | لا توجد خطة — وهو نفسه الملف اللي بيتم تعديله باستمرار من كل الأدوات (Claude/Codex/Replit) هذه الأيام |

**إجمالي المشروع: 53,228 سطر عبر 107 ملف.** فقط feature واحد (`budget`) دخل
مرحلة تنفيذ فعلية، وحتى هو توقف عند Phase 3 من أصل 5.

## 3. مشكلة معمارية مش موصوفة في أي خطة موجودة: الـ God Cubit

`app_cubit.dart` فيه **61 دالة عامة (public method)** في كيان واحد بيدير كل
حالة التطبيق (transactions, budget, wallets, notifications, settings,
backup). خطة `refactor-settings-appcubit-feature.md` الموجودة بتذكر الملف
كـ "feature" لوحده لكن مبتفصّلش إزاي هيتقسم الـ Cubit نفسه (feature cubits
منفصلة؟ نفس الـ Cubit مقسّم لـ mixins؟). ده قرار معماري لازم يتاخد قبل أي شغل
تنفيذي على الملف ده — تحطيته من غير قرار واضح هيبقى إعادة ترتيب لغياب حقيقي.

## 4. مخالفة موثقة فعليًا حصلت النهارده (يوليو 9)

Commit `c7d183a` ("إصلاح: منع رفض الصرف المباشر...") ضاف استدعاء
`MoneyLocationEngine.addSpendingMismatchReview` مباشرة من `app_cubit.dart`
مع تحديث `walletSources` عن طريق `updateBudgetSetup` مباشرة — **بدون** أن يكون
مربوطًا بمعاملة (transaction) قابلة للعكس.

هذا يخالف قاعدتين موثقتين في `.agents/memory/money-location-engine.md`:
- *"walletSources changes are always backed by a transaction that can be
  reversed correctly"*
- *"No direct mutation, no `jar.withUpdatedSource()` outside the engine"*

**الحالة:** لا يوجد دليل على أن هذا يسبب باگ فعليًا في السيناريو الحالي (لأن
المراجعة لا تحمل رصيدًا ماليًا)، لكنه مخالفة للقاعدة ويجب حسمها قبل أن يُبنى
عليها كود إضافي. **[Speculation — يحتاج قرار من محمد: هل يُعاد هذا المسار عبر
`addTransaction` بمعاملة label من نوع `jarAllocation`-مشابه، أم تُستثنى
مراجعات "label فقط" من قاعدة "لازم transaction" لأنها بطبيعتها ليست معاملة
مالية؟]**

## 5. الأولوية المقترحة (وليست قرارًا نهائيًا)

الترتيب الموثق فعلاً في الخطة: `Budget → Wallets → Transactions →
Notifications → Home → Settings`. بناءً على الفحص أعلاه، الأولوية العملية:

1. **إغلاق مخالفة §4 أولًا** — قرار معماري بسيط الأثر لكنه يمنع تراكم كود
   جديد فوق مسار مخالف للقاعدة.
2. **إكمال Budget Phase 4–5** (المتبقي من الخطة القائمة) قبل الانتقال —
   الالتزام بـ "أنهِ feature كامل قبل الانتقال لغيره" الموثق في نفس الـ spec.
3. **`budget_setup_screen.dart`** — أكبر ملف في المشروع (4228 سطر) ولم يُلمس
   إطلاقًا؛ يحتاج قرار صريح: هل هو ضمن نطاق Budget الحالي أم Phase منفصلة؟ الخطة
   الحالية صامتة عن هذا تحديدًا.
4. **`app_cubit.dart`** — يحتاج قرار معماري (§3) قبل أي تنفيذ، وليس تنفيذًا
   مباشرًا.
5. Wallets → Transactions → Notifications → Home → Settings كما هو موثق.

## 6. ما لم يتم فحصه في هذا التقرير

- لا توجد أي اختبارات تغطي `add_transaction_screen.dart` أو `app_cubit.dart`
  (يوجد فقط `transaction_processor_test.dart` و
  `budget_metrics_service_test.dart` و`widget_test.dart` الافتراضي).
  أي refactor لهذين الملفين بدون شبكة أمان اختبارات هو مخاطرة حقيقية، ولا حل
  سريع لها غير كتابة اختبارات أولًا.
- لم يتم التحقق يدويًا هنا من أن Phase 1–3 بتاعة Budget فعلاً بتعمل
  `flutter analyze` نظيف على الحالة الحالية للكود (لا يوجد Flutter SDK في
  هذه البيئة).
