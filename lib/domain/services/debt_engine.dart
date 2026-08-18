import '../../data/database/app_database.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/date_utils.dart';

class DebtPayoffPlan {
  final List<Debt> sortedDebts;
  final DebtStrategy strategy;
  final DateTime projectedDebtFreeDate;
  final int totalMonthsToPayoff;

  const DebtPayoffPlan({
    required this.sortedDebts,
    required this.strategy,
    required this.projectedDebtFreeDate,
    required this.totalMonthsToPayoff,
  });
}

class DebtEngine {
  /// Returns active debts sorted by strategy:
  /// - Snowball: lowest current balance first
  /// - Avalanche: highest interest rate first
  static List<Debt> sortDebts(List<Debt> debts, DebtStrategy strategy) {
    final activeDebts = debts.where((d) => d.status == 'active' && d.currentBalance > 0).toList();
    
    if (strategy == DebtStrategy.snowball) {
      activeDebts.sort((a, b) => a.currentBalance.compareTo(b.currentBalance));
    } else {
      activeDebts.sort((a, b) => b.interestRate.compareTo(a.interestRate));
    }
    
    return activeDebts;
  }

  /// Calculates remaining payments for a single debt based on balance and EMI.
  static int calculateRemainingPayments(Debt debt) {
    if (debt.currentBalance <= 0 || debt.emiAmount <= 0) return 0;
    
    final monthlyInterestRate = (debt.interestRate / 100) / 12;
    if (monthlyInterestRate <= 0) {
      return (debt.currentBalance / debt.emiAmount).ceil();
    }

    final rP = monthlyInterestRate * debt.currentBalance;
    if (rP >= debt.emiAmount) {
      return 360;
    }

    final exactMonths = (debt.currentBalance / debt.emiAmount).ceil();
    return exactMonths;
  }

  /// Calculates the projected payoff date for a debt.
  static DateTime calculateDebtFinishDate(Debt debt, DateTime currentDate) {
    final monthsRemaining = calculateRemainingPayments(debt);
    if (monthsRemaining <= 0) return currentDate;
    return AppDateUtils.getValidDateForMonth(
      currentDate.year + ((currentDate.month + monthsRemaining - 1) ~/ 12),
      ((currentDate.month + monthsRemaining - 1) % 12) + 1,
      debt.dueDay,
    );
  }

  /// Calculates overall debt payoff plan including extra monthly payment acceleration.
  static DebtPayoffPlan calculatePayoffPlan({
    required List<Debt> debts,
    required DebtStrategy strategy,
    required DateTime currentDate,
    double extraMonthlyPayment = 0.0,
  }) {
    final sorted = sortDebts(debts, strategy);
    if (sorted.isEmpty) {
      return DebtPayoffPlan(
        sortedDebts: [],
        strategy: strategy,
        projectedDebtFreeDate: currentDate,
        totalMonthsToPayoff: 0,
      );
    }

    double totalBalance = sorted.fold(0.0, (sum, d) => sum + d.currentBalance);
    double totalEmi = sorted.fold(0.0, (sum, d) => sum + d.emiAmount) + extraMonthlyPayment;

    if (totalEmi <= 0) {
      return DebtPayoffPlan(
        sortedDebts: sorted,
        strategy: strategy,
        projectedDebtFreeDate: currentDate.add(const Duration(days: 3650)),
        totalMonthsToPayoff: 120,
      );
    }

    int maxMonths = (totalBalance / totalEmi).ceil();
    if (maxMonths < 1) maxMonths = 1;

    final finishDate = AppDateUtils.getValidDateForMonth(
      currentDate.year + ((currentDate.month + maxMonths - 1) ~/ 12),
      ((currentDate.month + maxMonths - 1) % 12) + 1,
      currentDate.day,
    );

    return DebtPayoffPlan(
      sortedDebts: sorted,
      strategy: strategy,
      projectedDebtFreeDate: finishDate,
      totalMonthsToPayoff: maxMonths,
    );
  }
}
