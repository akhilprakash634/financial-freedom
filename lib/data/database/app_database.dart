import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Accounts,
  LedgerTransactions,
  IncomeSources,
  IncomeOccurrences,
  RecurringRules,
  Debts,
  DebtPayments,
  Expenses,
  Categories,
  FinancialSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(incomeOccurrences);
            await m.addColumn(incomeSources, incomeSources.defaultConfidence);
          }
          if (from < 3) {
            await m.addColumn(debts, debts.endDate);
          }
        },
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'financial_freedom.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // Pre-populate system categories & initial settings if empty
  Future<void> seedInitialData() async {
    final existingSettings = await select(financialSettings).get();
    if (existingSettings.isEmpty) {
      await into(financialSettings).insert(
        FinancialSettingsCompanion.insert(
          primaryCurrency: const Value('₹'),
          minimumCashBuffer: const Value(10000.0),
          defaultDebtStrategy: const Value('avalanche'),
        ),
      );
    }

    final existingCategories = await select(categories).get();
    if (existingCategories.isEmpty) {
      final defaultCats = [
        ('Food & Groceries', 'expense', 'restaurant', '#EF4444'),
        ('Transportation & Fuel', 'expense', 'directions_car', '#F59E0B'),
        ('Rent & Housing', 'expense', 'home', '#3B82F6'),
        ('Electricity & Utilities', 'expense', 'bolt', '#EAB308'),
        ('Internet & Phone', 'expense', 'wifi', '#06B6D4'),
        ('Salary', 'income', 'work', '#10B981'),
        ('Freelance', 'income', 'laptop', '#8B5CF6'),
        ('Medical & Healthcare', 'expense', 'local_hospital', '#EC4899'),
        ('Shopping & Lifestyle', 'expense', 'shopping_bag', '#6366F1'),
        ('EMI Loan Repayment', 'expense', 'account_balance', '#64748B'),
      ];

      for (final cat in defaultCats) {
        await into(categories).insert(
          CategoriesCompanion.insert(
            name: cat.$1,
            type: Value(cat.$2),
            icon: Value(cat.$3),
            color: Value(cat.$4),
            isSystem: const Value(true),
          ),
        );
      }
    }

    final existingAccounts = await select(accounts).get();
    if (existingAccounts.isEmpty) {
      await into(accounts).insert(
        AccountsCompanion.insert(
          name: 'Primary Bank',
          type: 'bank',
          openingBalance: const Value(0.0),
          currency: const Value('₹'),
        ),
      );
    }
  }
}
