import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../domain/models/financial_snapshot.dart';
import '../../domain/services/financial_engine.dart';
import '../../domain/services/income_sync_engine.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final currentDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final accountsStreamProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.accounts).watch();
});

final transactionsStreamProvider = StreamProvider<List<LedgerTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.ledgerTransactions).watch();
});

final incomeSourcesStreamProvider = StreamProvider<List<IncomeSource>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.incomeSources).watch();
});

final incomeOccurrencesStreamProvider = StreamProvider<List<IncomeOccurrence>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.incomeOccurrences).watch();
});

final debtsStreamProvider = StreamProvider<List<Debt>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.debts).watch();
});

final recurringRulesStreamProvider = StreamProvider<List<RecurringRule>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.recurringRules).watch();
});

final expensesStreamProvider = StreamProvider<List<ExpenseRecord>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.expenses).watch();
});

final settingsFutureProvider = FutureProvider<FinancialSetting>((ref) async {
  final db = ref.watch(databaseProvider);
  await db.seedInitialData();
  final settingsList = await db.select(db.financialSettings).get();
  if (settingsList.isNotEmpty) {
    return settingsList.first;
  }
  return FinancialSetting(
    id: 1,
    primaryCurrency: '₹',
    minimumCashBuffer: 10000.0,
    defaultDebtStrategy: 'avalanche',
    pinLockEnabled: false,
    createdAt: DateTime.now(),
  );
});

final financialSnapshotProvider = Provider<AsyncValue<FinancialSnapshot>>((ref) {
  final accountsAsync = ref.watch(accountsStreamProvider);
  final txsAsync = ref.watch(transactionsStreamProvider);
  final incomeAsync = ref.watch(incomeSourcesStreamProvider);
  final occurrencesAsync = ref.watch(incomeOccurrencesStreamProvider);
  final debtsAsync = ref.watch(debtsStreamProvider);
  final rulesAsync = ref.watch(recurringRulesStreamProvider);
  final expensesAsync = ref.watch(expensesStreamProvider);
  final settingsAsync = ref.watch(settingsFutureProvider);
  final currentDate = ref.watch(currentDateProvider);

  if (accountsAsync is AsyncData &&
      txsAsync is AsyncData &&
      incomeAsync is AsyncData &&
      occurrencesAsync is AsyncData &&
      debtsAsync is AsyncData &&
      rulesAsync is AsyncData &&
      expensesAsync is AsyncData &&
      settingsAsync is AsyncData) {
    
    final db = ref.watch(databaseProvider);
    final sources = incomeAsync.value!;
    final occurrences = occurrencesAsync.value!;
    
    // Idempotent sync trigger
    IncomeSyncEngine.syncIncomeOccurrences(
      db: db,
      incomeSources: sources,
      existingOccurrences: occurrences,
      currentDate: currentDate,
    );

    final snapshot = FinancialEngine.computeSnapshot(
      accounts: accountsAsync.value!,
      transactions: txsAsync.value!,
      incomeSources: sources,
      incomeOccurrences: occurrences,
      debts: debtsAsync.value!,
      recurringRules: rulesAsync.value!,
      expenses: expensesAsync.value!,
      settings: settingsAsync.value!,
      currentDate: currentDate,
    );
    return AsyncData(snapshot);
  }

  if (accountsAsync.hasError) return AsyncError(accountsAsync.error!, accountsAsync.stackTrace!);
  if (txsAsync.hasError) return AsyncError(txsAsync.error!, txsAsync.stackTrace!);
  if (incomeAsync.hasError) return AsyncError(incomeAsync.error!, incomeAsync.stackTrace!);
  if (occurrencesAsync.hasError) return AsyncError(occurrencesAsync.error!, occurrencesAsync.stackTrace!);
  if (debtsAsync.hasError) return AsyncError(debtsAsync.error!, debtsAsync.stackTrace!);
  if (rulesAsync.hasError) return AsyncError(rulesAsync.error!, rulesAsync.stackTrace!);
  if (expensesAsync.hasError) return AsyncError(expensesAsync.error!, expensesAsync.stackTrace!);
  if (settingsAsync.hasError) return AsyncError(settingsAsync.error!, settingsAsync.stackTrace!);

  return const AsyncLoading();
});
