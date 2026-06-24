# خطة إعادة هيكلة الكود — Mezanya

**الهدف:** تقسيم الملفات الضخمة لملفات أصغر منظمة بمعايير مهندس محترف،
بدون تغيير أي سلوك فعلي للتطبيق (refactor بحت، مفيش منطق جديد).

**القاعدة الذهبية لكل مرحلة:**
1. نقل كود موجود فقط (copy → استدعاء من المكان الجديد → حذف الأصل)
2. التحقق من توازن الأقواس بعد كل خطوة (`( ) [ ] { }`)
3. التأكد إن كل الـ imports اللازمة موجودة في الملف الجديد
4. Commit + push فوري بعد كل مرحلة كاملة (مش بعد كل خطوة صغيرة)
5. ممنوع دمج مرحلتين في commit واحد — كل مرحلة بمفردها

**الحالة الحالية (قبل البدء):**
| الملف | عدد الأسطر |
|---|---|
| budget_tracking_screen.dart | 5607 |
| budget_setup_screen.dart | 4228 |
| wallets_screen.dart | 4071 |
| recurring_transaction_composer_screen.dart | 2612 |
| debts_and_subscriptions_screen.dart | 2483 |
| add_transaction_screen.dart | 2456 |
| logs_screen.dart | 1746 |
| app_cubit.dart | 1746 |
| app_icon_picker_dialog.dart | 1523 |

---

## استراتيجية الترتيب

نبدأ بأقل خطورة (widgets صغيرة مستقلة بالفعل كـ class منفصل، بس
مكدّسة في نفس الملف) وننتهي بأعلى خطورة (تقسيم منطق الـ State class
الرئيسي نفسه). كل مرحلة لازم تخلص بنجاح قبل ما نبدأ التالية.

---

## ✅ Phase 0 — هذا الملف (تم)

كتابة الخطة ده وحفظها في الريبو نفسه (`docs/REFACTOR_PLAN.md`) بحيث
تفضل موجودة حتى لو الـ container اتعمله reset.

---

## Phase 1 — wallets_screen.dart: فصل الـ widgets الصغيرة المستقلة

**الخطورة: منخفضة جداً** (كلاسات stateless صغيرة، بدون اعتماد على
حالة الشاشة الأم)

استخراج الكلاسات دي لملف جديد
`lib/features/wallets/presentation/widgets/wallet_shared_widgets.dart`:
- `_ActionBtn`
- `_InlineNote`
- `_EmptyStateCard`
- `_WalletPickerTile`
- `_TransferItemTile`

تحويلها من `_PrivateClass` لـ `PublicClass` (شيل الـ underscore) عشان
تتصدّر من الملف الجديد، وتحديث كل أماكن استخدامها في
`wallets_screen.dart` بالاسم الجديد + إضافة الـ import.

**الحالة: لم تبدأ بعد**

---

## Phase 2 — wallets_screen.dart: فصل صفحات القوائم الكاملة

**الخطورة: منخفضة-متوسطة**

نقل الكلاسات دي (كل واحدة Widget كامل بحالته الخاصة) لملفات منفصلة:
- `_WalletsListPage` + `_WalletsListPageState` →
  `lib/features/wallets/presentation/screens/wallets_list_page.dart`
- `_JarsListPage` + `_JarsListPageState` →
  `lib/features/wallets/presentation/screens/jars_list_page.dart`

**الحالة: لم تبدأ بعد**

---

## Phase 3 — budget_setup_screen.dart: فصل محرر المخصصات

**الخطورة: متوسطة**

نقل `AllocationEditorResult` + `_AllocationEditorScreen` +
`_AllocationEditorScreenState` + الـ widgets المساعدة ليه
(`_EditorSection`, `_ChoiceTile`, `_FundingCard`, `_DetailsBlock`,
`_StartDayPickerTile`) لملف جديد:
`lib/features/budget/presentation/screens/allocation_editor_screen.dart`

**الحالة: لم تبدأ بعد**

---

## Phase 4 — budget_tracking_screen.dart: فصل الكروت المساعدة

**الخطورة: متوسطة**

نقل الكلاسات المستقلة:
- `_BudgetLentPendingCard`
- `_InstallmentPaymentsCard` + `_InstallmentPaymentsCardState`
- `_DraggableFilterableTxSheet` + `_DraggableFilterableTxSheetState`

لملف جديد:
`lib/features/budget/presentation/widgets/budget_tracking_cards.dart`

**الحالة: لم تبدأ بعد**

---

## Phase 5 — app_icon_picker_dialog.dart: فصل الـ Color Picker

**الخطورة: منخفضة** (عملنا فيه شغل مؤخراً، التقسيم واضح)

نقل `_ColorBoxPicker` + `_ColorBoxPickerState` + `_SatValBoxPainter`
لملف جديد:
`lib/core/widgets/color_box_picker.dart`

**الحالة: لم تبدأ بعد**

---

## Phase 6 — app_cubit.dart: فصل حسب الـ Domain

**الخطورة: عالية** (أهم ملف في التطبيق، كل التعديل عليه حساس)

تقسيم الـ `AppCubit` لـ **mixins** منفصلة بدل ملف واحد ضخم، كل mixin
في ملف خاص بيه، والـ AppCubit الرئيسي بيجمعهم:
- `WalletCubitMixin` → عمليات المحافظ
- `JarCubitMixin` → عمليات الحصالات والتوزيعات المعلّقة
- `AllocationCubitMixin` → عمليات المخصصات
- `RecurringCubitMixin` → المعاملات المتكررة/الديون/الاشتراكات/السلف
- `GoalCubitMixin` → الأهداف
- `BudgetSetupCubitMixin` → إعدادات الميزانية العامة

**ملاحظة مهمة:** المرحلة دي لازم تتعمل بحذر شديد وبعد ما كل
المراحل اللي قبلها تخلص وتتأكد إنها شغالة. هي آخر مرحلة بالعمد.

**الحالة: لم تبدأ بعد**

---

## Phase 7 — باقي الملفات الكبيرة (تقييم لاحق)

بعد ما المراحل اللي فوق تخلص، نقيّم تاني:
- `recurring_transaction_composer_screen.dart` (2612 سطر)
- `debts_and_subscriptions_screen.dart` (2483 سطر)
- `add_transaction_screen.dart` (2456 سطر)
- `logs_screen.dart` (1746 سطر)

**الحالة: لم تبدأ بعد**

---

## سجل التنفيذ

| المرحلة | تاريخ البدء | الحالة | Commit hash |
|---|---|---|---|
| Phase 0 | اليوم | ✅ تم | (هذا الملف) |
| Phase 1 | 2026-06-25 | ✅ تم | f318533 |
| Phase 2 | - | ⏳ لم تبدأ | - |
| Phase 3 | - | ⏳ لم تبدأ | - |
| Phase 4 | - | ⏳ لم تبدأ | - |
| Phase 5 | - | ⏳ لم تبدأ | - |
| Phase 6 | - | ⏳ لم تبدأ | - |
| Phase 7 | - | ⏳ لم تبدأ | - |

**ملحوظة لأي محادثة قادمة:** اقرأ الجدول ده الأول لمعرفة آخر مرحلة
خلصت، وابدأ من اللي بعدها مباشرة. متبدأش من الآخر.
