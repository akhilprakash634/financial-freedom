import '../../data/database/app_database.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/date_utils.dart';
import '../models/financial_snapshot.dart';
import 'transaction_engine.dart';
import 'debt_engine.dart';
import 'cash_flow_engine.dart';
import 'income_sync_engine.dart';

class FinancialEngine {
  /// Computes the complete FinancialSnapshot based on current system state and date.
  static FinancialSnapshot computeSnapshot({
    required List<Account> accounts,
    required List<LedgerTransaction> transactions,
    required List<IncomeSource> incomeSources,
    required List<IncomeOccurrence> incomeOccurrences,
    required List<Debt> debts,
    required List<RecurringRule> recurringRules,
    required List<ExpenseRecord> expenses,
    required FinancialSetting settings,
    required DateTime currentDate,
  }) {
    final today = AppDateUtils.dateOnly(currentDate);

    // 1. Actual Cash strictly from ledger transactions + opening balances
    final actualCash = TransactionEngine.calculateActualCash(
      accounts: accounts,
      transactions: transactions,
    );

    // 2. Receivables & Salary Arrears
    final moneyOwedToMe = IncomeSyncEngine.calculateMoneyOwedToMe(incomeOccurrences);
    final salaryArrears = IncomeSyncEngine.calculateSalaryArrears(incomeOccurrences);
    
    final unpaidSalaryOccurrences = incomeOccurrences.where((occ) =>
        occ.status != 'received' &&
        occ.status != 'cancelled' &&
        occ.title.toLowerCase().contains('salary')).toList();
    final salaryArrearsMonths = unpaidSalaryOccurrences.length;

    // 3. Next 30 days income breakdowns by confidence & status
    final horizonEnd = today.add(const Duration(days: 30));
    double confirmedIncome = 0.0;
    double expectedIncome = 0.0;
    double potentialIncome = 0.0;

    DateTime? nextConfirmedDate;
    double nextConfirmedAmount = 0.0;
    DateTime? nextExpectedDate;
    double nextExpectedAmount = 0.0;

    for (final occ in incomeOccurrences) {
      if (occ.status == 'cancelled' || occ.status == 'received') continue;

      final expDate = AppDateUtils.dateOnly(occ.expectedDate);

      // Identify next confirmed vs next expected
      if (!expDate.isBefore(today)) {
        if (occ.status == 'confirmed' || occ.confidence == 'high') {
          if (nextConfirmedDate == null || expDate.isBefore(nextConfirmedDate)) {
            nextConfirmedDate = expDate;
            nextConfirmedAmount = occ.amount - occ.receivedAmount;
          }
        } else if (occ.status == 'expected' && occ.confidence == 'medium') {
          if (nextExpectedDate == null || expDate.isBefore(nextExpectedDate)) {
            nextExpectedDate = expDate;
            nextExpectedAmount = occ.amount - occ.receivedAmount;
          }
        }
      }

      // Sums for 30-day horizon (low confidence excluded from safe spend)
      if (!expDate.isBefore(today) && !expDate.isAfter(horizonEnd)) {
        final netAmount = occ.amount - occ.receivedAmount;
        if (occ.confidence == 'low') {
          potentialIncome += netAmount;
        } else if (occ.status == 'confirmed' || occ.confidence == 'high') {
          confirmedIncome += netAmount;
        } else if (occ.status == 'expected' || occ.status == 'due' || occ.status == 'delayed') {
          expectedIncome += netAmount;
        }
      }
    }

    // 4. Mandatory Debt Payments & Compulsory Minimum Due
    final activeDebts = debts.where((d) => d.status == 'active' && d.currentBalance > 0).toList();
    double totalMonthlyDebtPayment = 0.0;
    double minimumRequiredDebtPayment = 0.0;

    for (final debt in activeDebts) {
      if (debt.debtType == 'credit_card') {
        final stmtDue = debt.currentMonthDue > 0 ? debt.currentMonthDue : debt.minimumDue;
        final minDue = debt.minimumDue > 0 ? debt.minimumDue : stmtDue;
        totalMonthlyDebtPayment += stmtDue;
        minimumRequiredDebtPayment += minDue;
      } else {
        if (debt.emiAmount > 0) {
          totalMonthlyDebtPayment += debt.emiAmount;
          minimumRequiredDebtPayment += debt.emiAmount;
        }
      }
    }

    // Mandatory payments due BEFORE the next confirmed income
    final nextConfirmedCutoff = nextConfirmedDate ?? today.add(const Duration(days: 30));
    double mandatoryBeforeNextConfirmed = 0.0;
    for (final debt in activeDebts) {
      final paymentAmount = debt.debtType == 'credit_card'
          ? (debt.currentMonthDue > 0 ? debt.currentMonthDue : debt.minimumDue)
          : debt.emiAmount;

      if (paymentAmount > 0) {
        final dueDay = AppDateUtils.clampDayOfMonth(today.year, today.month, debt.dueDay);
        var dueDate = DateTime(today.year, today.month, dueDay);
        if (dueDate.isBefore(today)) {
          final nextM = today.month == 12 ? 1 : today.month + 1;
          final nextY = today.month == 12 ? today.year + 1 : today.year;
          dueDate = DateTime(nextY, nextM, AppDateUtils.clampDayOfMonth(nextY, nextM, debt.dueDay));
        }

        if (!dueDate.isAfter(nextConfirmedCutoff)) {
          mandatoryBeforeNextConfirmed += paymentAmount;
        }
      }
    }

    // 5. Planned Essential Expenses
    double plannedExpenses = 0.0;
    for (final rule in recurringRules) {
      if (rule.active && rule.type == 'expense') {
        plannedExpenses += rule.amount;
      }
    }

    final buffer = settings.minimumCashBuffer;

    // 6. Safe To Spend Now vs Monthly Disposable Amount
    final safeToSpendNow = actualCash - mandatoryBeforeNextConfirmed - plannedExpenses - buffer;
    final monthlyDisposableAmount = actualCash + confirmedIncome - totalMonthlyDebtPayment - plannedExpenses - buffer;

    // 7. Cash Flow Warning check
    final hasCashFlowWarning = actualCash < (mandatoryBeforeNextConfirmed + plannedExpenses);

    // 8. Cash Flow timeline forecast
    final cashFlowResult = CashFlowEngine.forecastCashFlow(
      startingActualCash: actualCash,
      currentDate: currentDate,
      incomeSources: incomeSources,
      activeDebts: activeDebts,
      recurringRules: recurringRules,
    );

    // 9. Debt Engine plan
    final strategy = settings.defaultDebtStrategy == 'snowball'
        ? DebtStrategy.snowball
        : DebtStrategy.avalanche;

    final debtPlan = DebtEngine.calculatePayoffPlan(
      debts: activeDebts,
      strategy: strategy,
      currentDate: currentDate,
    );

    final totalDebt = activeDebts.fold(0.0, (sum, d) => sum + d.currentBalance);
    final nextTarget = debtPlan.sortedDebts.isNotEmpty ? debtPlan.sortedDebts.first.name : 'None (Debt Free!)';

    // 10. Financial Reality Indicators (🟢 / 🟡 / 🔴)
    final realityMap = <String, String>{};
    
    // Cash Flow Status
    if (hasCashFlowWarning || actualCash < 0) {
      realityMap['Cash Flow'] = '🔴';
    } else if (safeToSpendNow < 0) {
      realityMap['Cash Flow'] = '🟡';
    } else {
      realityMap['Cash Flow'] = '🟢';
    }

    // Debt Burden
    if (totalMonthlyDebtPayment > actualCash + confirmedIncome) {
      realityMap['Debt Burden'] = '🔴';
    } else if (totalMonthlyDebtPayment > 0.4 * (actualCash + confirmedIncome + 1.0)) {
      realityMap['Debt Burden'] = '🟡';
    } else {
      realityMap['Debt Burden'] = '🟢';
    }

    // Income Reliability
    if (salaryArrearsMonths >= 2) {
      realityMap['Income Reliability'] = '🔴';
    } else if (salaryArrearsMonths == 1) {
      realityMap['Income Reliability'] = '🟡';
    } else {
      realityMap['Income Reliability'] = '🟢';
    }

    // Safety Buffer
    if (actualCash < 0.5 * buffer) {
      realityMap['Safety Buffer'] = '🔴';
    } else if (actualCash < buffer) {
      realityMap['Safety Buffer'] = '🟡';
    } else {
      realityMap['Safety Buffer'] = '🟢';
    }

    // 11. Actions for today
    final todayActions = <String>[];
    if (hasCashFlowWarning) {
      todayActions.add('⚠️ Cash Flow Warning: Available cash (${settings.primaryCurrency}${actualCash.toStringAsFixed(0)}) is lower than upcoming mandatory obligations.');
    }
    for (final debt in activeDebts) {
      if (debt.dueDay == currentDate.day) {
        final amountDue = debt.debtType == 'credit_card' ? (debt.currentMonthDue > 0 ? debt.currentMonthDue : debt.minimumDue) : debt.emiAmount;
        todayActions.add('Pay ${debt.name} — ${settings.primaryCurrency}${amountDue.toStringAsFixed(0)} due today');
      }
    }
    for (final occ in incomeOccurrences) {
      final isDueToday = AppDateUtils.isSameDay(occ.expectedDate, currentDate) || occ.status == 'due';
      final isPending = occ.status != 'received' && occ.status != 'cancelled' && occ.status != 'delayed' && occ.status != 'overdue';

      if (isDueToday && isPending && (occ.amount - occ.receivedAmount) > 0) {
        todayActions.add('Expected Income: ${occ.title} — ${settings.primaryCurrency}${(occ.amount - occ.receivedAmount).toStringAsFixed(0)} expected today');
      }
    }
    if (todayActions.isEmpty) {
      todayActions.add('All clear for today! Cash and obligations are on track.');
    }

    return FinancialSnapshot(
      actualCash: actualCash,
      moneyOwedToMe: moneyOwedToMe,
      salaryArrears: salaryArrears,
      salaryArrearsMonths: salaryArrearsMonths,
      confirmedFutureIncome: confirmedIncome,
      expectedFutureIncome: expectedIncome,
      potentialIncome: potentialIncome,
      nextConfirmedIncomeDate: nextConfirmedDate,
      nextConfirmedIncomeAmount: nextConfirmedAmount,
      nextExpectedIncomeDate: nextExpectedDate,
      nextExpectedIncomeAmount: nextExpectedAmount,
      upcomingMandatoryPayments: totalMonthlyDebtPayment,
      mandatoryPaymentsBeforeNextConfirmedIncome: mandatoryBeforeNextConfirmed,
      plannedEssentialExpenses: plannedExpenses,
      minimumCashBuffer: buffer,
      safeToSpendNow: safeToSpendNow,
      monthlyDisposableAmount: monthlyDisposableAmount,
      projectedBalanceBeforeNextIncome: cashFlowResult.projectedBalanceBeforeNextIncome,
      lowestProjectedBalance: cashFlowResult.lowestProjectedBalance,
      lowestProjectedBalanceDate: cashFlowResult.lowestProjectedBalanceDate,
      hasCashFlowWarning: hasCashFlowWarning,
      financialRealityIndicators: realityMap,
      totalDebt: totalDebt,
      totalMonthlyDebtPayment: totalMonthlyDebtPayment,
      minimumRequiredDebtPayment: minimumRequiredDebtPayment,
      activeDebtCount: activeDebts.length,
      nextDebtTarget: nextTarget,
      projectedDebtFreeDate: debtPlan.projectedDebtFreeDate,
      todayActions: todayActions,
    );
  }
}
