import '../../data/database/app_database.dart';
import '../../core/utils/date_utils.dart';
import 'debt_engine.dart';

class CashFlowTimelineEvent {
  final DateTime date;
  final String title;
  final double amount; // positive for income, negative for mandatory payment/expense
  final String type; // income, mandatory_debt, essential_expense
  final String confidenceStatus; // confirmed, expected, upcoming
  final double projectedBalanceAfter;

  const CashFlowTimelineEvent({
    required this.date,
    required this.title,
    required this.amount,
    required this.type,
    required this.confidenceStatus,
    required this.projectedBalanceAfter,
  });
}

class CashFlowForecastResult {
  final List<CashFlowTimelineEvent> timeline;
  final double lowestProjectedBalance;
  final DateTime? lowestProjectedBalanceDate;
  final DateTime? nextIncomeDate;
  final double nextIncomeAmount;
  final DateTime? nextMandatoryPaymentDate;
  final double nextMandatoryPaymentAmount;
  final double projectedBalanceBeforeNextIncome;

  const CashFlowForecastResult({
    required this.timeline,
    required this.lowestProjectedBalance,
    this.lowestProjectedBalanceDate,
    this.nextIncomeDate,
    this.nextIncomeAmount = 0.0,
    this.nextMandatoryPaymentDate,
    this.nextMandatoryPaymentAmount = 0.0,
    required this.projectedBalanceBeforeNextIncome,
  });
}

class CashFlowEngine {
  /// Builds a detailed timeline forecast starting from current actual cash over a forecast window (default 90 days).
  static CashFlowForecastResult forecastCashFlow({
    required double startingActualCash,
    required DateTime currentDate,
    required List<IncomeSource> incomeSources,
    required List<Debt> activeDebts,
    required List<RecurringRule> recurringRules,
    int forecastDays = 90,
  }) {
    final endDate = currentDate.add(Duration(days: forecastDays));
    final rawEvents = <({DateTime date, String title, double amount, String type, String status})>[];

    // 1. Income occurrences
    for (final inc in incomeSources) {
      if (inc.status == 'cancelled' || inc.status == 'received') continue;

      if (inc.frequency == 'monthly') {
        final occurrences = AppDateUtils.generateMonthlyOccurrences(
          targetDay: inc.recurrenceDay,
          startDate: currentDate,
          endDate: endDate,
        );
        for (final occ in occurrences) {
          rawEvents.add((
            date: occ,
            title: inc.sourceName,
            amount: inc.amount,
            type: 'income',
            status: inc.status,
          ));
        }
      } else {
        // One-time or specific date income
        if (!inc.expectedDate.isBefore(AppDateUtils.dateOnly(currentDate)) &&
            !inc.expectedDate.isAfter(endDate)) {
          rawEvents.add((
            date: inc.expectedDate,
            title: inc.sourceName,
            amount: inc.amount,
            type: 'income',
            status: inc.status,
          ));
        }
      }
    }

    // 2. Active Debt EMI occurrences (Strictly capped by remaining payments count!)
    for (final debt in activeDebts) {
      if (debt.status != 'active' || debt.currentBalance <= 0 || debt.emiAmount <= 0) continue;

      final remainingPayments = DebtEngine.calculateRemainingPayments(debt);
      if (remainingPayments <= 0) continue;

      final occurrences = AppDateUtils.generateMonthlyOccurrences(
        targetDay: debt.dueDay,
        startDate: currentDate,
        endDate: endDate,
      );

      // Only take max remainingPayments occurrences so closing debts stop recurring!
      final cappedOccurrences = occurrences.take(remainingPayments);

      for (final occ in cappedOccurrences) {
        rawEvents.add((
          date: occ,
          title: '${debt.name} EMI',
          amount: -debt.emiAmount,
          type: 'mandatory_debt',
          status: 'upcoming',
        ));
      }
    }

    // 3. Recurring expenses
    for (final rule in recurringRules) {
      if (!rule.active || rule.type != 'expense') continue;

      if (rule.frequency == 'monthly') {
        final occurrences = AppDateUtils.generateMonthlyOccurrences(
          targetDay: rule.dayOfMonth,
          startDate: currentDate,
          endDate: endDate,
        );
        for (final occ in occurrences) {
          rawEvents.add((
            date: occ,
            title: rule.title,
            amount: -rule.amount,
            type: 'essential_expense',
            status: 'upcoming',
          ));
        }
      }
    }

    // Sort events chronologically
    rawEvents.sort((a, b) => a.date.compareTo(b.date));

    // Calculate running projected balance
    double runningBalance = startingActualCash;
    double lowestBalance = startingActualCash;
    DateTime? lowestBalanceDate = currentDate;

    DateTime? nextIncomeDate;
    double nextIncomeAmount = 0.0;

    DateTime? nextMandatoryDate;
    double nextMandatoryAmount = 0.0;

    double balanceBeforeNextIncome = startingActualCash;
    bool foundFirstIncome = false;

    final timeline = <CashFlowTimelineEvent>[];

    for (final item in rawEvents) {
      runningBalance += item.amount;

      if (runningBalance < lowestBalance) {
        lowestBalance = runningBalance;
        lowestBalanceDate = item.date;
      }

      if (item.amount > 0 && !foundFirstIncome) {
        nextIncomeDate = item.date;
        nextIncomeAmount = item.amount;
        foundFirstIncome = true;
      } else if (!foundFirstIncome) {
        balanceBeforeNextIncome = runningBalance;
      }

      if (item.amount < 0 && nextMandatoryDate == null) {
        nextMandatoryDate = item.date;
        nextMandatoryAmount = item.amount.abs();
      }

      timeline.add(CashFlowTimelineEvent(
        date: item.date,
        title: item.title,
        amount: item.amount,
        type: item.type,
        confidenceStatus: item.status,
        projectedBalanceAfter: runningBalance,
      ));
    }

    return CashFlowForecastResult(
      timeline: timeline,
      lowestProjectedBalance: lowestBalance,
      lowestProjectedBalanceDate: lowestBalanceDate,
      nextIncomeDate: nextIncomeDate,
      nextIncomeAmount: nextIncomeAmount,
      nextMandatoryPaymentDate: nextMandatoryDate,
      nextMandatoryPaymentAmount: nextMandatoryAmount,
      projectedBalanceBeforeNextIncome: balanceBeforeNextIncome,
    );
  }
}
