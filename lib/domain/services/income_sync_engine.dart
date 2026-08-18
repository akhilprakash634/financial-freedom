import 'package:drift/drift.dart';
import '../../data/database/app_database.dart';
import '../../core/utils/date_utils.dart';

class IncomeSyncEngine {
  /// Cleans up any duplicate unpaid income occurrences matching the same title, year, and month.
  static Future<void> cleanupDuplicateOccurrences(AppDatabase db) async {
    final all = await db.select(db.incomeOccurrences).get();
    final seenKeys = <String, int>{};
    final idsToDelete = <int>[];

    for (final occ in all) {
      if (occ.status == 'received' || occ.status == 'cancelled') continue;
      final key = '${occ.title.toLowerCase().trim()}_${occ.expectedDate.year}_${occ.expectedDate.month}';
      if (seenKeys.containsKey(key)) {
        idsToDelete.add(occ.id);
      } else {
        seenKeys[key] = occ.id;
      }
    }

    if (idsToDelete.isNotEmpty) {
      await (db.delete(db.incomeOccurrences)..where((tbl) => tbl.id.isIn(idsToDelete))).go();
    }
  }

  /// Idempotently synchronizes income sources to income occurrences in SQLite.
  /// Deduplicates by incomeSourceId OR title + (year, month).
  static Future<void> syncIncomeOccurrences({
    required AppDatabase db,
    required List<IncomeSource> incomeSources,
    required List<IncomeOccurrence> existingOccurrences,
    required DateTime currentDate,
  }) async {
    await cleanupDuplicateOccurrences(db);
    final today = AppDateUtils.dateOnly(currentDate);

    for (final source in incomeSources) {
      if (source.status == 'cancelled') continue;

      // First: Resync existing unreceived occurrences if parent source date or amount was updated
      for (final occ in existingOccurrences) {
        if (occ.incomeSourceId == source.id &&
            occ.status != 'received' &&
            occ.status != 'cancelled' &&
            occ.status != 'delayed') {
          final srcExpDate = AppDateUtils.dateOnly(source.expectedDate);
          if (!AppDateUtils.isSameDay(occ.expectedDate, srcExpDate) || occ.amount != source.amount) {
            String newStatus;
            if (srcExpDate.isBefore(today)) {
              newStatus = 'overdue';
            } else if (AppDateUtils.isSameDay(srcExpDate, today)) {
              newStatus = 'due';
            } else {
              newStatus = source.status == 'confirmed' ? 'confirmed' : 'expected';
            }

            await (db.update(db.incomeOccurrences)..where((tbl) => tbl.id.equals(occ.id))).write(
              IncomeOccurrencesCompanion(
                amount: Value(source.amount),
                expectedDate: Value(srcExpDate),
                status: Value(newStatus),
              ),
            );
          }
        }
      }

      if (source.frequency == 'monthly') {
        // Start from source.expectedDate or earliest start date
        var targetDate = AppDateUtils.dateOnly(source.expectedDate);
        
        // Loop monthly up to today + 30 days
        final horizonEnd = today.add(const Duration(days: 30));

        while (!targetDate.isAfter(horizonEnd)) {
          final year = targetDate.year;
          final month = targetDate.month;

          // Deduplicate: check if an occurrence exists for this source OR matching title in (year, month)
          final exists = existingOccurrences.any((occ) =>
              (occ.incomeSourceId == source.id || occ.title.toLowerCase().trim() == source.sourceName.toLowerCase().trim()) &&
              occ.expectedDate.year == year &&
              occ.expectedDate.month == month);

          if (!exists) {
            // Determine status based on targetDate vs today
            String status;
            if (targetDate.isBefore(today)) {
              status = 'overdue';
            } else if (AppDateUtils.isSameDay(targetDate, today)) {
              status = 'due';
            } else {
              status = source.status == 'confirmed' ? 'confirmed' : 'expected';
            }

            await db.into(db.incomeOccurrences).insert(
                  IncomeOccurrencesCompanion.insert(
                    incomeSourceId: Value(source.id),
                    title: source.sourceName,
                    amount: source.amount,
                    expectedDate: targetDate,
                    status: Value(status),
                    confidence: Value(source.defaultConfidence),
                    accountId: Value(source.accountId),
                    createdAt: Value(DateTime.now()),
                  ),
                );
          }

          // Move to next month
          final nextMonth = month == 12 ? 1 : month + 1;
          final nextYear = month == 12 ? year + 1 : year;
          final day = AppDateUtils.clampDayOfMonth(nextYear, nextMonth, source.recurrenceDay);
          targetDate = DateTime(nextYear, nextMonth, day);
        }
      } else {
        // One-time income source (e.g. Freelance)
        final exists = existingOccurrences.any((occ) =>
            occ.incomeSourceId == source.id || occ.title.toLowerCase().trim() == source.sourceName.toLowerCase().trim());

        if (!exists) {
          final expDate = AppDateUtils.dateOnly(source.expectedDate);
          String status = source.status;
          if (expDate.isBefore(today) && status != 'received' && status != 'cancelled') {
            status = 'overdue';
          }

          await db.into(db.incomeOccurrences).insert(
                IncomeOccurrencesCompanion.insert(
                  incomeSourceId: Value(source.id),
                  title: source.sourceName,
                  amount: source.amount,
                  expectedDate: expDate,
                  status: Value(status),
                  confidence: Value(source.defaultConfidence),
                  accountId: Value(source.accountId),
                  createdAt: Value(DateTime.now()),
                ),
              );
        }
      }
    }

    // Also update existing occurrences whose expected date passed without being received
    for (final occ in existingOccurrences) {
      if (occ.status != 'received' && occ.status != 'cancelled') {
        final expDate = AppDateUtils.dateOnly(occ.expectedDate);
        if (expDate.isBefore(today) && occ.status != 'overdue' && occ.status != 'delayed') {
          await (db.update(db.incomeOccurrences)..where((tbl) => tbl.id.equals(occ.id)))
              .write(const IncomeOccurrencesCompanion(status: Value('overdue')));
        }
      }
    }
  }

  /// Settles a receivable occurrence with full or partial payment.
  /// Creates exactly ONE actual income LedgerTransaction.
  static Future<void> settleReceivable({
    required AppDatabase db,
    required IncomeOccurrence occurrence,
    required double amountReceived,
    required int accountId,
    required DateTime receivedDate,
  }) async {
    final newReceived = occurrence.receivedAmount + amountReceived;
    final isFullyPaid = newReceived >= occurrence.amount;
    final newStatus = isFullyPaid ? 'received' : occurrence.status;

    // 1. Update occurrence record
    await (db.update(db.incomeOccurrences)..where((tbl) => tbl.id.equals(occurrence.id))).write(
      IncomeOccurrencesCompanion(
        receivedAmount: Value(newReceived),
        receivedDate: isFullyPaid ? Value(receivedDate) : const Value.absent(),
        status: Value(newStatus),
        accountId: Value(accountId),
      ),
    );

    // 2. Create actual income ledger transaction
    await db.into(db.ledgerTransactions).insert(
          LedgerTransactionsCompanion.insert(
            accountId: accountId,
            type: 'income',
            amount: amountReceived,
            transactionDate: receivedDate,
            note: Value('Receivable payment: ${occurrence.title}'),
            isActual: const Value(true),
          ),
        );
  }

  /// Reconciles an account balance by inserting an adjustment transaction.
  static Future<void> reconcileAccountBalance({
    required AppDatabase db,
    required int accountId,
    required double actualBankBalance,
    required double currentCalculatedBalance,
    required DateTime transactionDate,
  }) async {
    final difference = actualBankBalance - currentCalculatedBalance;
    if (difference == 0) return; // No adjustment needed

    await db.into(db.ledgerTransactions).insert(
          LedgerTransactionsCompanion.insert(
            accountId: accountId,
            type: 'adjustment',
            amount: difference, // positive or negative
            transactionDate: transactionDate,
            note: const Value('Balance reconciliation'),
            isActual: const Value(true),
          ),
        );
  }

  /// Calculate total unpaid salary arrears from occurrences
  static double calculateSalaryArrears(List<IncomeOccurrence> occurrences) {
    double total = 0.0;
    for (final occ in occurrences) {
      if (occ.status != 'received' &&
          occ.status != 'cancelled' &&
          occ.title.toLowerCase().contains('salary')) {
        total += (occ.amount - occ.receivedAmount);
      }
    }
    return total;
  }

  /// Calculate total Money Owed To Me from unpaid receivables
  static double calculateMoneyOwedToMe(List<IncomeOccurrence> occurrences) {
    double total = 0.0;
    for (final occ in occurrences) {
      if (occ.status != 'received' && occ.status != 'cancelled') {
        total += (occ.amount - occ.receivedAmount);
      }
    }
    return total;
  }
}
