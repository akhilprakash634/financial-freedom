import 'package:drift/drift.dart';

@DataClassName('Account')
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()(); // bank, cash, savings, other
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  TextColumn get currency => text().withDefault(const Constant('₹'))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('LedgerTransaction')
class LedgerTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get targetAccountId => integer().nullable().references(Accounts, #id)();
  TextColumn get type => text()(); // income, expense, debt_payment, transfer, adjustment
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get isActual => boolean().withDefault(const Constant(true))();
  IntColumn get recurringRuleId => integer().nullable().references(RecurringRules, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('IncomeSource')
class IncomeSources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceName => text()();
  RealColumn get amount => real()();
  DateTimeColumn get expectedDate => dateTime()();
  TextColumn get frequency => text().withDefault(const Constant('monthly'))();
  IntColumn get recurrenceDay => integer().withDefault(const Constant(1))();
  TextColumn get status => text().withDefault(const Constant('expected'))(); // expected, confirmed, received, cancelled, overdue
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  TextColumn get defaultConfidence => text().withDefault(const Constant('high'))(); // high, medium, low
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('IncomeOccurrence')
class IncomeOccurrences extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get incomeSourceId => integer().nullable().references(IncomeSources, #id)();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  RealColumn get receivedAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get expectedDate => dateTime()();
  DateTimeColumn get receivedDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('expected'))(); // expected, confirmed, due, overdue, delayed, received, cancelled
  TextColumn get confidence => text().withDefault(const Constant('high'))(); // high, medium, low
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('RecurringRule')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // income, expense, debt_payment, bill
  TextColumn get frequency => text().withDefault(const Constant('monthly'))();
  IntColumn get interval => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get dayOfMonth => integer().withDefault(const Constant(1))();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Debt')
class Debts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get lenderBorrower => text()();
  TextColumn get debtType => text()(); // emi_loan, personal_debt, credit_card, bnpl, family_friend, other
  RealColumn get originalAmount => real()();
  RealColumn get currentBalance => real()();
  RealColumn get interestRate => real().withDefault(const Constant(0.0))(); // annual percentage
  TextColumn get interestType => text().withDefault(const Constant('simple'))(); // simple, reducing, compound
  RealColumn get emiAmount => real()();
  TextColumn get paymentFrequency => text().withDefault(const Constant('monthly'))();
  IntColumn get dueDay => integer().withDefault(const Constant(1))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  IntColumn get tenureMonths => integer().withDefault(const Constant(12))();
  IntColumn get priority => integer().withDefault(const Constant(1))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, settled
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('DebtPaymentRecord')
class DebtPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get debtId => integer().references(Debts, #id)();
  IntColumn get transactionId => integer().nullable().references(LedgerTransactions, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get paymentDate => dateTime()();
  TextColumn get paymentType => text().withDefault(const Constant('normal_emi'))(); // normal_emi, minimum, extra, partial_settlement, full_settlement
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ExpenseRecord')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  IntColumn get categoryId => integer().nullable().references(Categories, #id)();
  IntColumn get accountId => integer().nullable().references(Accounts, #id)();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get isPlanned => boolean().withDefault(const Constant(false))();
  BoolColumn get isActual => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Category')
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text().withDefault(const Constant('expense'))(); // income, expense, both
  TextColumn get icon => text().withDefault(const Constant('category'))();
  TextColumn get color => text().withDefault(const Constant('#10B981'))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('FinancialSetting')
class FinancialSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get primaryCurrency => text().withDefault(const Constant('₹'))();
  RealColumn get minimumCashBuffer => real().withDefault(const Constant(10000.0))();
  TextColumn get defaultDebtStrategy => text().withDefault(const Constant('avalanche'))(); // snowball, avalanche
  BoolColumn get pinLockEnabled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
