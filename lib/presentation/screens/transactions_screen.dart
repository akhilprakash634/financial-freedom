import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../providers/app_providers.dart';

final selectedTxFilterProvider = StateProvider<String>((ref) => 'all');

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsStreamProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';
    final filter = ref.watch(selectedTxFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Ledger'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Log Transaction'),
        backgroundColor: AppTheme.primaryEmerald,
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(ref, 'all', 'All'),
                _buildFilterChip(ref, 'income', 'Income'),
                _buildFilterChip(ref, 'expense', 'Expense'),
                _buildFilterChip(ref, 'debt_payment', 'Debt Payment'),
                _buildFilterChip(ref, 'transfer', 'Transfer'),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: txsAsync.when(
              data: (txs) {
                final filtered = txs.where((t) {
                  if (filter == 'all') return true;
                  return t.type == filter;
                }).toList()
                  ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No actual transactions recorded yet.\nTap "+ Log Transaction" to add your first transaction.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final isIncome = tx.type == 'income';
                    final isExpense = tx.type == 'expense' || tx.type == 'debt_payment';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isIncome
                              ? AppTheme.positiveGreen.withValues(alpha: 0.2)
                              : (isExpense
                                  ? AppTheme.negativeRed.withValues(alpha: 0.2)
                                  : AppTheme.accentIndigo.withValues(alpha: 0.2)),
                          child: Icon(
                            isIncome
                                ? Icons.arrow_downward
                                : (isExpense ? Icons.arrow_upward : Icons.swap_horiz),
                            color: isIncome
                                ? AppTheme.positiveGreen
                                : (isExpense ? AppTheme.negativeRed : AppTheme.accentIndigo),
                          ),
                        ),
                        title: Text(tx.note ?? tx.type.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(tx.transactionDate),
                          style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${isIncome ? '+' : (isExpense ? '-' : '')}${CurrencyFormatter.format(tx.amount, currencySymbol: currency)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isIncome
                                    ? AppTheme.positiveGreen
                                    : (isExpense ? AppTheme.negativeRed : Colors.white),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.neutralGray),
                              onPressed: () async {
                                final db = ref.read(databaseProvider);
                                await (db.delete(db.ledgerTransactions)..where((t) => t.id.equals(tx.id))).go();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String value, String label) {
    final selected = ref.watch(selectedTxFilterProvider) == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (val) {
          if (val) ref.read(selectedTxFilterProvider.notifier).state = value;
        },
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = 'income';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Actual Transaction'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'income', child: Text('Income (Received)')),
                    DropdownMenuItem(value: 'expense', child: Text('Expense (Paid)')),
                    DropdownMenuItem(value: 'debt_payment', child: Text('Debt Payment')),
                    DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                    DropdownMenuItem(value: 'adjustment', child: Text('Balance Adjustment')),
                  ],
                  onChanged: (val) => setState(() => type = val ?? 'income'),
                  decoration: const InputDecoration(labelText: 'Transaction Type'),
                ),
                TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Notes / Description')),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final amount = double.tryParse(amountCtrl.text) ?? 0.0;
              if (amount <= 0) return;

              final accounts = await db.select(db.accounts).get();
              final primaryAccount = accounts.firstWhere((a) => a.active, orElse: () => accounts.first);

              await db.into(db.ledgerTransactions).insert(
                LedgerTransactionsCompanion.insert(
                  accountId: primaryAccount.id,
                  type: type,
                  amount: amount,
                  transactionDate: DateTime.now(),
                  note: drift.Value(noteCtrl.text.isEmpty ? type.toUpperCase() : noteCtrl.text),
                  isActual: const drift.Value(true),
                ),
              );

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Transaction'),
          ),
        ],
      ),
    );
  }
}
