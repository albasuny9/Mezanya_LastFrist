# تقرير أداء شامل — تطبيق الميزانية (Mezanya)
**نوع التدقيق:** تحليل ثابت للكود (Static Analysis)
**تاريخ التقرير:** 2026-07-20
**الملفات المُفحوصة:** جميع ملفات `lib/` الرئيسية

---

## ⚠️ ملاحظة منهجية

هذا تدقيق ثابت (static audit) كامل. القياسات الواردة هي تقديرات تحليلية مبنية على قراءة الكود مباشرة، وليست نتائج profiler فعلية. تقدير التكلفة لكل مشكلة بصيغة "X ms" يعتمد على الحجم النموذجي للبيانات (مئات المعاملات، عدة محافظ، عدة حصالات ومخصصات).

---

## القسم الأول: قائمة كل المشاكل المرصودة

---

### 🔴 CRITICAL-01
**الملف:** `lib/features/app_state/presentation/cubits/app_cubit.dart`
**الدالة:** `_applyAndLog()`
**السطور:** 301–346

**وصف المشكلة:**
كل عملية حفظ أي بيانات في التطبيق (معاملة، ميزانية، محفظة، …) تمر عبر `_applyAndLog`. هذه الدالة تُنفّذ **ثلاث عمليات JSON serialize كاملة** لكامل الـ AppState في كل مرة:

1. `jsonEncode(_coreMap(state))` → قبل التعديل (السطر 310)
2. `jsonEncode(_coreMap(nextRaw))` → بعد التعديل (السطر 312)
3. `_repository.saveState(next)` → يُشغّل `jsonEncode(state.toMap())` (السطر 343)

ثم تُخزَّن الـ JSON الكاملة قبل وبعد في كل `LogEntryEntity` (600 سجل كحد أقصى).

**الكلفة المقدّرة:**
- حجم الـ AppState مع 500 معاملة: 200–600 كيلوبايت JSON
- كل serialization: 15–50ms على الـ UI thread (Dart المتزامن)
- المجموع لكل حفظ: **50–150ms** فقط من الـ serialization، بالإضافة إلى كتابة SharedPreferences على القرص

**الأثر المتوقع:** التأخر الواضح عند الضغط على زر "حفظ" (Save) في كل شاشة. كلما زادت المعاملات كلما ازداد التأخر.

**الأولوية:** 🔴 Critical

---

### 🔴 CRITICAL-02
**الملف:** `lib/features/budget/domain/services/budget_metrics_service.dart`
**الدالة:** `BudgetMetricsService.computeActualBudgetExpense()`
**السطور:** 47–75

**وصف المشكلة:**
الدالة تحتوي على `debugPrint` بداخل حلقة `for` تتكرر على كل معاملة في الدورة:
```dart
debugPrint('  [${included ? 'INCLUDED' : 'EXCLUDED'}]  amount=${t.amount} ...');
```
و`debugPrint` إضافية قبل وبعد الحلقة. هذه الدالة تُستدعى في كل `build()` لشاشة `BudgetTrackingScreen`.

في وضع debug، كل `debugPrint` تكتب على stdout وهي عملية متزامنة تستغرق وقتاً غير متوقع على الـ UI thread.

**الكلفة المقدّرة:**
- مع 100 معاملة في الدورة: ~100 debugPrint calls لكل rebuild
- زمن إجمالي: **5–20ms إضافية** على كل build cycle

**الأثر المتوقع:** يُبطئ شاشة Budget Tracking بشكل ملحوظ عند كل تحديث للحالة. يختفي تلقائياً في release build.

**الأولوية:** 🔴 Critical

---

### 🔴 CRITICAL-03
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `build()` ← `StreamBuilder`
**السطور:** 135–354

**وصف المشكلة:**
`BudgetTrackingScreen.build()` يستخدم `StreamBuilder` مباشرة على `widget.cubit.stream`. كل `emit` من الـ cubit (أي تغيير في الـ state) يُعيد بناء الشاشة بالكامل من الصفر، بما في ذلك:

- استدعاء `BudgetCycleService.budgetForMonth()` (راجع CRITICAL-04)
- `BudgetTransactionFilter.forCycle()` → filter + sort على كامل قائمة المعاملات
- `BudgetMetricsService.computeActualBudgetExpense()` (مع debugPrints - CRITICAL-02)
- `_incomeInlineCards()` → دالة تحسب مؤشرات لكل مصدر دخل (راجع HIGH-01)
- `_allocationSummaryTile()` لكل مخصص → حسابات متكررة
- `_installmentCards()` → يمسح كل المعاملات لكل دين
- `_subscriptionCards()` → يحسب الاستحقاقات لكل اشتراك

**الكلفة المقدّرة:**
- rebuild كامل لشاشة بها 5 مصادر دخل + 5 مخصصات + 3 ديون + 500 معاملة: **30–100ms** لكل rebuild
- في حالة `jarNeedingMismatchReview` عند addTransaction: يحدث **emit إضافي** من `updateBudgetSetup`، أي rebuild مضاعف

**الأثر المتوقع:** تجميد واضح عند فتح شاشة Budget Tracking وعند أي تحديث.

**الأولوية:** 🔴 Critical

---

### 🔴 CRITICAL-04
**الملف:** `lib/features/budget/domain/services/budget_cycle_service.dart`
**الدالة:** `BudgetCycleService.budgetForMonth()`
**السطور:** 55–92

**وصف المشكلة:**
عند عرض دورة **غير حالية** (past/future cycle)، تسقط الدالة إلى الـ fallback loop الذي يمشي على **كل سجلات الـ logs** ويُنفّذ `jsonDecode(log.afterState)` لكل سجل حتى يجد واحداً قبل `cycleEnd`:
```dart
for (final log in state.logs) {
  if (log.timestamp.isAfter(cycleEnd)) continue;
  try {
    final map = jsonDecode(log.afterState) as Map<String, dynamic>;
    return AppStateEntity.fromMap(map).budgetSetup;
  } catch (_) { continue; }
}
```
كل `log.afterState` هو JSON كامل للـ AppState (بسبب CRITICAL-01)، أي أن كل `jsonDecode` يُعالج 200–600 كيلوبايت.

**الكلفة المقدّرة:**
- مع 600 سجل (الحد الأقصى)، وكل سجل 300 KB JSON:
- في worst case: **600 × 15ms = 9 ثوانٍ** لفتح دورة قديمة
- حتى في average case (تجد match مبكراً): **100–500ms** بسهولة

**الأثر المتوقع:** فتح شهر قديم = تجميد التطبيق كليًا لثوانٍ. هذه على الأرجح **أبطأ نقطة منفردة في التطبيق**.

**الأولوية:** 🔴 Critical

---

### 🔴 CRITICAL-05
**الملف:** `lib/features/app_state/data/repositories/shared_prefs_app_repository.dart`
**الدالة:** `saveState()`
**السطور:** 33–36

**وصف المشكلة:**
كل الـ AppState تُكتب في **مفتاح واحد** في SharedPreferences كـ JSON blob ضخم. مع نمو البيانات (500+ معاملة، 600 سجل)، يصل حجم هذا الـ blob إلى **1–3 ميجابايت**. كتابة 3 ميجابايت على القرص عبر SharedPreferences تأخذ **20–80ms** وتحدث على الـ UI thread.

علاوة على ذلك، عند `addTransaction` الذي يحتاج `mismatchReview`، يتم استدعاء `saveState` مرتين:
- مرة داخل `_applyAndLog` للمعاملة نفسها
- مرة ثانية داخل `updateBudgetSetup` للـ review

**الكلفة المقدّرة:**
- كتابة blob 1MB: ~20ms
- كتابة blob 3MB: ~60-80ms
- مرتين عند addTransaction مع mismatch: ضعف هذه القيم

**الأثر المتوقع:** تأخر "حفظ المعاملة" يشعر به المستخدم مباشرة.

**الأولوية:** 🔴 Critical

---

### 🔴 CRITICAL-06
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `build()` — debugging closure داخل `build()`
**السطور:** 219–226

**وصف المشكلة:**
داخل `build()` يوجد closure يُنفَّذ كل rebuild:
```dart
() {
  debugPrint('── BudgetHeroSummaryCard inputs ──────────────────');
  debugPrint('  totalIncomeActual  : $totalIncomeActual');
  ...
  return const SizedBox.shrink();
}(),
```
هذه 3 `debugPrint` calls في كل rebuild، وهي متضمنة تحت تعليق `// TODO(debug): remove before release`.

**الكلفة المقدّرة:** صغيرة (3ms)، لكنها في كل rebuild

**الأثر المتوقع:** يُضاف لبطء الـ rebuild في debug mode

**الأولوية:** 🔴 Critical (سهلة الحل جداً)

---

### 🟠 HIGH-01
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `_incomeInlineCards()`
**السطور:** 472–644

**وصف المشكلة:**
لكل مصدر دخل في `_incomeInlineCards()`، يتم استدعاء:

1. `BudgetCycleService.linkedRecurringIncome(state, source)` → تمشي على كل `recurringTransactions`
2. `BudgetCycleService.incomePendingMeta(...)` → تستدعي `linkedRecurringIncome` مرة ثانية داخليًا
3. `BudgetIncomeMetricsService.spentAttributedToIncomeSource(budget, monthTx, source.id)` → O(allocations × monthTx + debts × monthTx)
4. `BudgetIncomeMetricsService.incomeRemainingProgress(...)` → تستدعي `spentAttributedToIncomeSource` مرة ثالثة داخليًا

أي لكل مصدر دخل واحد: `linkedRecurringIncome` يُستدعى **مرتين** و`spentAttributedToIncomeSource` يُستدعى **مرتين**.

**الكلفة المقدّرة:**
- مع 5 مصادر دخل، 10 مخصصات، 200 معاملة في الدورة: ~10ms لكل rebuild

**الأثر المتوقع:** يُبطئ شاشة Budget Tracking على كل rebuild.

**الأولوية:** 🟠 High

---

### 🟠 HIGH-02
**الملف:** `lib/features/budget/domain/services/budget_recurring_plan_service.dart`
**الدالة:** `_dayInRange()`, `_yearlyDayInRange()`, `_multiMonthOccurrences()`
**السطور:** 289–319

**وصف المشكلة:**
هذه الدوال تُحدد هل يوم معين يقع ضمن نطاق تاريخ عن طريق **تكرار يوم بيوم**:
```dart
static bool _dayInRange(int day, DateTime start, DateTime end) {
  var cursor = start;
  while (!cursor.isAfter(end)) {
    if (cursor.day == day.clamp(1, 28)) return true;
    cursor = cursor.add(const Duration(days: 1));
  }
  return false;
}
```
دورة 30 يوم = 30 iteration لكل دين. تُستدعى في كل rebuild عند `_installmentCards` و `_subscriptionCards`.

**الكلفة المقدّرة:**
- مع 5 ديون/اشتراكات × 30 يوم: 150 iterations لكل rebuild
- زمن فعلي: 2–5ms، لكنه غير ضروري إطلاقاً

**الأثر المتوقع:** صغير بمفرده، لكن يتراكم مع غيره.

**الأولوية:** 🟠 High

---

### 🟠 HIGH-03
**الملف:** `lib/features/budget/domain/services/budget_recurring_plan_service.dart`
**الدالة:** `allDebtPayments()`
**السطور:** 149–158

**وصف المشكلة:**
```dart
static List<TransactionEntity> allDebtPayments(AppStateEntity state, DebtEntity debt) {
  final list = state.transactions
      .where((t) => transactionCountsTowardDebt(t, debt))
      .toList()
    ..sort(...);
  return list;
}
```
تمشي على **كل المعاملات التاريخية** (ليس فقط الدورة الحالية) لكل دين، وهذا لعرض حالة الدين الكلية (كم سُدّد من الأصل). تُستدعى في كل rebuild داخل `_installmentCards`.

**الكلفة المقدّرة:**
- 3 ديون × 500 معاملة × string.contains: ~5–10ms لكل rebuild

**الأثر المتوقع:** يُبطئ البناء بشكل ملحوظ مع نمو المعاملات.

**الأولوية:** 🟠 High

---

### 🟠 HIGH-04
**الملف:** `lib/features/transactions/presentation/form/transaction_entry_form.dart`
**الدالة:** `build()`
**السطور:** 799–811

**وصف المشكلة:**
في كل `build()` للـ form، يتم تسجيل `addPostFrameCallback` جديد:
```dart
if (_ctrl.budgetTargetId.isNotEmpty &&
    !allocationItems.contains(_ctrl.budgetTargetId)) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    setState(() => _ctrl.budgetTargetId = '');
  });
}
```
إذا كان الشرط صحيحاً، يتم استدعاء `setState()` بعد كل frame، مما يخلق **حلقة rebuild لا نهائية** حتى يتغير الشرط. حتى إذا كان الشرط خاطئاً، تسجيل callback في كل build هو نمط خاطئ.

**الكلفة المقدّرة:**
- في الحالة العادية: callback يُسجَّل ثم لا يُفعَّل = تسريب صغير
- في حالة الشرط صحيح: **rebuild loop** = التطبيق يجمد أو يصبح متأخراً جداً

**الأثر المتوقع:** يُبطئ فتح Add Transaction Screen وقد يسبب تجميداً.

**الأولوية:** 🟠 High

---

### 🟠 HIGH-05
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `_lentCards()`
**السطور:** 913–1104

**وصف المشكلة:**
لكل شخص في قائمة السلف (`cycleLentPersons`)، تمشي `_lentCards` على **كل المعاملات** (`state.transactions`) بحثًا عن معاملات تحتوي في `notes` على `'سلفة لـ $name'`:
```dart
final personCycleTxs = state.transactions
    .where((t) =>
        ((t.notes?.contains('سلفة لـ $personName') ?? false) || ...)
        && !t.createdAt.isBefore(_cycleStart)
        && !t.createdAt.isAfter(cycleEnd))
    .toList();
```
`String.contains()` مع البحث في Arabic strings أبطأ من مقارنة IDs. مع مئات المعاملات وعدة أشخاص يتكرر هذا كثيراً. 

علاوة على ذلك، هذا البحث بالـ notes يعني أن أي معاملة تحتوي صدفةً على نفس الاسم ستُحسب بطريقة خاطئة.

**الكلفة المقدّرة:**
- 3 أشخاص × 500 معاملة × string.contains: ~5–15ms لكل rebuild

**الأثر المتوقع:** يُبطئ البناء مع نمو البيانات.

**الأولوية:** 🟠 High

---

### 🟠 HIGH-06
**الملف:** `lib/features/app_state/presentation/cubits/app_cubit.dart`
**الدالة:** `addTransaction()` مع `jarNeedingMismatchReview`
**السطور:** 544–590

**وصف المشكلة:**
عند إضافة مصروف من حصالة مع عدم كفاية التوزيع، ينتهي الأمر بـ **emit مزدوج** و**حفظين متتاليين**:
```dart
// أولاً: _applyAndLog للمعاملة الأصلية (emit #1 + save #1)
await _applyAndLog(...apply: () async => TransactionProcessor.apply(state, transaction));

// ثانياً: updateBudgetSetup للـ review (emit #2 + save #2)
await updateBudgetSetup(state.budgetSetup.copyWith(linkedWallets: jars));
```
كل واحدة منهما تحتوي على 3 serializations (CRITICAL-01)، أي المجموع **6 serializations كاملة** لعملية واحدة.

**الكلفة المقدّرة:** 150–300ms للعملية الكاملة

**الأثر المتوقع:** تأخر واضح جداً عند إضافة مصروف من حصالة.

**الأولوية:** 🟠 High

---

### 🟠 HIGH-07
**الملف:** `lib/features/transactions/presentation/form/transaction_entry_form.dart`
**الدالة:** `_submitNormal()`
**السطور:** 412–413

**وصف المشكلة:**
عند تعديل معاملة موجودة، يتم:
```dart
if (widget.initialTransaction != null) {
  await widget.cubit.deleteTransaction(widget.initialTransaction!.id);
}
await widget.cubit.addTransaction(...);
```
**Delete** يُشغّل `_applyAndLog` كاملاً (3 serializations + save).
**Add** يُشغّل `_applyAndLog` كاملاً (3 serializations + save).
المجموع: **6 serializations + 2 writes** لعملية تعديل واحدة.

**الكلفة المقدّرة:** 150–300ms

**الأثر المتوقع:** تأخر ملحوظ عند تعديل أي معاملة.

**الأولوية:** 🟠 High

---

### 🟠 HIGH-08
**الملف:** `lib/features/transactions/domain/services/recurring_schedule_engine.dart`
**الدالة:** `nextOccurrence()` — الفرع الأسبوعي
**السطور:** 141–156

**وصف المشكلة:**
```dart
for (var offset = 0; offset <= 366 * 3; offset++) {
  final day = now.add(Duration(days: offset));
  if (!weekdays.contains(day.weekday)) continue;
  if (!_weekCycleMatches(anchor, day, intervalWeeks)) continue;
  ...
}
```
الحلقة تتكرر حتى **1098 مرة** (366 × 3) للعثور على التكرار الأسبوعي التالي. هذه الدالة تُستدعى لكل اشتراك/دين في `_subscriptionCards` و`_installmentCards` وفي `expensePendingMeta`.

**الكلفة المقدّرة:**
- في worst case: 1098 iterations × عدة استدعاءات
- زمن فعلي: 5–15ms لكل اشتراك أسبوعي

**الأثر المتوقع:** بطء ملحوظ إذا كان هناك اشتراكات بتكرار أسبوعي/كل أسبوعين.

**الأولوية:** 🟠 High

---

### 🟠 HIGH-09
**الملف:** `lib/features/app_state/presentation/cubits/app_cubit.dart`
**الدالة:** `_autoSync()`
**السطور:** 377–413

**وصف المشكلة:**
`_autoSync` يُستدعى بعد كل `_applyAndLog` (وبعد كل save). تحتوي على:
1. `SharedPreferences.getInstance()` مجدداً (I/O ثانوي غير ضروري)
2. `jsonEncode(appState.toMap())` مرة أخرى → **serialization رابعة** (بعد الثلاث في CRITICAL-01)

حتى لو كانت اللامتزامنة (async/non-blocking)، إلا أن الـ serialization نفسها تحدث على الـ Dart isolate الرئيسي.

**الكلفة المقدّرة:** serialization إضافية (15–50ms) لكل save تقريباً

**الأثر المتوقع:** يُبطئ كل العمليات تراكمياً.

**الأولوية:** 🟠 High

---

### 🟡 MEDIUM-01
**الملف:** `lib/features/transactions/presentation/form/transaction_entry_form.dart`
**الدالة:** `initState()` ← `_ctrl.amountController.addListener(_rebuild)`
**السطور:** 88–91

**وصف المشكلة:**
4 TextEditingControllers يستدعون `setState(() {})` على كل تغيير في النص:
```dart
_ctrl.amountController.addListener(_rebuild);
_ctrl.debtPrincipalController.addListener(_rebuild);
_ctrl.installmentCountController.addListener(_rebuild);
_ctrl.downPaymentController.addListener(_rebuild);
```
كل ضغطة مفتاح على حقل المبلغ تُعيد بناء `TransactionEntryForm` كاملاً، وهو يقرأ `widget.cubit.state` ويحسب عشرات المتغيرات من جديد.

**الكلفة المقدّرة:** rebuild عند كل keystroke: ~5ms

**الأثر المتوقع:** الكتابة في حقل المبلغ تبدو بطيئة أو متأخرة.

**الأولوية:** 🟡 Medium

---

### 🟡 MEDIUM-02
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `build()` ← `_isFutureMonth()`, `_isPastMonth()`
**السطور:** 358–360

**وصف المشكلة:**
```dart
bool _isFutureMonth() => _isFutureCycle(widget.cubit.state.budgetSetup);
bool _isPastMonth() => _isPastCycle(widget.cubit.state.budgetSetup);
```
هذه تقرأ من `widget.cubit.state` مباشرة، بينما داخل `build()` تُوجد بالفعل `state` من الـ `StreamBuilder`. هذا يعني استدعاء `getter` إضافي، وأحياناً قد تتعارض مع الـ snapshot.

**الكلفة المقدّرة:** صغيرة جداً، لكنها تدل على عدم اتساق.

**الأولوية:** 🟡 Medium

---

### 🟡 MEDIUM-03
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `_allocationSummaryTile()`
**السطور:** 646–748

**وصف المشكلة:**
لكل مخصص، تُنفَّذ في كل rebuild:
```dart
final funded = allocation.funding.fold<double>(0, (sum, f) {
  final incomeReceived = monthTx
      .where((t) => t.type == income && t.incomeSourceId == f.incomeSourceId)
      .fold<double>(0, (s, t) => s + t.amount);
  return sum + min(incomeReceived, f.plannedAmount);
});
```
بالنسبة لكل funding source (داخل allocation): تمشي على كل `monthTx`. O(fundings × monthTx) لكل مخصص.

**الكلفة المقدّرة:** مع 5 مخصصات × 3 مصادر × 200 معاملة: ~5ms لكل rebuild

**الأثر المتوقع:** يُضاف لبطء الـ rebuild

**الأولوية:** 🟡 Medium

---

### 🟡 MEDIUM-04
**الملف:** `lib/features/transactions/domain/services/transaction_processor.dart`
**الدالة:** `apply()` — income branch with incomeSourceId
**السطور:** 258–390

**وصف المشكلة:**
عند معالجة دخل مرتبط بـ incomeSourceId:
- حلقة على كل `linkedWallets`
- لكل jar: `DistributionEngine.totalFromWalletForJar()` → يمشي على كل `moneyDistributions`
- إضافة sub-transactions جديدة إلى قائمة المعاملات

مع نمو قائمة `moneyDistributions` (تتضخم مع كل دخل)، تصبح هذه العملية أثقل. كما أن كل sub-transaction يُضاف يزيد حجم الـ transactions list الذي يُضغط في JSON لاحقاً.

**الكلفة المقدّرة:** مع 5 jars و100 distribution entries: ~3–8ms للعملية نفسها

**الأثر المتوقع:** يُبطئ معالجة الدخل بشكل تدريجي.

**الأولوية:** 🟡 Medium

---

### 🟡 MEDIUM-05
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `_lentCards()` ← حساب `hasOverdueGlobal`
**السطور:** 946–954

**وصف المشكلة:**
```dart
final hasOverdueGlobal = cycleLentPersons.any((r) =>
    r.hasOutstandingLent &&
    r.lentEntries.any((e) {
      if (e['isSettled'] == true) return false;
      final retStr = e['expectedReturnDate'] as String?;
      if (retStr == null) return false;
      final d = DateTime.tryParse(retStr);  // ← parse في كل rebuild
      return d != null && d.isBefore(DateTime.now());
    }));
```
`DateTime.tryParse()` تُستدعى لكل entry لكل شخص في كل rebuild. قيمة `DateTime.now()` تُعاد حساباً في كل مرة.

**الكلفة المقدّرة:** صغيرة لكنها تحدث في كل rebuild

**الأثر المتوقع:** ضئيل بمفرده

**الأولوية:** 🟡 Medium

---

### 🟡 MEDIUM-06
**الملف:** `lib/features/app_state/presentation/cubits/app_cubit.dart`
**الدالة:** `settleLentRecord()`, `writeOffLentRecord()`, `postponeLentRecord()`
**السطور:** 1891–1931

**وصف المشكلة:**
هذه الدوال تُنفّذ `await settleLentEntry()` أو `writeOffLentEntry()` لكل entry **في حلقة متسلسلة**. كل `settleLentEntry` تستدعي `_applyAndLog` (3 serializations + save). مع 5 entries:

```dart
for (final entry in outstanding) {
  if (entryId != null) await settleLentEntry(personId, entryId); // 5× save!
}
```

5 saves × 3 serializations = **15 serializations** لعملية "تسوية كاملة".

**الكلفة المقدّرة:** 5 entries: ~500ms–1500ms

**الأثر المتوقع:** تجميد تام عند تسوية شخص لديه عدة سلف.

**الأولوية:** 🟡 Medium

---

### 🟡 MEDIUM-07
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `build()` ← حساب `plannedDebts`
**السطور:** 195–204

**وصف المشكلة:**
```dart
final plannedDebts = budget.debts.fold<double>(0, (s, d) {
  final rec = _linkedRecurringDebt(state, d);  // ← scan كل recurringTransactions
  return s + BudgetRecurringPlanService.amountDueInCycle(
    debt: d,
    recurring: rec,
    cycleStart: _cycleStart,
    cycleEnd: _cycleEnd,
  );
});
```
`_linkedRecurringDebt` تمشي على كل `recurringTransactions` لكل دين، وتُستدعى مرة لحساب `plannedDebts` ثم مرة أخرى داخل `_installmentCards`. لا يوجد caching.

**الكلفة المقدّرة:** مع 5 ديون × 20 recurring = 100 scans لكل rebuild

**الأثر المتوقع:** تراكمي مع غيره.

**الأولوية:** 🟡 Medium

---

### 🟡 MEDIUM-08
**الملف:** `lib/features/budget/presentation/widgets/budget_icon_badge.dart` (يُستخدم من budget_tracking_screen.dart)
**الدالة:** `BudgetIconBadge.colorFromHex()`

**وصف المشكلة:**
`colorFromHex()` تُستدعى عشرات المرات في كل rebuild لتحليل hex string → Color. لا يوجد caching. مع 5 مصادر دخل + 5 مخصصات + 3 ديون + 3 اشتراكات = **16+ استدعاء** لكل rebuild.

**الكلفة المقدّرة:** 1ms أو أقل لكنها تحدث في كل rebuild

**الأثر المتوقع:** ضئيل لكن يمكن تحسينه بسهولة.

**الأولوية:** 🟡 Medium

---

### 🟢 LOW-01
**الملف:** `lib/features/transactions/domain/services/transaction_processor.dart`
**الدالة:** `_auditId()`
**السطر:** 17

**وصف المشكلة:**
```dart
static String _auditId(String prefix, int count) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-$count';
```
عند معالجة دخل مع incomeSourceId، قد تُستدعى هذه الدالة عدة مرات داخل نفس الـ function call. في نفس الـ microsecond قد تُنتج IDs متكررة.

**الكلفة المقدّرة:** منخفضة جداً، خطر تضارب IDs نادر.

**الأثر المتوقع:** ضئيل جداً، لكن يدل على نمط غير آمن.

**الأولوية:** 🟢 Low

---

### 🟢 LOW-02
**الملف:** `lib/features/budget/domain/services/budget_transaction_filter.dart`
**الدالة:** `BudgetTransactionFilter.forCycle()`
**السطور:** 66–77

**وصف المشكلة:**
```dart
return tx
    .where(...)
    .toList()
  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
```
Sort يحدث على كل rebuild بدلاً من الحفاظ على قائمة مرتبة مسبقاً. مع 500 معاملة: O(500 log 500) في كل rebuild.

**الكلفة المقدّرة:** ~1–2ms لكل rebuild

**الأثر المتوقع:** ضئيل

**الأولوية:** 🟢 Low

---

### 🟢 LOW-03
**الملف:** `lib/features/budget/domain/services/budget_income_metrics_service.dart`
**الدالة:** `spentAttributedToIncomeSource()`
**السطور:** 83–93

**وصف المشكلة:**
```dart
for (final t in monthTx.where((x) =>
    x.type == expense &&
    x.notes?.contains(debt.name) == true)) {
```
البحث بالـ notes string لمطابقة دفعات الدين نفس مشكلة HIGH-05 ولكن هنا لحساب المصروف. يعتمد على `notes.contains(debt.name)` وهو هش وبطيء.

**الكلفة المقدّرة:** صغيرة

**الأثر المتوقع:** ضئيل

**الأولوية:** 🟢 Low

---

### 🟢 LOW-04
**الملف:** `lib/features/app_state/presentation/cubits/app_cubit.dart`
**الدالة:** `_id()`
**السطر:** 268

**وصف المشكلة:**
```dart
String _id(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';
```
عند إنشاء LogEntryEntity و NotificationEntity داخل `_applyAndLog`، يُستدعى `_id` مرتين. `DateTime.now()` في كل مرة. ليست مشكلة أداء حقيقية، لكن يمكن استبدالها بـ counter أو UUID.

**الأثر المتوقع:** لا شيء يُذكر.

**الأولوية:** 🟢 Low

---

### 🟢 LOW-05
**الملف:** `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
**الدالة:** `build()` — استدعاء `_isFutureMonth/_isPastMonth` مرتين
**السطور:** 141–142

**وصف المشكلة:**
```dart
final futureMonth = _isFutureMonth();
final pastMonth = _isPastMonth();
```
بعدها:
```dart
final showSetupPromptOnly = futureMonth || !hasBudgetPlan;
```
ثم في `BudgetMonthBar`:
```dart
isPast: _isPastCycle(budget),
isFuture: _isFutureCycle(budget),
```
نفس الحساب يحدث مرتين.

**الأثر المتوقع:** لا شيء يُذكر.

**الأولوية:** 🟢 Low

---

## القسم الثاني: أبطأ 10 نقاط في التطبيق

| الترتيب | الموقع | التكلفة المقدّرة | التأثير |
|---------|--------|-----------------|---------|
| 1 | `BudgetCycleService.budgetForMonth()` — الـ logs fallback loop (CRITICAL-04) | 100ms – 9,000ms | فتح شهر قديم يُجمّد التطبيق |
| 2 | `_applyAndLog()` — 3× JSON serialize كاملة (CRITICAL-01) | 50–150ms لكل save | كل حفظ بطيء |
| 3 | `saveState()` — كتابة blob ضخم على SharedPreferences (CRITICAL-05) | 20–80ms | تأخر محسوس عند الحفظ |
| 4 | `addTransaction()` مع mismatchReview = 6 serializations (HIGH-06) | 150–300ms | حفظ مصروف من حصالة بطيء جداً |
| 5 | `_submitNormal()` تعديل معاملة = delete + add = 6 serializations (HIGH-07) | 150–300ms | تعديل معاملة بطيء جداً |
| 6 | `BudgetTrackingScreen.build()` — rebuild كامل على كل emit (CRITICAL-03) | 30–100ms | تجميد شاشة Budget Tracking |
| 7 | `_autoSync()` — serialization رابعة + SharedPrefs.getInstance() (HIGH-09) | 15–50ms لكل save | يُضاف لكل عملية حفظ |
| 8 | `settleLentRecord()` — N saves متسلسلة (MEDIUM-06) | 500–1500ms | تسوية كاملة تجمّد التطبيق |
| 9 | `_incomeInlineCards()` — استدعاءات مكررة (HIGH-01) | 10–30ms لكل rebuild | Budget Tracking بطيء |
| 10 | `allDebtPayments()` — مسح كل المعاملات لكل دين (HIGH-03) | 5–10ms لكل rebuild | يتراكم في Budget Tracking |

---

## القسم الثالث: أسهل 10 كاسبات أداء

| الترتيب | الإجراء | الأثر المتوقع | مستوى الجهد |
|---------|---------|--------------|-------------|
| 1 | حذف `debugPrint` من `computeActualBudgetExpense()` (CRITICAL-02) | -5–20ms لكل rebuild | ⭐ سهل جداً |
| 2 | حذف `debugPrint` من `BudgetTrackingScreen.build()` (CRITICAL-06) | -3ms لكل rebuild | ⭐ سهل جداً |
| 3 | إزالة `WidgetsBinding.addPostFrameCallback` من `build()` في TransactionEntryForm — استبداله بـ check في `initState` أو setter (HIGH-04) | القضاء على rebuild loop | ⭐ سهل |
| 4 | في `_applyAndLog`: إزالة `jsonEncode` قبل/بعد وتخزين الـ diff فقط أو معرف العملية بدلاً من كامل الـ state — أو تقليل `logs` من 600 إلى 50 سجل | تقليل ~66% من كلفة الـ serialization | ⭐⭐ متوسط |
| 5 | في `_incomeInlineCards`: استدعاء `linkedRecurringIncome` و`spentAttributedToIncomeSource` مرة واحدة فقط وحفظ النتيجة في local variable قبل استخدامها (HIGH-01) | -50% كلفة income section | ⭐ سهل |
| 6 | استبدال `_dayInRange` بحساب رياضي مباشر: `day >= cycleStart.day && day <= cycleEnd.day` أو حساب التاريخ المستهدف مباشرة (HIGH-02) | القضاء على 30+ iterations لكل دين | ⭐ سهل |
| 7 | تحويل `BudgetTrackingScreen` من `StreamBuilder` إلى `BlocBuilder` مع `buildWhen` لتحديد متى يُعاد البناء — أو استخدام Selectors | تقليل عدد rebuilds بشكل كبير | ⭐⭐ متوسط |
| 8 | في `_lentCards`: بدلاً من البحث بالـ notes، إضافة `lentPersonId` على TransactionEntity أو استخدام Set من IDs (HIGH-05) | إزالة O(N) string search | ⭐⭐ متوسط |
| 9 | في `settleLentRecord/writeOffLentRecord`: دمج كل الـ entries في `_applyAndLog` واحد بدلاً من loop من N saves (MEDIUM-06) | من N×150ms إلى 150ms | ⭐⭐ متوسط |
| 10 | في `BudgetCycleService.budgetForMonth()`: قبل الـ logs fallback loop، إضافة check أن `monthlyBudgetSnapshots` لا يحتوي على snapshot بمفتاح قريب — وإذا استُخدم الـ logs fallback، تخزين النتيجة في cache بدلاً من إعادة الحساب في كل rebuild (CRITICAL-04) | القضاء على الجزء الأكثر بطئاً | ⭐⭐ متوسط |

---

## القسم الرابع: ترتيب التنفيذ الموصى به

### المرحلة الأولى: كاسبات فورية بدون خطر (أيام)

1. **CRITICAL-02**: حذف `debugPrint` داخل الحلقة في `computeActualBudgetExpense` + `TODO(debug)` في `build()`  
   → يحسّن debug mode فوراً، بدون أي تغيير منطقي.

2. **CRITICAL-06**: حذف debugging closures من `BudgetTrackingScreen.build()`  
   → سطر واحد.

3. **HIGH-04**: إصلاح `addPostFrameCallback` في TransactionEntryForm  
   → نقل الـ check لـ `initState` أو جعله يُستدعى مرة واحدة فقط.

4. **HIGH-01**: تخزين نتائج `linkedRecurringIncome` و`spentAttributedToIncomeSource` في variables محلية وعدم إعادة حسابها  
   → تعديل نصي بسيط جداً.

5. **HIGH-02**: استبدال `_dayInRange` بحساب رياضي  
   → تحسّن فوري لكل شاشة Budget Tracking.

---

### المرحلة الثانية: تقليل الضغط على الـ UI thread (أسبوع)

6. **CRITICAL-01**: تقليل عدد الـ `LogEntryEntity` من 600 إلى 50-100، أو تخزين snapshot مضغوط (أهم حقول فقط) بدلاً من كامل الـ state في `beforeState`/`afterState`  
   → يقلل كلفة كل save بنسبة كبيرة.

7. **MEDIUM-06**: دمج `settleLentRecord` في `_applyAndLog` واحد  
   → يمنع تجميد التطبيق عند تسوية سلف.

8. **HIGH-07**: إضافة `updateTransaction` حقيقية إلى `TransactionProcessor` بدلاً من delete + add  
   → يقلل 6 serializations إلى 3.

9. **HIGH-06**: عند الحاجة لـ mismatch review، دمجه مع الـ transaction نفسها في `_applyAndLog` واحد  
   → يقلل 6 serializations إلى 3.

---

### المرحلة الثالثة: هيكلة الـ UI للحد من الـ rebuilds (أسبوعان)

10. **CRITICAL-03**: تحويل `BudgetTrackingScreen` من `StreamBuilder` إلى `BlocConsumer/BlocBuilder` مع `buildWhen` لتحديد متى يُعاد البناء فعلاً  
    → تقليل عدد الـ rebuilds غير الضرورية.

11. **HIGH-05 + LOW-03**: إضافة `lentPersonId` / `debtId` على TransactionEntity للمطابقة بدلاً من `notes.contains()`  
    → تحسّن أداء وصحة المنطق.

12. **MEDIUM-01**: تأخير rebuild الـ form عند الكتابة (debouncing أو استخدام `ValueNotifier` للمبلغ فقط بدلاً من `setState` كاملاً)

---

### المرحلة الرابعة: معالجة الجذر (أسابيع)

13. **CRITICAL-04 + CRITICAL-05**: الانتقال من SharedPreferences كـ single blob إلى تخزين مقسّم (transactions في ملف منفصل، الـ budget setup في ملف، الـ logs في ملف) أو استخدام Hive/SQLite  
    → يُزيل المشكلة الجذرية لكلفة الـ serialization كلياً.

14. **HIGH-09**: إعادة استخدام `_autoSync` لاستخدام الـ JSON المُنتَج مسبقاً من `saveState` بدلاً من إعادة الـ encode

15. **CRITICAL-04**: تعديل `BudgetCycleService.budgetForMonth()` لتخزين نتائج الـ logs lookup في `_cycleStart`-keyed cache داخل الـ State أو داخل الـ widget

---

## ملخص الأولويات

| الأولوية | العدد | الأثر الكلي |
|---------|------|------------|
| 🔴 Critical | 6 مشاكل | أبطأ نقاط في التطبيق، تسبب تجميداً محسوساً |
| 🟠 High | 9 مشاكل | تأخر واضح في تدفقات المستخدم الأساسية |
| 🟡 Medium | 8 مشاكل | بطء تراكمي يُلاحظ مع نمو البيانات |
| 🟢 Low | 5 مشاكل | تحسينات صغيرة |

**التقدير الكلي**: الإصلاحات الثلاثة الأسهل (CRITICAL-02، CRITICAL-06، HIGH-04) يمكن تنفيذها في ساعة وتُحسّن الاستجابة الذاتية في debug mode. المشاكل الجوهرية (CRITICAL-01، CRITICAL-04، CRITICAL-05) تتطلب إعادة هيكلة الـ persistence layer.
