# تدقيق دورة حياة العمليات المتكررة

**نوع المستند:** تحقيق وتوثيق فقط  
**النطاق:** دورة حياة العمليات المتكررة في مشروع Mezanya  
**حالة التدقيق:** مكتمل  
**حالة التنفيذ:** لا توجد تغييرات كود ضمن هذا التحقيق  
**مصدر الأدلة:** الكود الحالي، اختبارات recurring الحالية، وDomain Bible  

> هذا المستند يوثق السلوك الفعلي المرصود في الكود وقت التحقيق. لا يُعدّ
> تنفيذًا لإصلاح، ولا قرارًا معماريًا نهائيًا. أي قسم بعنوان «مقترح» أو
> «موصى به» هو تصميم مستقبلي فقط.

## 1. الملخص التنفيذي

### النتيجة الرئيسية

**CONFIRMED:** لا توجد دورة حياة واحدة مركزية بالكامل للعمليات المتكررة.
توجد نقطة معالجة تلقائية عامة عند تهيئة `AppCubit`، ومسار مستقل لمعالجة
الديون التلقائية داخل شاشة الميزانية، بالإضافة إلى مسارات تأكيد وتأجيل وتخطي
تُستدعى من أكثر من واجهة.

المحرك المالي نفسه أكثر مركزية: عند إنشاء مناسبة recurring، تقوم دوال التسجيل
المركزية بإنشاء `TransactionEntity` ثم تمريرها إلى
`TransactionProcessor.apply`. لكن قرار *متى* تُنشأ المعاملة، و*من* يعرض
المناسبة، و*من* يطلق التأكيد أو التأجيل، ما زال موزعًا بين:

- `AppCubitRecurringMixin`.
- `BudgetTrackingScreen`.
- `NotificationsScreen`.
- `NotificationsCenterScreen`.
- `RecurringTransactionsScreen`.
- مسارات توزيع الحصالات والمخصصات.

### الحقائق المؤكدة

1. العملية المتكررة تمثل نية مجدولة، وليست أثرًا ماليًا مستقلًا.
2. التسجيل المركزي للدخل والمصروف المتكرر ينشئ معاملة ويمررها إلى
   `TransactionProcessor.apply`.
3. الأثر المالي للحصالة الناتج عن recurring يُطبّق داخل
   `TransactionProcessor`.
4. حالة المناسبة الحالية تعتمد على `lastHandledOccurrenceAt` واحد فقط.
5. لا يوجد `occurrenceId` دائم أو سجل مستقل لمجموعة المناسبات المعالجة.
6. دوال `recordRecurringIncomeOccurrence` و
   `recordRecurringExpenseOccurrence` لا تحتويان على تحقق idempotency مركزي
   مستقل قبل تطبيق المعاملة.
7. بعض الحماية الحالية موجودة في الواجهات، مثل `_processingIds` و
   `_handledOccurrenceKeys`، وليست ضمانًا دائمًا في طبقة الحالة أو المحرك.
8. إشعارات recurring محفوظة، لكن الواجهات تعيد اشتقاق pending state من
   recurring والميزانية والمعاملات، لذلك الإشعار ليس المالك الوحيد للدورة.
9. تعديل أو حذف تعريف recurring لا يعدل تاريخ المعاملات المالية التي سبق
   إنشاؤها.
10. يوجد مسار مستقل لمعالجة الديون التلقائية داخل الميزانية، موازٍ لمسار
    `processDueRecurringOperations`.

### المخاطر الأهم

- **CONFIRMED:** تعدد نقاط الدخول والمسؤوليات المتداخلة.
- **CONFIRMED:** نموذج المناسبة الحالي لا يمثل أكثر من مناسبة overdue بشكل
  مستقل.
- **CONFIRMED:** الحماية من التكرار ليست ضمانًا مركزيًا ذريًا.
- **LIKELY:** قد يؤدي تزامن تأكيد من واجهتين أو إعادة محاولة أثناء الحفظ إلى
  تكرار الأثر المالي إذا تجاوز الطلب حماية الواجهة.
- **LIKELY:** يمكن أن تختلف البطاقات pending بين شاشة الإشعارات وشاشة
  الميزانية لأن كل شاشة تعيد الحساب من مصادر مختلفة.
- **LIKELY:** مسار توزيع الحصالة لديه نافذة اتساق جزئي لأنه يمسح pending ويحفظ
  الحالة قبل إنشاء معاملة التوزيع اللاحقة.
- **UNRESOLVED:** السياسة التجارية المطلوبة عند حذف تعريف recurring بعد
  النشر، وتجربة المستخدم عند وجود عدة مناسبات overdue.

## 2. قواعد Domain Bible ذات الصلة

### 2.1 العملية المتكررة نية مجدولة

**المصدر:**  
`docs/architecture/Mezanya Domain Bible/09 - Recurring Operations.md:14-22`

الفصل يقرر أن recurring يصف موعد تكرار عملية مالية، ولا يملك أثرًا ماليًا
خاصًا به. الأثر يحدث عندما تُنفذ المناسبة وتُنشأ معاملة حقيقية تمر بالمحرك
المالي.

### 2.2 المناسبة لها حالة زمنية

**المصدر:**  
`docs/architecture/Mezanya Domain Bible/09 - Recurring Operations.md:55-...`

المناسبة قد تكون مستحقة أو متأخرة أو مؤجلة أو منفذة أو متخطاة بحسب قواعد
الدومين. التحقيق الحالي وجد أن النموذج البرمجي لا يخزن هذه الحالات كسجل
مستقل لكل مناسبة؛ بل يعيد اشتقاقها من موعد الجدولة وحقلي التأجيل والمعالجة.

### 2.3 المحرك المالي هو حد تغيير الأرصدة

**المصدر:**  
`docs/architecture/Mezanya Domain Bible/04 - Financial Engine .md`  
`docs/architecture/Mezanya Domain Bible/09 - Recurring Operations.md:16-22`

العملية المتكررة لا يجب أن تغير رصيد محفظة أو حصالة أو مخصص مباشرة. يجب أن
تنشئ `TransactionEntity` ثم تمررها إلى المحرك المالي.

### 2.4 المعاملة الناتجة عن recurring لا تختلف عن المعاملة العادية

**المصدر:**  
`docs/architecture/Mezanya Domain Bible/10 - Transaction Lifecycle.md`

المعاملة الناتجة عن مناسبة recurring يجب أن تمر بنفس دورة المعاملة العادية:
إنشاء، تطبيق عبر المحرك، تحديث الحالة، تسجيل الأثر، وحفظ الحالة.

### 2.5 الحقيقة المالية من المعاملات لا من الخطة

**المصدر:**  
`docs/architecture/Mezanya Domain Bible/11 - Financial Ledger.md`

الـ recurring يمثل الخطة أو النية. أما الدخل المستلم أو المصروف الفعلي أو
تغير الرصيد فيعتمد على المعاملة الفعلية والسجل المالي.

## 3. خريطة الاعتماد الفعلية

```text
AppCubit.initialize()
  └─ processDueRecurringOperations()
       ├─ RecurringScheduleEngine.unhandledDueOccurrence()
       ├─ recordRecurringIncomeOccurrence()
       │    ├─ TransactionEntity
       │    ├─ TransactionProcessor.apply()
       │    └─ _applyRecurringSync()
       ├─ recordRecurringExpenseOccurrence()
       │    ├─ TransactionEntity
       │    ├─ TransactionProcessor.apply()
       │    └─ _applyRecurringSync()
       └─ _withDueRecurringNotifications()

BudgetTrackingScreen
  ├─ _processAutomaticDebts()
  │    └─ recordRecurringExpenseOccurrence()
  ├─ _recordIncomeFromTracking()
  │    └─ recordRecurringIncomeOccurrence()
  ├─ _recordDebtFromTracking()
  │    └─ recordRecurringExpenseOccurrence()
  ├─ _postponeIncome()
  │    └─ recordRecurringPostpone()
  └─ _postponeDebt()
       └─ updateRecurringTransaction()

NotificationsScreen
  ├─ يعيد اشتقاق pending للدخل والديون
  ├─ يؤكد الدخل أو الدين
  ├─ يؤجل recurring
  └─ يؤكد توزيع الحصالات/المخصصات

NotificationsCenterScreen
  ├─ يعيد اشتقاق pending من state
  ├─ يحمي النقرات المتكررة محليًا عبر _processingIds
  ├─ يؤكد الدخل أو الدين
  └─ يستدعي مسارات تأجيل وتوزيع مستقلة

RecurringTransactionsScreen
  ├─ يعرض تعريفات recurring
  ├─ ينشئ ويعدل ويحذف التعريف
  └─ يوفر النشر اليدوي عند الحاجة

TransactionProcessor.apply()
  ├─ يضيف TransactionEntity إلى السجل
  ├─ يغير أرصدة المحافظ
  ├─ يغير أرصدة الحصالات والمخصصات
  ├─ ينشئ معاملات فرعية عند تمويل الحصالات
  └─ يعيد AppStateEntity
```

## 4. سلاسل دورة الحياة الكاملة

### 4.1 دخل recurring مستحق ثم تأكيد يدوي

**المسار الرئيسي من شاشة الميزانية:**

```text
BudgetTrackingScreen._recordIncomeFromTracking()
  → BudgetCycleService.linkedRecurringIncome()
  → RecurringScheduleEngine.unhandledDueOccurrence()
  → AppCubit.recordRecurringIncomeOccurrence()
  → إنشاء TransactionEntity من نوع income
  → TransactionProcessor.apply(state, transaction)
  → _applyRecurringSync()
  → lastHandledOccurrenceAt = occurrence
  → snoozedUntil = ''
  → _applyAndLog()
  → حفظ AppState عبر repository
```

**الأدلة:**

- `lib/features/budget/presentation/screens/budget_tracking_screen.dart:2665-2728`
  يحدد المناسبة ثم يستدعي التسجيل المركزي.
- `lib/features/app_state/presentation/cubits/app_cubit_recurring.dart:294-349`
  ينشئ المعاملة ويطبقها ثم يحدث تعريف recurring.
- `lib/features/transactions/domain/services/transaction_processor.dart:22-36`
  يضيف المعاملة إلى قائمة المعاملات ويبدأ تطبيق الأثر المالي.

**الأثر المالي:** نعم، عبر `TransactionProcessor`.  
**أثر recurring:** نعم، تحديث المناسبة المعالجة.  
**أثر الإشعار:** نعم، التسجيل المركزي يطلب تسجيل التاريخ في الإشعارات.  
**أثر الميزانية:** غير مباشر عبر المعاملة و`incomeSourceId` و`budgetScope`.

### 4.2 دخل recurring مستحق ثم نشر تلقائي

```text
AppCubit.initialize()
  → processDueRecurringOperations()
  → يمر على recurring ذات executionType = auto
  → unhandledDueOccurrence()
  → recordRecurringIncomeOccurrence()
  → TransactionProcessor.apply()
  → _applyRecurringSync()
  → _withDueRecurringNotifications()
  → saveState()
```

**الأدلة:**

- `lib/features/app_state/presentation/cubits/app_cubit_recurring.dart:5-56`
  يعالج الدخل والمصروف التلقائي عند وجود مناسبة مستحقة في اليوم نفسه.
- `test/recurring_lifecycle_test.dart:84-105`
  يثبت أن التهيئة تنشئ معاملة دخل وتحدث `lastHandledOccurrenceAt`.

**ملاحظة:** هذا المسار لا يعالج كل أنواع recurring؛ فهو يتجاوز الدخل المتغير
والتعريفات التي ليست `auto`.

### 4.3 مصروف recurring مستحق ثم تأكيد يدوي

```text
NotificationsScreen أو NotificationsCenterScreen أو BudgetTrackingScreen
  → حساب pending من recurring والميزانية
  → recordRecurringExpenseOccurrence()
  → TransactionEntity من نوع expense
  → TransactionProcessor.apply()
  → _applyRecurringSync()
  → تحديث lastHandledOccurrenceAt
  → تسجيل history وحفظ الحالة
```

**الأدلة:**

- `lib/features/app_state/presentation/cubits/app_cubit_recurring.dart:351-398`
  يوضح إنشاء المصروف وتطبيقه وتحديث حالة recurring.
- `lib/features/notifications/presentation/screens/notifications_center_screen.dart:194-237`
  يربط بطاقة الدين بفعل `_recordDebt`.
- `lib/features/budget/presentation/screens/budget_tracking_screen.dart:2840-2855`
  يستدعي التسجيل المركزي لسداد الدين.

### 4.4 مصروف recurring مستحق ثم نشر تلقائي

يوجد مساران:

#### المسار العام

```text
AppCubit.initialize()
  → processDueRecurringOperations()
  → recordRecurringExpenseOccurrence()
```

الدليل:  
`lib/features/app_state/presentation/cubits/app_cubit_recurring.dart:5-43`.

#### مسار الديون داخل الميزانية

```text
BudgetTrackingScreen rebuild / معالجة الشاشة
  → _processAutomaticDebts()
  → _dueOccurrenceNow()
  → wasOccurrenceHandled()
  → _handledOccurrenceKeys
  → فحص alreadyPaidThisCycle
  → recordRecurringExpenseOccurrence()
```

الدليل:  
`lib/features/budget/presentation/screens/budget_tracking_screen.dart:2583-2663`.

**النتيجة:** المساران يستدعيان نفس دالة التسجيل المركزية، لكنهما يقرران
الاستحقاق والحماية من التكرار بشكل مستقل.

### 4.5 دخل recurring مع تمويل حصالة تلقائي

```text
recordRecurringIncomeOccurrence()
  → TransactionEntity:
       incomeSourceId = recurring.incomeSourceId
       walletId = recurring.walletId
       toWalletId = null غالبًا
       transferType = null غالبًا
  → TransactionProcessor.apply()
  → فحص funding المرتبط بـ incomeSourceId
  → updateVirtualBalance() للحصالة الآلية
  → تحديث walletBalances / moneyDistributions حسب نوع التمويل
```

**الأدلة:**

- `app_cubit_recurring.dart:302-318` ينسخ `incomeSourceId` إلى المعاملة.
- `transaction_processor.dart:291-330` يبحث عن خطط التمويل المرتبطة بمصدر
  الدخل ويطبق التمويل الآلي.

**المالك المالي:** `TransactionProcessor.apply()`.  
**المالك recurring:** `recordRecurringIncomeOccurrence()` ثم
`_applyRecurringSync()`.

### 4.6 دخل recurring مع حصالة مستهدفة يدويًا

```text
recordRecurringIncomeOccurrence()
  → toWalletId = recurring.targetJarId
  → transferType = depositWithJarLabel
  → TransactionProcessor.apply()
  → تطبيق الإيداع الموجه للحصالة
```

الدليل:  
`lib/features/app_state/presentation/cubits/app_cubit_recurring.dart:302-318`.

### 4.7 وجود incomeSourceId وtargetJarId معًا

عند وجود المصدر والحصالة معًا، تنشئ دالة التسجيل معاملة تحتوي على:

- `incomeSourceId`.
- `toWalletId`.
- `transferType = depositWithJarLabel`.

داخل `TransactionProcessor` يوجد علم:

```text
manualJarDepositAlreadyApplied =
  transferType == depositWithJarLabel &&
  toWalletId != null
```

وعند تحققه يتم تخطي حلقة التمويل التلقائي للحصالات حتى لا يطبق الإيداع
الموجه والتمويل التلقائي للحصالة نفسها مرتين.

**الدليل:**  
`lib/features/transactions/domain/services/transaction_processor.dart:281-317`.

**الحكم:** توجد حماية صريحة لهذا التعارض داخل المحرك، لكن لا توجد هوية
recurring occurrence مربوطة بالمعاملة نفسها.

### 4.8 تأجيل دخل recurring

```text
BudgetTrackingScreen._postponeIncome()
  → RecurringPostponeDialog.show()
  → BudgetCycleService.linkedRecurringIncome()
  → AppCubit.recordRecurringPostpone()
  → snoozedUntil = selected date
  → _applyRecurringSync()
  → _applyAndLog()
  → حفظ الحالة
```

الدليل:  
`budget_tracking_screen.dart:2732-2771`،  
`app_cubit_recurring.dart:400-419`.

### 4.9 تأجيل مصروف recurring أو تخطيه

```text
BudgetTrackingScreen._postponeDebt()
  → RecurringPostponeDialog.show(allowSkip: true)
  ├─ PostponeChoice.skip
  │    → lastHandledOccurrenceAt = occurrence
  │    → snoozedUntil = ''
  │    → updateRecurringTransaction()
  └─ DateTime
       → snoozedUntil = selected date
       → updateRecurringTransaction()
```

الدليل:  
`budget_tracking_screen.dart:2795-2832`.

يوجد أيضًا مسار مركزي:

- `recordRecurringPostpone()` في
  `app_cubit_recurring.dart:400-419`.
- `recordRecurringSkip()` في
  `app_cubit_recurring.dart:421-440`.

لكن شاشة الميزانية تستخدم `updateRecurringTransaction()` مباشرة في مسار
الدين بدل الدالتين المركزيتين أعلاه.

### 4.10 تأكيد من الإشعار

شاشتا الإشعارات لا تنفذان أثرًا ماليًا مستقلًا. البطاقات تستدعي دوال cubit
التي تنتهي إلى التسجيل المركزي أو إلى مسارات توزيع الحصالات والمخصصات.

**NotificationsCenterScreen:**

- يبني البطاقات من `_pendingNotificationCards`.
- يربط تأكيد الدخل بـ `_recordIncome`.
- يربط تأكيد الدين بـ `_recordDebt`.
- يستخدم `_processingIds` لمنع النقرات المتكررة أثناء الطلب.

الدليل:  
`lib/features/notifications/presentation/screens/notifications_center_screen.dart:37-44`,
`115-191`, `194-237`.

**NotificationsScreen:**

- يعيد بناء pending عبر `_pendingNotifications`.
- يربط أفعال الدخل والدين بالتسجيل والتأجيل.
- يعرض pending توزيع الحصالات والمخصصات بشكل مستقل.

الدليل:  
`lib/features/notifications/presentation/screens/notifications_screen.dart:23-34`,
`94-190`, `240-293`.

### 4.11 تأكيد من شاشة الميزانية

شاشة الميزانية لا تقتصر على العرض:

- تنشئ تسجيل دخل recurring.
- تنشئ تسجيل مصروف recurring.
- تعالج الديون التلقائية.
- تؤجل أو تتخطى المناسبات.
- تحدث recurring state مباشرة في بعض المسارات.

الأدلة الرئيسية:

- `budget_tracking_screen.dart:2583-2663`.
- `budget_tracking_screen.dart:2665-2728`.
- `budget_tracking_screen.dart:2732-2793`.
- `budget_tracking_screen.dart:2795-2855`.

### 4.12 إعادة تشغيل التطبيق مع مناسبة مستحقة

```text
AppCubit.initialize()
  → تحميل AppState من repository
  → processDueRecurringOperations()
  → حساب unhandledDueOccurrence()
  → نشر المناسبات auto
  → إنشاء/تنظيف recurring notifications
  → saveState()
```

الاختبار:

- `test/recurring_lifecycle_test.dart:84-105`.

### 4.13 إعادة التشغيل مع تأكيد pending

الإشعار محفوظ في `AppStateEntity.notifications`، لكن pending cards لا تعتمد
على وجود `NotificationEntity` فقط. شاشات الإشعارات تعيد اشتقاق pending من:

- recurring definitions.
- income sources.
- debts.
- معاملات الدورة أو الشهر.
- `snoozedUntil`.
- `lastHandledOccurrenceAt`.

لذلك إعادة التشغيل تعيد تكوين البطاقة من الحالة الحالية. لا يوجد سجل مستقل
يربط action pending بمناسبة محددة عبر `occurrenceId`.

### 4.14 تشغيل نفس الإجراء مرتين

الحماية المرصودة:

- `NotificationsCenterScreen._processingIds` يمنع النقر المتزامن داخل نفس
  جلسة الواجهة.
- `BudgetTrackingScreen._processingAutomaticDebts` يمنع إعادة الدخول إلى
  المسار التلقائي أثناء تشغيله.
- `_handledOccurrenceKeys` يمنع إعادة المعالجة الناتجة عن rebuild في نفس
  جلسة شاشة الميزانية.
- `lastHandledOccurrenceAt` يجعل المناسبة تبدو معالجة بعد نجاح تحديث الحالة.

لكن دوال التسجيل المركزية نفسها لا تبدأ بفحص:

```text
if (wasOccurrenceHandled(recurring, occurrence)) return;
```

بل تنشئ المعاملة وتطبقها ثم تحدث marker. لذلك لا توجد idempotency مركزية
مستقلة يمكن الاعتماد عليها عبر كل نقاط الدخول.

### 4.15 عدة مناسبات overdue

`RecurringScheduleEngine` يستطيع حساب عدد أو تواريخ مناسبات في نطاق عبر:

- `occurrencesInRange()`.
- `occurrenceDatesInRange()`.

لكن `unhandledDueOccurrence()` يعيد مناسبة واحدة فقط، و
`lastHandledOccurrenceAt` يخزن آخر timestamp واحدًا. لا يوجد داخل
`RecurringTransactionEntity` سجل occurrences أو حالة مستقلة لكل تاريخ.

الدليل:  
`recurring_schedule_engine.dart:300-323`, `414-547`،  
`recurring_transaction_entity.dart:68-69`.

## 5. جميع نقاط الدخول recurring

### 5.1 إنشاء وتعديل وحذف التعريف

| الملف والوظيفة | المستدعي | الغرض | أثر مالي | أثر recurring | أثر إشعار | أثر ميزانية |
|---|---|---|---|---|---|---|
| `AppCubitRecurringMixin.addRecurringTransaction` (`app_cubit_recurring.dart:138-239`) | شاشة composer / شاشة recurring | إنشاء تعريف recurring وربط الدين عند الحاجة | لا | نعم | سجل إداري محتمل | نعم عند debt |
| `updateRecurringTransaction` (`:241-255`) | الشاشات المختلفة | تعديل تعريف أو marker أو snooze | لا مباشرة | نعم | سجل | نعم عند debt |
| `deleteRecurringTransaction` (`:443-468`) | شاشة recurring | حذف التعريف وحذف DebtEntity المرتبط | لا يعكس التاريخ | نعم | سجل | نعم بحذف الدين المرتبط |
| `RecurringTransactionsScreen` (`recurring_transactions_screen.dart:32-120`) | المستخدم | عرض واختيار الإنشاء والتعديل | لا | لا مباشرة | لا | لا مباشرة |

### 5.2 حساب الاستحقاق

| الملف والوظيفة | الاستخدام |
|---|---|
| `RecurringScheduleEngine.dueOccurrenceNow` | حساب مناسبة الاستحقاق الحالية |
| `unhandledDueOccurrence` (`recurring_schedule_engine.dart:300-305`) | إعادة مناسبة due غير المعالجة أو null |
| `wasOccurrenceHandled` (`:307-323`) | مقارنة المناسبة مع marker واحد |
| `expensePrompt` (`:333-412`) | اشتقاق حالة upcoming/due/overdue للمصروف |
| `occurrencesInRange` و`occurrenceDatesInRange` (`:414-547`) | إسقاط أو حساب مناسبات نطاق |
| `_dueOccurrenceNow` في `BudgetTrackingScreen` (`:2577-2581`) | wrapper محلي للمحرك |

### 5.3 إنشاء المعاملة

| الملف والوظيفة | الغرض |
|---|---|
| `recordRecurringIncomeOccurrence` (`app_cubit_recurring.dart:294-349`) | إنشاء دخل recurring وتطبيقه |
| `recordRecurringExpenseOccurrence` (`:351-398`) | إنشاء مصروف recurring وتطبيقه |
| `BudgetTrackingScreen._recordIncomeFromTracking` (`budget_tracking_screen.dart:2665-2728`) | اختيار المناسبة والمبلغ ثم استدعاء التسجيل |
| `BudgetTrackingScreen._recordDebtFromTracking` (`:2840-2855`) | تسجيل دفعة دين |
| `NotificationsScreen` handlers (`notifications_screen.dart:94-190`) | استدعاء التسجيل من بطاقات pending |
| `NotificationsCenterScreen` handlers (`notifications_center_screen.dart:135-237`) | استدعاء التسجيل مع حماية UI محلية |
| `RecurringTransactionsScreen` ومسارات composer | النشر اليدوي من شاشة recurring |

### 5.4 النشر التلقائي

| الملف والوظيفة | الغرض |
|---|---|
| `AppCubitRecurringMixin.processDueRecurringOperations` (`app_cubit_recurring.dart:5-56`) | نشر auto income/expense عند التهيئة |
| `BudgetTrackingScreen._processAutomaticDebts` (`budget_tracking_screen.dart:2583-2663`) | نشر auto debts من شاشة الميزانية |

### 5.5 التأجيل والتخطي

| الملف والوظيفة | السلوك |
|---|---|
| `recordRecurringPostpone` (`app_cubit_recurring.dart:400-419`) | يضبط `snoozedUntil` |
| `recordRecurringSkip` (`:421-440`) | يضبط marker للمناسبة ويمسح snooze |
| `BudgetTrackingScreen._postponeIncome` (`:2732-2771`) | تأجيل دخل recurring أو مصدر دخل غير مربوط |
| `BudgetTrackingScreen._postponeDebt` (`:2795-2832`) | تأجيل أو تخطي دين |
| `_clearIncomePostpone` (`:2773-2793`) | مسح التأجيل من recurring أو income source |
| `_clearDebtPostpone` (`:2834-2838`) | مسح التأجيل من recurring |

### 5.6 الإشعارات

| الملف والوظيفة | السلوك |
|---|---|
| `_withDueRecurringNotifications` (`app_cubit_recurring.dart:58-131`) | تنظيف وإضافة إشعارات recurring المستحقة |
| `NotificationsScreen._pendingNotifications` (`notifications_screen.dart:94-190`) | اشتقاق بطاقات pending |
| `NotificationsCenterScreen._pendingNotificationCards` (`notifications_center_screen.dart:115-298`) | اشتقاق بطاقات pending مع `_processingIds` |
| `NotificationEntity` (`notification_entity.dart:1-75`) | كيان محفوظ للعرض والتاريخ، دون occurrence ID |

### 5.7 تمويل الحصالات والمخصصات

| الملف والوظيفة | السلوك |
|---|---|
| `TransactionProcessor.apply` (`transaction_processor.dart:22-330`) | الأثر المالي وتمويل الحصالات والمخصصات |
| `AppCubitJarsMixin.confirmJarDistribution` (`app_cubit_jars.dart:50-...`) | يمسح pending ثم يستدعي `addTransaction` |
| `AppCubitAllocationsMixin.confirmAllocationDistribution` (`app_cubit_allocations.dart:5-53`) | يبني معاملة ثم يطبقها عبر `TransactionProcessor` |
| `NotificationsCenterScreen` و`NotificationsScreen` | تعرض وتستدعي تأكيد التوزيع |

## 6. مصفوفة ملكية المسؤوليات

| المسؤولية | المالك/المالكون الحاليون | التكرار | تعارض مؤكد |
|---|---|---|---|
| إنشاء المعاملة المالية | `recordRecurringIncomeOccurrence`، `recordRecurringExpenseOccurrence`، ومسارات `addTransaction` للتدفقات غير المربوطة | نعم، حسب نوع التدفق والواجهة | **CONFIRMED** تعدد نقاط الاستدعاء، مع وجود مسار مركزي لإنشاء recurring |
| تحديد المناسبة المستحقة | `RecurringScheduleEngine`، wrappers محلية في الميزانية والإشعارات | نعم | **CONFIRMED** وجود إعادة اشتقاق خارج wrapper مركزي واحد |
| وضع المناسبة كمعالجة | دوال التسجيل، `recordRecurringSkip`، و`updateRecurringTransaction` المباشر | نعم | **CONFIRMED** أكثر من مسار لتحديث marker |
| تأكيد recurring | الإشعارات، الميزانية، شاشة recurring | نعم | **CONFIRMED** نفس العملية يمكن إطلاقها من واجهات متعددة |
| تأجيل recurring | `recordRecurringPostpone`، `updateRecurringTransaction` المباشر، income source fallback | نعم | **CONFIRMED** تعدد المسارات |
| إنشاء إشعار recurring | `_withDueRecurringNotifications` | يبدو مركزيًا نسبيًا | **CONFIRMED** pending UI لا يعتمد على الإشعار وحده |
| استهلاك الإشعار | شاشتا الإشعارات، مع إعادة اشتقاق pending | نعم | **CONFIRMED** الإشعار ليس lifecycle owner وحيدًا |
| تقديم الموعد التالي | `RecurringScheduleEngine.nextOccurrence` والحسابات المشتقة | لا يوجد next field متغير لكل مناسبة | **CONFIRMED** لا يوجد mutation دائم للموعد التالي؛ الحساب اشتقاقي |
| تحديث realized income | `TransactionProcessor` والمعاملات المقروءة بواسطة خدمات الميزانية | لا يوجد تحديث مباشر من recurring marker | لا يوجد تعارض مالي مؤكد |
| تمويل الحصالات تلقائيًا | `TransactionProcessor.apply` | نعم بحسب المعاملة | لا يوجد تعارض مؤكد داخل المحرك عند `depositWithJarLabel` |
| تأكيد توزيع pending للحصالة | `confirmJarDistribution` ثم `addTransaction` | مستقل عن recurring income posting | **LIKELY** نافذة اتساق جزئي بسبب ترتيب الحفظ |

## 7. مسارات متنافسة ومكررة

### 7.1 النشر التلقائي العام مقابل نشر الديون من الميزانية

**CONFIRMED:** كلا المسارين يمكن أن يصلا إلى
`recordRecurringExpenseOccurrence`:

- `processDueRecurringOperations` عند تهيئة التطبيق.
- `_processAutomaticDebts` عند تشغيل/إعادة بناء شاشة الميزانية.

مسار الميزانية يضيف حماية خاصة به:

- `_processingAutomaticDebts`.
- `_handledOccurrenceKeys`.
- فحص `alreadyPaidThisCycle`.

هذه الحماية لا تجعل المسارَيْن مسارًا واحدًا؛ بل تعني أن كل مسار يملك جزءًا
من منطق منع التكرار.

### 7.2 التأكيد من الإشعارات مقابل التأكيد من الميزانية

**CONFIRMED:** كل شاشة تعيد بناء pending state وتستدعي دوال recurring.
لا توجد عملية claim دائمة للمناسبة قبل بدء التطبيق المالي.

### 7.3 دوال التأجيل المركزية مقابل التعديل المباشر

`recordRecurringPostpone` و`recordRecurringSkip` موجودتان في mixin المركزي،
لكن `_postponeDebt` يستخدم `updateRecurringTransaction` مباشرة، ويضع
`lastHandledOccurrenceAt` أو `snoozedUntil` بنفسه.

### 7.4 إشعار محفوظ مقابل pending مشتق

`NotificationEntity` يخزن:

- `id`.
- `type`.
- `message`.
- `createdAt`.
- `isPendingAction`.
- `relatedLogId`.

لكن لا يخزن `recurringId` أو `occurrenceId` كحقول مستقلة. ويتم استخراج
المعرفات في `_withDueRecurringNotifications` من النص المفصول بعلامة `|`.

**CONFIRMED:** الإشعار المحفوظ ليس مصدر الحالة الوحيد.

## 8. هوية المناسبة وIdempotency

### 8.1 الهوية الحالية

هوية المناسبة العملية مكونة من:

- `recurring.id`.
- التاريخ/الوقت المحسوب من الجدول.
- `lastHandledOccurrenceAt` للمقارنة.
- `snoozedUntil` للتأجيل.

النموذج لا يحتوي على:

- `recurringOperationId` داخل `TransactionEntity`.
- `occurrenceId` دائم.
- مجموعة `handledOccurrences`.
- رابط صريح من `NotificationEntity` إلى مناسبة.

### 8.2 ما يثبته الكود

`RecurringTransactionEntity` يخزن:

- `snoozedUntil`.
- `lastHandledOccurrenceAt`.

الدليل:

- `lib/features/transactions/domain/entities/recurring_transaction_entity.dart:31-69`
  لتعريف الحقلين.
- `lib/features/transactions/domain/entities/recurring_transaction_entity.dart:171-200`
  لحفظهما في `toMap`.
- `lib/features/transactions/domain/entities/recurring_transaction_entity.dart:209-246`
  لاستعادتهما من الحالة المحفوظة.

### 8.3 هل يمكن نشر المناسبة نفسها مرتين؟

**الحكم:** توجد حماية جزئية على مستوى الواجهة، لكن لا توجد ضمانة مركزية
كافية لإثبات أن التكرار مستحيل في كل الحالات.

#### الضغط المزدوج داخل مركز الإشعارات

**LIKELY محمي داخل الجلسة نفسها:**  
`NotificationsCenterScreen` يستخدم `_processingIds` قبل استدعاء handler
ويزيل المفتاح بعد انتهاء العملية:

- `notifications_center_screen.dart:37-44`.
- `notifications_center_screen.dart:160-191`.
- `notifications_center_screen.dart:250-262`.

هذه حماية UI مؤقتة، وليست قفلًا محفوظًا أو عملية claim ذرية.

#### الضغط المزدوج على دالة التسجيل نفسها

**CONFIRMED:**  
`recordRecurringIncomeOccurrence` و
`recordRecurringExpenseOccurrence` تنشئان transaction وتستدعيان
`TransactionProcessor.apply` قبل تحديث marker، ولا يظهر في بدايتهما فحص
مركزي يمنع مناسبة معالجة مسبقًا.

الدليل:

- `app_cubit_recurring.dart:294-349`.
- `app_cubit_recurring.dart:351-398`.

#### تأكيد الإشعار والميزانية معًا

**LIKELY خطر:**  
كلتا الواجهتين تعيدان اشتقاق pending وتستطيعان الوصول إلى التسجيل المركزي.
لا يوجد claim دائم للمناسبة قبل التطبيق، ولا رابط occurrence محفوظ في
الإشعار يفرض رفض الطلب الثاني. نجاح الطلب الأول يحدث marker لاحقًا، لكن
الطلب الثاني إذا بدأ قبل انعكاس الحالة أو من snapshot قديم لا يواجه ضمانًا
مركزيًا مستقلًا.

#### إعادة تشغيل التطبيق وإعادة المحاولة

**LIKELY محمي غالبًا بعد الحفظ الناجح:**  
بعد نجاح التسجيل، يتم تحديث `lastHandledOccurrenceAt` وحفظ الحالة. عند
إعادة التهيئة تستبعد `unhandledDueOccurrence` المناسبة التي أصبحت marker
معالجة.

لكن إذا حدث الفشل بعد تطبيق أثر مالي وقبل حفظ marker، أو حدثت عمليتان متوازيتان
قبل الحفظ، لا يوجد في الكود الذي تمت مراجعته ضمان ذري يربط المعاملة بالمناسبة.

#### تشغيل مساري auto في وقت واحد

**CONFIRMED:**  
المسار العام ومسار الديون في الميزانية يملكان حمايات منفصلة. لا توجد
serialization عامة على مستوى cubit أو recurring occurrence تمنع دخولهما معًا.

### 8.4 الاختبارات الحالية

الاختبارات تثبت السلوك المتوقع في مسارات محددة، لكنها لا تثبت تغطية كل
التنافس بين نقاط الدخول:

- `test/recurring_lifecycle_test.dart:65-81` يثبت أن الخطة وحدها لا تجعل
  الدخل المستلم غير صفري.
- `test/recurring_lifecycle_test.dart:84-105` يثبت نشر auto عند التهيئة.
- `test/recurring_lifecycle_test.dart:107-132` يثبت إنشاء إشعار pending
  لتدفق confirm.
- `test/recurring_expense_jar_test.dart:65-113` يثبت إنشاء مصروف recurring
  موجه للحصالة وتحديث marker.
- `test/recurring_expense_jar_test.dart:119-170` يثبت أثر حماية UI عند
  استخدام القاعدة المحدثة بعد النشر، ولا يثبت idempotency مركزية مستقلة
  داخل دالة التسجيل.

## 9. تحليل حد المحرك المالي

### 9.1 النتيجة

**CONFIRMED:** مسارات تسجيل recurring التي تمت مراجعتها تنشئ
`TransactionEntity` ثم تمررها إلى `TransactionProcessor.apply`.

**المسار:**

```text
Recurring definition / UI action
  → recordRecurringIncomeOccurrence أو recordRecurringExpenseOccurrence
  → TransactionEntity
  → TransactionProcessor.apply
  → AppStateEntity جديد
  → تحديث recurring marker
  → repository.saveState عبر _applyAndLog
```

### 9.2 التغييرات المالية داخل TransactionProcessor

`TransactionProcessor.apply` هو المكان الذي:

- يضيف المعاملة إلى `current.transactions`.
- يغير أرصدة المحافظ.
- يغير أرصدة الحصالات والمخصصات.
- يحدث `walletBalances`.
- يحدث `moneyDistributions`.
- ينشئ معاملات فرعية عند الحاجة.

الدليل:

- `lib/features/transactions/domain/services/transaction_processor.dart:22-36`
  لإضافة المعاملة.
- `transaction_processor.dart:38-73` لتحديث توزيع المال ومصادر الحصالة.
- `transaction_processor.dart:75-110` لتحديث الأرصدة الافتراضية والحقيقية.
- `transaction_processor.dart:120-238` لمسارات أثر الدخل/المصروف والتحويل.
- `transaction_processor.dart:291-330` لتمويل الحصالات المرتبط بمصدر الدخل.

### 9.3 هل توجد مباشرة مالية خارج المحرك بسبب recurring؟

لم يثبت التحقيق مسار recurring يغير رصيد محفظة أو حصالة مباشرة خارج
`TransactionProcessor.apply`.

التعديلات المباشرة التي ظهرت في مسارات pending للحصالات والمخصصات ليست
تغييرات رصيد مالية نهائية؛ هي مسح لحالة `pendingDistribution` قبل استدعاء
`addTransaction` لاحقًا:

- `lib/features/app_state/presentation/cubits/app_cubit_jars.dart:50-96`.
- `lib/features/app_state/presentation/cubits/app_cubit_allocations.dart:5-53`.

لكن ترتيب مسار الحصالة يخلق خطر اتساق منفصل موثق في قسم المخاطر.

## 10. تحليل الدخل والراتب

### 10.1 هل يظهر الدخل المخطط كمستلم قبل معاملة حقيقية؟

**CONFIRMED: لا، في المسار الذي يغطيه الاختبار وخدمة المقاييس.**

`BudgetIncomeMetricsService` يستقبل قيمة الدخل المتحقق/المعاملات، ولا يعتبر
وجود `RecurringTransactionEntity` وحده رصيدًا مستلمًا.

الدليل:

- `test/recurring_lifecycle_test.dart:65-81` يتوقع أن يكون
  `incomeDisplayPool` صفرًا عندما لا توجد معاملة.
- `test/recurring_lifecycle_test.dart:84-105` يبين أن قيمة المعاملة تظهر
  بعد `processDueRecurringOperations` وإنشاء transaction.
- `lib/features/budget/domain/services/budget_income_metrics_service.dart`
  يعتمد على المعاملات الفعلية لحساب الدخل المستلم.

### 10.2 مصدر الدخل المخطط

مصدر الخطة يأتي من:

- `IncomeSourceEntity` داخل `budgetSetup.incomeSources`.
- `RecurringTransactionEntity` المربوط عبر `incomeSourceId`.
- خدمات التخطيط مثل `BudgetRecurringPlanService`.

هذا يمثل المتوقع أو المخطط، وليس realized income.

### 10.3 مصدر الدخل المتحقق

المصدر المتحقق هو `TransactionEntity` من نوع income، غالبًا مع:

- `incomeSourceId`.
- `walletId`.
- `budgetScope`.
- `createdAt`.

ويتم إنشاؤه في:

- `recordRecurringIncomeOccurrence`.
- أو `addTransaction` لمسار دخل غير مربوط بتعريف recurring.

### 10.4 الملاحظة الخاصة بالدخل المبكر

`BudgetTrackingScreen._recordIncomeFromTracking` يسمح بمسار `early` ويختار
`nextOccurrence` بدل المناسبة المستحقة عند الحاجة:

- `budget_tracking_screen.dart:2693-2713`.

بعد ذلك ما زال يستخدم `recordRecurringIncomeOccurrence`، وبالتالي يصبح
الأثر المالي معاملة فعلية، بينما يغير marker للمناسبة التي اختارها المسار.

## 11. تحليل تمويل الحصالات

### 11.1 الدخل مع التمويل الآلي

```text
RecurringTransactionEntity
  → incomeSourceId
  → TransactionEntity.incomeSourceId
  → TransactionProcessor.apply
  → البحث في jar.funding
  → تطبيق funding حسب automationType
  → تحديث jar.balance / walletBalances / moneyDistributions
```

الأدلة:

- `app_cubit_recurring.dart:302-318`.
- `transaction_processor.dart:291-330`.

### 11.2 الدخل مع حصالة مستهدفة صراحةً

عند وجود `targetJarId`:

- `toWalletId` يأخذ قيمة الحصالة.
- `transferType` يصبح `depositWithJarLabel`.
- `TransactionProcessor` يطبق الإيداع الموجه.

الدليل:  
`app_cubit_recurring.dart:302-318`.

### 11.3 من ينشئ المعاملة الأب؟

`recordRecurringIncomeOccurrence` ينشئ معاملة دخل واحدة تمثل العملية الأب
من منظور التسجيل:

- `app_cubit_recurring.dart:307-330`.

### 11.4 من ينشئ المعاملات الفرعية؟

المعاملات الفرعية الخاصة بأثر تمويل الحصالة تنشأ داخل
`TransactionProcessor.apply` في فروع التمويل والإيداع، وتحمل `parentId`
وفق مسار المعاملة الفرعية الحالي.

الدليل العام:

- `transaction_processor.dart:22-36` لإضافة المعاملة الأساسية.
- فروع `transaction_processor.dart` الخاصة بتمويل الحصالات
  والمعاملات المرتبطة بها.
- `lib/features/transactions/domain/entities/transaction_entity.dart`
  لتعريف `parentId`.

### 11.5 من يغير رصيد الحصالة؟

`TransactionProcessor.apply` هو المالك المالي لتغيير:

- `LinkedWalletEntity.balance`.
- `LinkedWalletEntity.walletBalances`.
- `moneyDistributions`.

لا يغير recurring هذه القيم بنفسه.

### 11.6 كيف تتم الإزالة/العكس؟

العكس يعتمد على مسار معالجة المعاملة وعلاقتها بالمعاملات الفرعية و`parentId`.
وجود `parentId` يتيح ربط الابن بالأب، لكن لا يوجد في
`RecurringTransactionEntity` رابط occurrence دائم يربط كل أثر مالي بالمناسبة
التي أنشأته.

### 11.7 هل يمكن أن يعمل التمويل اليدوي والآلي معًا؟

داخل `TransactionProcessor` توجد حماية محددة:

```text
manualJarDepositAlreadyApplied
```

وهي تمنع حلقة التمويل الآلي للحصالات عندما تكون المعاملة نفسها إيداعًا
موجهًا يدويًا إلى حصالة.

**الحكم:** عدم تطبيق المسارين على نفس المعاملة محمي داخل المحرك في الحالة
المحددة. أما تكرار نشر نفس المناسبة من معاملتين مختلفتين، فلا يحسمه هذا
العلم لأنه يعمل على كل transaction على حدة.

### 11.8 نافذة تأكيد توزيع الحصالة

`confirmJarDistribution`:

1. يقرأ pending amount.
2. ينشئ state مرحلية بعد تصفير pending.
3. يعمل `emit`.
4. يحفظ state المرحلية.
5. يستدعي `addTransaction`.

الدليل:

- `lib/features/app_state/presentation/cubits/app_cubit_jars.dart:50-96`.

**LIKELY:** إذا فشل إنشاء المعاملة أو الحفظ اللاحق بعد خطوة التصفير، يمكن أن
تختفي حالة pending قبل اكتمال الأثر المالي. لم يثبت التحقيق حدوث الفشل في
التشغيل، لذلك تُصنّف كنقطة خطر لا كعطل مؤكد.

## 12. تحليل الإشعارات

### 12.1 هل الإشعارات محفوظة؟

**CONFIRMED:** `NotificationEntity` جزء من الحالة ويتم تحويله إلى map والعكس.

الدليل:

- `lib/features/notifications/domain/entities/notification_entity.dart:1-75`.
- `app_cubit_recurring.dart:45-56` لحفظ الحالة بعد تحديث الإشعارات.

### 12.2 كيف تُنشأ إشعارات recurring؟

`_withDueRecurringNotifications`:

- يزيل إشعارات recurring التي لم تعد صالحة.
- يقرأ `recurringId` وoccurrence من `message`.
- يبقي الإشعار فقط إذا كان execution type هو confirm والمناسبة غير معالجة.
- ينشئ إشعارًا بمفتاح مشتق من النوع وrecurring id ووقت المناسبة.

الدليل:

- `app_cubit_recurring.dart:58-131`.

### 12.3 هل الإشعار idempotent؟

**جزئيًا فقط على مستوى توليد قائمة الإشعارات.**

المفتاح النصي:

```text
type|recurring.id|occurrence.toIso8601String()
```

يمنع تكرارًا معينًا أثناء إعادة بناء قائمة الإشعارات، لكنه لا يمثل قفلًا
للتنفيذ المالي، ولا يربط action بمعاملة ناتجة.

### 12.4 هل الإشعارات lifecycle owner؟

**CONFIRMED: لا.**

الواجهات تعيد اشتقاق pending state من recurring والميزانية والمعاملات، حتى
عندما تكون `NotificationEntity` محفوظة. كما أن `NotificationEntity` لا يحتوي
حقلًا مستقلًا لـ occurrence أو recurring operation.

### 12.5 هل يمكن للتأكيد تجاوز المحرك المالي؟

في مسارات تأكيد دخل ومصروف recurring التي تمت مراجعتها، التأكيد يصل إلى:

```text
recordRecurring*Occurrence
  → TransactionProcessor.apply
```

ولم يثبت مسار تأكيد recurring يغير الرصيد مباشرة خارج المحرك.

أما تأكيد توزيع الحصالة/المخصص، فهو مسار منفصل ينتهي أيضًا إلى
`addTransaction` و`TransactionProcessor`، مع ملاحظة الترتيب المرحلي المذكورة
أعلاه.

## 13. تحليل الميزانية

### 13.1 ما الذي تفعله شاشة الميزانية؟

**CONFIRMED:** شاشة الميزانية تشارك في دورة recurring ماليًا، ولا تكتفي
بعرض read model:

- تنشر الديون التلقائية.
- تسجل الدخل recurring.
- تسجل دفعات الدين.
- تؤجل دخلًا أو دينًا.
- تتخطى مناسبة دين.
- تحدث recurring marker مباشرة في مسارات معينة.

### 13.2 هل تنشئ معاملات؟

نعم، بصورة غير مباشرة عبر:

- `recordRecurringIncomeOccurrence`.
- `recordRecurringExpenseOccurrence`.
- `addTransaction` عندما لا يوجد تعريف recurring مربوط بمصدر الدخل.

الأدلة:

- `budget_tracking_screen.dart:2704-2727`.
- `budget_tracking_screen.dart:2845-2853`.

### 13.3 هل تغير realized income مباشرة؟

لم يثبت التحقيق تغيير realized income عبر recurring marker فقط. التسجيل
المتحقق يمر بالمعاملة، وخدمات المقاييس تقرأ المعاملات الفعلية.

### 13.4 هل تتشارك الميزانية نفس pending state مع الإشعارات؟

**CONFIRMED:** لا يوجد مالك pending موحد ظاهر في الكود. الميزانية والإشعارات
تستخدمان recurring والميزانية والمعاملات، لكن لكل شاشة حسابات وتجميعات
ومسارات UI خاصة بها.

## 14. التعديل والحذف

### 14.1 إنشاء التعريف قبل الاستحقاق

`addRecurringTransaction` ينشئ تعريف recurring ويحفظه، وقد ينشئ
`DebtEntity` مرتبطًا إذا كان التعريف دينًا أو اشتراكًا:

- `app_cubit_recurring.dart:138-239`.

لا تنشأ معاملة مالية بمجرد حفظ التعريف.

### 14.2 التعديل قبل النشر

`updateRecurringTransaction` يستبدل التعريف في القائمة، ويزامن بعض حقول
`DebtEntity` المرتبط:

- `app_cubit_recurring.dart:241-291`.

لا يوجد أثر مالي مباشر.

### 14.3 التعديل بعد النشر

التعديل يغير تعريف recurring الحالي فقط. المعاملات التاريخية الموجودة لا
يعاد بناؤها ولا تعدلها هذه الدالة.

### 14.4 الحذف بعد النشر

`deleteRecurringTransaction`:

- يحذف recurring definition.
- يحذف `DebtEntity` المرتبط بالمعرف.
- لا يحذف المعاملات التاريخية الناتجة.

الدليل:

- `app_cubit_recurring.dart:443-468`.

**CONFIRMED:** التاريخ المالي يبقى بعد حذف تعريف recurring.

### 14.5 الحذف مع إشعار pending

`_withDueRecurringNotifications` يزيل إشعار recurring إذا لم يجد تعريفًا
مطابقًا أو لم تعد المناسبة صالحة:

- `app_cubit_recurring.dart:64-75`.

لكن لا يوجد occurrence record دائم يوضح للمستخدم ماذا حدث للإجراء المعلق
بعد حذف التعريف.

**UNRESOLVED:** السياسة التجارية المقصودة لإشعار pending عند حذف التعريف.

### 14.6 التعديل أثناء التأجيل

التأجيل مخزن في `snoozedUntil` داخل تعريف recurring. تعديل التعريف قد يغير
الجدول أو marker أو التأجيل بحسب الحقول المرسلة من الشاشة، دون وجود سجل
مناسبات منفصل يحفظ تاريخًا لكل تغيير.

## 15. آلة الحالات الحالية

هذه آلة حالات مستنتجة من الحقول والمسارات الحالية فقط، وليست حالات جديدة:

| الحالة الفعلية/المشتقة | trigger | الكود | النتيجة | الأثر المالي | أثر الإشعار |
|---|---|---|---|---|---|
| تعريف محفوظ وغير مستحق | مرور الوقت قبل الموعد | `nextOccurrence` / `expensePrompt` | يبقى التعريف فعالًا | لا يوجد | قد يظهر upcoming حسب نوع العرض |
| مستحق | بلوغ الموعد | `dueOccurrenceNow` | المناسبة متاحة للتنفيذ | لا يوجد بعد | يمكن إنشاء pending notification |
| متأخر | مرور الموعد دون marker | `expensePrompt` أو pending calculators | يعاد عرض المناسبة الحالية | لا يوجد بعد | pending/overdue مشتق |
| مؤجل | اختيار تاريخ جديد | `recordRecurringPostpone` أو `updateRecurringTransaction` | `snoozedUntil` يمنع المعالجة قبل التاريخ | لا يوجد | يخفي/يؤجل pending |
| متخطى | اختيار skip | `recordRecurringSkip` أو update مباشر | marker يساوي المناسبة وsnooze يمسح | لا يوجد | يزول pending |
| مؤكد يدويًا | ضغط confirm | `recordRecurring*Occurrence` | تنشأ transaction وmarker | نعم عبر المحرك | يسجل history وتنظف pending |
| منشور تلقائيًا | initialization أو مسار ديون الميزانية | `processDueRecurringOperations` أو `_processAutomaticDebts` | تنشأ transaction وmarker | نعم عبر المحرك | قد لا يبقى pending لهذه المناسبة |
| محذوف التعريف | حذف المستخدم | `deleteRecurringTransaction` | يختفي التعريف والدين المرتبط | التاريخ لا يتغير | pending يعاد تنظيفه بالاشتقاق |

### 15.1 التناقضات أو الغموض

- يوجد أكثر من مسار للوصول إلى النشر.
- لا يوجد state record مستقل لكل occurrence.
- `lastHandledOccurrenceAt` الواحد لا يصف قائمة مناسبات overdue.
- pending notification وpending UI ليسا مصدرًا واحدًا.
- بعض مسارات التأجيل تستخدم دوالًا مركزية، وبعضها يعدل recurring مباشرة.

## 16. العيوب المؤكدة

### BUG-A — تعدد مالكي دورة recurring

**CONFIRMED:** توجد نقطة auto عامة ومسار auto مستقل للديون داخل الميزانية،
وتوجد واجهات متعددة تؤكد وتؤجل وتخطي.

**الأدلة:**  
`app_cubit_recurring.dart:5-56`،  
`budget_tracking_screen.dart:2583-2663`،  
`budget_tracking_screen.dart:2665-2855`،  
`notifications_screen.dart:94-190`،  
`notifications_center_screen.dart:115-298`.

### BUG-B — غياب idempotency مركزية في دوال التسجيل

**CONFIRMED كفجوة ضمان:** دوال التسجيل المركزية تطبق transaction ثم تحدث
marker، ولا تحتوي على بوابة idempotency مستقلة تغطي كل المستدعين.

**الأدلة:**  
`app_cubit_recurring.dart:294-398`.

> التصنيف هنا يصف غياب الضمان المركزي، وليس إثباتًا أن التكرار يحدث في كل
> تشغيل. الاختبارات الحالية تثبت حالات محمية عبر الواجهة.

### BUG-C — marker واحد لا يمثل مجموعة المناسبات

**CONFIRMED:** `lastHandledOccurrenceAt` قيمة واحدة، ولا توجد مجموعة
occurrences أو occurrence IDs دائمة.

**الأدلة:**  
`recurring_transaction_entity.dart:31-69`, `209-246`;  
`recurring_schedule_engine.dart:300-323`, `414-547`.

### BUG-D — مسار ديون تلقائي منافس

**CONFIRMED:** `_processAutomaticDebts` يقرر الاستحقاق والحماية ثم يستدعي
نفس التسجيل المركزي خارج `processDueRecurringOperations`.

**الدليل:**  
`budget_tracking_screen.dart:2583-2663`.

### BUG-E — تعدد مسارات التأجيل والتخطي

**CONFIRMED:** يوجد تسجيل مركزي للتأجيل والتخطي، لكن شاشة الميزانية تعدل
recurring مباشرة في مسار الدين.

**الأدلة:**  
`app_cubit_recurring.dart:400-440`;  
`budget_tracking_screen.dart:2795-2832`.

## 17. المخاطر المحتملة

### RISK-A — race condition بين واجهتين

**LIKELY:** إشعار وميزانية أو عمليتا تأكيد قد تستخدمان state قديمة قبل تحديث
marker. لا توجد serialization أو claim ذرية عامة ظاهرة.

### RISK-B — اختلاف pending بين الشاشات

**LIKELY:** كل من `NotificationsScreen` و`NotificationsCenterScreen`
والميزانية يعيد اشتقاق الحالة من مجموعات مختلفة من المعاملات والكيانات.

### RISK-C — نافذة اتساق توزيع الحصالة

**LIKELY:** `confirmJarDistribution` يحفظ تصفير pending قبل إنشاء المعاملة
اللاحقة.

### RISK-D — مطابقة الدين بالاسم

**LIKELY:** بعض حسابات المدفوعات في واجهات الميزانية تستخدم بحثًا في
`transaction.notes` يحتوي على اسم الدين، بدل رابط occurrence أو recurring
ID صريح.

**الدليل:**  
`budget_tracking_screen.dart:2637-2643`،  
`notifications_center_screen.dart:200-208`.

### RISK-E — اعتماد الإشعار على نص مركب

**LIKELY:** `_withDueRecurringNotifications` يستخرج recurring id ووقت
المناسبة من `message` المفصول بعلامة `|` بدل حقول typed مستقلة.

### RISK-F — قبول مناسبة مستقبلية في مسار early

**LIKELY/مقصود وظيفيًا على الأرجح:** مسار `early` يستخدم
`nextOccurrence` ويسجلها فورًا. يلزم قرار تجاري مستقل لتحديد ما إذا كان
هذا يعتبر نشرًا للمناسبة التالية أو تسجيلًا منفصلًا خارج الجدول.

## 18. الضمانات المفقودة

بناءً على الكود الحالي، لم يثبت وجود الضمانات التالية:

1. `occurrenceId` دائم لكل مناسبة.
2. رابط typed بين المعاملة والمناسبة التي أنشأتها.
3. قفل أو claim ذري قبل إنشاء المعاملة.
4. unique constraint على `(recurringId, occurrenceId)`.
5. سجل مستقل للمناسبات المتعددة overdue.
6. transaction boundary واحدة تشمل:
   - الأثر المالي.
   - marker.
   - notification history.
   - حفظ الحالة.
7. مالك واحد لحساب pending state.
8. مالك واحد لتحديد الاستحقاق والنشر التلقائي.
9. سياسة موثقة لحذف recurring بعد وجود تاريخ مالي.
10. سياسة موثقة لمعالجة عدة مناسبات overdue.
11. رابط مستقل بين notification action وoccurrence.
12. ضمان أن مسارات UI لا تستخدم snapshot قديمًا بعد نجاح عملية أخرى.

## 19. دورة حياة canonical مقترحة — تصميم فقط

> هذا القسم لا يطبق أي تغيير. هو تصور تصميمي مستخرج من مشكلات التدقيق، كما
> طلب التكليف الأصلي.

```text
RecurringOperationDefinition
  → ScheduleService يولد Occurrence identity
  → LifecycleOwner يطالب بالمناسبة claim
  → قرار post / skip / postpone
  → عند post:
       إنشاء TransactionEntity مرتبطة بالمناسبة
       TransactionProcessor.apply
       تحديث occurrence state
       إنشاء/تحديث notification history
       حفظ الكل كوحدة واحدة
  → عند skip:
       تحديث occurrence state دون أثر مالي
  → عند postpone:
       تحديث موعد المناسبة نفسها
```

المبادئ المقترحة:

- لا تنشر أي واجهة مباشرة خارج مالك lifecycle واحد.
- لا تعتبر notification مصدر الحقيقة المالي.
- لا تعتبر recurring definition معاملة.
- اربط كل أثر مالي بمناسبة محددة.
- اجعل post/skip/postpone أفعالًا صريحة على occurrence.
- اجعل idempotency جزءًا من مسار الدومين لا من حماية الشاشة فقط.

## 20. مالك دورة الحياة المقترح

**تصميم فقط — غير منفذ:**

مالك واحد في طبقة application/domain مسؤول عن:

1. حساب occurrence.
2. claim أو التحقق من حالتها.
3. تنفيذ post/skip/postpone.
4. استدعاء `TransactionProcessor`.
5. تحديث الحالة المتكررة.
6. إصدار event/notification مشتق.
7. تمرير النتيجة إلى persistence.

تكون الشاشات ومركز الإشعارات مستهلكات لهذا المالك، ولا تعيد تنفيذ
حساب الاستحقاق أو تحديث marker مباشرة.

## 21. مراحل تنفيذ قصيرة مقترحة

> مراحل تصميمية مستقبلية فقط، وليست أعمالًا منفذة في هذا التحقيق.

1. تثبيت تعريف occurrence وهوية المناسبة.
2. جرد كل المستدعين ونقل القرار إلى خدمة lifecycle واحدة.
3. إضافة اختبار idempotency على مستوى core قبل أي تعديل UI.
4. توحيد post/skip/postpone.
5. فصل pending read model عن notification history.
6. توحيد مسار auto للديون والدخل والمصروف.
7. معالجة multiple overdue occurrences بسياسة تجارية صريحة.
8. إضافة اختبارات التنافس وإعادة التشغيل والفشل بين الأثر والحفظ.
9. مراجعة مسار تأكيد الحصالات لضمان الاتساق الذري.

## 22. الملفات التي قد تحتاج تعديلًا في تنفيذ لاحق

> القائمة التالية تحديد نطاق فقط، وليست طلبًا لتنفيذ التعديلات الآن.

- `lib/features/app_state/presentation/cubits/app_cubit_recurring.dart`
- `lib/features/transactions/domain/entities/recurring_transaction_entity.dart`
- `lib/features/transactions/domain/entities/transaction_entity.dart`
- `lib/features/transactions/domain/services/recurring_schedule_engine.dart`
- `lib/features/transactions/domain/services/transaction_processor.dart`
- `lib/features/budget/presentation/screens/budget_tracking_screen.dart`
- `lib/features/notifications/presentation/screens/notifications_screen.dart`
- `lib/features/notifications/presentation/screens/notifications_center_screen.dart`
- `lib/features/notifications/domain/entities/notification_entity.dart`
- `lib/features/app_state/presentation/cubits/app_cubit_jars.dart`
- `lib/features/app_state/presentation/cubits/app_cubit_allocations.dart`
- `lib/features/transactions/presentation/screens/recurring_transactions_screen.dart`
- اختبارات recurring ذات الصلة داخل `test/`.

## 23. الملفات التي لا ينبغي تعديلها ضمن إصلاح recurring دون سبب مثبت

هذه ليست حظرًا مطلقًا، لكنها ملفات خارج نطاق دورة recurring بحسب الأدلة
الحالية، ولا ينبغي تعديلها كحل جانبي قبل إثبات علاقتها:

- واجهات لا تنشئ أو تعرض recurring.
- `TransactionProcessor` لأسباب تجميلية أو لإعادة تصميم عامة لا تخص
  occurrence/idempotency.
- Domain Bible لتبرير سلوك غير موجود في الكود؛ يجب فصل تحديث الدومين عن
  تنفيذ الإصلاح.
- خدمات المقاييس المالية لتغيير معنى realized income قبل إثبات خلل في
  المعاملات الفعلية.
- مسارات النسخ الاحتياطي أو الاسترجاع ما لم يظهر أثر مباشر في حفظ recurring
  أو atomicity الخاصة به.

## 24. خلاصة التصنيف

### CONFIRMED

- تعدد المسارات.
- غياب idempotency مركزية في دوال التسجيل.
- marker واحد للمناسبة.
- مسار ديون تلقائي منافس.
- تعدد مسارات postpone/skip.
- استمرار المعاملات التاريخية بعد حذف تعريف recurring.
- عدم وجود serialization عامة.
- الإشعارات ليست lifecycle owner وحيدًا.
- الأثر المالي recurring يمر بالمحرك في المسارات التي تمت مراجعتها.
- الدخل المخطط لا يُحسب كدخل مستلم قبل وجود transaction في الاختبارات
  وخدمة المقاييس التي تمت مراجعتها.

### LIKELY

- race condition بين واجهتين أو محاولتين متزامنتين.
- اختلاف pending بين الشاشات.
- نافذة اتساق في `confirmJarDistribution`.
- مطابقة الديون بالاسم قد تربط معاملات غير مقصودة.
- الاعتماد على نص الإشعار قد يسبب هشاشة في الاستخراج.

### UNRESOLVED

- السلوك الدقيق عند فتح أو تأكيد نفس الإشعار مرتين بعد اختلاف snapshots.
- السياسة التجارية لحذف recurring بعد النشر.
- سياسة multiple overdue occurrences.
- هل تصبح الإشعارات lifecycle owner أم تبقى read model/trigger.
- هل تسجيل `early` يجب أن يستهلك المناسبة التالية أم يمثل فعلًا منفصلًا.

## 25. حدود التحقيق

هذا التقرير:

- لا يغير كود التطبيق.
- لا يغير Domain Bible أو Decisions.
- لا ينشئ migration.
- لا يحدد قرارًا تجاريًا نهائيًا في النقاط المصنفة UNRESOLVED.
- لا يثبت وقوع race condition في كل تشغيل؛ يثبت فقط غياب الضمان المركزي
  الكافي من الكود الذي تمت مراجعته.
- لا يعتبر وجود مسار غير مثالي bug ماليًا إلا حيث وُصفت الفجوة المؤكدة
  صراحةً.

**نهاية التقرير.**
