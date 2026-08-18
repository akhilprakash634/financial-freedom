import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../providers/app_providers.dart';

class RecurringRulesScreen extends ConsumerWidget {
  const RecurringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(recurringRulesStreamProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Financial Rules'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRuleDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
        backgroundColor: AppTheme.primaryEmerald,
      ),
      body: rulesAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('No recurring rules configured.\nRules generate expected occurrences without storing fake transactions.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.accentIndigo.withValues(alpha: 0.2),
                    child: const Icon(Icons.autorenew, color: AppTheme.accentIndigo),
                  ),
                  title: Text(rule.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(
                    '${rule.type.toUpperCase()} • ${rule.frequency} (Day ${rule.dayOfMonth})',
                    style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyFormatter.format(rule.amount, currencySymbol: currency),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.neutralGray),
                        onPressed: () async {
                          final db = ref.read(databaseProvider);
                          await (db.delete(db.recurringRules)..where((r) => r.id.equals(rule.id))).go();
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

  void _showAddRuleDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '31');
    String type = 'expense';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Recurring Rule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title (e.g. Rent, Electricity)')),
            TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
            TextField(controller: dayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Target Day of Month (1-31)')),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Recurring Expense')),
                DropdownMenuItem(value: 'income', child: Text('Recurring Income')),
              ],
              onChanged: (val) => type = val ?? 'expense',
              decoration: const InputDecoration(labelText: 'Rule Type'),
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

              await db.into(db.recurringRules).insert(
                RecurringRulesCompanion.insert(
                  title: titleCtrl.text.isEmpty ? 'Rule' : titleCtrl.text,
                  amount: amt,
                  type: type,
                  dayOfMonth: drift.Value(day),
                  startDate: DateTime.now(),
                ),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Rule'),
          ),
        ],
      ),
    );
  }
}
