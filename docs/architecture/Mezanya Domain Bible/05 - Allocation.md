<!--
Status: Canonical
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# الفصل الخامس - Allocation & Money Ownership

> هذا الفصل يعرّف كيف يفهم Mezanya المخصصات، والملكية المالية، وعلاقة الميزانية بالحصالات، وما الذي يُعدّ حجزًا للمال وما الذي يُعدّ حركة مالية حقيقية.

---

# 1. الفكرة الأساسية

في Mezanya، ليس كل كيان مالي يملك المال بنفس المعنى.

بعض الكيانات تمتلك أموالًا حقيقية فعلًا داخل محفظة حقيقية.
وبعض الكيانات لا تملك المال، لكنها تصف كيف يُستخدم هذا المال أو لماذا حُجز أو أين أصبح موقعه المنطقي داخل النظام.

هذا الفصل يثبت الفرق بين:

- المال الحقيقي
- المال المخصص
- المال المحجوز
- الخطة المالية داخل الدورة

ولا يشرح التنفيذ البرمجي لهذه الفروق، بل يثبت معناها الدوميني فقط.

---

# 2. تعريف Allocation

الـ Allocation هو جزء من الخطة المالية داخل الدورة.

هو ليس محفظة.

وليس حصالة.

وليس حسابًا نقديًا.

وليس رصيدًا حقيقيًا مستقلًا.

الـ Allocation يمثل قرارًا ماليًا داخل الدورة الحالية، يحدد أن جزءًا من المال المتاح قد تم تخصيصه لغرض معين.

أمثلة:

- الطعام
- المواصلات
- الفواتير
- التعليم
- الترفيه
- أي غرض إنفاقي داخل الدورة المالية

الـ Allocation يتغير مع تغيّر الخطة أو مع تنفيذ العمليات التي تؤثر عليه داخل الدورة.

---

# 3. تعريف Jar

الـ Jar هو كيان دائم يمثل غرضًا ماليًا محجوزًا.

الـ Jar ليس نوعًا مختلفًا من الكيانات.

ولا يوجد داخل Mezanya:

- Physical Jar
- Virtual Jar

الحصالة واحدة فقط.

الاختلاف ليس في الحصالة نفسها، بل في نوع المعاملة التي أثرت عليها.

الـ Jar يمثل هدفًا دائمًا مثل:

- سيارة
- زواج
- طوارئ
- سفر
- بيت
- تعليم طويل الأجل

الـ Jar قد يستقبل رصيدًا أو يفقده، لكن هذا الرصيد لا يعني أن المال أصبح موجودًا داخل الحصالة كمكان مادي مستقل.

الـ Jar يصف المال من حيث الهدف الذي انتمى إليه.

---

# 4. المال الحقيقي مقابل المال الموصوف

المال الحقيقي يوجد دائمًا داخل Wallet.

أما Allocation وJar فهما يصفان المال، ولا يخلقان المال من العدم.

والفرق بينهما كالآتي:

- Wallet: أين يوجد المال الحقيقي؟
- Allocation: كيف خُطط لاستخدام المال داخل الدورة؟
- Jar: لماذا حُجز هذا المال لهدف دائم؟

ومن المهم التمييز بين طبقات النظام المختلفة.

المال الحقيقي يوجد فقط داخل Wallet.

أما Allocation وJar فهما يعملان كطبقتين افتراضيتين (Virtual Layers) فوق هذا المال الحقيقي.

هما لا يملكان مالًا مستقلًا، وإنما يصفان كيف يُدار المال أو لأي غرض أصبح محجوزًا.

قد يشير Allocation وJar إلى نفس المال الحقيقي في الوقت نفسه، لأنهما يصفانه من زاويتين مختلفتين، وليس لأن المال تكرر أو تضاعف.

هذا الفرق أساسي، لأنه يمنع الخلط بين الرصيد الفعلي وبين التخصيص أو الحجز أو الوصف.

---

# 5. Budget Reservation

Budget Reservation هي العملية التي تنقل جزءًا من المخصص الدوري إلى حصالة دائمة.

في هذه الحالة:

- ينقص الجزء من الخطة المالية داخل الدورة.
- وتزداد الحصالة المقابلة له.
- ويغادر هذا الجزء الدورة المالية النشطة باعتباره مخصصًا أصبح محفوظًا لهدف دائم.

هذا ليس تحويلًا ماليًا حقيقيًا بين محافظ.

إنه انتقال من نطاق التخطيط الدوري إلى نطاق الحجز الدائم.

مثال:

```text
Allocation (Monthly Plan)
        ↓
Jar (Permanent Purpose)
```

إذا تم حجز 5000 من المخصص الشهري إلى حصالة الزواج، فإن الخمسة آلاف:

- لم تعد متاحة كمخصص داخل الدورة.
- وأصبحت محجوزة لغرض دائم داخل الحصالة.

---

# 6. Reservation Release

Reservation Release هي العملية العكسية.

عندما يقرر المستخدم إعادة جزء من المال المحجوز في Jar إلى الخطة المالية للدورة، فإن المال لا يعود كمحفظة جديدة، بل يعود كجزء من التخصيص الدوري.

مثال:

```text
Jar (Permanent Purpose)
        ↓
Allocation (Monthly Plan)
```

في هذه الحالة:

- تقل قيمة الحجز الدائم.
- وتزداد المساحة المتاحة داخل الدورة المالية.
- ويعود هذا الجزء ليُدار كخطة إنفاق أو تخصيص داخل الدورة.

---

# 7. الفرق بين Budget Reservation و Physical Deposit

هنا يوجد نوعان مختلفان تمامًا من الأثر.

## أولًا: Budget Reservation

هذا النوع لا ينقل المال الحقيقي من محفظة إلى أخرى.

هو فقط يعيد تصنيف المال داخل النظام المالي.

ويحدث عندما يتحول جزء من الخطة الشهرية إلى حجز دائم داخل Jar.

## ثانيًا: Physical Deposit to Jar

هذا النوع يخصم المال الحقيقي من Wallet.

ثم يجعل هذا المال يظهر كرصيد داخل Jar.

وهنا يكون هناك أثر مالي فعلي على المحفظة، لأن المال خرج منها بالفعل.

مثال:

- المستخدم لديه كاش.
- يضع 1000 في حصالة الزواج.
- ينقص الكاش الحقيقي.
- وتزداد الحصالة بالمبلغ نفسه.

هذا ليس مجرد ترتيب داخلي.

إنه صرف فعلي من Wallet مع توجيه المال إلى Jar.

---

# 8. Money Location

## 8.1 Definition
Money Location هو نظام يصف أين يُعتبر المال المحجوز داخل Jar مدعومًا فعليًا.

هو لا يمثل مكانًا جديدًا للمال.

ولا يغيّر الأرصدة.

ولا يُنشئ معاملة مالية.

بل يصف العلاقة بين رصيد الحصالة الحالي والمحافظ التي تدعمه.


## 8.2 Automatic Money Location Lifecycle

أي معاملة تؤثر على Jar تُنتج أثرًا تلقائيًا على Money Location.

يقوم النظام بإنشاء أو تحديث أو إزالة سجلات Money Location كنتيجة مباشرة لتنفيذ المعاملة.

إذا تم حذف المعاملة أو التراجع عنها، فيجب إزالة أو عكس أثرها على Money Location أيضًا.

لا ينشئ المستخدم Money Location أثناء التشغيل الطبيعي.

ولا يتدخل يدويًا إلا عند وجود Money Location Issue.

## 8.3 Money Location Issues
الـ Issue ليس Bug.
الـ Issue ليس Transaction Error.
الـ Issue لا يمنع التسجيل.
الـ Issue يعني:

"النظام لم يعد يستطيع تفسير توزيع مكان الفلوس الحالي بشكل كامل."

Money Location Issue لا تعني أن المعاملة خاطئة.

ولا تعني أن أرصدة المحافظ أو الحصالة أصبحت خاطئة.

وإنما تعني فقط أن النظام لم يعد قادرًا على تفسير توزيع مكان الفلوس الحالي بالكامل اعتمادًا على القواعد التلقائية.

## 8.4 Automatic vs Manual Changes

يقوم النظام تلقائيًا بتحديث Money Location عند:

- الإيداع.
- السحب.
- المصروف.
- الدخل.
- حذف المعاملة.
- التراجع عن المعاملة.
- تعديل المعاملة إذا كان تعديلها يغيّر أثرها المالي.

أما التعديل اليدوي فلا يستخدم لإنشاء أو تعديل المعاملات، وإنما يستخدم فقط لإعادة تنظيم Money Location عندما يعجز النظام عن الوصول إلى توزيع متسق تلقائيًا.

التحديث التلقائي لا يعني دائمًا أن Money Location أصبح متسقًا بالكامل.

إذا لم تتمكن القواعد التلقائية من الوصول إلى توزيع متسق، تُسجل Money Location Issue مع الاحتفاظ بجميع آثار المعاملة المالية كما هي.

# 9. Jar ككيان واحد قابل للمشاركة

الـ Jar في Mezanya كيان واحد، لكنه قابل مستقبلًا لأن يُستخدم داخل Workspace أو بيئة مشتركة بين عدة مستخدمين.

هذا لا يغيّر تعريف الـ Jar نفسه.

بل يضيف فقط طبقة من الملكية أو المشاركة أو الأعضاء المرتبطين به.

مثال:

- حصالة البيت
- حصالة الزواج
- حصالة الأسرة

كلها ما زالت Jars.

لكن قد يكون لها أكثر من مساهم أو أكثر من مستخدم يسجل فيها أو يقرأها.

هذا التوسع مستقبلي، لكنه لا يغيّر أن الـ Jar واحد وليس نوعين.

---

# 10. قاعدة التمييز بين النوع والعملية

الكيان لا يتغير نوعه بسبب العملية.

بل العملية هي التي تحدد ماذا حدث فعليًا.

لذلك:

- Jar لا يصبح Physical Jar.
- Jar لا يصبح Virtual Jar.
- Allocation لا يصبح نوعًا مختلفًا من Jar.
- Wallet لا يصبح Allocation.

الاختلاف فقط في المعنى الذي تولد عن العملية.

---

# 11. العلاقة مع الميزانية

الميزانية هي دورة مالية.

والـ Allocation يعيش داخل هذه الدورة.

أما الـ Jar فهو هدف دائم خارج تقييد الدورة، رغم أنه قد يتغذى من موارد الدورة أو من تحويلات قادمة منها.

ولهذا فإن انتقال المال من Allocation إلى Jar يعني خروج المال من إدارة الدورة إلى حجز دائم.

أما انتقال المال من Jar إلى Allocation فيعني رجوع الحجز الدائم إلى إدارة الدورة.

---

# 12. Money Location



# 13. القواعد الأساسية

1. الـ Allocation ليس Wallet.
2. الـ Jar ليس Wallet.
3. الـ Jar ليس نوعًا ثانيًا من الكيان.
4. لا يوجد Physical Jar وVirtual Jar.
5. الفرق بين Budget Reservation وPhysical Deposit فرق عملية، لا فرق كيان.
6. أي جزء من المال إما أن يكون داخل إدارة الدورة أو داخل حجز دائم، وليس الاثنين معًا في نفس اللحظة.
7. أي تغيير في Jar أو Allocation لا يعني تلقائيًا تغييرًا في المال الحقيقي.
8. تغيير المال الحقيقي يحدث فقط عندما تتأثر Wallet.
9. لا يجوز أن يتجاوز مجموع قيم Money Location الرصيد الفعلي القابل للتوزيع داخل الحصالة. وعند وجود رصيد سالب، يجب أن تغطي أي إيداعات جديدة هذا العجز أولًا قبل أن تضيف قيمة جديدة إلى Money Location.
---

# 14. Negative jar balances and deposit reconciliation

A jar may temporarily go negative.

When that happens, a later deposit cannot be treated as if the entire deposited amount is newly available to the jar location map.

The deposit must first cover the negative part, and only the remaining positive portion may become available as mapped reserved money.

Example:

- Jar balance = -300
- Deposit = 1000 from Cash Wallet

Then:

- 300 covers the deficit
- 700 remains as positive jar-backed value

This prevents Money Location from becoming larger than the jar's real effective balance.

The money-location layer must therefore obey balance-aware reconciliation rules, not just simple labels.

---

# 15. Reconciliation-oriented behavior

The Money Location layer should behave like a reconciliation layer, not a strict enforcement layer.

That means it should:

- detect inconsistencies
- surface them to the user
- help the user review them
- allow later correction
- optionally support automatic reconciliation if a policy exists

It should not reject real user history.
It should not rewrite the event into something else just to satisfy the map.

---

# 16. Real life is not deterministic

Real financial behavior is often messy.

The same jar may be funded from one wallet, then later spent from another wallet, then corrected later, then reviewed again.

The domain must reflect that reality.

So the application should preserve the recorded transaction as the truth of what happened, while the Money Location map can be reviewed, corrected, or reconciled later.

---



# 17. Summary

## Summary

- Wallet هو المصدر الوحيد للمال الحقيقي.
- Allocation وJar طبقتان افتراضيتان تنظمان هذا المال.
- Money Location يصف كيف يُدعَم رصيد الحصالة بالمحافظ.
- Money Location لا يمنع تسجيل الحقيقة المالية.
- عند حدوث تعارض، تُسجل Issue ويُقترح حل دون تعديل المعاملة الأصلية.