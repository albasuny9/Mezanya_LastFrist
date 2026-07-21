# AppState Size Diagnosis Report
**تاريخ:** 2026-07-21  
**نوع:** تحليل ثابت للكود + تحليل بنية البيانات  
**الهدف:** تحديد سبب الـ payload الضخم والـ OOM error

---

## ملاحظة منهجية

الأرقام في هذا التقرير **تقديرات** مبنية على قراءة بنية الكود. الأرقام الدقيقة ستظهر في الـ console بعد تشغيل التطبيق — انظر القسم السابع (كيف تقرأ output الـ console).

---

## القسم الأول: بنية AppState

AppState يحتوي على 12 collection/section رئيسية:

| Field | النوع | ملاحظة |
|-------|-------|--------|
| `transactions` | `List<TransactionEntity>` | كل معاملات التاريخ |
| `logs` | `List<LogEntryEntity>` | حد أقصى 600 سجل |
| `notifications` | `List<NotificationEntity>` | حد أقصى 800 |
| `wallets` | `List<WalletEntity>` | صغير (عدة محافظ) |
| `budgetSetup` | `BudgetSetupEntity` | يشمل linkedWallets/allocations/debts |
| `categories` | `List<CategoryEntity>` | صغير |
| `goals` | `List<GoalEntity>` | صغير |
| `recurringTransactions` | `List<RecurringTransactionEntity>` | محدود |
| `moneyDistributions` | `List<DistributionEntry>` | ⚠️ يتضخم مع كل دخل |
| `monthlyBudgetSnapshots` | `Map<String, Map>` | snapshot كامل لكل شهر |
| `profileImageUrl` | `String` | عادة URL فارغ أو قصير |
| metadata fields | `String/bool` | ثابتة صغيرة |

---

## القسم الثاني: أعداد Collections (تقديرية)

بناءً على الاستخدام الحقيقي الذي أفرز المشكلة:

| Collection | العدد المتوقع |
|-----------|--------------|
| transactions | 500–2000+ |
| logs | ~600 (الحد الأقصى) |
| moneyDistributions | 500–3000+ (يتضخم مع كل income) |
| notifications | ~800 (الحد الأقصى) |

---

## القسم الثالث: الحجم المسلسل لكل section (تقديري)

| Section | تقدير الحجم |
|---------|------------|
| **logs** | **70–360 MB** ← المشكلة الرئيسية |
| transactions | 0.5–2 MB |
| moneyDistributions | 0.2–1 MB |
| budgetSetup | 10–100 KB |
| notifications | 50–500 KB |
| monthlyBudgetSnapshots | 50–500 KB |
| الباقي مجتمعاً | < 50 KB |

---

## القسم الرابع: التحقيق العميق في الـ Logs

### البنية الجوهرية للمشكلة

```dart
class LogEntryEntity {
  final String beforeState;  // ← JSON string كامل للـ AppState
  final String afterState;   // ← JSON string كامل للـ AppState
}
```

كل `LogEntryEntity` يحتوي على **نسختين كاملتين من الـ AppState** كـ JSON strings.

### كيف يُنتَج beforeState/afterState

في `app_cubit.dart → _applyAndLog()`:
```dart
final before = jsonEncode(_coreMap(state));       // ← AppState بدون logs
final after  = jsonEncode(_coreMap(nextRaw));     // ← AppState بدون logs
```

حيث `_coreMap()` يستدعي `state.toMap(includeLogs: false)`.

### الحجم الفعلي لكل string

`toMap(includeLogs: false)` يشمل:
- transactions كاملة (500–2000 معاملة)
- moneyDistributions كاملة
- budgetSetup
- notifications
- كل شيء **ما عدا** logs

مع 1000 معاملة ومئات الـ distributions:
- كل `beforeState` أو `afterState` ≈ **500 KB – 2 MB**

### الحجم التراكمي للـ logs section

```
600 سجل × 2 string × 500 KB = 600 MB   ← حد أدنى
600 سجل × 2 string × 2 MB  = 2,400 MB  ← حد أقصى
```

### التضاعف عند الـ JSON Encoding

عند `jsonEncode(state.toMap())` مع `includeLogs: true`، كل `beforeState` string يحتوي على `"` تصبح `\"` — مما يزيد حجم الـ string الأصلي بنسبة 10–30% إضافية.

---

## القسم الخامس: اكتشاف التسلسل المكرر

### التكرار الرئيسي ✅ مؤكد من الكود

```
AppState (الـ blob الكامل)
└── logs[]                          ← 600 entry
    └── each LogEntryEntity
        ├── beforeState: String     ← AppState_WITHOUT_LOGS (كـ JSON string)
        │   ├── transactions[]      ← نفس المعاملات
        │   ├── moneyDistributions[] ← نفس الـ distributions
        │   ├── budgetSetup         ← نفس الإعداد
        │   └── notifications[]     ← نفس الإشعارات
        └── afterState: String      ← نسخة ثانية من AppState_WITHOUT_LOGS
```

**التكرار:** كل ما في AppState (بدون logs) يُسلسَل **1201 مرة** في الـ blob الكامل:
- مرة واحدة في الـ root
- 600 مرة كـ `beforeState`
- 600 مرة كـ `afterState`

### تسلسلات أخرى موجودة لكن أصغر

| الموقع | ما يُكرَّر | الحجم التقريبي |
|--------|-----------|--------------|
| `LinkedWalletEntity.toMap()` → `categories[]` | نسخة من categories مرتبطة بكل jar | صغير (< 50KB) |
| `monthlyBudgetSnapshots` | snapshot من `BudgetSetupEntity.toMap()` لكل شهر | صغير (< 500KB) |
| لا يوجد: Transaction ↔ Wallet أو Allocation ↔ Wallet | ✅ | — |

---

## القسم السادس: ترتيب المساهمين

| Component | الحجم المسلسل | % من الـ payload |
|-----------|--------------|-----------------|
| **Logs** (beforeState + afterState لكل سجل) | **70 MB – 2,400 MB** | **~99%** |
| Transactions | 0.5 MB – 2 MB | < 1% |
| MoneyDistributions | 0.2 MB – 1 MB | < 0.5% |
| BudgetSetup | 50 KB – 200 KB | < 0.1% |
| Notifications | 50 KB – 500 KB | < 0.1% |
| MonthlyBudgetSnapshots | 50 KB – 500 KB | < 0.1% |
| الباقي | < 50 KB | نزر |

---

## القسم السابع: التشخيص النهائي

### س1: ما الذي يجعل AppState ضخماً؟

**الجواب:** `logs` array. كل log entry يُسلسَّل بـ `beforeState` و `afterState` وهما JSON strings كاملة للـ AppState (بدون logs). مع 600 سجل وكل AppState snapshot بحجم 500KB–2MB، يصل حجم الـ logs section وحده إلى **70MB–2.4GB**.

### س2: لماذا jsonEncode يأخذ ~1.5 ثانية؟

**الجواب:** `jsonEncode(state.toMap())` مع `includeLogs: true` يُسلسَّل الـ 600 `LogEntryEntity` objects. كل منها يحتوي على `beforeState` و `afterState` كـ Dart String. الـ JSON encoder يمر عليها ويـ escape كل `"` فيها إلى `\"` — وهي عملية O(N × L) حيث N = عدد اللوگات و L = طول الـ string. مع 600 × 2 × 500,000 حرف = **600 مليون عملية مقارنة حرفية** على الـ UI thread.

### س3: لماذا SharedPreferences.setString() يأخذ ~2 ثانية؟

**الجواب:** مزيج من عاملين:
1. نقل الـ string الضخم (70MB+) عبر platform channel (Dart → Android/iOS) — هذا يتطلب نسخ الـ bytes في الذاكرة
2. على بعض إصدارات Android، `SharedPreferences` يستخدم `commit()` (وليس `apply()`) مما يعني الانتظار الفعلي للكتابة على القرص لـ 70MB+

### س4: لماذا LocalBackup encoding يأخذ ~4 ثانية؟

**الجواب:** نفس سبب الـ 1.5 ثانية — `jsonEncode(appState.toMap())` مرة ثانية، لكنها أبطأ لأن هذا encode يحدث بعد أن الـ UI thread قد استُنفد من موارده من العمليتين السابقتين، والـ GC pressure يكون أعلى. أيضاً قد تكون هذه العملية تسبب أو تزيد من ضغط الـ GC بشكل ملحوظ.

### س5: ما السبب الجذري؟

✅ **oversized logs** — هذا هو السبب الجذري بنسبة 99%+.

السبب التحديدي هو اختيار تصميم تخزين `beforeState`/`afterState` كـ **JSON strings من AppState الكامل** داخل كل log entry. هذا يعني أن:

1. كل عملية حفظ (save) تُضيف log entry يحتوي على نسختين من AppState
2. عدد الـ logs يصل إلى 600 (الحد الأقصى)
3. حجم كل AppState snapshot يكبر مع كل معاملة جديدة (لأن `transactions[]` و `moneyDistributions[]` يكبران)
4. النتيجة: حجم الـ blob يتضاعف مع كل معاملة جديدة بدلاً من النمو الخطي

هذا يُفسّر أيضاً لماذا المشكلة تظهر بعد فترة من الاستخدام وليس من أول يوم.

---

## كيف تقرأ output الـ console

بعد تشغيل التطبيق وحفظ أي معاملة، ستظهر هذه البلوك في الـ debug console:

```
╔═══════════════════════════════════════════════════════╗
║          APPSTATE SIZE DIAGNOSIS                      ║
╠═══════════════════════════════════════════════════════╣
  Payload
    Characters : 87432156
    Bytes      : 87432156
    KB         : 85383.0
    MB         : 83.37

  Collection counts
    transactions             : 847
    logs                     : 600
    notifications            : 413
    wallets                  : 3
    categories               : 12
    goals                    : 2
    recurringTransactions    : 5
    moneyDistributions       : 1243
    monthlyBudgetSnapshots   : 8
    budgetSetup.incomeSources: 3
    budgetSetup.allocations  : 7
    budgetSetup.linkedWallets: 4
    budgetSetup.debts        : 2

  Section serialized sizes
    transactions           :    1.82 MB  (2.2%)
    logs                   :   79.44 MB  (95.3%)  ← هنا المشكلة
    notifications          :   89.2 KB   (0.1%)
    wallets                :    1.2 KB   (0.0%)
    budgetSetup            :   34.5 KB   (0.0%)
    ...

  Logs deep investigation
    count                       : 600
    largest beforeState (chars) : 143821  (140.5 KB)
    largest afterState  (chars) : 144103  (140.8 KB)
    average beforeState (chars) : 98432   (96.1 KB)
    average afterState  (chars) : 98651   (96.3 KB)
    total beforeState bytes     : 57.61 MB
    total afterState  bytes     : 57.74 MB
    total state-string overhead : 115.35 MB
╚═══════════════════════════════════════════════════════╝
```

### جدول قراءة القيم

| القيمة التي تراها | ماذا تعني |
|------------------|-----------|
| `logs` section % > 90% | التشخيص مؤكد: logs هي المشكلة |
| `logs` section % < 50% | يوجد مشكلة أخرى — انظر transactions/moneyDistributions |
| `average beforeState > 50KB` | كل log يحمل AppState ضخم = root cause مؤكد |
| `moneyDistributions > 2000` | مشكلة ثانوية: DistributionEntry تتراكم بلا تنظيف |
| `total state-string overhead > 50 MB` | الحجم الحقيقي لـ double-embedding في كل سجل |

---

## ملاحظة للـ Sprint التالي

هذا التشخيص **لا يتضمن أي إصلاح**. الحل سيكون موضوع Sprint منفصل.

الخيارات الموثقة للـ Sprint التالي (مرتبة من الأسهل للأكثر صحةً):

| الخيار | الأثر | الجهد |
|--------|-------|-------|
| تقليل حد الـ logs من 600 → 20 | يقلل الحجم بنسبة 96.7% مع الاحتفاظ بالبنية الحالية | ⭐ فوري |
| حذف `beforeState`/`afterState` من LogEntryEntity | يقلل 99% من حجم الـ logs | ⭐⭐ سهل |
| تخزين diff بدلاً من snapshot كامل | الحل الأمثل لوظيفة الـ undo | ⭐⭐⭐ متوسط |
| فصل logs في storage منفصل (ملف/SQLite) | يُبقي الـ log history كاملاً ويزيل ضغط الـ SharedPreferences | ⭐⭐⭐ متوسط |
