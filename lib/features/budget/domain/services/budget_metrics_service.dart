class BudgetMetrics {
  // Actual
  final double actualIncome;
  final double actualExpense;

  // Planned
  final double plannedIncome;

  // Jar
  final double virtualJarReserved;
  final double physicalJarFunding;

  // Result
  final double remainingIncome;

  const BudgetMetrics({
    required this.actualIncome,
    required this.actualExpense,
    required this.plannedIncome,
    required this.virtualJarReserved,
    required this.physicalJarFunding,
    required this.remainingIncome,
  });
}
