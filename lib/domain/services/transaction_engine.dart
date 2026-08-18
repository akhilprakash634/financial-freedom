import '../../data/database/app_database.dart';

class TransactionEngine {
  /// Computes total actual cash from accounts and actual ledger transactions.
  /// Actual cash = Sum of Account Opening Balances
  ///               + Sum(Actual Income)
  ///               - Sum(Actual Expense)
  ///               - Sum(Actual Debt Payment)
  ///               +/- Transfers & Adjustments
  static double calculateActualCash({
    required List<Account> accounts,
    required List<LedgerTransaction> transactions,
  }) {
    double totalBalance = 0.0;

    // Add opening balances of active accounts
    for (final account in accounts) {
      if (account.active) {
        totalBalance += account.openingBalance;
      }
    }

    // Process actual recorded ledger transactions
    for (final tx in transactions) {
      if (!tx.isActual) continue;

      switch (tx.type) {
        case 'income':
          totalBalance += tx.amount;
          break;
        case 'expense':
        case 'debt_payment':
          totalBalance -= tx.amount;
          break;
        case 'adjustment':
          totalBalance += tx.amount; // Can be positive or negative
          break;
        case 'transfer':
          // Internal transfers between active accounts do not alter total cash
          break;
      }
    }

    return totalBalance;
  }
}
