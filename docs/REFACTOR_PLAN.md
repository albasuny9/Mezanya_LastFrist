# خطة إعادة الهيكلة — Mezanya
**آخر تحديث:** 2026-07-01 | **آخر commit:** 3d4fc6d

---

## الحالة الحالية — ما تم الأسبوع الماضي

### Critical Fixes (مرفوعة)
| Commit | الإصلاح |
|--------|---------|
| `e61d3bc` | حذف `_syncSavingsJarWithReservedSync` — كان يصفّر رصيد حصالة التوفير عند كل فتح |
| `03162f0` | شيل أيقونة الخنزير `Icons.savings` من كل التطبيق → `Icons.monetization_on_rounded` |
| `d714129` | `jarFunding` apply/reverse يحدّث `walletSources` + `jar.balance` معاً |
| `532e7c6` | الحجوزات تعديل label فقط بدون مساس بالمعاملة الأصلية |
| `1f28b76` | تغيير نوع معاملة expense→income يحافظ على الجار المرتبط |
| `2a58b39` | الإيداع اليدوي للحصالة لا يُحسب ضمن دخل الميزانية الشهرية |
| `008904f` | قائمة معاملات الحصالة تعرض كل المعاملات (مش بس transferTypes محددة) |

### UI/UX (مرفوعة)
- كروت المعاملات في الـ home screen: لون الفئة + أيقونتها + label صحيح
- صفحة كل المعاملات: كروت ثابتة الحجم بألوان حمراء/خضراء
- تفاصيل المعاملة: hero card gradient + details مرتبة
- sort/filter في قائمة معاملات الحصالة

---

## المشاكل المعروفة الباقية

### P1 — Sort/Filter للمحافظ (D1 مؤجل)
في `_openWalletDetailsSheet` — نفس UI اللي عملناه للحصالة
**الملف:** `wallets_screen.dart`

### P2 — فتح معاملات الحجز من صفحة المحافظ (D2 مؤجل)
من تفاصيل المحفظة → كروت الحصالات المرتبطة → معاملات حجزها
**الملف:** `wallets_screen.dart`

### P3 — `_openBudgetFundingEditor` في `budget_tracking_screen.dart` (line 2212)
Codex أضاف نسخة موازية من jar details sheet في صفحة متابعة الميزانية.
لازم تتراجع أو تتوحد مع `_openJarDetailsSheet` في `wallets_screen.dart`.
**خطر:** code duplication — أي fix بيتعمل في مكان ممكن ما يتعملش في التاني.

---

## خطة الـ Refactor

| المرحلة | الملف | الحالة |
|---------|-------|--------|
| Phase 0 | هذا الملف | ✅ |
| Phase 1 | extract 5 widgets من `wallets_screen` → `wallet_shared_widgets.dart` | ✅ `f318533` |
| Phase 2 | extract `_WalletsListPage` + `_JarsListPage` | ⏳ |
| Phase 3 | extract `AllocationEditorScreen` | ⏳ |
| Phase 4 | extract budget tracking cards | ⏳ |
| Phase 5 | extract `_ColorBoxPicker` | ⏳ |
| Phase 6 | split `app_cubit.dart` → domain mixins | ⏳ |
| Phase 7 | باقي الملفات الكبيرة | ⏳ |

---

## قواعد العمل

1. `git commit + push` بعد كل وحدة منطقية صغيرة — مش تراكم
2. تحقق من توازن الأقواس بعد كل تعديل
3. `Icons.savings` ممنوع — دايماً `Icons.monetization_on_rounded`
4. في chat جديد: ابدأ بـ `اقرأ docs/REFACTOR_PLAN.md وكمل من آخر commit`

---

## ملاحظات معمارية مهمة

- **الحجوزات** = label فقط على `walletSources` — لا تنشئ معاملات
- **المعاملة الأصلية** لما تتعدل → `reverse() + apply()` يحدّث `walletSources` تلقائياً
- **`jarFunding`** (virtual) يحدّث `walletSources` + `jar.balance` معاً
- **`depositWithJarLabel`** لا تُحسب في دخل الميزانية الشهرية
- **الـ false-positive** المعروف: `p=-2` في `transaction_processor.dart` من تعليقات "أ)"/"ب)"
- **الـ false-positive** الثاني: `p=+2` في `notification_action_copy.dart` من regex `\\(`

