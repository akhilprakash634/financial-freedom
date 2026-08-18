import 'package:flutter_test/flutter_test.dart';
import 'package:financial_freedom/data/database/app_database.dart';
import 'package:financial_freedom/domain/services/transaction_engine.dart';
import 'package:financial_freedom/domain/services/financial_engine.dart';

void main() {
  group('TransactionEngine & FinancialEngine Calculations', () {
    final account = Account(
      id: 1,
      name: 'Bank',
      type: 'bank',
      openingBalance: 10000.0,
      currency: '₹',
      active: true,
      createdAt: DateTime.now(),
    );

    final txIncome = LedgerTransaction(
      id: 1,
      accountId: 1,
      targetAccountId: null,
      type: 'income',
      amount: 25000.0,
      categoryId: null,
      transactionDate: DateTime(2026, 8, 1),
      note: 'Salary',
      isActual: true,
      recurringRuleId: null,
      createdAt: DateTime.now(),
    );

    final txExpense = LedgerTransaction(
      id: 2,
      accountId: 1,
      targetAccountId: null,
      type: 'expense',
      amount: 5000.0,
      categoryId: null,
      transactionDate: DateTime(2026, 8, 5),
      note: 'Groceries',
      isActual: true,
      recurringRuleId: null,
      createdAt: DateTime.now(),
    );

    test('Actual Cash formula equals Opening + Income - Expenses', () {
      final actualCash = TransactionEngine.calculateActualCash(
        accounts: [account],
        transactions: [txIncome, txExpense],
      );

      // 10000 + 25000 - 5000 = 30000
      expect(actualCash, 30000.0);
    });

    test('Safe to Spend calculation equals Cash - Mandatory - Expenses - Buffer', () {
      final settings = FinancialSetting(
        id: 1,
        primaryCurrency: '₹',
        minimumCashBuffer: 10000.0,
        defaultDebtStrategy: 'avalanche',
        pinLockEnabled: false,
        createdAt: DateTime.now(),
      );

      final snapshot = FinancialEngine.computeSnapshot(
        accounts: [account],
        transactions: [txIncome, txExpense], // Cash = 30000
        incomeSources: [],
        incomeOccurrences: [],
        debts: [],
        recurringRules: [
          RecurringRule(
            id: 1,
            title: 'Electricity',
            amount: 2000.0,
            type: 'expense',
            frequency: 'monthly',
            interval: 1,
            startDate: DateTime(2026, 1, 1),
            endDate: null,
            dayOfMonth: 25,
            active: true,
            categoryId: null,
            accountId: null,
            createdAt: DateTime.now(),
          ),
        ],
        expenses: [],
        settings: settings,
        currentDate: DateTime(2026, 8, 17),
      );

      // Actual cash: 30000
      // Upcoming mandatory debts: 0
      // Planned essential expenses: 2000
      // Buffer: 10000
      // Safe to spend = 30000 - 0 - 2000 - 10000 = 18000
      expect(snapshot.actualCash, 30000.0);
      expect(snapshot.safeToSpendNow, 18000.0);
    });
  });
}
