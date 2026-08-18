import 'dart:convert';
import 'package:intl/intl.dart';

import '../data/database/app_database.dart';

class BackupService {
  /// Exports all financial data into a clean JSON string for local backup.
  static Future<String> exportToJson(AppDatabase db) async {
    final accounts = await db.select(db.accounts).get();
    final txs = await db.select(db.ledgerTransactions).get();
    final income = await db.select(db.incomeSources).get();
    final occurrences = await db.select(db.incomeOccurrences).get();
    final debts = await db.select(db.debts).get();
    final rules = await db.select(db.recurringRules).get();
    final settings = await db.select(db.financialSettings).get();

    final data = {
      'app': 'Financial Freedom',
      'version': '2.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'accounts': accounts.map((a) => {'id': a.id, 'name': a.name, 'type': a.type, 'openingBalance': a.openingBalance, 'currency': a.currency}).toList(),
      'transactions': txs.map((t) => {'id': t.id, 'accountId': t.accountId, 'type': t.type, 'amount': t.amount, 'date': t.transactionDate.toIso8601String(), 'note': t.note}).toList(),
      'income_sources': income.map((i) => {'id': i.id, 'name': i.sourceName, 'amount': i.amount, 'recurrenceDay': i.recurrenceDay, 'status': i.status, 'confidence': i.defaultConfidence}).toList(),
      'income_occurrences': occurrences.map((o) => {'id': o.id, 'title': o.title, 'amount': o.amount, 'receivedAmount': o.receivedAmount, 'expectedDate': o.expectedDate.toIso8601String(), 'status': o.status, 'confidence': o.confidence}).toList(),
      'debts': debts.map((d) => {'id': d.id, 'name': d.name, 'lender': d.lenderBorrower, 'type': d.debtType, 'originalAmount': d.originalAmount, 'currentBalance': d.currentBalance, 'emiAmount': d.emiAmount, 'dueDay': d.dueDay}).toList(),
      'recurring_rules': rules.map((r) => {'id': r.id, 'title': r.title, 'amount': r.amount, 'type': r.type, 'dayOfMonth': r.dayOfMonth}).toList(),
      'settings': settings.isNotEmpty ? {'primaryCurrency': settings.first.primaryCurrency, 'minimumCashBuffer': settings.first.minimumCashBuffer} : {},
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Exports ledger transactions into CSV string.
  static Future<String> exportTransactionsToCsv(AppDatabase db) async {
    final txs = await db.select(db.ledgerTransactions).get();
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Type,Amount,Note');

    for (final tx in txs) {
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.transactionDate);
      final noteStr = (tx.note ?? '').replaceAll(',', ' ');
      buffer.writeln('${tx.id},$dateStr,${tx.type},${tx.amount},$noteStr');
    }

    return buffer.toString();
  }
}
