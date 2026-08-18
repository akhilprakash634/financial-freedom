import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:financial_freedom/data/database/app_database.dart';
import 'package:financial_freedom/domain/services/income_sync_engine.dart';
import 'package:financial_freedom/domain/services/financial_engine.dart';
import 'package:financial_freedom/domain/services/transaction_engine.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Salary Arrears Accumulation: June, July, August unpaid = 75k arrears, cash unchanged', () async {
    final accId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Bank', type: 'bank', openingBalance: const drift.Value(20000.0)),
    );

    await db.into(db.incomeSources).insert(
      IncomeSourcesCompanion.insert(
        sourceName: 'Monthly Salary',
        amount: 25000.0,
        expectedDate: DateTime(2026, 6, 30),
        frequency: const drift.Value('monthly'),
        recurrenceDay: const drift.Value(30),
        status: const drift.Value('expected'),
        accountId: drift.Value(accId),
      ),
    );

    final currentDate = DateTime(2026, 8, 15);
    final sources = await db.select(db.incomeSources).get();

    await IncomeSyncEngine.syncIncomeOccurrences(
      db: db,
      incomeSources: sources,
      existingOccurrences: [],
      currentDate: currentDate,
    );

    final occurrences = await db.select(db.incomeOccurrences).get();
    expect(occurrences.length, equals(3)); // June, July, August

    final salaryArrears = IncomeSyncEngine.calculateSalaryArrears(occurrences);
    expect(salaryArrears, equals(75000.0));

    final accounts = await db.select(db.accounts).get();
    final txs = await db.select(db.ledgerTransactions).get();
    final actualCash = TransactionEngine.calculateActualCash(accounts: accounts, transactions: txs);
    expect(actualCash, equals(20000.0));
  });

  test('Salary Settlement: Settling 25k marks oldest (June) received and increases actual cash', () async {
    final accId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Bank', type: 'bank', openingBalance: const drift.Value(20000.0)),
    );

    await db.into(db.incomeSources).insert(
      IncomeSourcesCompanion.insert(
        sourceName: 'Monthly Salary',
        amount: 25000.0,
        expectedDate: DateTime(2026, 6, 30),
        frequency: const drift.Value('monthly'),
        recurrenceDay: const drift.Value(30),
      ),
    );

    await IncomeSyncEngine.syncIncomeOccurrences(
      db: db,
      incomeSources: await db.select(db.incomeSources).get(),
      existingOccurrences: [],
      currentDate: DateTime(2026, 8, 15),
    );

    var occurrences = await db.select(db.incomeOccurrences).get();
    occurrences.sort((a, b) => a.expectedDate.compareTo(b.expectedDate));
    final oldest = occurrences.first; // June

    await IncomeSyncEngine.settleReceivable(
      db: db,
      occurrence: oldest,
      amountReceived: 25000.0,
      accountId: accId,
      receivedDate: DateTime(2026, 8, 16),
    );

    occurrences = await db.select(db.incomeOccurrences).get();
    final remainingArrears = IncomeSyncEngine.calculateSalaryArrears(occurrences);
    expect(remainingArrears, equals(50000.0));

    final accounts = await db.select(db.accounts).get();
    final txs = await db.select(db.ledgerTransactions).get();
    final actualCash = TransactionEngine.calculateActualCash(accounts: accounts, transactions: txs);
    expect(actualCash, equals(45000.0));
  });

  test('Partial Salary Payment: 15k payment leaves 10k remaining on June occurrence', () async {
    final accId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Bank', type: 'bank', openingBalance: const drift.Value(20000.0)),
    );

    await db.into(db.incomeOccurrences).insert(
      IncomeOccurrencesCompanion.insert(
        title: 'Monthly Salary',
        amount: 25000.0,
        expectedDate: DateTime(2026, 6, 30),
        status: const drift.Value('overdue'),
      ),
    );

    var occ = (await db.select(db.incomeOccurrences).get()).first;

    await IncomeSyncEngine.settleReceivable(
      db: db,
      occurrence: occ,
      amountReceived: 15000.0,
      accountId: accId,
      receivedDate: DateTime(2026, 8, 16),
    );

    occ = (await db.select(db.incomeOccurrences).get()).first;
    expect(occ.receivedAmount, equals(15000.0));
    expect(occ.amount - occ.receivedAmount, equals(10000.0));
    expect(occ.status, isNot(equals('received')));
  });

  test('Idempotent Sync: Running sync multiple times produces zero duplicates', () async {
    await db.into(db.incomeSources).insert(
      IncomeSourcesCompanion.insert(
        sourceName: 'Monthly Salary',
        amount: 25000.0,
        expectedDate: DateTime(2026, 6, 30),
        frequency: const drift.Value('monthly'),
        recurrenceDay: const drift.Value(30),
      ),
    );

    final sources = await db.select(db.incomeSources).get();

    for (int i = 0; i < 5; i++) {
      final existing = await db.select(db.incomeOccurrences).get();
      await IncomeSyncEngine.syncIncomeOccurrences(
        db: db,
        incomeSources: sources,
        existingOccurrences: existing,
        currentDate: DateTime(2026, 8, 15),
      );
    }

    final occurrences = await db.select(db.incomeOccurrences).get();
    expect(occurrences.length, equals(3));
  });

  test('Freelance Workflow: Expected freelance has zero effect on cash until received', () async {
    final accId = await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Bank', type: 'bank', openingBalance: const drift.Value(20000.0)),
    );

    await db.into(db.incomeOccurrences).insert(
      IncomeOccurrencesCompanion.insert(
        title: 'ABC Client Freelance',
        amount: 15000.0,
        expectedDate: DateTime(2026, 8, 25),
        status: const drift.Value('expected'),
        confidence: const drift.Value('medium'),
      ),
    );

    var accounts = await db.select(db.accounts).get();
    var txs = await db.select(db.ledgerTransactions).get();
    expect(TransactionEngine.calculateActualCash(accounts: accounts, transactions: txs), equals(20000.0));

    var occurrences = await db.select(db.incomeOccurrences).get();
    expect(IncomeSyncEngine.calculateMoneyOwedToMe(occurrences), equals(15000.0));

    await IncomeSyncEngine.settleReceivable(
      db: db,
      occurrence: occurrences.first,
      amountReceived: 15000.0,
      accountId: accId,
      receivedDate: DateTime(2026, 8, 25),
    );

    accounts = await db.select(db.accounts).get();
    txs = await db.select(db.ledgerTransactions).get();
    expect(TransactionEngine.calculateActualCash(accounts: accounts, transactions: txs), equals(35000.0));
  });

  test('Confidence Filter: Low confidence income is excluded from safe to spend', () async {
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(name: 'Bank', type: 'bank', openingBalance: const drift.Value(20000.0)),
    );

    await db.into(db.incomeOccurrences).insert(
      IncomeOccurrencesCompanion.insert(
        title: 'Uncertain Freelance',
        amount: 50000.0,
        expectedDate: DateTime(2026, 8, 25),
        status: const drift.Value('expected'),
        confidence: const drift.Value('low'),
      ),
    );

    await db.seedInitialData();
    final settings = (await db.select(db.financialSettings).get()).first;
    final occurrences = await db.select(db.incomeOccurrences).get();

    final snapshot = FinancialEngine.computeSnapshot(
      accounts: await db.select(db.accounts).get(),
      transactions: [],
      incomeSources: [],
      incomeOccurrences: occurrences,
      debts: [],
      recurringRules: [],
      expenses: [],
      settings: settings,
      currentDate: DateTime(2026, 8, 15),
    );

    expect(snapshot.potentialIncome, equals(50000.0));
    expect(snapshot.actualCash, equals(20000.0));
    expect(snapshot.safeToSpendNow, equals(10000.0));
  });
}
