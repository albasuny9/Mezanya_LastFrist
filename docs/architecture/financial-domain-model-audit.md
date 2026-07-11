# Financial Domain Model Audit

> تدقيق للكيانات المالية فقط — مسؤوليات، ملكية الحسابات، تسريبات
> مسؤولية، ازدواج ملكية، مراجع غير مستقرة، حقول قديمة. **توثيقي بالكامل،
> صفر تعديل كود.** مبني على فحص مباشر للكيانات والخدمات بتاريخ commit
> `6ab814c`. يعيد استخدام نتائج موثّقة سابقًا (`financial-calculation-map.md`,
> `text-parsing-business-logic-inventory.md`) بدل إعادة اشتقاقها، ويضيف
> اكتشافات جديدة على مستوى تعريف الكيانات نفسها (لا الحسابات فقط).

---

## ملاحظة هيكلية عامة قبل الجداول

**لا يوجد ملف كيان مستقل لـ Jar، Allocation، Debt، أو Subscription.** كل
الأربعة معرَّفة كـ classes منفصلة داخل ملف واحد ضخم:
`lib/features/budget/domain/entities/budget_setup_entity.dart` (يحتوي:
`IncomeSourceEntity`, `AllocationFundingEntity`, `AllocationEntity`,
`LinkedWalletEntityFunding`, `LinkedWalletEntity` (=Jar), `JarWalletSource`,
`DebtEntity`, `BudgetSetupEntity`). هذا نفسه مثال على تسريب مسؤولية على
مستوى تعريف البيانات، لا الحسابات فقط — ملف واحد يملك تعريف 6+ كيانات
مختلفة معماريًا.

**لا يوجد `SubscriptionEntity` منفصل.** الاشتراكات هي `DebtEntity` بقيمة
`kind` مختلفة (حقل `kind` على `DebtEntity` يفرّق بين دَين واشتراك، مؤكَّد
من الكود، لا افتراض).

---

## Wallet (`WalletEntity`)

**الملف:** `lib/features/wallets/domain/entities/wallet_entity.dart`

**الحقول:** `id, name, balance, reservedForSavings, icon, iconColor, isHighlighted`

| البند | التفاصيل |
|---|---|
| **المسؤوليات** | تمثيل محفظة حقيقية (physical) — رصيد نقدي فعلي |
| **مالك الحسابات** | `TransactionProcessor` (تعديل `balance`، مؤكَّد سابقًا: سطرين فقط، لا تكرار) |
| **ملفات أخرى تحسب قيمها مباشرة** | `wallets_screen.dart` (`_walletReservedAmount`/`_walletReservations` — **تم توحيدها في `DistributionEngine` بالفعل**، commit `94853f4`) |
| **تسريب مسؤولية** | لا يوجد حاليًا على `balance` نفسها (مُركزة) |
| **ازدواج ملكية** | **لا يوجد ازدواج على `balance`** — لكن يوجد **التباس تسمية خطير**: `wallet.reservedForSavings` (حقل مخزَّن على الكيان) مقابل `DistributionEngine.reservedForWallet(...)` (قيمة محسوبة) — **مفهومان مختلفان تمامًا بنفس كلمة "Reserved" تقريبًا**، قابلان للخلط من أي مطوّر/أداة جديدة |
| **مراجع غير مستقرة** | لا يوجد — `id` هو المرجع الوحيد المستخدم |
| **⚠️ حقل قديم مرشَّح للحذف** | **`reservedForSavings`: حقل ميت بالكامل.** فُحص كل استخدام له في المشروع — موجود فقط داخل تعريف الكيان نفسه (constructor, copyWith, toMap, fromMap). **صفر قراءة أو كتابة من أي منطق عمل أو UI في أي مكان آخر.** مرشَّح واضح للحذف بعد تأكيد عدم استخدامه في نسخ محفوظة قديمة (backups/Firestore) قبل الحذف الفعلي. |

---

## Jar (`LinkedWalletEntity`)

**الملف:** `budget_setup_entity.dart` (داخل الملف الضخم المذكور أعلاه)

**الحقول:** `id, name, balance, monthlyAmount, executionDay, fundingSource, funding[], icon, iconColor, automationType, categories[], walletBalances{}, walletSources[], isHighlighted`

| البند | التفاصيل |
|---|---|
| **المسؤوليات** | تمثيل حصالة (فيزيائية أو label-only حسب النقاش المفاهيمي السابق مع محمد) — رصيد + جدولة تلقائية + تصنيفات |
| **مالك الحسابات** | `TransactionProcessor` لـ `balance` (مؤكَّد)؛ `DistributionEngine` لـ Known/Unknown |
| **ملفات أخرى تحسب قيمها مباشرة** | راجع `financial-calculation-map.md` — 4 عائلات تكرار حرفي في `budget_tracking_screen.dart` تخص هذا الكيان تحديدًا (`planned/funded/spent/remaining/ratio`, مكررة بين `_allocationSummaryTile`/`_openAllocationSheet` — **ملاحظة: هذا التكرار موصوف في الملف باسم "Allocation" لكن بعض المسارات تُطبَّق على Jar أيضًا حسب السياق — يحتاج تمييز أدق لم يُنفَّذ بعد**) |
| **تسريب مسؤولية** | `walletBalances{}` (Map مخزَّن مباشرة على الكيان) **يبدو متداخلاً مفاهيميًا مع** `walletSources[]` (`JarWalletSource`، نفس الكيان أيضًا) — **حقلان مختلفان لتخزين توزيع نفس الفكرة (مكان الفلوس) على نفس الكيان.** لم يُتحقَّق بعد أيهما فعّال حاليًا وأيهما قديم — **يحتاج فحص إضافي، غير مؤكَّد بعد.** |
| **ازدواج ملكية** | لا يوجد على `balance` نفسها |
| **مراجع غير مستقرة** | لا يوجد على مستوى الكيان نفسه — لكن **`walletSources[].walletId`** (نوع `JarWalletSource`، الحقول: `walletId, amount` فقط) هو بالضبط الحقل اللي فيه المخالفة المعمارية الموثّقة في ADR-0004 (تحديثه بدون ربط بمعاملة قابلة للعكس) |
| **حقل قديم مرشَّح للحذف** | **`walletBalances{}` مرشَّح محتمل** — إذا تأكَّد إنه بديل قديم لـ `walletSources[]`. **لم يُتحقَّق، غير مؤكَّد.** |

---

## Allocation (`AllocationEntity`)

**الملف:** `budget_setup_entity.dart`

**الحقول:** `id, name, balance, icon, iconColor, rolloverBehavior, funding[], categories[], walletBalances{}, automationType, pendingDistribution, pendingDistributionWalletId, pendingDistributionSourceId, pendingDistributionSnoozedUntil`

| البند | التفاصيل |
|---|---|
| **المسؤوليات** | تخصيص افتراضي (label) من الميزانية — دائمًا 100% virtual حسب المفهوم اللي شرحه محمد، بلا خصم فعلي من محفظة |
| **مالك الحسابات** | لا يوجد مالك مركزي واحد مؤكَّد — `BudgetMetricsService`/`BudgetIncomeMetricsService` يغطيان جزءًا، والباقي inline في `budget_tracking_screen.dart` |
| **ملفات أخرى تحسب قيمها مباشرة** | نفس عائلة التكرار الموثّقة في `financial-calculation-map.md` (#7/#9: `planned/funded/spent/remaining/ratio`، مكررة حرفيًا مرتين) |
| **⚠️ تسريب مسؤولية حقيقي (اكتشاف جديد)** | **حقول `pendingDistribution*` الأربعة مخزَّنة كـ state مباشرة على الكيان نفسه**، وتُستخدَم (قراءة/كتابة) من **6 ملفات مختلفة**: `transaction_processor.dart`, `notifications_center_screen.dart`, `budget_setup_screen.dart`, `budget_tracking_screen.dart`, `app_cubit.dart`, بالإضافة لتعريفها. عملية "توزيع مُعلَّقة" (كأنها عملية عابرة/مؤقتة) مخزَّنة بشكل دائم على الكيان، ومُدارة من نص طبقات مختلفة (processor + cubit + شاشتين) بدل خدمة واحدة — **هذا نمط تسريب مسؤولية كلاسيكي**: حالة عملية معلَّقة (transient/pending) يجب أن تُدار من خدمة orchestration واحدة، لا أن تكون حقلاً دائمًا على الكيان يُعدَّل من كل مكان. |
| **ازدواج ملكية** | نفس `walletBalances{}` الموجود أيضًا على Jar — **نفس التساؤل غير المحسوم**: علاقته بـ `funding[]` (`AllocationFundingEntity`) غير واضحة بدون فحص إضافي. |
| **مراجع غير مستقرة** | `pendingDistributionWalletId`, `pendingDistributionSourceId` — على الأقل هذان معرّفان صريحان (لا نص)، نقطة إيجابية نسبيًا مقارنة بمشاكل `notes.contains` الموثّقة في كيانات أخرى. |
| **حقل قديم مرشَّح للحذف** | لا يوجد دليل كافٍ بعد — الحقول الأربعة نشطة الاستخدام، المشكلة في توزيع إدارتها لا في وجودها. |

---

## Transaction (`TransactionEntity`)

**الملف:** `lib/features/transactions/domain/entities/transaction_entity.dart`

**الحقول:** `id, walletId, fromWalletId, toWalletId, allocationId, toAllocationId, budgetScope, incomeSourceId, categoryId, transferType, amount, type, createdAt, notes, parentId`

| البند | التفاصيل |
|---|---|
| **المسؤوليات** | السجل المالي الوحيد الحقيقي (audit record) لأي حركة فلوس فعلية |
| **مالك الحسابات** | `TransactionProcessor` (تطبيق/عكس المعاملة على الأرصدة) |
| **ملفات أخرى تحسب قيمها مباشرة** | لا يوجد على مستوى تعديل المعاملة نفسها — لكن **62 موضع `.fold()`** عبر المشروع (موثّقة بالكامل في `financial-calculation-map.md`) تُجمِّع/تُصنِّف معاملات لأغراض حسابية متعددة |
| **تسريب مسؤولية** | لا يوجد على الكيان نفسه (نظيف نسبيًا كـ سجل بيانات) |
| **ازدواج ملكية** | لا يوجد |
| **⚠️ مراجع غير مستقرة (موثّقة بالكامل سابقًا)** | **32 موضع Entity relationship** يعتمد على `notes.contains`/`.startsWith` بدل معرّف — راجع `text-parsing-business-logic-inventory.md` و`ADR-0001` للتفصيل الكامل (Debt، Lending، هدف المعاملة). لا تكرار هنا، فقط إحالة. |
| **حقل قديم مرشَّح للحذف** | **لا يوجد دليل حالي** — كل الحقول الـ15 مستخدمة فعليًا حسب الفحص السابق (لا حقل وُجد بصفر استخدام، بعكس `reservedForSavings` على Wallet). |

---

## Debt (`DebtEntity`) — يشمل Subscription

**الملف:** `budget_setup_entity.dart`

**الحقول:** `id, name, amount, executionDay, type, fundingSource, recurringTransactionId, kind, principalTotal, installmentCount, downPayment, recurrencePattern`

| البند | التفاصيل |
|---|---|
| **المسؤوليات** | دَين أو قسط أو اشتراك (يُميَّز بـ `kind`) — جدولة سداد دورية |
| **مالك الحسابات** | `BudgetRecurringPlanService` (`amountDueInCycle`, `transactionCountsTowardDebt`, `allDebtPayments`) — **مركزي جزئيًا** |
| **ملفات أخرى تحسب قيمها مباشرة** | راجع `text-parsing-business-logic-inventory.md` جدول 1 — **19 موضع**، منها تكرار **بين خدمتين domain** (`BudgetRecurringPlanService` و`budget_income_metrics_service.dart` سطر 85) لا شاشات فقط |
| **تسريب مسؤولية** | منطق "هل هذه المعاملة تخص هذا الدَّين" مُطبَّق جزئيًا داخل `BudgetRecurringPlanService` (صحيح معماريًا) لكن **مُعاد تنفيذه يدويًا** في شاشات متعددة بدل استدعاء الخدمة |
| **ازدواج ملكية** | **مؤكَّد**: `transactionCountsTowardDebt` (الخدمة) مقابل نسخ يدوية في `notifications_center_screen.dart`, `notifications_screen.dart`, `main_shell_screen.dart` |
| **⚠️ مراجع غير مستقرة** | **الأخطر في كل الكيانات المالية**: الربط الوحيد بين `DebtEntity` والمعاملة هو `notes.contains(debt.name)` — **لا يوجد `debtId` على `TransactionEntity` إطلاقًا**. القرار موثَّق ومؤجَّل عمدًا (`referenceType`/`referenceId`, ADR-0001). حقل `recurringTransactionId` موجود فعلاً على `DebtEntity` كمرجع مستقر لكنه يربط بـ`RecurringTransactionEntity`، لا بمعاملات السداد الفعلية. |
| **حقل قديم مرشَّح للحذف** | لم يُفحص كل حقل فرديًا (`downPayment`, `principalTotal` وغيرها) — **غير مؤكَّد، يحتاج فحص إضافي منفصل.** |

---

## Goal (`GoalEntity`)

**الملف:** `lib/features/goals/domain/entities/goal_entity.dart`

**الحقول:** `id, name, targetAmount, startDate, endDate, icon, iconColor, notes`

| البند | التفاصيل |
|---|---|
| **المسؤوليات** | هدف ادخار بمبلغ مستهدف ومدة زمنية |
| **مالك الحسابات** | **غير محدَّد — لم يُعثر على خدمة domain مخصَّصة لـ Goal إطلاقًا** (لا يوجد `goal` في قائمة خدمات `domain/services` الكاملة المفحوصة) |
| **ملفات أخرى تحسب قيمها مباشرة** | `goals_screen.dart` (1 موضع `.fold()` موثّق سابقًا في `financial-calculation-map.md`، لم يُفحص بالتفصيل) |
| **تسريب مسؤولية** | **الكيان الوحيد من بين التسعة بلا أي طبقة domain خدمية — كل الحساب (التقدُّم نحو الهدف على الأرجح) في الـ presentation مباشرة على الأرجح.** غير مؤكَّد بالكامل، لم يُفتح `goals_screen.dart` بالتفصيل في هذا التدقيق. |
| **ازدواج ملكية** | لا ينطبق (لا يوجد ملكية مركزية من الأساس) |
| **مراجع غير مستقرة** | لا يوجد دليل على ربط بمعاملات — **غير مؤكَّد كيف يُموَّل الهدف فعليًا** (عبر جدال أم عبر حصالة؟) بدون فحص إضافي. |
| **حقل قديم مرشَّح للحذف** | لم يُفحص |

---

## Money Distribution (`DistributionEntry`)

**الملف:** `lib/features/money_distribution/domain/entities/distribution_entry.dart`

**الحقول:** `id, jarId, walletId, amount, origin, createdAt, updatedAt, linkedTransactionId`

| البند | التفاصيل |
|---|---|
| **المسؤوليات** | تسجيل "مكان الفلوس" — أي جزء من رصيد حصالة موجود فعليًا في أي محفظة |
| **مالك الحسابات** | `DistributionEngine` — **الأنظف من بين كل الكيانات التسعة معماريًا** |
| **ملفات أخرى تحسب قيمها مباشرة** | لا يوجد (بعد توحيد `wallets_screen.dart`، commit `94853f4`) |
| **تسريب مسؤولية** | لا يوجد مكتشف |
| **ازدواج ملكية** | لا يوجد |
| **✅ مراجع مستقرة (مثال إيجابي)** | **يملك `linkedTransactionId` بالفعل** — هذا الكيان الوحيد من بين التسعة يستخدم معرّفًا صريحًا للربط بمعاملة بدل نص. **هذا هو النمط الصحيح المطلوب تعميمه** عبر ADR-0001 على باقي الكيانات. |
| **حقل قديم مرشَّح للحذف** | لا يوجد دليل |

---

## Budget (`BudgetSetupEntity`)

**الملف:** `budget_setup_entity.dart` (الحاوية الجذرية)

**الحقول الرئيسية:** `incomeSources[], allocations[], linkedWallets[], debts[]` (+ حقول أخرى لم تُسرَد بالكامل)

| البند | التفاصيل |
|---|---|
| **المسؤوليات** | حاوية جذرية لكل إعدادات الميزانية — ليست كيانًا حسابيًا بذاته، بل تجميع لكيانات فرعية |
| **مالك الحسابات** | لا ينطبق مباشرة — الحسابات تخص الكيانات الفرعية (`AllocationEntity`, `LinkedWalletEntity`, `DebtEntity`) |
| **تسريب مسؤولية** | **هيكلي بحت، لا حسابي**: كون كل الكيانات الفرعية (Jar/Allocation/Debt/IncomeSource) معرَّفة داخل نفس الملف الجذري هو تسريب مسؤولية على مستوى بنية الملفات نفسها — أي تعديل على تعريف أي كيان منها يفتح نفس الملف الضخم |
| **ملاحظة عابرة للكيانات** | `budget_tracking_screen.dart` و`budget_setup_screen.dart` (أكبر ملفين بالمشروع، موثَّقان في `REFACTOR_STATUS.md`) يقرآن من كل الكيانات الفرعية الأربعة معًا — هما نقطة التقاء كل تسريبات المسؤولية المذكورة أعلاه في مكان واحد |

---

## ملخص الأنماط المتكررة عبر كل الكيانات

| النمط | الكيانات المتأثرة |
|---|---|
| **حقل ميت (صفر استخدام خارج تعريف الكيان)** | Wallet (`reservedForSavings`) — مؤكَّد بالدليل الكامل |
| **State عملية معلَّقة/مؤقتة مخزَّن دائمًا على الكيان، مُدار من طبقات متعددة** | Allocation (`pendingDistribution*`) — اكتشاف جديد، يحتاج قرار تصميم منفصل |
| **حقلان مختلفان يبدوان مكررين مفاهيميًا على نفس الكيان** | Jar و Allocation (`walletBalances{}` مقابل `walletSources[]`/`funding[]`) — **غير محسوم، يحتاج فحص إضافي منفصل قبل أي قرار** |
| **مرجع نصي بدل ID** | Transaction ↔ Debt (الأخطر، موثَّق بالكامل)، Transaction ↔ Lending (بلا خدمة مركزية حتى) |
| **مرجع ID موجود فعلاً (نمط جيد)** | DistributionEntry (`linkedTransactionId`)، DebtEntity (`recurringTransactionId`) — نقطتا انطلاق جيدتان لتعميم النمط عبر ADR-0001 |
| **كيان بلا أي طبقة domain خدمية** | Goal — الوحيد من بين التسعة |
| **ملف تعريف كيانات مُتضخِّم (مسؤولية تعريف بيانات، لا حسابات)** | Jar/Allocation/Debt/IncomeSource كلها داخل `budget_setup_entity.dart` واحد |

**ما لم يُنفَّذ في هذا التدقيق:** أي تعديل أو نقل كود. عدة نقاط أعلاه
مُعلَّمة صراحة "غير مؤكَّد" أو "يحتاج فحص إضافي" — لم تُفترَض إجاباتها.
