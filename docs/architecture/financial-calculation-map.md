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
