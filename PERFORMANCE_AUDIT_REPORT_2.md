# تقرير أداء — Sprint #2: الأدوات والنتائج المتوقعة

**نوع التقرير:** تحليل الأدوات الجديدة + مراجعة ومراجعة نتائج التقرير الأول  
**تاريخ التقرير:** 2026-07-21  
**يُكمّل:** `PERFORMANCE_AUDIT_REPORT.md` (2026-07-20)

---

## ⚠️ ملاحظة منهجية

هذا التقرير **ليس** قياسات فعلية. Sprint #2 أضاف 12 نقطة قياس ستُطبع تلقائياً بعد كل حفظ في debug mode. هذا التقرير يوثّق:

1. ما تقيسه كل نقطة بالضبط وما تُخفيه  
2. مراجعات وتصحيحات للتقرير الأول بناءً على قراءة الكود الأعمق أثناء التجهيز  
3. مشاكل جديدة لم ترد في التقرير الأول  
4. كيفية قراءة تقرير الـ console  

---

## القسم الأول: الـ 12 نقطة — ما تقيس وما لا تقيس

---

### نقطة 01 — Form open (initState)
**الملف:** `transaction_entry_form.dart` → `initState()`

**ما تقيسه:** الوقت الكلي لـ `initState()` من أول سطر إلى آخر سطر، يشمل:
- `TransactionFormController.create()` ← نقطة 02
- `_ensureRecurringIncomeSourceSelected()`
- تسجيل الـ 4 listeners على الـ TextEditingControllers

**ما لا تقيسه:** وقت بناء الـ Widget tree الأول (`build()` الأول بعد initState) — هذا يحدث بعد أن تُرجع `initState()`.

**ملاحظة تفسيرية:** هذه القيمة تُقرأ مرة واحدة فقط من `_formOpenMs` عند الضغط على حفظ. إذا فتح المستخدم الـ form وانتظر 5 دقائق ثم ضغط حفظ، ستظهر فقط وقت الـ `initState`، لا وقت الانتظار.

---

### نقطة 02 — Form init (ctrl.create)
**الملف:** `transaction_entry_form.dart` → `TransactionFormController.create()`

**ما تقيسه:** وقت إنشاء الـ controller، يشمل تهيئة الـ TextEditingControllers وقراءة `widget.cubit.state.wallets` وإعداد القيم الافتراضية.

**ما لا تقيسه:** وقت `_ensureRecurringIncomeSourceSelected()` — هذا يقع بين نقطة 02 ونهاية نقطة 01.

**الفارق بين 01 و 02:** وقت `_ensureRecurringIncomeSourceSelected()` + تسجيل الـ listeners = (قيمة 01) - (قيمة 02).

---

### نقطة 03 — Validation (sync checks)
**الملف:** `transaction_entry_form.dart` → `_submitNormal()`

**ما تقيسه:** كل الفحوصات المتزامنة من بداية `_submitNormal()` وحتى لحظة ظهور الـ `_confirmExpenseImpact` dialog (أو الوصول لنهاية الفحوصات إذا لم يكن هناك dialog).

**ما لا تقيسه:** وقت تفكير المستخدم في dialog `_confirmExpenseImpact` — هذا مقصود تماماً. الـ timer يتوقف قبل الـ `await` على الـ dialog.

**إذا كانت القيمة صفراً أو 1ms:** طبيعي جداً — الفحوصات المتزامنة البحتة سريعة جداً ما لم يكن هناك حلقات ضخمة.

---

### نقطة 04 — TransactionProcessor.apply()
**الملف:** `app_cubit.dart` → `_applyAndLog()` → `await apply()`

**ما تقيسه:** وقت `TransactionProcessor.apply(state, transaction)` كاملاً، يشمل:
- كل منطق تطبيق المعاملة على الـ state
- توليد sub-transactions للدخل (incomeSourceId)
- حسابات MoneyLocationEngine / DistributionEngine

**ما لا تقيسه:** وقت `jsonEncode` قبله وبعده — هذه منفصلة في 06a و 06b.

**نمط التعديل:** عند تعديل معاملة، يُستدعى `_applyAndLog` مرتين (delete + add). ستظهر نقطة 04 مرتين في نفس التقرير بترتيب: delete أولاً ثم add.

---

### نقطة 05 — _applyAndLog() total
**الملف:** `app_cubit.dart` → `_applyAndLog()`

**ما تقيسه:** الوقت الكلي لـ `_applyAndLog()` من أول سطر إلى آخر سطر (بعد `_autoSync`).

**يشمل:** 06a + 04 + 06b + بناء LogEntryEntity + بناء NotificationEntity + 07 + 09 + 10

**لا يشمل:** وقت 01، 02، 03 (تسبق الاستدعاء)

**ملاحظة:** عند تعديل معاملة، تظهر نقطة 05 مرتين — مرة للـ delete ومرة للـ add. المجموع الكلي للـ UI blocking = 03 + 05(delete) + 05(add).

---

### نقطة 06a — jsonEncode: before state
**الملف:** `app_cubit.dart` → `_applyAndLog()` → `jsonEncode(_coreMap(state))`

**مفاجأة مهمة:** `_coreMap()` يستدعي `toMap(includeLogs: false)` — **لا يتضمن الـ logs**. هذا يعني أن هذا الـ encode يعمل على **AppState بدون جدول الـ 600 سجل**. تكلفته أقل بكثير مما قدّره التقرير الأول.

**تصحيح للتقرير الأول:** CRITICAL-01 أشار إلى أن الـ encodes الثلاثة متكافئة. هذا غير دقيق. 06a و 06b أرخص من 06c. الـ logs array هي أكثر العناصر حجماً في الـ AppState.

---

### نقطة 06b — jsonEncode: after state
**الملف:** `app_cubit.dart` → `_applyAndLog()` → `jsonEncode(_coreMap(nextRaw))`

نفس ملاحظات 06a — `includeLogs: false`. القيمة يجب أن تكون قريبة جداً من 06a.

**الفارق بين 06a و 06b:** أي فارق يعكس الحجم المُضاف من المعاملة الجديدة نفسها (أو المحذوفة). في الغالب < 2ms.

---

### نقطة 06c — jsonEncode: saveState.toMap()
**الملف:** `shared_prefs_app_repository.dart` → `saveState()`

**هذه هي الأغلى:** `toMap()` هنا بدون `includeLogs: false` — تشمل **كل الـ logs الـ 600 سجل**. كل سجل يحتوي على `beforeState` و `afterState` كـ JSON strings مُضمَّنة داخل JSON أكبر.

**تقدير الحجم:** مع 600 سجل × متوسط 300KB لكل سجل: blob إجمالية 2-5MB. هذه هي النقطة التي ستُظهر الأرقام الأعلى في التقرير.

**تصحيح مهم للتقرير الأول:** CRITICAL-01 قال "3 serializations متكافئة". الحقيقة:
- 06a, 06b: serialize AppState **بدون logs** ← رخيصتان نسبياً
- 06c: serialize AppState **مع logs** ← الأغلى بفارق كبير

---

### نقطة 07 — Repository.saveState()
**الملف:** `app_cubit.dart` → `_applyAndLog()` → `await _repository.saveState(next)`

**يشمل:** 06c + 08 معاً (هما يقعان داخل `saveState()`).

**يجب أن تكون 07 ≈ 06c + 08 دائماً.** أي فارق = overhead إضافي في `SharedPrefsAppRepository`.

---

### نقطة 08 — SharedPreferences.setString()
**الملف:** `shared_prefs_app_repository.dart` → `_prefs.setString(...)`

**ما تقيسه:** وقت الكتابة الفعلية على القرص عبر SharedPreferences — I/O خالص.

**ملاحظة هامة:** `await` هنا لا يعني بالضرورة أن الكتابة اكتملت على القرص. SharedPreferences على Android تستخدم `commit()` في بعض الإصدارات و`apply()` في إصدارات أخرى. `apply()` تكتب بشكل asynchronous في الخلفية وترجع فوراً — مما قد يجعل قيمة 08 تبدو منخفضة جداً (0-5ms) حتى للـ blobs الضخمة.

---

### نقطة 09 — emit(next)
**الملف:** `app_cubit.dart` → `_applyAndLog()` → `emit(next)`

**ما تقيسه:** وقت إرسال الـ state الجديد لكل المستمعين المتزامنين. يشمل أي `BlocListener` أو `BlocConsumer` يتفاعل بشكل متزامن.

**المتوقع:** 0-2ms في الغالب. إذا ظهرت قيمة عالية، هناك listener ينفذ عملاً ثقيلاً بشكل متزامن.

**ما لا تقيسه:** وقت إعادة البناء الفعلي لأي Widget — هذا يحدث في الـ frame التالي، بعد أن ترجع `emit()`.

---

### نقطة 10 — _autoSync (fire-and-forget scheduled)
**الملف:** `app_cubit.dart` → `_applyAndLog()` → `_autoSync(next)`

**ما تقيسه:** وقت جدولة المهام الخلفية فقط — ليس وقت تنفيذها. `_autoSync` ترتب `.then()` callbacks وترجع فوراً.

**المتوقع:** 0ms دائماً تقريباً. هذه القيمة ستكون 0 في كل الحالات العادية.

**الوقت الفعلي للـ backup** يظهر لاحقاً في نقطتي 11 و 12 (background lines).

---

### نقطة 11 — BackupUploadPipeline.run()
**الملف:** `app_cubit.dart` → `_autoSync()` → خط `[BG]` في الـ console

**ما تقيسه:** الوقت من لحظة استدعاء `run()` حتى انتهاء الـ Future، يشمل:
- استدعاء `exportJson()` داخلياً (`jsonEncode` رابع)
- مقارنة CRC/hash مع النسخة الأخيرة
- رفع الملف لـ Firebase Storage إذا كانت مختلفة
- أي retry منطق

**المتوقع:** 500ms–5000ms حسب حجم البيانات وسرعة الشبكة.

**ملاحظة:** تظهر في الـ console **بعد** السطر الأخير من التقرير المتزامن، وبعد ثوانٍ. إذا لم تظهر هذه السطور = الـ backup مُعطَّل من الإعدادات أو المستخدم غير مسجَّل دخول.

---

### نقطة 12 — LocalBackupService (encode + write)
**الملف:** `app_cubit.dart` → `_autoSync()` → خط `[BG]` في الـ console

**ما تقيسه:** `jsonEncode(appState.toMap())` + `writeAuto()` معاً. الـ encode هنا تشمل الـ logs (مثل 06c).

**serialization خامسة:** هذه هي الـ jsonEncode الخامسة لكل save (06a، 06b، 06c، داخل BackupUploadPipeline، وهنا). ذُكر في التقرير الأول (HIGH-09) لكن لم يُحدَّد عددها بدقة.

**المتوقع:** 50–200ms (encode 50–100ms + كتابة ملف محلي 10–50ms).

---

## القسم الثاني: مراجعات وتصحيحات للتقرير الأول

---

### 🔴 REVISION-A — CRITICAL-01: التقدير الكلي للـ serialization كان مبالغاً فيه

**ما قاله التقرير الأول:**
> ثلاث عمليات JSON serialize كاملة للـ AppState الكامل في كل مرة

**الحقيقة بعد Sprint #2:**

| النقطة | تشمل الـ logs؟ | الحجم التقديري (500 معاملة، 600 سجل) |
|--------|---------------|--------------------------------------|
| 06a (before state) | ❌ لا | 100–250 KB |
| 06b (after state) | ❌ لا | 100–250 KB |
| 06c (saveState) | ✅ نعم | 500 KB – 3 MB |

النتيجة: 06a و 06b أرخص بكثير مما قُدِّر. **التكلفة الحقيقية مُركَّزة في 06c** (حيث يُضاف الـ logs array). هذا يعني أن تقليل حجم الـ logs (تقليل 600 → 100 سجل) سيحسّن 06c تحديداً دون أن يؤثر على 06a و 06b.

---

### 🔴 REVISION-B — CRITICAL-05 تصبح الأولوية الأعلى وليس CRITICAL-01

لأن 06c هي الأغلى (تتضمن كل الـ logs)، فإن `saveState()` هي المشكلة الجوهرية أكثر من `_applyAndLog()` الـ before/after encodes. الترتيب المنقّح لأبطأ النقاط في الـ pipeline المتزامن:

1. **06c** ← `jsonEncode(appState.toMap())` مع الـ logs ← أغلى نقطة
2. **08** ← كتابة القرص ← متغيرة حسب الجهاز والإصدار
3. **04** ← `TransactionProcessor.apply()` ← مرتبطة بعدد الـ jars والـ distributions
4. **06a / 06b** ← أرخص مما قُدِّر (بدون logs)

---

### 🟠 REVISION-C — HIGH-07 (تعديل معاملة): التقرير سيُظهر التكلفة مضاعفة تلقائياً

**المشكلة في التقرير الأول:** ذُكرت أن التعديل = delete + add = 6 serializations.

**ما سيُظهره التقرير الآن:**
- نقطة 04 تظهر مرتين (مرة للـ delete + مرة للـ add)
- نقطة 05 تظهر مرتين
- نقطة 06a/06b/06c/07/08/09/10 كلها تظهر مرتين

**كيف تقرأ الرقم الإجمالي للتعديل:** TOTAL في التقرير = 03 + delete pipeline + add pipeline كاملة = الوقت الحقيقي الذي ينتظره المستخدم.

هذا يجعل HIGH-07 مباشرة قابلاً للقياس بدون أي حسابات يدوية.

---

### 🟠 REVISION-D — HIGH-09: عدد الـ serializations فعلياً خمسة لا أربعة

**التقرير الأول:** قال "serialization رابعة في `_autoSync`".

**الحقيقة:**
- `exportJson: () => jsonEncode(appState.toMap())` داخل `BackupUploadPipeline.run()` ← الرابعة (إذا السحابة مُفعَّلة)
- `jsonEncode(appState.toMap())` في اللحظة التالية مباشرة للـ LocalBackupService ← الخامسة (إذا النسخ المحلي مُفعَّل)

**مع تفعيل الاثنين معاً:** 5 serializations لكل save. مع تعطيلهما: 3 serializations فقط.

---

### 🟢 REVISION-E — نقطة 08 (setString) قد تُظهر أرقاماً مضللة

على Android، `SharedPreferences.setString()` يستخدم داخلياً `apply()` (وليس `commit()`) في أغلب الإصدارات. `apply()` ترجع فوراً وتكتب على القرص في thread منفصل. هذا يعني:

- **قيمة 08 قد تكون 0-5ms حتى مع blob 3MB**
- هذا لا يعني أن الكتابة رخيصة — بل يعني أن الـ await لا يمثّل الوقت الفعلي

**الدلالة:** إذا رأيت 08 = 2ms، لا تفترض أن الكتابة انتهت. الـ I/O الفعلي قد يستغرق 50-200ms في خلفية الـ Android.

---

## القسم الثالث: مشاكل جديدة اكتُشفت خلال Sprint #2

---

### 🟠 NEW-01
**الملف:** `shared_prefs_app_repository.dart` → `loadState()`  
**السطور:** 16–30

**وصف المشكلة:**
عند فشل `jsonDecode` على الـ payload المحفوظ (السطر 26)، يستدعي `loadState()` مباشرة:
```dart
final fallback = AppStateEntity.initial();
await saveState(fallback);
return fallback;
```
هذه `saveState()` ستُسجّل نقطتي 06c و 08 في الـ `TxnTimingCollector` **الحالي قبل أي `startSave()`**، أي في collector "بارد" لم يُهيَّأ بـ `startSave()`. النتائج تتراكم في instance لن يُطبع أبداً.

**هذا ليس خطأ في الـ instrumentation** — هو خطأ في بنية الكود الأصلية: `loadState()` يكتب على الـ storage عند الفشل بدلاً من إرجاع قيمة افتراضية فقط ثم الكتابة من الـ cubit.

**الأولوية:** 🟠 High (correctness issue, ليس فقط performance)

---

### 🟡 NEW-02
**الملف:** `app_cubit.dart` → `initialize()`  
**السطر:** 93

**وصف المشكلة:**
`initialize()` تستدعي `_repository.saveState(appState)` عند كل بداية تشغيل (حتى لو لم تتغير البيانات). مع كل بيانات migrations لا تحدث تغييراً، يحدث save كامل غير ضروري عند كل cold start:

```dart
appState = MigrationService.ensureDefaultSavingsJarSync(appState);
// ... 3 migrations أخرى ...
await _repository.saveState(appState); // يحدث دائماً
```

لا يوجد فحص "هل تغيرت البيانات؟" قبل الكتابة.

**الكلفة:** 50-150ms إضافية عند كل فتح للتطبيق (06c + 08).

**الأولوية:** 🟡 Medium

---

### 🟡 NEW-03
**الملف:** `app_cubit.dart` → `_autoSync()` → LocalBackupService

**وصف المشكلة:**
الكود الأصلي كان:
```dart
LocalBackupService.writeAuto(jsonEncode(appState.toMap()));
```
بدون `await` وبدون `.then()`. في Sprint #2 حوّلنا الاستدعاء لـ `.then()` لقياس الوقت:
```dart
LocalBackupService.writeAuto(_localJson).then((_) { ... });
```
**هذا يكشف أن `writeAuto` ترجع `Future`** لكن الكود الأصلي كان يتجاهل هذا الـ Future تماماً. أي خطأ في الكتابة كان يُبتلع بصمت بواسطة `catchError((_) {})` الخارجي (الذي يلتقط فقط أخطاء `autoEnabled()`، لا أخطاء `writeAuto()`).

**النتيجة:** إذا فشل حفظ النسخة المحلية، لا يعلم أحد.

**الأولوية:** 🟡 Medium

---

### 🟢 NEW-04
**الملف:** `app_cubit.dart` → `_autoSync()` → BackupUploadPipeline

**وصف المشكلة:**
`_swBup` يبدأ قبل `BackupUploadPipeline.run()` لكن يتوقف في `.then()`. إذا استُدعيت `catchError()` (خطأ في الرفع)، يتوقف `_swBup` هناك أيضاً. لكن إذا كان الـ Future ينتهي بـ exception غير مُعالج (ليس نوع `Error`)، يبقى `_swBup` يدور إلى الأبد (لا leak حقيقي، Dart يُدمّر الـ Stopwatch مع انتهاء scope).

**تأثير الـ instrumentation:** لن تُرى `[BG] 11` في حالة exception غير `Error`. هذا مقبول للـ Sprint #2 ولا يستحق تعديلاً الآن.

**الأولوية:** 🟢 Low (instrumentation-only concern)

---

## القسم الرابع: كيف تقرأ تقرير الـ Console

```
╔══════════════════════════════════════════════════════════════════╗
║        TRANSACTION PIPELINE — TIMING REPORT (sync)              ║
╠══════════════════════════════════════════════════════════════════╣
║  01 | Form open (initState)                  8 ms
║  02 | Form init (ctrl.create)                3 ms
║  03 | Validation (sync checks)               0 ms
║  06a | jsonEncode — before state            12 ms  ██
║  04  | TransactionProcessor.apply()          8 ms  █
║  06b | jsonEncode — after state             11 ms  ██
║  06c | jsonEncode — saveState.toMap()       63 ms  ████████████
║  08  | SharedPreferences.setString()         4 ms
║  07  | Repository.saveState()               68 ms  █████████████
║  09  | emit(next)                            0 ms
║  10  | _autoSync (fire-and-forget)           0 ms
║  05  | _applyAndLog() total                104 ms  ████████████████████
╠══════════════════════════════════════════════════════════════════╣
║  TOTAL  Save → UI responsive               116 ms
╠══════════════════════════════════════════════════════════════════╣
║  Background tasks below (reported when each finishes)           ║
╚══════════════════════════════════════════════════════════════════╝
  ║ [BG]  11  | BackupUploadPipeline.run()        2140 ms  █████████████████████
  ║ [BG]  12  | LocalBackupService (encode+write)   87 ms  █
```

### جدول تفسير القيم

| ما تراه | ماذا يعني |
|---------|-----------|
| 06c >> 06a, 06b | طبيعي — 06c تشمل الـ logs |
| 07 ≈ 06c + 08 | صحيح رياضياً — هذا التحقق يؤكد عدم وجود overhead خفي في الـ repository |
| 07 > 06c + 08 بفارق > 5ms | يشير إلى overhead إضافي داخل `saveState()` |
| 08 = 0-5ms دائماً | طبيعي على Android (apply() mode) — لا يعني الكتابة رخيصة |
| 05 < مجموع 04+06a+06b+07+09+10 | مستحيل — إذا حدث يعني Stopwatch لم يبدأ صح |
| 05 > TOTAL | طبيعي — TOTAL = wall clock كامل من startSave()، يشمل أيضاً 01+02+03 |
| نقطة 04 تظهر مرتين | أنت تعدّل معاملة موجودة (delete + add) |
| لا ترى [BG] | الـ backup مُعطَّل من الإعدادات أو المستخدم غير مسجَّل |
| [BG] 11 > 5000ms | تأخر في الشبكة أو Firebase — لا يؤثر على الـ UI |

### نسبة الـ bar charts

- **الـ sync bars:** كل `█` = 5ms
- **الـ background bars:** كل `█` = 50ms

هذا الفرق مقصود — الـ bars تجعل الحجم النسبي واضحاً داخل كل قسم.

---

## القسم الخامس: جدول المشاكل المُحدَّث

يجمع التقرير الأول مع الإضافات الجديدة، مرتبة حسب الأولوية:

| المعرف | الملف الأساسي | الوصف الموجز | الأولوية | التقدير المُعدَّل |
|--------|--------------|-------------|---------|-----------------|
| CRITICAL-04 | `budget_cycle_service.dart` | logs fallback loop + jsonDecode × 600 | 🔴 | 100ms – 9s |
| **CRITICAL-05** | `shared_prefs_app_repository.dart` | **الـ saveState blob الكامل مع logs** | 🔴 | **50–150ms** ← **أشد تأثيراً من CRITICAL-01** |
| CRITICAL-01 | `app_cubit.dart` | 3 serializations في `_applyAndLog` | 🔴 | ~~50–150ms~~ → 06a/06b رخيصتان، 06c هي الأثقل |
| CRITICAL-02 | `budget_metrics_service.dart` | debugPrint داخل loop لكل rebuild | 🔴 | 5–20ms |
| CRITICAL-03 | `budget_tracking_screen.dart` | StreamBuilder rebuild كامل لكل emit | 🔴 | 30–100ms |
| CRITICAL-06 | `budget_tracking_screen.dart` | debugPrint closure داخل build() | 🔴 | 3ms |
| HIGH-06 | `app_cubit.dart` | addTransaction مع mismatch = 6 serializations | 🟠 | 150–300ms |
| HIGH-07 | `transaction_entry_form.dart` | تعديل معاملة = delete+add = 6 serializations | 🟠 | 150–300ms |
| HIGH-09 | `app_cubit.dart` | 5 serializations كل save (ليس 4) | 🟠 | 15–100ms |
| **NEW-01** | `shared_prefs_app_repository.dart` | **loadState يكتب عند الفشل (correctness bug)** | 🟠 | N/A |
| HIGH-01 | `budget_tracking_screen.dart` | استدعاءات مكررة في `_incomeInlineCards` | 🟠 | 10–30ms/rebuild |
| HIGH-02–05, 08 | متنوعة | مشاكل rebuild متراكمة | 🟠 | متراكمة |
| MEDIUM-06 | `app_cubit.dart` | settleLentRecord = N saves متسلسلة | 🟡 | 500–1500ms |
| **NEW-02** | `app_cubit.dart` | **initialize() يحفظ دائماً حتى بدون تغيير** | 🟡 | 50–150ms/cold start |
| **NEW-03** | `app_cubit.dart` | **LocalBackupService أخطاؤه مُبتلعة بصمت** | 🟡 | — |
| MEDIUM-01–08 | متنوعة | مشاكل متوسطة | 🟡 | — |
| LOW-01–05, NEW-04 | متنوعة | مشاكل صغيرة | 🟢 | — |

---

## القسم السادس: التوصية المُعدَّلة للمرحلة الثانية

بناءً على مراجعة REVISION-A وREVISION-B، الترتيب المُعدَّل للمرحلة الثانية:

**قبل Sprint #2 كان:** تقليل LogEntryEntity من 600 → 100 سجل (يؤثر على 06a، 06b، 06c)

**بعد Sprint #2:** القيم الفعلية ستُظهر ما إذا كانت 06a/06b مؤثرة أصلاً. إذا كانت 06a/06b < 20ms، فجهد تقليلها لا يستحق. الجهد الأعلى عائداً هو:

1. **تقليل logs إلى 50 سجل** → يخفض 06c بشكل كبير (العنصر الأثقل)
2. **إعادة استخدام JSON المُنتَج في saveState داخل _autoSync** → يلغي serialization #4 و#5 في الخلفية (لا يؤثر على الـ UI thread)
3. **فصل logs عن الـ main blob** → يجعل `saveState()` رخيصة بشكل جذري

---

## ملخص Sprint #2

| العنصر | النتيجة |
|--------|---------|
| نقاط قياس مُضافة | 12 نقطة |
| ملفات مُعدَّلة | 4 ملفات (collector + 3 ملفات instrumented) |
| تغيير سلوكي | لا شيء |
| تحسين أداء في release | صفر (كل الكود محاط بـ kDebugMode) |
| مشاكل جديدة اكتُشفت | 4 (NEW-01 أهمها — correctness bug) |
| تصحيحات للتقرير الأول | 5 (REVISION-A → E) |

**لحذف الـ instrumentation كاملاً:** احذف `lib/core/perf/txn_timing.dart` ثم ابحث عن كل `// Sprint #2` في الكود (8 تعليقات) وأزل السطور المحيطة بها.
