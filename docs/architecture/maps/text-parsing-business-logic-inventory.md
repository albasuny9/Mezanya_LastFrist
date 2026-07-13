# Text-Parsing Business Logic Inventory

> جرد كامل لكل مكان في المشروع فيه منطق عمل (business logic) معتمد على
> تحليل نص قابل للقراءة البشرية (`notes.contains`, `startsWith`,
> `endsWith`, مطابقة عبر string interpolation). **بحث شامل بالمشروع كله،
> مش عيّنة.** لا تعديل كود — جرد فقط.
>
> طريقة البحث: `grep -rn` لـ `notes.contains`, `notes?.contains`,
> `.startsWith(`, `.endsWith(`, و`.contains(` على حقول نصية أخرى
> (`details`, `.name`, `title`) عبر `lib/` بالكامل.

---

## جدول 1: `notes.contains(...)` — 23 موضع

| # | الملف | السطر | النص المطابَق | التصنيف | الكيان الذي يجب أن يملك المرجع مستقبلاً |
|---|---|---:|---|---|---|
| 1–2 | `debts_and_subscriptions_screen.dart` | 529, 531 | `'سلفة لـ $personName'` / `'استرداد سلفة من $personName'` | **Entity relationship** | كيان "الشخص المُسلَّف" (Lent Person) — لا يوجد entity منفصل له حاليًا، غالبًا مجرد اسم نصي داخل `LentEntry`/`record` |
| 3–4 | `debts_and_subscriptions_screen.dart` | 974, 977 | `'خصم تلقائي دين: ${currentRecord.name}'` | **Entity relationship** | `DebtEntity` |
| 5–6 | `debts_and_subscriptions_screen.dart` | 1879, 1880 | `'سداد دين: ${record.name}'` / `'سداد قسط: ${record.name}'` | **Entity relationship** | `DebtEntity` |
| 7–9 | `debts_and_subscriptions_screen.dart` | 2144–2146 | `'دفع اشتراك:'` / `'سداد اشتراك:'` / `'سداد قسط: ${record.name}'` | **Entity relationship** | `DebtEntity` (الاشتراكات نوع فرعي من نفس الكيان حسب الكود) |
| 10 | `recurring_transactions_screen.dart` | 886 | `notes.contains(recurringName)` | **Entity relationship** | `RecurringTransactionEntity` |
| 11 | `notifications_center_screen.dart` | 199 | `debt.name` | **Entity relationship** (تكرار لـ #14) | `DebtEntity` |
| 12 | `notifications_screen.dart` | 144 | `debt.name` | **Entity relationship** (تكرار لـ #14) | `DebtEntity` |
| 13 | `budget_tracking_screen.dart` | 536 | `debt.name` | **معطّل (كود مُعلَّق/dead code)** — لا يُصنَّف كموضع حي | — |
| 14 | `budget_tracking_screen.dart` | 1004, 1005, 1018 | `'سلفة لـ $name'` / `'استرداد سلفة من $name'` | **Entity relationship** | كيان الشخص المُسلَّف (نفس #1–2) |
| 15 | `budget_tracking_screen.dart` | 1040, 1041 | نفس نمط السَّلف | **Entity relationship** | نفس #1–2 |
| 16 | `budget_tracking_screen.dart` | 1197, 1198 | نفس نمط السَّلف | **Entity relationship** | نفس #1–2 |
| 17 | `budget_tracking_screen.dart` | 2716 | `debt.name` | **Entity relationship** | `DebtEntity` — **هذا هو المصدر المركزي الفعلي**: نفس المنطق موجود كدالة باسم `BudgetRecurringPlanService.transactionCountsTowardDebt` (`notes.contains(debt.name)` حرفيًا) |
| 18 | `budget_income_metrics_service.dart` | 85 | `debt.name` | **Entity relationship** — **داخل خدمة domain مركزية بالفعل** | `DebtEntity` |
| 19 | `main_shell_screen.dart` | 233 | `debt.name` | **Entity relationship** (تكرار آخر لنفس نمط `DebtEntity`) | `DebtEntity` |

**ملخص جدول 1:** كل الـ 23 موضع (فيما عدا واحد معطّل) هي **Entity
relationship** — لا يوجد موضع واحد من نوع UI formatting أو Search-only أو
Legacy هنا. تنقسم فعليًا لمجموعتين حسب الكيان المستهدف:
- **`DebtEntity`** (13 موضع: #3–13، #17–19) — المالك المركزي الموجود
  فعلاً جزئيًا: `BudgetRecurringPlanService.transactionCountsTowardDebt`
  و`budget_income_metrics_service.dart` سطر 85 (تكرار للمنطق نفسه داخل
  خدمة مختلفة — تكرار بين خدمتين مركزيتين، وليس فقط بين شاشات).
- **الشخص المُسلَّف / Lending** (6 مواضع: #1–2، #14–16) — **لا يوجد أي
  خدمة مركزية لهذا النمط حاليًا** (بعكس الديون).
- **`RecurringTransactionEntity`** (#10) — حالة منفصلة تمامًا، موضع وحيد.

---

## جدول 2: `.startsWith(...)` — 19 موضع

| # | الملف | السطر | النمط | التصنيف | الكيان الذي يجب أن يملك المرجع مستقبلاً |
|---|---|---:|---|---|---|
| 1–8 | `add_transaction_screen.dart` | 252, 257, 329, 332, 482, 485, 690, 723, 733, 798 | `budgetTargetId.startsWith('alloc:')` / `.startsWith('jar:')` | **Entity relationship** — معرّف مركّب (composite id) بادئته نصية تحدد نوع الهدف (مخصص أم حصالة) | لا يوجد كيان مالك حاليًا — نفس فئة مشكلة `debtId` تمامًا؛ الحل المتسق منطقيًا هو نفس قرار `referenceType + referenceId` المؤجَّل بالفعل لملف الديون، مطبَّق هنا على هدف المعاملة (`targetType`/`targetId`) بدل بادئة نصية على `String` واحد |
| 9–14 | `transaction_details_sheet.dart` | 1251–1256 | `note.startsWith('حجز للحصالة')` وما شابه | **UI formatting** — يُستخدم *بعد* التحقق من `transferType` (enum فعلي: `jarFunding`/`jarFundingPhysical`) فقط لتحديد نص فرعي للعرض، مش لتحديد نوع المعاملة نفسه | لا حاجة لمالك جديد — الربط الحقيقي بالكيان موجود ومضمون عبر `transferType` بالفعل؛ هذا مجرد تصنيف نص للعرض |
| 15–17 | `notification_history_helper.dart` | 65–70 (`_legacyPendingActionPrefixes` + بادئتان إضافيتان) | `message.startsWith(prefix)` | **Legacy compatibility** — الاسم نفسه `_legacyPendingActionPrefixes` يوثّق النية؛ يعمل كـ fallback بعد فحص `item.relatedLogId` (معرّف حقيقي) في نفس الدالة | لا حاجة لمالك جديد — طبقة توافق قديمة صريحة ومقصودة |

**ملخص جدول 2:** 10 مواضع Entity relationship حقيقية (كلها نفس النمط
الواحد `budgetTargetId`)، 6 مواضع UI formatting بريئة فعليًا (محمية
بفحص `transferType` قبلها)، 3 مواضع Legacy compatibility معلنة صراحة في
التسمية.

---

## جدول 3: مطابقة نصية أخرى (`.contains` على حقول غير `notes`)

| # | الملف | السطر | النمط | التصنيف |
|---|---|---:|---|---|
| 1–2 | `notification_action_copy.dart` | 139–140 | `title.contains('جنيه')` / `title.contains('—')` | **UI formatting بحت** — تحديد هل نص الإشعار "يبدو كجملة كاملة" لأغراض تنسيق العرض فقط، لا علاقة له بأي كيان |

لا توجد مواضع `.endsWith(` في المشروع كله (0 نتيجة).

---

## الخلاصة الإجمالية

| التصنيف | العدد | ملاحظة |
|---|---:|---|
| **Entity relationship** | **32** | 19 منها لـ `DebtEntity` (بينها تكرار داخل خدمتين domain مختلفتين، مش بس شاشات UI)، 6 لكيان "شخص مُسلَّف" غير موجود بعد، 10 لهدف المعاملة (مخصص/حصالة) عبر `budgetTargetId`، 1 لـ `RecurringTransactionEntity` |
| **UI formatting** | 8 | 6 محمية بالفعل بفحص `transferType` قبلها (مخاطرة منخفضة)، 2 تنسيق نص بحت |
| **Legacy compatibility** | 3 | معلنة صراحة بالتسمية (`_legacyPendingActionPrefixes`) |
| **Search/filter only** | 0 | لم يُعثر على أي موضع من هذا النوع |
| **معطّل (dead code)** | 1 | لا يُحتسب |

### أهم ملاحظة هيكلية

**مشكلة `budgetTargetId.startsWith('jar:'/'alloc:')` (10 مواضع) هي نفس
فئة مشكلة `debtId` بالضبط**، وكلاهما مرشّح طبيعي لنفس الحل المؤجَّل
(`referenceType` + `referenceId`) بدل حلين منفصلين. هذا يُرجَّح كفة توسيع
نطاق تصميم النموذج القادم ليشمل *هدف المعاملة* (target)، مش الديون فقط.

**التكرار بين خدمتين مركزيتين (`BudgetRecurringPlanService` و
`budget_income_metrics_service.dart`) لنفس منطق `notes.contains(debt.name)`**
يعني إن المشكلة مش بس "شاشات بتنسخ من بعض" — فيه تكرار حتى على مستوى طبقة
الـ domain نفسها، وهذا أهم من تكرار الشاشات لأنه يعني حتى لو تم توحيد
الاستدعاء من الشاشات، لسه فيه نسختين من "الحقيقة" داخل الـ domain.

**ما لم يُنفَّذ:** أي تعديل أو نقل كود. هذا جرد فقط، حسب التوجيه.
