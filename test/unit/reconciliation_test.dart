import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:financial_freedom/data/database/app_database.dart';
import 'package:financial_freedom/domain/services/income_sync_engine.dart';
import 'package:financial_freedom/domain/services/transaction_engine.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Negative Account Reconciliation: 18,500 to 18,200 creates -300 adjustment transaction', () async {
    final accId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Primary Bank', type: 'bank', openingBalance: const drift.Value(18500.0)),
    );

    var accounts = await db.select(db.accounts).get();
    var txs = await db.select(db.ledgerTransactions).get();
    var cash = TransactionEngine.calculateActualCash(accounts: accounts, transactions: txs);
    expect(cash, equals(18500.0));

    // Reconcile to 18,200
    await IncomeSyncEngine.reconcileAccountBalance(
      db: db,
      accountId: accId,
      actualBankBalance: 18200.0,
      currentCalculatedBalance: 18500.0,
      transactionDate: DateTime.now(),
    );

    accounts = await db.select(db.accounts).get();
    txs = await db.select(db.ledgerTransactions).get();
    expect(txs.length, equals(1));
    expect(txs.first.type, equals('adjustment'));
    expect(txs.first.amount, equals(-300.0));

    cash = TransactionEngine.calculateActualCash(accounts: accounts, transactions: txs);
    expect(cash, equals(18200.0));
  });

  test('Positive Account Reconciliation: 18,500 to 19,000 creates +500 adjustment transaction', () async {
    final accId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Primary Bank', type: 'bank', openingBalance: const drift.Value(18500.0)),
    );

    await IncomeSyncEngine.reconcileAccountBalance(
      db: db,
      accountId: accId,
      actualBankBalance: 19000.0,
      currentCalculatedBalance: 18500.0,
      transactionDate: DateTime.now(),
    );

    final txs = await db.select(db.ledgerTransactions).get();
    expect(txs.first.type, equals('adjustment'));
    expect(txs.first.amount, equals(500.0));

    final accounts = await db.select(db.accounts).get();
    final cash = TransactionEngine.calculateActualCash(accounts: accounts, transactions: txs);
    expect(cash, equals(19000.0));
  });

  test('Zero Account Reconciliation: 18,500 to 18,500 creates NO adjustment transaction', () async {
    final accId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Primary Bank', type: 'bank', openingBalance: const drift.Value(18500.0)),
    );

    await IncomeSyncEngine.reconcileAccountBalance(
      db: db,
      accountId: accId,
      actualBankBalance: 18500.0,
      currentCalculatedBalance: 18500.0,
      transactionDate: DateTime.now(),
    );

    final txs = await db.select(db.ledgerTransactions).get();
    expect(txs.isEmpty, isTrue);
  });

  test('Internal Transfers: Transfer 10,000 from Bank (20k) to Savings (5k) leaves total cash at 25,000', () async {
    final bankId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Bank', type: 'bank', openingBalance: const drift.Value(20000.0)),
    );
    final savingsId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Savings', type: 'savings', openingBalance: const drift.Value(5000.0)),
    );

    // Record transfer
    await db.into(db.ledgerTransactions).insert(
      LedgerTransactionsCompanion.insert(
        accountId: bankId,
        targetAccountId: drift.Value(savingsId),
        type: 'transfer',
        amount: 10000.0,
        transactionDate: DateTime.now(),
        isActual: const drift.Value(true),
      ),
    );

    final accounts = await db.select(db.accounts).get();
    final txs = await db.select(db.ledgerTransactions).get();
    final totalCash = TransactionEngine.calculateActualCash(accounts: accounts, transactions: txs);

    expect(totalCash, equals(25000.0));
  });
}
