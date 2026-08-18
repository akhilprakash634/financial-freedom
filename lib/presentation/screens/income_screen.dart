import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

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
        onPressed: () => _showIncomeDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Income Source'),
        backgroundColor: AppTheme.primaryEmerald,
      ),
      body: incomeAsync.when(
        data: (sources) {
          if (sources.isEmpty) {
            return const Center(
              child: Text(
                'No income sources configured yet.\nTap "+ Add Income Source" to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.neutralGray),
              ),
            );
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
                    backgroundColor: AppTheme.positiveGreen.withValues(alpha: 0.2),
                    child: const Icon(Icons.attach_money, color: AppTheme.positiveGreen),
                  ),
                  title: Text(inc.sourceName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text(
                    '${inc.frequency.toUpperCase()} • Day ${inc.recurrenceDay} • Start: ${DateFormat('MMM yyyy').format(inc.expectedDate)}\nConfidence: ${inc.defaultConfidence.toUpperCase()}',
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
                        icon: const Icon(Icons.edit, color: AppTheme.primaryEmerald),
                        onPressed: () => _showIncomeDialog(context, ref, existing: inc),
                        tooltip: 'Edit Income Source',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppTheme.negativeRed),
                        onPressed: () => _confirmDelete(context, ref, inc),
                        tooltip: 'Delete',
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

  void _showIncomeDialog(BuildContext context, WidgetRef ref, {IncomeSource? existing}) {
    final nameCtrl = TextEditingController(text: existing?.sourceName ?? '');
    final amountCtrl = TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final dayCtrl = TextEditingController(text: existing?.recurrenceDay.toString() ?? '31');
    String frequency = existing?.frequency ?? 'monthly';
    String confidence = existing?.defaultConfidence ?? 'high';
    String status = existing?.status ?? 'confirmed';
    DateTime startDate = existing?.expectedDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardDark,
            title: Text(existing == null ? 'Add Income Source' : 'Edit Income Source'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Source Name (e.g. Monthly Salary, Client Freelance)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly Recurring')),
                      DropdownMenuItem(value: 'one_time', child: Text('One-Time (Freelance/Other)')),
                    ],
                    onChanged: (val) => setState(() => frequency = val ?? 'monthly'),
                    decoration: const InputDecoration(labelText: 'Frequency'),
                  ),
                  if (frequency == 'monthly') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: dayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Expected Payment Day of Month (1-31)'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Start / Expected Month', style: TextStyle(fontSize: 13, color: AppTheme.neutralGray)),
                    subtitle: Text(DateFormat('MMMM yyyy').format(startDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    trailing: const Icon(Icons.calendar_month, color: AppTheme.primaryEmerald),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: confidence,
                    items: const [
                      DropdownMenuItem(value: 'high', child: Text('High Confidence (Guaranteed)')),
                      DropdownMenuItem(value: 'medium', child: Text('Medium Confidence (Expected)')),
                      DropdownMenuItem(value: 'low', child: Text('Low Confidence (Uncertain)')),
                    ],
                    onChanged: (val) => setState(() => confidence = val ?? 'high'),
                    decoration: const InputDecoration(labelText: 'Default Reliability Confidence'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                      DropdownMenuItem(value: 'expected', child: Text('Expected')),
                    ],
                    onChanged: (val) => setState(() => status = val ?? 'confirmed'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  final day = int.tryParse(dayCtrl.text.trim()) ?? 31;
                  final name = nameCtrl.text.trim().isEmpty ? 'Income Source' : nameCtrl.text.trim();

                  if (existing == null) {
                    await db.into(db.incomeSources).insert(
                          IncomeSourcesCompanion.insert(
                            sourceName: name,
                            amount: amt,
                            expectedDate: startDate,
                            frequency: drift.Value(frequency),
                            recurrenceDay: drift.Value(day),
                            defaultConfidence: drift.Value(confidence),
                            status: drift.Value(status),
                          ),
                        );
                  } else {
                    await (db.update(db.incomeSources)..where((i) => i.id.equals(existing.id))).write(
                      IncomeSourcesCompanion(
                        sourceName: drift.Value(name),
                        amount: drift.Value(amt),
                        expectedDate: drift.Value(startDate),
                        frequency: drift.Value(frequency),
                        recurrenceDay: drift.Value(day),
                        defaultConfidence: drift.Value(confidence),
                        status: drift.Value(status),
                      ),
                    );
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Save Income' : 'Update Income'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, IncomeSource inc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text('Delete ${inc.sourceName}?'),
        content: const Text('Are you sure you want to delete this income source? Existing recorded transactions will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.negativeRed),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await (db.delete(db.incomeSources)..where((i) => i.id.equals(inc.id))).go();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
