import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../../domain/services/income_sync_engine.dart';
import '../providers/app_providers.dart';

class ReceivablesScreen extends ConsumerWidget {
  const ReceivablesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final occurrencesAsync = ref.watch(incomeOccurrencesStreamProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Owed To You (Receivables)'),
      ),
      body: occurrencesAsync.when(
        data: (occurrences) {
          final unpaid = occurrences.where((occ) => occ.status != 'received' && occ.status != 'cancelled').toList();
          
          final salaryArrears = unpaid.where((occ) => occ.title.toLowerCase().contains('salary')).toList();
          final freelance = unpaid.where((occ) => !occ.title.toLowerCase().contains('salary')).toList();

          final totalOwed = unpaid.fold(0.0, (sum, occ) => sum + (occ.amount - occ.receivedAmount));
          final totalSalaryArrears = salaryArrears.fold(0.0, (sum, occ) => sum + (occ.amount - occ.receivedAmount));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Primary Summary Card
              Card(
                color: AppTheme.cardDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF334155)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL MONEY OWED TO YOU',
                        style: TextStyle(color: AppTheme.neutralGray, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        CurrencyFormatter.format(totalOwed, currencySymbol: currency),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                      ),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppTheme.neutralGray, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'This is pending money owed to you. It is NOT part of your actual cash balance.',
                              style: TextStyle(color: AppTheme.neutralGray, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Salary Arrears Section
              if (salaryArrears.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Salary Arrears (${salaryArrears.length} months pending)',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      CurrencyFormatter.format(totalSalaryArrears, currencySymbol: currency),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...salaryArrears.map((occ) => _buildReceivableCard(context, ref, occ, currency)),
                const SizedBox(height: 24),
              ],

              // Freelance & Other Receivables
              if (freelance.isNotEmpty) ...[
                const Text(
                  'Freelance & Other Receivables',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 12),
                ...freelance.map((occ) => _buildReceivableCard(context, ref, occ, currency)),
              ],

              if (unpaid.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 48),
                        SizedBox(height: 12),
                        Text('No outstanding receivables!', style: TextStyle(color: AppTheme.neutralGray, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildReceivableCard(BuildContext context, WidgetRef ref, IncomeOccurrence occ, String currency) {
    final pendingAmount = occ.amount - occ.receivedAmount;
    final isOverdue = occ.status == 'overdue';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFF334155)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    occ.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOverdue ? const Color(0x33EF4444) : const Color(0x33EAB308),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    occ.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? const Color(0xFFEF4444) : const Color(0xFFEAB308),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expected: ${DateFormat('MMM dd, yyyy').format(occ.expectedDate)}',
                  style: const TextStyle(color: AppTheme.neutralGray, fontSize: 13),
                ),
                Text(
                  CurrencyFormatter.format(pendingAmount, currencySymbol: currency),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            if (occ.receivedAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Partially paid: ${CurrencyFormatter.format(occ.receivedAmount, currencySymbol: currency)} (Original: ${CurrencyFormatter.format(occ.amount, currencySymbol: currency)})',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showSettleDialog(context, ref, occ, currency),
                    icon: const Icon(Icons.download_done, size: 16),
                    label: const Text('Mark Received'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showDelayDialog(context, ref, occ),
                  icon: const Icon(Icons.event, size: 16),
                  label: const Text('Delay'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEAB308),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSettleDialog(BuildContext context, WidgetRef ref, IncomeOccurrence occ, String currency) {
    final pendingAmount = occ.amount - occ.receivedAmount;
    final amountController = TextEditingController(text: pendingAmount.toStringAsFixed(0));
    int? selectedAccountId;

    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, child) {
            final accountsAsync = ref.watch(accountsStreamProvider);
            final accounts = accountsAsync.value ?? [];
            if (selectedAccountId == null && accounts.isNotEmpty) {
              selectedAccountId = accounts.first.id;
            }

            return AlertDialog(
              backgroundColor: AppTheme.cardDark,
              title: Text('Settle ${occ.title}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total Owed: ${CurrencyFormatter.format(pendingAmount, currencySymbol: currency)}'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Received Amount ($currency)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: selectedAccountId,
                      decoration: const InputDecoration(
                        labelText: 'Deposit to Account',
                        border: OutlineInputBorder(),
                      ),
                      items: accounts.map((acc) {
                        return DropdownMenuItem<int>(
                          value: acc.id,
                          child: Text('${acc.name} (${acc.type})'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        selectedAccountId = val;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final enteredAmount = double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (enteredAmount <= 0 || selectedAccountId == null) return;

                    final db = ref.read(databaseProvider);
                    await IncomeSyncEngine.settleReceivable(
                      db: db,
                      occurrence: occ,
                      amountReceived: enteredAmount,
                      accountId: selectedAccountId!,
                      receivedDate: DateTime.now(),
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Received ${CurrencyFormatter.format(enteredAmount, currencySymbol: currency)} added to actual cash!')),
                      );
                    }
                  },
                  child: const Text('Confirm Settle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDelayDialog(BuildContext context, WidgetRef ref, IncomeOccurrence occ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: occ.expectedDate.isBefore(DateTime.now()) ? DateTime.now() : occ.expectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final db = ref.read(databaseProvider);
      await (db.update(db.incomeOccurrences)..where((tbl) => tbl.id.equals(occ.id))).write(
        IncomeOccurrencesCompanion(
          expectedDate: drift.Value(pickedDate),
          status: const drift.Value('delayed'),
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Expected date updated to ${DateFormat('MMM dd, yyyy').format(pickedDate)}')),
        );
      }
    }
  }
}
