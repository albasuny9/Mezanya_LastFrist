enum TransactionType {
  income('income'),
  expense('expense'),
  transfer('transfer'),
  balanceAdjustment('balance-adjustment');

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
  allocationFunding('allocation-funding'),
  jarFunding('jar-funding'),
  jarFundingPhysical('jar-funding-physical'),
  jarAllocation('jar-allocation'),
  jarAllocationCancel('jar-allocation-cancel'),
  jarAllocationSpend('jar-allocation-spend'),
  depositWithJarLabel('deposit-with-jar-label'),
  allocationToJar('allocation-to-jar'),
  jarToAllocation('jar-to-allocation'),
  jarToJar('jar-to-jar'),
  jarBalanceAdjustmentIncrease('jar-balance-adjustment-increase'),
  jarBalanceAdjustmentDecrease('jar-balance-adjustment-decrease');

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

enum ExpensePlanKind {
  installment('installment'),
  subscription('subscription');

  const ExpensePlanKind(this.value);

  final String value;

  static ExpensePlanKind? fromValue(String? value) {
    for (final kind in ExpensePlanKind.values) {
      if (kind.value == value) return kind;
    }
    return null;
  }
}

enum RecurrencePattern {
  daily('daily'),
  weekly('weekly'),
  biweekly('biweekly'),
  every3Weeks('every_3_weeks'),
  monthly('monthly'),
  every2Months('every_2_months'),
  every3Months('every_3_months'),
  every6Months('every_6_months'),
  yearly('yearly'),
  manualVariable('manual-variable');

  const RecurrencePattern(this.value);

  final String value;

  static RecurrencePattern? fromValue(String? value) {
    for (final pattern in RecurrencePattern.values) {
      if (pattern.value == value) return pattern;
    }
    return null;
  }
}

enum RolloverBehavior {
  toSavings('to-savings'),
  keep('keep');

  const RolloverBehavior(this.value);
  final String value;

  static RolloverBehavior? fromValue(String? value) {
    for (final r in RolloverBehavior.values) {
      if (r.value == value) return r;
    }
    return null;
  }
}

enum AutoBackupMode {
  off('off'),
  auto('auto'),
  manual('manual');

  const AutoBackupMode(this.value);
  final String value;
}
