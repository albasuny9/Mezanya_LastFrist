class TransactionEntity {
  const TransactionEntity({
    required this.id,
    required this.amount,
    required this.type,
    required this.createdAt,
    this.walletId,
    this.fromWalletId,
    this.toWalletId,
    this.allocationId,
    this.toAllocationId,
    this.budgetScope,
    this.incomeSourceId,
    this.categoryId,
    this.transferType,
    this.notes,
  });

  final String id;
  final String? walletId;
  final String? fromWalletId;
  final String? toWalletId;
  final String? allocationId;
  final String? toAllocationId;
  final String? budgetScope;
  final String? incomeSourceId;
  final String? categoryId;
  final String? transferType;
  final double amount;
  final String type;
  final DateTime createdAt;
  final String? notes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'walletId': walletId,
      'fromWalletId': fromWalletId,
      'toWalletId': toWalletId,
      'allocationId': allocationId,
      'toAllocationId': toAllocationId,
      'budgetScope': budgetScope,
      'incomeSourceId': incomeSourceId,
      'categoryId': categoryId,
      'transferType': transferType,
      'amount': amount,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'notes': notes,
    };
  }

  factory TransactionEntity.fromMap(Map<String, dynamic> map) {
    return TransactionEntity(
      id: map['id'] as String? ?? '',
      walletId: map['walletId'] as String?,
      fromWalletId: map['fromWalletId'] as String?,
      toWalletId: map['toWalletId'] as String?,
      allocationId: map['allocationId'] as String?,
      toAllocationId: map['toAllocationId'] as String?,
      budgetScope: map['budgetScope'] as String?,
      incomeSourceId: map['incomeSourceId'] as String?,
      categoryId: map['categoryId'] as String?,
      transferType: map['transferType'] as String?,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      type: map['type'] as String? ?? 'expense',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      notes: map['notes'] as String?,
    );
  }
}
