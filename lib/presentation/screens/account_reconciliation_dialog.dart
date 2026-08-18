import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../../domain/services/income_sync_engine.dart';
import '../providers/app_providers.dart';

class AccountReconciliationDialog extends ConsumerStatefulWidget {
  final Account account;

  const AccountReconciliationDialog({super.key, required this.account});

  @override
  ConsumerState<AccountReconciliationDialog> createState() => _AccountReconciliationDialogState();
}

class _AccountReconciliationDialogState extends ConsumerState<AccountReconciliationDialog> {
  late TextEditingController _balanceController;

  @override
  void initState() {
    super.initState();
    _balanceController = TextEditingController();
  }

  @override
  void dispose() {
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txsAsync = ref.watch(transactionsStreamProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';

    final txs = txsAsync.value ?? [];
    final accountTxs = txs.where((t) => t.accountId == widget.account.id || t.targetAccountId == widget.account.id).toList();

    // Calculate current recorded balance for this account
    double recordedBalance = widget.account.openingBalance;
    for (final tx in accountTxs) {
      if (!tx.isActual) continue;
      if (tx.type == 'income') {
        recordedBalance += tx.amount;
      } else if (tx.type == 'expense' || tx.type == 'debt_payment') {
        recordedBalance -= tx.amount;
      } else if (tx.type == 'adjustment') {
        recordedBalance += tx.amount;
      } else if (tx.type == 'transfer') {
        if (tx.accountId == widget.account.id) recordedBalance -= tx.amount;
        if (tx.targetAccountId == widget.account.id) recordedBalance += tx.amount;
      }
    }

    if (_balanceController.text.isEmpty) {
      _balanceController.text = recordedBalance.toStringAsFixed(0);
    }

    final enteredActual = double.tryParse(_balanceController.text.trim()) ?? recordedBalance;
    final difference = enteredActual - recordedBalance;

    return AlertDialog(
      backgroundColor: AppTheme.cardDark,
      title: Text('Reconcile ${widget.account.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current App Balance:',
              style: TextStyle(color: AppTheme.neutralGray, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(recordedBalance, currencySymbol: currency),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Actual Real-World Bank Balance ($currency)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: difference == 0
                    ? const Color(0x2210B981)
                    : (difference < 0 ? const Color(0x22EF4444) : const Color(0x2238BDF8)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Adjustment Required:'),
                  Text(
                    CurrencyFormatter.format(difference, currencySymbol: currency),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: difference == 0
                          ? const Color(0xFF10B981)
                          : (difference < 0 ? const Color(0xFFEF4444) : const Color(0xFF38BDF8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This will create an explicit adjustment ledger transaction to sync your account balance without altering past records.',
              style: TextStyle(color: AppTheme.neutralGray, fontSize: 11),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: difference == 0
              ? null
              : () async {
                  final db = ref.read(databaseProvider);
                  await IncomeSyncEngine.reconcileAccountBalance(
                    db: db,
                    accountId: widget.account.id,
                    actualBankBalance: enteredActual,
                    currentCalculatedBalance: recordedBalance,
                    transactionDate: DateTime.now(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Account reconciled! Recorded adjustment of ${CurrencyFormatter.format(difference, currencySymbol: currency)}')),
                    );
                  }
                },
          child: const Text('Adjust & Save'),
        ),
      ],
    );
  }
}
