import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/database/app_database.dart';
import '../../domain/services/debt_engine.dart';
import '../providers/app_providers.dart';

final selectedDebtStrategyProvider = StateProvider<DebtStrategy>((ref) => DebtStrategy.avalanche);

class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';
    final strategy = ref.watch(selectedDebtStrategyProvider);
    final currentDate = ref.watch(currentDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debts & Loan Tracker'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDebtDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Debt'),
        backgroundColor: AppTheme.primaryEmerald,
      ),
      body: debtsAsync.when(
        data: (debts) {
          final activeDebts = debts.where((d) => d.status == 'active' && d.currentBalance > 0).toList();
          final sortedDebts = DebtEngine.sortDebts(activeDebts, strategy);
          final payoffPlan = DebtEngine.calculatePayoffPlan(
            debts: activeDebts,
            strategy: strategy,
            currentDate: currentDate,
          );

          final totalDebt = activeDebts.fold(0.0, (sum, d) => sum + d.currentBalance);
          final totalEMI = activeDebts.fold(0.0, (sum, d) => sum + d.emiAmount);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Responsive Strategy Selection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 420;
                          final selector = SegmentedButton<DebtStrategy>(
                            segments: const [
                              ButtonSegment(value: DebtStrategy.avalanche, label: Text('Avalanche')),
                              ButtonSegment(value: DebtStrategy.snowball, label: Text('Snowball')),
                            ],
                            selected: {strategy},
                            onSelectionChanged: (set) {
                              ref.read(selectedDebtStrategyProvider.notifier).state = set.first;
                            },
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Repayment Strategy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 10),
                                SizedBox(width: double.infinity, child: selector),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Repayment Strategy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              selector,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strategy == DebtStrategy.avalanche
                            ? '💡 Avalanche mode prioritizes high-interest loans first to save the most money.'
                            : '💡 Snowball mode prioritizes low balances first for quick psychological wins.',
                        style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Responsive Debt Portfolio Overview Header Card
              Card(
                color: AppTheme.cardDark,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 360;
                      return Column(
                        children: [
                          if (isNarrow) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Outstanding', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.format(totalDebt, currencySymbol: currency),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.negativeRed),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Monthly EMI', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                const SizedBox(height: 4),
                                Text(
                                  CurrencyFormatter.format(totalEMI, currencySymbol: currency),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.warningAmber),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Outstanding', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                    const SizedBox(height: 4),
                                    Text(
                                      CurrencyFormatter.format(totalDebt, currencySymbol: currency),
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.negativeRed),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Monthly EMI', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                    const SizedBox(height: 4),
                                    Text(
                                      CurrencyFormatter.format(totalEMI, currencySymbol: currency),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.warningAmber),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 24, color: AppTheme.borderDark),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Active Debts: ${activeDebts.length}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                              Flexible(
                                child: Text(
                                  'Projected Debt-Free: ${DateFormat('MMM yyyy').format(payoffPlan.projectedDebtFreeDate)}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.positiveGreen),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Active Debts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              if (sortedDebts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('🎉 Congratulations! You have no active debt!')),
                  ),
                )
              else
                ...sortedDebts.map((debt) {
                  final remainingMonths = DebtEngine.calculateRemainingPayments(debt);
                  final finishDate = DebtEngine.calculateDebtFinishDate(debt, currentDate);
                  final progress = debt.originalAmount > 0
                      ? ((debt.originalAmount - debt.currentBalance) / debt.originalAmount).clamp(0.0, 1.0)
                      : 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(debt.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${debt.lenderBorrower} • ${debt.interestRate}% interest', style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Chip(
                                    label: Text(debt.debtType.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    backgroundColor: AppTheme.borderDark,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: AppTheme.primaryEmerald),
                                    onPressed: () => _showDebtDialog(context, ref, existing: debt),
                                    tooltip: 'Edit Debt',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: AppTheme.borderDark,
                            color: AppTheme.primaryEmerald,
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Paid: ${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray),
                              ),
                              Flexible(
                                child: Text(
                                  'Outstanding: ${CurrencyFormatter.format(debt.currentBalance, currencySymbol: currency)}',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.negativeRed),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Display Total Tenure vs Pending Tenure
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0x2210B981),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Tenure: ${debt.tenureMonths} mos', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                Text('Pending Tenure: $remainingMonths ${remainingMonths == 1 ? "mo" : "mos"}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isSmall = constraints.maxWidth < 340;
                              final info = Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('EMI: ${CurrencyFormatter.format(debt.emiAmount, currencySymbol: currency)}/mo', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text('Finish: ${DateFormat('MMM dd, yyyy').format(finishDate)} ($remainingMonths ${remainingMonths == 1 ? "payment" : "payments"} left)', style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray)),
                                ],
                              );
                              final button = ElevatedButton.icon(
                                onPressed: () => _showPayDebtDialog(context, ref, debt, currency),
                                icon: const Icon(Icons.payment, size: 16),
                                label: const Text('Pay EMI'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryEmerald,
                                  foregroundColor: Colors.white,
                                ),
                              );

                              if (isSmall) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    info,
                                    const SizedBox(height: 8),
                                    SizedBox(width: double.infinity, child: button),
                                  ],
                                );
                              }
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  info,
                                  button,
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading debts: $err')),
      ),
    );
  }

  void _showDebtDialog(BuildContext context, WidgetRef ref, {Debt? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final lenderCtrl = TextEditingController(text: existing?.lenderBorrower ?? '');
    final originalAmountCtrl = TextEditingController(text: existing?.originalAmount.toStringAsFixed(0) ?? '');
    final currentBalanceCtrl = TextEditingController(text: existing?.currentBalance.toStringAsFixed(0) ?? '');
    final emiCtrl = TextEditingController(text: existing?.emiAmount.toStringAsFixed(0) ?? '');
    final tenureCtrl = TextEditingController(text: existing?.tenureMonths.toString() ?? '12');
    final interestRateCtrl = TextEditingController(text: existing?.interestRate.toString() ?? '12.0');
    final dueDayCtrl = TextEditingController(text: existing?.dueDay.toString() ?? '5');
    String debtType = existing?.debtType ?? 'emi_loan';
    String status = existing?.status ?? 'active';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text(existing == null ? 'Add New Debt' : 'Edit Debt / Loan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Debt Name (e.g. Personal Loan)')),
              TextField(controller: lenderCtrl, decoration: const InputDecoration(labelText: 'Lender / Bank Name')),
              DropdownButtonFormField<String>(
                initialValue: debtType,
                items: const [
                  DropdownMenuItem(value: 'emi_loan', child: Text('EMI Loan')),
                  DropdownMenuItem(value: 'credit_card', child: Text('Credit Card')),
                  DropdownMenuItem(value: 'personal_debt', child: Text('Personal Debt')),
                  DropdownMenuItem(value: 'bnpl', child: Text('BNPL')),
                  DropdownMenuItem(value: 'family_friend', child: Text('Family / Friend')),
                ],
                onChanged: (val) => debtType = val ?? 'emi_loan',
                decoration: const InputDecoration(labelText: 'Debt Type'),
              ),
              TextField(controller: originalAmountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Original Amount')),
              TextField(controller: currentBalanceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Current Outstanding Balance')),
              TextField(controller: emiCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly EMI / Payment')),
              TextField(controller: tenureCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Tenure (Total Months)')),
              TextField(controller: interestRateCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Interest Rate % per annum')),
              TextField(controller: dueDayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Payment Due Day of Month (1-31)')),
              if (existing != null)
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'settled', child: Text('Settled / Closed')),
                  ],
                  onChanged: (val) => status = val ?? 'active',
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
              final orig = double.tryParse(originalAmountCtrl.text.trim()) ?? 0.0;
              final curr = double.tryParse(currentBalanceCtrl.text.trim()) ?? orig;
              final emi = double.tryParse(emiCtrl.text.trim()) ?? 0.0;
              final tenure = int.tryParse(tenureCtrl.text.trim()) ?? 12;
              final rate = double.tryParse(interestRateCtrl.text.trim()) ?? 0.0;
              final dueDay = int.tryParse(dueDayCtrl.text.trim()) ?? 5;
              final name = nameCtrl.text.trim().isEmpty ? 'Debt Loan' : nameCtrl.text.trim();
              final lender = lenderCtrl.text.trim().isEmpty ? 'Lender' : lenderCtrl.text.trim();

              if (existing == null) {
                await db.into(db.debts).insert(
                  DebtsCompanion.insert(
                    name: name,
                    lenderBorrower: lender,
                    debtType: debtType,
                    originalAmount: orig,
                    currentBalance: curr,
                    interestRate: drift.Value(rate),
                    emiAmount: emi,
                    tenureMonths: drift.Value(tenure),
                    dueDay: drift.Value(dueDay),
                    startDate: DateTime.now(),
                  ),
                );
              } else {
                await (db.update(db.debts)..where((d) => d.id.equals(existing.id))).write(
                  DebtsCompanion(
                    name: drift.Value(name),
                    lenderBorrower: drift.Value(lender),
                    debtType: drift.Value(debtType),
                    originalAmount: drift.Value(orig),
                    currentBalance: drift.Value(curr),
                    interestRate: drift.Value(rate),
                    emiAmount: drift.Value(emi),
                    tenureMonths: drift.Value(tenure),
                    dueDay: drift.Value(dueDay),
                    status: drift.Value(status),
                  ),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Save Debt' : 'Update Debt'),
          ),
        ],
      ),
    );
  }

  void _showPayDebtDialog(BuildContext context, WidgetRef ref, Debt debt, String currency) {
    final payAmountCtrl = TextEditingController(text: debt.emiAmount.toStringAsFixed(0));
    final noteCtrl = TextEditingController(text: 'Monthly EMI Payment');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        title: Text('Record Payment for ${debt.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Outstanding: ${CurrencyFormatter.format(debt.currentBalance, currencySymbol: currency)}'),
            const SizedBox(height: 12),
            TextField(controller: payAmountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Payment Amount')),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Payment Note')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final db = ref.read(databaseProvider);
              final amount = double.tryParse(payAmountCtrl.text.trim()) ?? 0.0;
              if (amount <= 0) return;

              final accounts = await db.select(db.accounts).get();
              final primaryAccount = accounts.firstWhere((a) => a.active, orElse: () => accounts.first);

              // 1. Insert Ledger Transaction
              final txId = await db.into(db.ledgerTransactions).insert(
                LedgerTransactionsCompanion.insert(
                  accountId: primaryAccount.id,
                  type: 'debt_payment',
                  amount: amount,
                  transactionDate: DateTime.now(),
                  note: drift.Value('${debt.name} payment: ${noteCtrl.text}'),
                  isActual: const drift.Value(true),
                ),
              );

              // 2. Record Debt Payment
              await db.into(db.debtPayments).insert(
                DebtPaymentsCompanion.insert(
                  debtId: debt.id,
                  transactionId: drift.Value(txId),
                  amount: amount,
                  paymentDate: DateTime.now(),
                  note: drift.Value(noteCtrl.text.trim()),
                ),
              );

              // 3. Reduce Debt Outstanding Balance & update status if 0
              final newBalance = (debt.currentBalance - amount).clamp(0.0, double.infinity);
              final isSettled = newBalance <= 0;

              await (db.update(db.debts)..where((d) => d.id.equals(debt.id))).write(
                DebtsCompanion(
                  currentBalance: drift.Value(newBalance),
                  status: drift.Value(isSettled ? 'settled' : 'active'),
                ),
              );

              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Confirm Payment'),
          ),
        ],
      ),
    );
  }
}
