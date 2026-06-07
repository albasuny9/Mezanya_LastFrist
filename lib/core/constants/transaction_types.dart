enum TransactionType {
  income('income'),
  expense('expense'),
  transfer('transfer');

  const TransactionType(this.value);

  final String value;

  static TransactionType? fromValue(String? value) {
    for (final type in TransactionType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

enum TransferType {
  walletToWallet('wallet-to-wallet'),
  internalTransfer('internal-transfer'),
  jarFunding('jar-funding'),
  jarFundingPhysical('jar-funding-physical'),
  jarAllocation('jar-allocation'),
  jarAllocationCancel('jar-allocation-cancel'),
  jarAllocationSpend('jar-allocation-spend'),
  depositWithJarLabel('deposit-with-jar-label'),
  allocationToJar('allocation-to-jar'),
  jarToAllocation('jar-to-allocation');

  const TransferType(this.value);

  final String value;

  static TransferType? fromValue(String? value) {
    for (final type in TransferType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

enum AutomationType {
  auto('auto'),
  confirm('confirm'),
  manual('manual');

  const AutomationType(this.value);

  final String value;

  static AutomationType? fromValue(String? value) {
    for (final type in AutomationType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

enum BudgetScope {
  withinBudget('within-budget'),
  outsideBudget('outside-budget');

  const BudgetScope(this.value);

  final String value;

  static BudgetScope? fromValue(String? value) {
    for (final scope in BudgetScope.values) {
      if (scope.value == value) return scope;
    }
    return null;
  }
}
