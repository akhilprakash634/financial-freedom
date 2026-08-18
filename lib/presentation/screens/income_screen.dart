import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../providers/app_providers.dart';

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(incomeSourcesStreamProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Income Sources'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddIncomeDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Income'),
        backgroundColor: AppTheme.primaryEmerald,
      ),
      body: incomeAsync.when(
        data: (sources) {
          if (sources.isEmpty) {
            return const Center(child: Text('No income sources configured yet.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final inc = sources[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.positiveGreen.withOpacity(0.2),
                    child: const Icon(Icons.attach_money, color: AppTheme.positiveGreen),
                  ),
                  title: Text(inc.sourceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(
                    '${inc.frequency.toUpperCase()} • Day ${inc.recurrenceDay} • ${inc.status.toUpperCase()}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.format(inc.amount, currencySymbol: currency),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.positiveGreen),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.neutralGray),
                        onPressed: () async {
                          final db = ref.read(databaseProvider);
                          await (db.delete(db.incomeSources)..where((i) => i.id.equals(inc.id))).go();
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
    );
  }

  void _showAddIncomeDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '31');
    String status = 'confirmed';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Income Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Source Name (e.g. Salary, Freelance)')),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
            TextField(controller: dayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Recurrence Day of Month (1-31)')),
            DropdownButtonFormField<String>(
              initialValue: status,
              items: const [
                DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                DropdownMenuItem(value: 'expected', child: Text('Expected')),
              ],
              onChanged: (val) => status = val ?? 'confirmed',
              decoration: const InputDecoration(labelText: 'Status / Confidence'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final amt = double.tryParse(amountCtrl.text) ?? 0.0;
              final day = int.tryParse(dayCtrl.text) ?? 31;

              await db.into(db.incomeSources).insert(
                IncomeSourcesCompanion.insert(
                  sourceName: nameCtrl.text.isEmpty ? 'Income' : nameCtrl.text,
                  amount: amt,
                  expectedDate: DateTime.now(),
                  recurrenceDay: drift.Value(day),
                  status: drift.Value(status),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Income'),
          ),
        ],
      ),
    );
  }
}
