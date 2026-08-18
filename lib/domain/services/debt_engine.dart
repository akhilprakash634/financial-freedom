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

  /// Calculates total tenure in months between startDate and endDate (or stored tenureMonths).
  static int calculateTotalTenureMonths(Debt debt) {
    if (debt.endDate != null) {
      final start = AppDateUtils.dateOnly(debt.startDate);
      final end = AppDateUtils.dateOnly(debt.endDate!);
      final totalMonths = (end.year - start.year) * 12 + (end.month - start.month) + 1;
      return totalMonths > 0 ? totalMonths : 1;
    }
    return debt.tenureMonths > 0 ? debt.tenureMonths : 1;
  }

  /// Calculates elapsed/paid EMI payments up to the target date.
  static int calculateElapsedPayments(Debt debt, [DateTime? currentDate]) {
    final now = currentDate ?? DateTime.now();
    final start = AppDateUtils.dateOnly(debt.startDate);
    if (now.isBefore(start)) return 0;

    final elapsedMonths = (now.year - start.year) * 12 + (now.month - start.month);
    final totalTenure = calculateTotalTenureMonths(debt);
    return elapsedMonths.clamp(0, totalTenure);
  }

  /// Calculates remaining payments for a single debt based on current date, endDate, balance and EMI.
  static int calculateRemainingPayments(Debt debt, [DateTime? currentDate]) {
    if (debt.status != 'active' || debt.currentBalance <= 0 || debt.emiAmount <= 0) return 0;
    
    final now = currentDate ?? DateTime.now();
    
    if (debt.endDate != null) {
      final end = AppDateUtils.dateOnly(debt.endDate!);
      final nowOnly = AppDateUtils.dateOnly(now);
      
      if (nowOnly.isAfter(end) || (nowOnly.year == end.year && nowOnly.month == end.month && nowOnly.day >= end.day)) {
        final isBeforeDueDay = nowOnly.year == end.year && nowOnly.month == end.month && nowOnly.day <= debt.dueDay;
        return isBeforeDueDay ? 1 : 0;
      }

      final monthsRemaining = (end.year - nowOnly.year) * 12 + (end.month - nowOnly.month) + (nowOnly.day <= debt.dueDay ? 1 : 0);
      return monthsRemaining.clamp(0, 360);
    }

    final exactMonths = (debt.currentBalance / debt.emiAmount).ceil();
    return exactMonths;
  }

  /// Calculates the projected payoff date for a debt based on endDate or remaining payments.
  static DateTime calculateDebtFinishDate(Debt debt, DateTime currentDate) {
    if (debt.endDate != null) {
      return debt.endDate!;
    }

    final monthsRemaining = calculateRemainingPayments(debt, currentDate);
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
    double baseEmi = sorted.fold(0.0, (sum, d) => sum + d.emiAmount);
    double totalEmi = baseEmi + extraMonthlyPayment;

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
