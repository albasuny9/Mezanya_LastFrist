part of 'app_cubit.dart';

mixin AppCubitLentMixin on AppCubitBase {
  // ── سلفة: أضف سجل سلفة وأخصم من المحفظة فوراً ──────────────────────────
  Future<void> addLentRecord({
    required String personName,
    required double amount,
    required String walletId,
    required DateTime expectedReturnDate,
    DateTime? lentDate,
    bool isMonthlyInstallments = false,
    String? existingPersonId,
    String? notes,
  }) async {
    final effectiveLentDate = lentDate ?? DateTime.now();
    final walletName = state.wallets
        .where((w) => w.id == walletId)
        .map((w) => w.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);

    final entryId = _id('lent-entry');
    final newEntry = <String, dynamic>{
      'id': entryId,
      'amount': amount,
      'lentDate': effectiveLentDate.toIso8601String(),
      'expectedReturnDate': expectedReturnDate.toIso8601String(),
      'notes': notes,
      'isSettled': false,
    };

    final txn = TransactionEntity(
      id: _id('txn'),
      walletId: walletId,
      amount: amount,
      type: TransactionType.expense.value,
      notes: 'سلفة لـ $personName',
      createdAt: effectiveLentDate,
    );

    List<RecurringTransactionEntity> updatedList;
    String personId;

    final existing = existingPersonId != null
        ? state.recurringTransactions
            .where((r) => r.id == existingPersonId)
            .cast<RecurringTransactionEntity?>()
            .firstWhere((_) => true, orElse: () => null)
        : null;

    if (existing != null) {
      personId = existing.id;
      final updatedPerson = existing.copyWith(
        walletId: walletId,
        lentEntries: [...existing.lentEntries, newEntry],
        isLentArchived: false,
        amount: existing.outstandingLentAmount + amount,
      );
      updatedList = state.recurringTransactions
          .map((r) => r.id == personId ? updatedPerson : r)
          .toList();
    } else {
      personId = _id('rec');
      final person = RecurringTransactionEntity(
        id: personId,
        name: personName,
        type: TransactionType.expense.value,
        amount: amount,
        dayOfMonth: 1,
        executionType: AutomationType.confirm.value,
        walletId: walletId,
        budgetScope: BudgetScope.outsideBudget.value,
        recurrencePattern: RecurrencePattern.manualVariable.value,
        icon: 'handshake',
        iconColor: '#1a7a4a',
        isLent: true,
        lentPersonName: personName,
        lentEntries: [newEntry],
      );
      updatedList = [...state.recurringTransactions, person];
    }

    await _applyAndLog(
      action: 'add',
      entityType: 'lent-record',
      entityId: personId,
      details:
          'سلفة لـ $personName بمبلغ ${amount.toStringAsFixed(2)} من ${walletName ?? walletId}',
      titleOverride: personName,
      apply: () async {
        final stateAfterTx = TransactionProcessor.apply(state, txn);
        return stateAfterTx.copyWith(recurringTransactions: updatedList);
      },
    );
  }

  // ── سلفة: استرداد سلفة فردية ────────────────────────────────────────────
  Future<void> settleLentEntry(String personId, String entryId) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;

    final entry = person.lentEntries
        .where((e) => e['id'] == entryId)
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);
    if (entry == null) return;

    final entryAmount = (entry['amount'] as num?)?.toDouble() ?? 0;
    final updatedEntries = person.lentEntries
        .map((e) => e['id'] == entryId ? {...e, 'isSettled': true} : e)
        .toList();
    final allSettled = updatedEntries.every((e) => e['isSettled'] == true);
    final updatedPerson = person.copyWith(
      lentEntries: updatedEntries,
      amount: (person.outstandingLentAmount - entryAmount)
          .clamp(0, double.infinity),
      isLentArchived: allSettled,
    );

    final txn = TransactionEntity(
      id: _id('txn'),
      walletId: person.walletId,
      amount: entryAmount,
      type: TransactionType.income.value,
      notes: 'استرداد سلفة من ${person.lentPersonName ?? person.name}',
      createdAt: DateTime.now(),
    );

    final updatedList = state.recurringTransactions
        .map((r) => r.id == personId ? updatedPerson : r)
        .toList();

    await _applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          'استرداد سلفة من ${person.lentPersonName ?? person.name} بمبلغ ${entryAmount.toStringAsFixed(2)}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async {
        final stateAfterTx = TransactionProcessor.apply(state, txn);
        return stateAfterTx.copyWith(recurringTransactions: updatedList);
      },
    );
  }

  // ── سلفة: تنازل عن سلفة فردية ──────────────────────────────────────────
  Future<void> writeOffLentEntry(String personId, String entryId) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;

    final entryAmount = (person.lentEntries
                .where((e) => e['id'] == entryId)
                .cast<Map<String, dynamic>?>()
                .firstWhere((_) => true, orElse: () => null)?['amount'] as num?)
            ?.toDouble() ??
        0;

    final updatedEntries = person.lentEntries
        .map((e) => e['id'] == entryId ? {...e, 'isSettled': true} : e)
        .toList();
    final allSettled = updatedEntries.every((e) => e['isSettled'] == true);
    final updatedPerson = person.copyWith(
      lentEntries: updatedEntries,
      amount: (person.outstandingLentAmount - entryAmount)
          .clamp(0, double.infinity),
      isLentArchived: allSettled,
    );
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((r) => r.id == personId ? updatedPerson : r)
          .toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          'تنازل عن سلفة ${person.lentPersonName ?? person.name} بمبلغ ${entryAmount.toStringAsFixed(2)}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  // ── سلفة: تأجيل موعد سلفة فردية ─────────────────────────────────────────
  Future<void> postponeLentEntry(
      String personId, String entryId, DateTime newDate) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final updatedEntries = person.lentEntries
        .map((e) => e['id'] == entryId
            ? {...e, 'expectedReturnDate': newDate.toIso8601String()}
            : e)
        .toList();
    final updatedPerson = person.copyWith(lentEntries: updatedEntries);
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((r) => r.id == personId ? updatedPerson : r)
          .toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details:
          'تأجيل سلفة ${person.lentPersonName ?? person.name} إلى ${newDate.day}/${newDate.month}/${newDate.year}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  // ── سلفة: أرشفة / إلغاء أرشفة شخص ─────────────────────────────────────
  Future<void> archiveLentPerson(String personId, {bool archive = true}) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final updated = person.copyWith(isLentArchived: archive);
    final next = state.copyWith(
      recurringTransactions: state.recurringTransactions
          .map((r) => r.id == personId ? updated : r)
          .toList(),
    );
    await _applyAndLog(
      action: 'edit',
      entityType: 'lent-record',
      entityId: personId,
      details: archive
          ? 'أرشفة ${person.lentPersonName ?? person.name}'
          : 'إلغاء أرشفة ${person.lentPersonName ?? person.name}',
      titleOverride: person.lentPersonName ?? person.name,
      apply: () async => next,
    );
  }

  // ── Legacy stubs — implemented to delegate to per-entry methods ──────────
  Future<void> settleLentRecord(String personId) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final outstanding =
        person.lentEntries.where((e) => e['isSettled'] != true).toList();
    for (final entry in outstanding) {
      final entryId = entry['id'] as String?;
      if (entryId != null) await settleLentEntry(personId, entryId);
    }
  }

  Future<void> writeOffLentRecord(String personId) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final outstanding =
        person.lentEntries.where((e) => e['isSettled'] != true).toList();
    for (final entry in outstanding) {
      final entryId = entry['id'] as String?;
      if (entryId != null) await writeOffLentEntry(personId, entryId);
    }
  }

  Future<void> postponeLentRecord(String personId, DateTime newDate) async {
    final person = state.recurringTransactions
        .where((r) => r.id == personId)
        .cast<RecurringTransactionEntity?>()
        .firstWhere((_) => true, orElse: () => null);
    if (person == null) return;
    final outstanding =
        person.lentEntries.where((e) => e['isSettled'] != true).toList();
    for (final entry in outstanding) {
      final entryId = entry['id'] as String?;
      if (entryId != null) await postponeLentEntry(personId, entryId, newDate);
    }
  }
}
