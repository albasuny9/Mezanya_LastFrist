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

# 8. Jar ككيان واحد قابل للمشاركة

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

# 9. قاعدة التمييز بين النوع والعملية

الكيان لا يتغير نوعه بسبب العملية.

بل العملية هي التي تحدد ماذا حدث فعليًا.

لذلك:

- Jar لا يصبح Physical Jar.
- Jar لا يصبح Virtual Jar.
- Allocation لا يصبح نوعًا مختلفًا من Jar.
- Wallet لا يصبح Allocation.

الاختلاف فقط في المعنى الذي تولد عن العملية.

---

# 10. العلاقة مع الميزانية

الميزانية هي دورة مالية.

والـ Allocation يعيش داخل هذه الدورة.

أما الـ Jar فهو هدف دائم خارج تقييد الدورة، رغم أنه قد يتغذى من موارد الدورة أو من تحويلات قادمة منها.

ولهذا فإن انتقال المال من Allocation إلى Jar يعني خروج المال من إدارة الدورة إلى حجز دائم.

أما انتقال المال من Jar إلى Allocation فيعني رجوع الحجز الدائم إلى إدارة الدورة.

---

# 11. القواعد الأساسية

1. الـ Allocation ليس Wallet.
2. الـ Jar ليس Wallet.
3. الـ Jar ليس نوعًا ثانيًا من الكيان.
4. لا يوجد Physical Jar وVirtual Jar.
5. الفرق بين Budget Reservation وPhysical Deposit فرق عملية، لا فرق كيان.
6. أي جزء من المال إما أن يكون داخل إدارة الدورة أو داخل حجز دائم، وليس الاثنين معًا في نفس اللحظة.
7. أي تغيير في Jar أو Allocation لا يعني تلقائيًا تغييرًا في المال الحقيقي.
8. تغيير المال الحقيقي يحدث فقط عندما تتأثر Wallet.

---

# 12. Money Location as a reconciliation-aware mapping

Money Location should be understood as a mapping between reserved value and its current backing source.

It is useful because users may reserve money for a jar from one place, then later spend from another wallet, or partially reconcile later.

That means Money Location must tolerate temporary inconsistency.
It should not block recording a real event just because the map is not yet perfect.

The app must allow the user to record what actually happened first, then fix or reconcile the map later.

---

# 13. Negative jar balances and deposit reconciliation

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

# 14. Reconciliation-oriented behavior

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

# 15. Real life is not deterministic

Real financial behavior is often messy.

The same jar may be funded from one wallet, then later spent from another wallet, then corrected later, then reviewed again.

The domain must reflect that reality.

So the application should preserve the recorded transaction as the truth of what happened, while the Money Location map can be reviewed, corrected, or reconciled later.

---

# 16. Candidate rules for future migration into the Bible

The following ideas look strong enough to become canonical later, but they are not finalized here:

- Jar is a single entity with no physical/virtual subtype.
- Allocation is budget-cycle planning.
- Budget Reservation moves money from cycle-planned to jar-reserved state.
- Reservation Release moves it back.
- Physical Deposit to Jar decreases a real wallet.
- Money Location is a reconciliation-aware mapping, not a physical location.
- Money Location must allow temporary inconsistency.
- Reconciliation should be possible after recording the real event.
- Money Location must be balance-aware when a jar can temporarily go negative.

---

# 17. Open questions

- Is Money Location part of domain state or a derived reconciliation model?
- Which exact rules should govern temporary inconsistency?
- What is the right user-facing name for the money location concept?
- Should reconciliation be automatic, manual, or hybrid?
- Which operations require strict consistency and which operations can remain loose until review?

---

# 18. Postponed topics

The following topics are intentionally postponed and should not be solved inside this document:

- full transaction implementation
- UI design for money location editing
- automatic reconciliation algorithms
- budget-to-jar UI flows
- transfer refactors

---

# 19. Candidate chapters that may eventually receive this content

Likely target chapters in the Bible:

- Chapter 03 — Transfers
- Chapter 04 — Financial Engine
- Chapter 05 — Allocation

This exploration may also require a dedicated money-location chapter later if the concept grows further.

---

# 20. Existing chapters that may require revision

The following chapters may need review if this exploration becomes canonical:

- Chapter 01 — Domain Fundamentals
- Chapter 03 — Transfers
- Chapter 04 — Financial Engine
- Chapter 05 — Allocation

---

# 21. Summary

Money Location should be treated as a reconciliation-aware mapping over real financial reality, not as a rigid enforcement gate.

The domain must preserve the recorded real event even if the current map is imperfect.

Jar remains one entity.
Allocation remains cycle planning.
Wallet remains the real balance holder.
The Money Location layer helps explain, reconcile, and review how jar-backed money is currently sourced.
