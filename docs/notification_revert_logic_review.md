# مراجعة لوجيك التراجع من الإشعارات

## الهدف من هذه المراجعة
توثيق اللوجيك الحالي الخاص بـ:
- سجل الإشعارات (History)
- زر التراجع (Undo/Redo) من تفاصيل الإشعار
- تأثير `toggleLogRevert` على بيانات التطبيق

> هذا الملف يوثق **الوضع الحالي كما هو موجود في الكود** وقت المراجعة، مع المخاطر المعروفة.

---

## 1) كيف يدخل الإشعار إلى سجل التاريخ

عند أي عملية تستخدم `AppCubit._applyAndLog(...)` مع:
- `recordInNotificationHistory: true`

يتم إنشاء:
- `LogEntryEntity` جديد (يحفظ `beforeState` و `afterState` كـ snapshot)
- `NotificationEntity` جديد مرتبط به عبر `relatedLogId`

مهم:
- `beforeState` و `afterState` ليسا للعنصر فقط، بل snapshot لحالة الـ core كاملة (بدون logs فقط).

---

## 2) كيف يظهر الإشعار في شاشة السجل

شاشة `NotificationsCenterScreen` تبني السجل عبر:
- `isNotificationHistoryEntry(item)`
- وتستبعد الإشعار لو كان الـ log المرتبط به `isReverted == true`

بالتالي:
- التراجع لا يحذف الإشعار فعلياً، لكنه يخفيه من العرض عبر `isReverted`.

---

## 3) ماذا يحدث عند الضغط على إشعار في السجل

عند فتح عنصر من السجل:
1. يحاول النظام ربطه بمعاملة عبر `transactionForHistoryLog(...)`.
2. لو وجد معاملة: يفتح `openTransactionDetailsSheet(...)` (عرض فقط).
3. لو لم يجد معاملة: يفتح `openNotificationHistoryDetailsSheet(...)`.

داخل `openNotificationHistoryDetailsSheet`:
- لو يوجد `log` مرتبط، يظهر زر:
  - `التراجع عن الإجراء` أو `إلغاء التراجع`
- هذا الزر ينفذ مباشرة:
  - `cubit.toggleLogRevert(log.id)`

---

## 4) لوجيك `toggleLogRevert` الحالي (الجزء الأهم)

الخطوات الحالية داخل `AppCubit.toggleLogRevert(logId)`:

1. يجلب الـ log الهدف.
2. يبدّل `isReverted` (true/false) في هذا الـ log.
3. يستعيد الحالة عبر:
   - `beforeState` إذا كان log غير متراجع
   - `afterState` إذا كان log متراجع (redo)
4. ينشئ `revert log` جديد (`action: 'revert'`).
5. يضيف `revert-system notification` (مخفي من history).
6. يحفظ الحالة الجديدة.

### نقطة حرجة
الاستعادة تتم من snapshot كامل للـ core state:
- wallets
- transactions
- budgetSetup
- recurringTransactions
- goals
- notifications
- ...إلخ

وليس فقط العنصر الذي يخص هذا الـ log.

---

## 5) المخاطر الحالية (مهم)

## High
- **التراجع قد يرجّع حالة التطبيق بالكامل لوقت قديم** (حسب توقيت الـ log)، وليس فقط المعاملة/العنصر المقصود.
- نتيجة ذلك ممكن يحصل:
  - فقدان تعديلات أحدث غير مرتبطة بنفس العملية
  - رجوع أرصدة/حصالات/مخصصات لقيم أقدم
  - تغيير إشعارات أو أهداف تمت بعد ذلك

## Medium
- زر التراجع ظاهر من تفاصيل إشعار التاريخ لأي log مرتبط، بدون قيود صارمة على نوع الإجراء.
- هذا يزيد احتمال تنفيذ revert واسع النطاق من UI يبدو بسيط للمستخدم.

## Medium
- بسبب حدود القوائم (`take(600)` للـ logs و `take(800)` للإشعارات)، المسارات الطويلة قد تصعّب تتبع سلاسل undo/redo القديمة.

## Low
- `revert-system` notifications مخفية من history (مقصود)، لكن هذا يقلل الشفافية للمستخدم النهائي إذا لم توجد شاشة توضح timeline التراجع.

---

## 6) الخلاصة الوظيفية الواضحة

- نعم: التراجع الحالي **قد يغيّر أكثر من المعاملة نفسها**.
- نعم: الخوف من اللوجيك في مكانه لأن التنفيذ مبني على snapshot كامل.
- الواجهة تبدو “تراجع عنصر”، لكن التنفيذ فعلياً “استعادة حالة شاملة” للـ core.

---

## 7) التوصيات (بدون تنفيذ الآن)

1. تقييد التراجع من الإشعارات إلى حالات آمنة فقط (مثل undo delete لمعاملة محددة).
2. استبدال snapshot-restore العام بـ **domain-specific revert**:
   - transaction revert
   - allocation revert
   - jar revert
   كل نوع له rollback صغير ومحدد.
3. إضافة شاشة/سجل واضح لعمليات undo/redo للمراجعة.
4. إضافة اختبار تكاملي يثبت أن revert لا يلمس كيانات غير مستهدفة.

---

## الملفات التي تعتمد عليها هذه المراجعة

- `lib/features/app_state/presentation/cubits/app_cubit.dart`
- `lib/features/notifications/presentation/screens/notifications_center_screen.dart`
- `lib/features/notifications/presentation/widgets/notification_history_details_sheet.dart`
- `lib/features/notifications/domain/notification_history_helper.dart`
- `lib/features/logs/domain/entities/log_entry_entity.dart`

