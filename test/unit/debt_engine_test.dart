import 'package:flutter_test/flutter_test.dart';
import 'package:financial_freedom/data/database/app_database.dart';
import 'package:financial_freedom/domain/services/debt_engine.dart';
import 'package:financial_freedom/core/constants/enums.dart';

void main() {
  group('DebtEngine - Snowball vs Avalanche & Payoff Scenarios', () {
    final debt1 = Debt(
      id: 1,
      name: 'Credit Card',
      lenderBorrower: 'Bank A',
      debtType: 'credit_card',
      originalAmount: 50000,
      currentBalance: 30000,
      interestRate: 36.0, // High interest rate
      interestType: 'simple',
      emiAmount: 3000,
      paymentFrequency: 'monthly',
      dueDay: 10,
      startDate: DateTime(2026, 1, 1),
      endDate: null,
      tenureMonths: 12,
      priority: 1,
      status: 'active',
      notes: null,
      creditLimit: 100000,
      currentMonthDue: 15000,
      minimumDue: 1500,
      billingDay: 15,
      createdAt: DateTime.now(),
    );

    final debt2 = Debt(
      id: 2,
      name: 'Personal Loan',
      lenderBorrower: 'Bank B',
      debtType: 'emi_loan',
      originalAmount: 200000,
      currentBalance: 150000,
      interestRate: 14.0, // Lower interest rate, higher balance
      interestType: 'simple',
      emiAmount: 8500,
      paymentFrequency: 'monthly',
      dueDay: 5,
      startDate: DateTime(2026, 1, 1),
      endDate: null,
      tenureMonths: 24,
      priority: 2,
      status: 'active',
      notes: null,
      creditLimit: 0,
      currentMonthDue: 0,
      minimumDue: 0,
      billingDay: 1,
      createdAt: DateTime.now(),
    );

    final debt3 = Debt(
      id: 3,
      name: 'Friend Loan',
      lenderBorrower: 'Alex',
      debtType: 'personal_debt',
      originalAmount: 10000,
      currentBalance: 5000, // Smallest balance, 0 interest
      interestRate: 0.0,
      interestType: 'simple',
      emiAmount: 1000,
      paymentFrequency: 'monthly',
      dueDay: 15,
      startDate: DateTime(2026, 1, 1),
      endDate: null,
      tenureMonths: 5,
      priority: 3,
      status: 'active',
      notes: null,
      creditLimit: 0,
      currentMonthDue: 0,
      minimumDue: 0,
      billingDay: 1,
      createdAt: DateTime.now(),
    );

    final allDebts = [debt1, debt2, debt3];

    test('Avalanche strategy sorts by highest interest rate first', () {
      final sorted = DebtEngine.sortDebts(allDebts, DebtStrategy.avalanche);
      expect(sorted[0].id, 1); // 36% interest first
      expect(sorted[1].id, 2); // 14% interest second
      expect(sorted[2].id, 3); // 0% interest last
    });

    test('Snowball strategy sorts by lowest balance first', () {
      final sorted = DebtEngine.sortDebts(allDebts, DebtStrategy.snowball);
      expect(sorted[0].id, 3); // 5000 balance first
      expect(sorted[1].id, 1); // 30000 balance second
      expect(sorted[2].id, 2); // 150000 balance last
    });

    test('Payoff plan accelerates debt-free date with extra payment', () {
      final basePlan = DebtEngine.calculatePayoffPlan(
        debts: allDebts,
        strategy: DebtStrategy.avalanche,
        currentDate: DateTime(2026, 8, 17),
        extraMonthlyPayment: 0.0,
      );

      final acceleratedPlan = DebtEngine.calculatePayoffPlan(
        debts: allDebts,
        strategy: DebtStrategy.avalanche,
        currentDate: DateTime(2026, 8, 17),
        extraMonthlyPayment: 10000.0,
      );

      expect(acceleratedPlan.totalMonthsToPayoff < basePlan.totalMonthsToPayoff, isTrue);
      expect(acceleratedPlan.projectedDebtFreeDate.isBefore(basePlan.projectedDebtFreeDate), isTrue);
    });
  });
}
