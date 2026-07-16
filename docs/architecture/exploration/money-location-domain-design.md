<!--
Status: Reference
Owner: Mohamed Basuny
Last Reviewed: 2026-07-15
Superseded By: N/A
-->

# Money Location Domain Design Exploration

> This is an exploration document, not a canonical Domain Bible chapter and not an ADR.
> It captures the discussion about Money Location, Allocation, Jar, budget reservation,
> physical deposit, and reconciliation.
>
> It is intentionally narrower than the full original discussion: shared-workspace design,
> multi-user ownership, and implementation-specific bug analysis are deferred elsewhere.

---

## 1. Current understanding

Mezanya records financial reality first, then interprets it through domain structures that describe money, ownership, purpose, and location.

The discussion established that the app must not try to force real life into a perfect deterministic model. Users may record what actually happened even when the system cannot yet reconcile every location or reservation detail. The domain should therefore support recording, later review, and later reconciliation.

---

## 2. The core domain objects

### Wallet

A Wallet represents a physical financial location that holds real money.
Examples:

- cash
- bank account
- card balance
- any real place the user can actually spend from

Wallets are the direct representation of actual balance.

### Allocation

An Allocation is a budget-cycle planning construct.
It is not a wallet and not a jar.
It describes how the current cycle intends to use available money.

### Jar

A Jar is a permanent purpose container.
It is a single entity; there is no Physical Jar subtype and no Virtual Jar subtype.
The difference is always in the transaction that affected the jar, not in the jar itself.

### Money Location

Money Location is the mapping between a jar's reserved value and its current backing source.
It is not a physical place by itself.
It describes how reserved money is currently backed.

---

## 3. Why Jar has no physical/virtual subtype

A Jar is one domain concept.

The same jar may participate in different kinds of operations:

- budget reservation into a jar
- reservation release out of a jar
- physical deposit to a jar

Those are operation differences, not jar-type differences.

The jar remains a jar.
Only the effect changes.

---

## 4. Budget Reservation

Budget Reservation means taking money planned in the current budget cycle and reserving it for a permanent jar purpose.

This is a domain-level move from cycle-managed money to purpose-reserved money.

It is not a wallet-to-wallet transfer.
It is not a physical movement of cash.
It is a change in how the money is committed inside the financial model.

Example:

```text
Monthly Allocation
        ↓
House Jar
```

When 5,000 is reserved for a house jar, that amount leaves the cycle-managed pool and becomes jar-reserved money.

---

## 5. Reservation Release

Reservation Release is the inverse of Budget Reservation.

It returns money from a jar back into the budget cycle.

Example:

```text
House Jar
        ↓
Monthly Allocation
```

This does not create new money.
It changes how already reserved money is treated in the domain.

---

## 6. Physical Deposit to Jar

Physical Deposit to Jar means that real money leaves a physical wallet and is then recorded as jar-backed money.

This is the case where the user actually spent or moved real cash in the physical world and then recorded that event into the jar.

The wallet decreases.
The jar increases.
The money location map must reflect the current backing source.

This operation is different from budget reservation because it changes actual wallet balance.

---

## 7. Money Location as a reconciliation-aware mapping

Money Location should be understood as a mapping between reserved value and its current backing source.

It is useful because users may reserve money for a jar from one place, then later spend from another wallet, or partially reconcile later.

That means Money Location must tolerate temporary inconsistency.
It should not block recording a real event just because the map is not yet perfect.

The app must allow the user to record what actually happened first, then fix or reconcile the map later.

---

## 8. Reconciliation-oriented behavior

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

## 9. Real life is not deterministic

Real financial behavior is often messy.

The same jar may be funded from one wallet, then later spent from another wallet, then corrected later, then reviewed again.

The domain must reflect that reality.

So the application should preserve the recorded transaction as the truth of what happened, while the Money Location map can be reviewed, corrected, or reconciled later.

---

## 10. Negative jar balances and deposit reconciliation

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

## 11. Candidate rules for future migration into the Bible

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

## 12. Open questions

- Is Money Location part of domain state or a derived reconciliation model?
- Which exact rules should govern temporary inconsistency?
- What is the right user-facing name for the money location concept?
- Should reconciliation be automatic, manual, or hybrid?
- Which operations require strict consistency and which operations can remain loose until review?

---

## 13. Postponed topics

The following topics are intentionally postponed and should not be solved inside this document:

- full transaction implementation
- UI design for money location editing
- automatic reconciliation algorithms
- budget-to-jar UI flows
- transfer refactors

---

## 14. Candidate chapters that may eventually receive this content

Likely target chapters in the Bible:

- Chapter 03 — Transfers
- Chapter 04 — Financial Engine
- Chapter 05 — Allocation

This exploration may also require a dedicated money-location chapter later if the concept grows further.

---

## 15. Existing chapters that may require revision

The following chapters may need review if this exploration becomes canonical:

- Chapter 01 — Domain Fundamentals
- Chapter 03 — Transfers
- Chapter 04 — Financial Engine
- Chapter 05 — Allocation

---

## 16. Summary

Money Location should be treated as a reconciliation-aware mapping over real financial reality, not as a rigid enforcement gate.

The domain must preserve the recorded real event even if the current map is imperfect.

Jar remains one entity.
Allocation remains cycle planning.
Wallet remains the real balance holder.
The Money Location layer helps explain, reconcile, and review how jar-backed money is currently sourced.
