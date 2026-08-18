class FinancialSnapshot {
  final double actualCash;
  final double moneyOwedToMe;
  final double salaryArrears;
  final int salaryArrearsMonths;
  final double confirmedFutureIncome;
  final double expectedFutureIncome;
  final double potentialIncome;
  
  final DateTime? nextConfirmedIncomeDate;
  final double nextConfirmedIncomeAmount;
  final DateTime? nextExpectedIncomeDate;
  final double nextExpectedIncomeAmount;
  
  final double upcomingMandatoryPayments;
  final double mandatoryPaymentsBeforeNextConfirmedIncome;
  final double plannedEssentialExpenses;
  final double minimumCashBuffer;
  
  final double safeToSpendNow;
  final double monthlyDisposableAmount;
  
  final double projectedBalanceBeforeNextIncome;
  final double lowestProjectedBalance;
  final DateTime? lowestProjectedBalanceDate;
  final bool hasCashFlowWarning;
  
  final Map<String, String> financialRealityIndicators; // 🟢 / 🟡 / 🔴

  final double totalDebt;
  final double totalMonthlyDebtPayment;
  final int activeDebtCount;
  final String nextDebtTarget;
  final DateTime? projectedDebtFreeDate;

  final List<String> todayActions;

  FinancialSnapshot({
    required this.actualCash,
    required this.moneyOwedToMe,
    required this.salaryArrears,
    required this.salaryArrearsMonths,
    required this.confirmedFutureIncome,
    required this.expectedFutureIncome,
    required this.potentialIncome,
    this.nextConfirmedIncomeDate,
    required this.nextConfirmedIncomeAmount,
    this.nextExpectedIncomeDate,
    required this.nextExpectedIncomeAmount,
    required this.upcomingMandatoryPayments,
    required this.mandatoryPaymentsBeforeNextConfirmedIncome,
    required this.plannedEssentialExpenses,
    required this.minimumCashBuffer,
    required this.safeToSpendNow,
    required this.monthlyDisposableAmount,
    required this.projectedBalanceBeforeNextIncome,
    required this.lowestProjectedBalance,
    this.lowestProjectedBalanceDate,
    required this.hasCashFlowWarning,
    required this.financialRealityIndicators,
    required this.totalDebt,
    required this.totalMonthlyDebtPayment,
    required this.activeDebtCount,
    required this.nextDebtTarget,
    this.projectedDebtFreeDate,
    required this.todayActions,
  });

  // Legacy fallback getter for backward compatibility
  double get safeToSpend => safeToSpendNow;
  DateTime? get nextIncomeDate => nextConfirmedIncomeDate ?? nextExpectedIncomeDate;
  double get nextIncomeAmount => nextConfirmedIncomeDate != null ? nextConfirmedIncomeAmount : nextExpectedIncomeAmount;
}
