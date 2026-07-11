# Financial Calculation Map

> هذا الملف هو نقطة الحقيقة الوحيدة لأي قيمة مالية في مِزانية. أي Bug مالي:
> شوف القيمة هنا، شوف مين "المالك الحالي" الفعلي، مقارنة بـ "المالك المستهدف".
>
> **هذا الملف يوثّق الواقع الفعلي للكود بتاريخ commit `e541a85` (تدقيق مباشر
> بالـ grep، مش تصور).** أي صف فيه "غير مؤكد" معناه محتاج تدقيق إضافي قبل ما
> يُعتمد عليه.
>
> الترتيب المقترح من محمد (4 مراحل: Centralize → Cubit كـ Orchestrator فقط
> → منع المعادلات في Widgets → Documentation) — هذا الملف هو ناتج مرحلة
> التوثيق، ويُستخدم كخريطة توجيه لمرحلة 1.

---

## جدول الملكية

| القيمة | المالك الحالي (الواقع) | تكرار مكتشف؟ | المالك المستهدف |
|---|---|---|---|
| Jar Balance (تعديل) | `TransactionProcessor` فقط (سطر 95، 487) | لا — **مُركزة بالفعل** | يبقى كما هو |
| Known Distribution | `DistributionEngine.summaryForJar` | لا | يبقى كما هو |
| Unknown | `DistributionEngine.snapshotForJar` / `unknownForJar` | ~~نعم~~ **تم الحل** — `jarUnknownDistribution` بقت تستدعي `DistributionEngine.snapshotForJar` مباشرة (حُلّت عبر تعديل متزامن من أداة أخرى أثناء إعداد هذا الملف) | `DistributionEngine` فقط — ✅ محقق |
| Wallet Reserved | `_walletReservedAmount` | ~~نعم~~ **تم الحل** — أُضيفت `DistributionEngine.reservationsForWallet`/`reservedForWallet`، وكلا الكلاسين في `wallets_screen.dart` (`_WalletsScreenState`, `_WalletsListPageState`) يستدعيانها الآن بدل إعادة كتابة المنطق | `DistributionEngine` — ✅ محقق (بقيت `WalletCalculationService` مطلوبة لقيم أخرى غير Reserved) |
| Wallet Available | `wallet.balance - reserved` inline (`wallets_screen.dart` سطر 2154) | غير مؤكد — لم يُفحص بقية المشروع بالكامل | `WalletCalculationService` |
| Actual Budget Expense | `BudgetMetricsService.computeActualBudgetExpense` | غير مؤكد | يبقى كما هو غالبًا (اسم الملف يطابق الاقتراح فعليًا) |
| Income Remaining/Progress | `BudgetIncomeMetricsService.incomeRemainingProgress` | غير مؤكد | يبقى كما هو غالبًا |
| Planned Expense / Progress العام | غير محدد — لم يُعثر على ملف واحد مسؤول | 18 ملف presentation فيها `.fold()` مالي مباشر (انظر القائمة تحت) | `BudgetCalculationService` (يحتاج إنشاء أو توسعة `BudgetMetricsService`) |

---

## الدليل الخام: كل ملف Presentation فيه معادلة مالية inline

نتيجة `grep` مباشر عن `.fold<double>` ومشتقاتها داخل طبقة `presentation` —
هذه القائمة هي **العرض الحقيقي لحجم المشكلة**، مش تقدير:

```
lib/features/app_shell/presentation/screens/main_shell_screen.dart
lib/features/budget/presentation/screens/budget_setup_screen.dart
lib/features/budget/presentation/screens/cycle_analysis_screen.dart
lib/features/budget/presentation/screens/budget_tracking_screen.dart
lib/features/budget/presentation/widgets/budget_hero_bar_chart.dart
lib/features/budget/presentation/widgets/budget_lent_pending_card.dart
lib/features/goals/presentation/screens/goals_screen.dart
lib/features/home/presentation/screens/transaction_charts_screen.dart
lib/features/home/presentation/screens/money_screen.dart
lib/features/home/presentation/screens/all_transactions_screen.dart
lib/features/home/presentation/widgets/money_overview_widgets.dart
lib/features/notifications/presentation/screens/notifications_center_screen.dart
lib/features/notifications/presentation/screens/notifications_screen.dart
lib/features/transactions/presentation/screens/recurring_transactions_screen.dart
lib/features/transactions/presentation/screens/recurring_transaction_composer_screen.dart
lib/features/transactions/presentation/screens/add_transaction_screen.dart
lib/features/wallets/presentation/screens/jar_editor_screen.dart
lib/features/wallets/presentation/screens/wallets_screen.dart
lib/features/wallets/presentation/widgets/jar_details_sheet.dart
```

**ملاحظة مهمة:** مش كل `.fold()` في القائمة دي بالضرورة معادلة مالية حرجة —
بعضها ممكن يكون تجميع بيانات للعرض بس (زي فرز قائمة). **كل ملف من دول محتاج
مراجعة سطر-بسطر قبل نقل أي حاجة منه** — القائمة دي نقطة بداية للتدقيق، مش
قرار نقل جاهز.

---

## المعادلات المؤكدة (Confirmed) حاليًا

### Unknown (مكان الفلوس)
```
unknown = jarBalance <= 0
    ? 0
    : clamp(jarBalance - known, 0, ∞)
```
المصدر: `DistributionEngine.snapshotForJar` (`distribution_engine.dart`).
**نسخة مكررة** بنفس المنطق بالضبط في `jarUnknownDistribution`
(`jar_details_sheet.dart` سطر 54–62) — لسه شغالة صح، بس منسوخة.

### Known Distribution
```
known = sum(entry.amount for entry in distributionEntries where entry.jarId == jarId)
```
المصدر: `DistributionEngine.summaryForJar`.

### Jar Balance (عند معاملة إيداع/سحب)
```
jar.balance_after = jar.balance_before ± delta
```
المصدر: `TransactionProcessor` فقط (سطرين، لا تكرار مكتشف). **هذه نقطة قوة
موجودة بالفعل في الكود — لازم تتحافظ عليها ولا تتفكك في أي refactor قادم.**

### Wallet Reserved
```
reserved = sum(walletReservations[walletId].values)
```
المصدر: `_walletReservedAmount` — **معرّفة مرتين متطابقتين** في
`wallets_screen.dart`.

---

## توصية مباشرة لمرحلة 1 (Centralization) — أولوية داخل الأولوية

بما إن محمد حدد 4 مراحل، وبما إن كل حاجة متساوية أهمية نظريًا، الدليل أعلاه
بيرشّح **نقطتين بالذات كبداية آمنة ومنخفضة المخاطر**:

1. **حذف تكرار `_walletReservedAmount`** داخل نفس الملف (`wallets_screen.dart`)
   — مش نقل بين ملفات، مجرد حذف نسخة مكررة من دالة موجودة بالفعل جنبها.
   صفر مخاطرة سلوكية تقريبًا.
2. **حذف `jarUnknownDistribution` واستبدالها باستدعاء `DistributionEngine`
   مباشرة** — المنطق مطابق حرفيًا، فده تبسيط بدون تغيير سلوك.

هاتين النقطتين تحديدًا تحققان جزء من هدف "مرحلة 1" **بدون فتح أي ملف من
الملفات العملاقة (4000+ سطر)** المذكورة في `REFACTOR_STATUS.md` — يعني
مخاطرة منخفضة جدًا واختبار حقيقي إن مبدأ Centralization بيشتغل قبل التوسع
فيه.

**تصحيح على التقييم الأصلي:** الافتراض الأول في هذا الملف كان إن حذف نسخة
واحدة من `_walletReservedAmount` كافٍ. بعد التحقق، تبيّن إن النسختين في
**كلاسين مختلفين تمامًا** (`_WalletsScreenState` و`_WalletsListPageState`)
— حذف نسخة كان سيكسر الكود فورًا. الحل الفعلي: نقل المنطق لـ
`DistributionEngine` (المالك الصحيح، لأنه يعمل على `moneyDistributions`)
وتحويل كل نسخة لـ wrapper رفيع يستدعيه. تم تنفيذ هذا (انظر الجدول أعلاه).

**ما لم يُنفَّذ في هذا الملف:** أي تعديل كود إضافي غير ما ذُكر أعلاه.

---

## اكتشاف جديد أثناء تدقيق ملفات `.fold()` (غير مغطّى في جدول الملكية أعلاه)

### ⚠️ مبلغ القسط المدفوع — مطابقة نصية هشة، ليست تكرارًا لمعادلة موجودة

**الموقع:** `notifications_center_screen.dart` سطر ~200:
```dart
final paidAmount = cycleTransactions
    .where((transaction) => transaction.notes?.contains(debt.name) == true)
    .fold<double>(0, (sum, transaction) => sum + transaction.amount);
```

هذه معادلة مالية جديدة كليًا (مش موجودة في جدول الملكية، ومش تكرار لحاجة
موجودة في `DistributionEngine`/`BudgetMetricsService`). **المخاطرة:**
الربط بين المعاملة والدَّين يتم عبر **مطابقة نصية على `debt.name` جوه حقل
`notes`**، مش عبر معرّف (`id`) صريح. هذا يعني:
- لو اتغيّر اسم الدَّين بعد إنشاء المعاملات، الحساب يفقد المعاملات القديمة
  بصمت (مفيش خطأ، بس النتيجة غلط).
- لو في دَينين بنفس الاسم أو اسم فرعي من اسم التاني (مثلاً "قسط سامسونج"
  و"قسط سامسونج A54")، `.contains()` هيدمج بينهم.
- لو المستخدم عدّل `notes` يدويًا لأي سبب، الربط ينكسر بصمت.

**الحالة:** تم التحقق بالكامل (راجع القرار أسفل الجدول). لا تعديل كود حاليًا.

### نتيجة التحقق: لا يوجد معرّف ثابت للدين في `TransactionEntity`

فُحصت كل حقول `TransactionEntity` الخمسة عشر (`id, walletId, fromWalletId,
toWalletId, allocationId, toAllocationId, budgetScope, incomeSourceId,
categoryId, transferType, amount, type, createdAt, notes, parentId`) —
لا يوجد حقل باسم `debt` أو ما يعادله. `budgetScope` يحمل قيمة enum ثابتة
فقط (`withinBudget`/`outsideBudget`)، وليس معرّف كيان. نقطة الإنشاء الفعلية
(`debts_and_subscriptions_screen.dart`، زر "سداد قسط") تؤكد: `record.id`
(معرّف الدَّين) **لا يُمرَّر للمعاملة إطلاقًا** — فقط `record.name` يُكتب
داخل `notes` كنص حر.

### القرار (محمد، بعد المراجعة)

**لن يُضاف `debtId`.** لن نضيف مفاتيح خارجية (foreign keys) خاصة بكل
كيان واحدًا تلو الآخر (`debtId`, ثم `goalId`, ثم غيرها لاحقًا). بدلاً من
ذلك، عند مراجعة نموذج البيانات القادمة، سيُضاف مرجع كيان عام على
`TransactionEntity`:

```
referenceType: String?   // مثال: 'debt', 'goal', ...
referenceId:   String?
```

سيحل هذا محل المطابقة النصية لكل من الديون ومستقبلاً أي علاقات كيانات
أخرى، بدل حل يخص الديون بمفرده.

**حتى تصميم تغيير النموذج ده رسميًا: التنفيذ الحالي (`notes.contains`)
يبقى كما هو بدون أي تعديل.** الخطر الموثّق أعلاه (تشابه الأسماء / تغيير
الاسم لاحقًا) يبقى معروفًا وغير محلول عمدًا لحين ذلك.

---

## حصر كامل لعدد مواضع `.fold()` لكل ملف presentation (تم تنفيذه بالكامل)

| الملف | عدد المواضع | التصنيف الأولي |
|---|---:|---|
| `budget_tracking_screen.dart` | **25** | يحتاج فحص فردي — يحتوي على الأقل زوج واحد شبه متطابق (`funded` في سطر 728 و1832، `received` في سطر 560 و1985) |
| `budget_setup_screen.dart` | **12** | لم يُفحص فرديًا بعد |
| `transaction_charts_screen.dart` | 8 | الأرجح تجميع بيانات رسم بياني (زي `budget_hero_bar_chart.dart`) — لم يُؤكَّد |
| `money_overview_widgets.dart` | 4 | لم يُفحص |
| `all_transactions_screen.dart` | 2 | لم يُفحص |
| `jar_editor_screen.dart` | 2 | لم يُفحص |
| `main_shell_screen.dart` | 1 | لم يُفحص |
| `cycle_analysis_screen.dart` | 1 | الأرجح رسم بياني (`maxVal` للمحور) |
| `budget_lent_pending_card.dart` | 1 | لم يُفحص |
| `goals_screen.dart` | 1 | لم يُفحص |
| `notifications_screen.dart` | 1 | لم يُفحص |
| `recurring_transactions_screen.dart` | 1 | لم يُفحص |
| `recurring_transaction_composer_screen.dart` | 1 | لم يُفحص |
| `add_transaction_screen.dart` | 1 | لم يُفحص |
| `jar_details_sheet.dart` | 1 | لم يُفحص (على الأرجح مرتبط بمنطق تم توحيده جزئيًا) |
| **الإجمالي** | **62** | **60% من كل المواضع (37) متركزة في ملفين فقط: budget_tracking_screen و budget_setup_screen** |

**خلاصة صادقة:** التحقق الفردي من الـ 37 موضع في الملفين الأكبر ليس "تدقيقًا
إضافيًا" — هذا هو التنفيذ الفعلي لمرحلة Centralization في أكبر نقطتي تركّز
بالمشروع، ويحتاج نفس مستوى التحقق (فحص حدود الـ class، فحص اختلاف الفلاتر
بين كل نسخة والتانية) اللي اتعمل مع `_walletReservedAmount` — لكن ×18 تقريبًا
من الحجم. هذا يستحق أن يُعامل كمهمة قائمة بذاتها، وليس ذيل تدقيق سريع.
