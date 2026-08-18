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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debts & Credit Cards'),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryEmerald,
            tabs: [
              Tab(icon: Icon(Icons.credit_card), text: 'Credit Cards'),
              Tab(icon: Icon(Icons.account_balance), text: 'Loans & EMIs'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showDebtDialog(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add Debt / Card'),
          backgroundColor: AppTheme.primaryEmerald,
        ),
        body: debtsAsync.when(
          data: (debts) {
            final creditCards = debts.where((d) => d.debtType == 'credit_card' && d.status == 'active').toList();
            final loanDebts = debts.where((d) => d.debtType != 'credit_card' && d.status == 'active' && d.currentBalance > 0).toList();

            final totalCardOutstanding = creditCards.fold(0.0, (sum, c) => sum + c.currentBalance);
            final totalCardMonthlyDue = creditCards.fold(0.0, (sum, c) => sum + c.currentMonthDue);
            final totalLoanDebt = loanDebts.fold(0.0, (sum, d) => sum + d.currentBalance);
            final totalLoanEMI = loanDebts.fold(0.0, (sum, d) => sum + d.emiAmount);

            final payoffPlan = DebtEngine.calculatePayoffPlan(
              debts: debts.where((d) => d.status == 'active' && d.currentBalance > 0).toList(),
              strategy: strategy,
              currentDate: currentDate,
            );

            return TabBarView(
              children: [
                // -------------------------------------------------------------
                // TAB 1: CREDIT CARDS VIEW
                // -------------------------------------------------------------
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Credit Cards Header Summary
                    Card(
                      color: AppTheme.cardDark,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Card Outstanding', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                    const SizedBox(height: 4),
                                    Text(
                                      CurrencyFormatter.format(totalCardOutstanding, currencySymbol: currency),
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Current Statement Due', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                    const SizedBox(height: 4),
                                    Text(
                                      CurrencyFormatter.format(totalCardMonthlyDue, currencySymbol: currency),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: AppTheme.borderDark),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Active Cards: ${creditCards.length}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                const Text('💳 Billing Cycle Managed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Active Credit Cards', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (creditCards.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('🎉 No active credit card debt!\nTap "+ Add Debt / Card" to add a credit card.'),
                          ),
                        ),
                      )
                    else
                      ...creditCards.map((card) => _buildCreditCardItem(context, ref, card, currency)),
                  ],
                ),

                // -------------------------------------------------------------
                // TAB 2: LOANS & EMIS VIEW
                // -------------------------------------------------------------
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Strategy Selection Card
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

                    // Portfolio Header Card
                    Card(
                      color: AppTheme.cardDark,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Total Loan Debt', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                    const SizedBox(height: 4),
                                    Text(
                                      CurrencyFormatter.format(totalLoanDebt, currencySymbol: currency),
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
                                      CurrencyFormatter.format(totalLoanEMI, currencySymbol: currency),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.warningAmber),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24, color: AppTheme.borderDark),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Active Loans: ${loanDebts.length}', style: const TextStyle(fontSize: 13, color: Colors.white70)),
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
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text('Active Loans & Personal Debts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),

                    if (loanDebts.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('🎉 Congratulations! You have no active loan debt!')),
                        ),
                      )
                    else
                      ...loanDebts.map((debt) => _buildLoanCardItem(context, ref, debt, currency, currentDate)),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error loading debts: $err')),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CREDIT CARD ITEM WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildCreditCardItem(BuildContext context, WidgetRef ref, Debt card, String currency) {
    final availableCredit = card.creditLimit - card.currentBalance;
    final isOverLimit = availableCredit < 0;
    final utilization = card.creditLimit > 0 ? (card.currentBalance / card.creditLimit).clamp(0.0, 1.0) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF6366F1), width: 1.0),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
                      Text('${card.lenderBorrower} • ${card.interestRate}% APR', style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Chip(
                      label: Text('CREDIT CARD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                      backgroundColor: Color(0x226366F1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Color(0xFF6366F1)),
                      onPressed: () => _showDebtDialog(context, ref, existing: card),
                      tooltip: 'Edit Card Details',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: utilization,
              backgroundColor: AppTheme.borderDark,
              color: isOverLimit || utilization > 0.7 ? AppTheme.negativeRed : const Color(0xFF6366F1),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Limit: ${CurrencyFormatter.format(card.creditLimit, currencySymbol: currency)}', style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray)),
                Text(
                  isOverLimit
                      ? 'Available: ${CurrencyFormatter.format(availableCredit, currencySymbol: currency)} (Over Limit)'
                      : 'Available: ${CurrencyFormatter.format(availableCredit, currencySymbol: currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isOverLimit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x116366F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Card Balance:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      Text(CurrencyFormatter.format(card.currentBalance, currencySymbol: currency), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Current Statement Bill:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      Text(CurrencyFormatter.format(card.currentMonthDue, currencySymbol: currency), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Minimum Due:', style: TextStyle(fontSize: 12, color: Colors.white70)),
                      Text(CurrencyFormatter.format(card.minimumDue, currencySymbol: currency), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                    ],
                  ),
                  const Divider(height: 16, color: Color(0xFF334155)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Billing Day: ${card.billingDay}th of month', style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray)),
                      Text('Payment Due: ${card.dueDay}th of month', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPayCreditCardDialog(context, ref, card, currency),
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('Pay Card Bill'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LOAN ITEM WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildLoanCardItem(BuildContext context, WidgetRef ref, Debt debt, String currency, DateTime currentDate) {
    final remainingMonths = DebtEngine.calculateRemainingPayments(debt, currentDate);
    final elapsedMonths = DebtEngine.calculateElapsedPayments(debt, currentDate);
    final totalTenure = DebtEngine.calculateTotalTenureMonths(debt);
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
                Text('Paid: ${(progress * 100).toStringAsFixed(0)}% ($elapsedMonths / $totalTenure EMIs)', style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray)),
                Flexible(
                  child: Text('Outstanding: ${CurrencyFormatter.format(debt.currentBalance, currencySymbol: currency)}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.negativeRed)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0x2210B981), borderRadius: BorderRadius.circular(8)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Start: ${DateFormat('MMM yyyy').format(debt.startDate)}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      Text('End: ${DateFormat('MMM dd, yyyy').format(finishDate)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tenure: $totalTenure months', style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray)),
                      Text('Pending: $remainingMonths ${remainingMonths == 1 ? "EMI" : "EMIs"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.warningAmber)),
                    ],
                  ),
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
                    Text('Closes: ${DateFormat('MMM dd, yyyy').format(finishDate)} ($remainingMonths ${remainingMonths == 1 ? "payment" : "payments"} left)', style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray)),
                  ],
                );
                final button = ElevatedButton.icon(
                  onPressed: () => _showPayDebtDialog(context, ref, debt, currency),
                  icon: const Icon(Icons.payment, size: 16),
                  label: const Text('Pay EMI'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald, foregroundColor: Colors.white),
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
                  children: [info, button],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ADD / EDIT DEBT & CREDIT CARD DIALOG
  // ---------------------------------------------------------------------------
  void _showDebtDialog(BuildContext context, WidgetRef ref, {Debt? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final lenderCtrl = TextEditingController(text: existing?.lenderBorrower ?? '');
    final originalAmountCtrl = TextEditingController(text: existing?.originalAmount.toStringAsFixed(0) ?? '');
    final currentBalanceCtrl = TextEditingController(text: existing?.currentBalance.toStringAsFixed(0) ?? '');
    final emiCtrl = TextEditingController(text: existing?.emiAmount.toStringAsFixed(0) ?? '');
    final tenureCtrl = TextEditingController(text: existing?.tenureMonths.toString() ?? '12');
    final interestRateCtrl = TextEditingController(text: existing?.interestRate.toString() ?? '12.0');
    final dueDayCtrl = TextEditingController(text: existing?.dueDay.toString() ?? '5');

    // Credit Card specific controllers
    final creditLimitCtrl = TextEditingController(text: existing?.creditLimit.toStringAsFixed(0) ?? '100000');
    final statementDueCtrl = TextEditingController(text: existing?.currentMonthDue.toStringAsFixed(0) ?? '0');
    final minimumDueCtrl = TextEditingController(text: existing?.minimumDue.toStringAsFixed(0) ?? '0');
    final billingDayCtrl = TextEditingController(text: existing?.billingDay.toString() ?? '15');

    String debtType = existing?.debtType ?? 'credit_card';
    String status = existing?.status ?? 'active';
    DateTime startDate = existing?.startDate ?? DateTime.now();
    DateTime? endDate = existing?.endDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final isCreditCard = debtType == 'credit_card';

          return AlertDialog(
            backgroundColor: AppTheme.cardDark,
            title: Text(existing == null ? 'Add Debt / Card' : 'Edit ${isCreditCard ? "Credit Card" : "Debt / Loan"}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: debtType,
                    items: const [
                      DropdownMenuItem(value: 'credit_card', child: Text('💳 Credit Card')),
                      DropdownMenuItem(value: 'emi_loan', child: Text('🏦 EMI Loan')),
                      DropdownMenuItem(value: 'personal_debt', child: Text('🤝 Personal Debt')),
                      DropdownMenuItem(value: 'bnpl', child: Text('🛍️ Buy Now Pay Later (BNPL)')),
                      DropdownMenuItem(value: 'family_friend', child: Text('👨‍👩‍👧 Family / Friend')),
                    ],
                    onChanged: (val) => setState(() => debtType = val ?? 'credit_card'),
                    decoration: const InputDecoration(labelText: 'Debt / Card Category'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(labelText: isCreditCard ? 'Card Name (e.g. HDFC Regalia)' : 'Debt Name (e.g. Personal Loan)'),
                  ),
                  TextField(
                    controller: lenderCtrl,
                    decoration: InputDecoration(labelText: isCreditCard ? 'Issuing Bank (e.g. HDFC Bank)' : 'Lender / Bank Name'),
                  ),
                  const SizedBox(height: 12),

                  if (isCreditCard) ...[
                    // Credit Card Specialized Inputs
                    TextField(
                      controller: creditLimitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Total Credit Limit (Available Limit)'),
                    ),
                    TextField(
                      controller: currentBalanceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Total Current Outstanding Balance'),
                    ),
                    TextField(
                      controller: statementDueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Current Month Statement Bill (Changes Monthly)'),
                    ),
                    TextField(
                      controller: minimumDueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Minimum Amount Due for Current Month'),
                    ),
                    TextField(
                      controller: billingDayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Monthly Statement Billing Day (1-31)'),
                    ),
                    TextField(
                      controller: dueDayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Payment Due Day of Month (1-31)'),
                    ),
                    TextField(
                      controller: interestRateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Annual Interest Rate % (APR)'),
                    ),
                  ] else ...[
                    // Standard EMI Loan Inputs
                    TextField(controller: originalAmountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Original Amount')),
                    TextField(controller: currentBalanceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Current Outstanding Balance')),
                    TextField(controller: emiCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Monthly EMI / Payment')),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('EMI Start Date', style: TextStyle(fontSize: 13, color: AppTheme.neutralGray)),
                      subtitle: Text(DateFormat('MMMM dd, yyyy').format(startDate), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      trailing: const Icon(Icons.calendar_month, color: AppTheme.primaryEmerald),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => startDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('EMI End / Closure Date', style: TextStyle(fontSize: 13, color: AppTheme.neutralGray)),
                      subtitle: Text(
                        endDate != null ? DateFormat('MMMM dd, yyyy').format(endDate!) : 'Auto-calculate from balance',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                      ),
                      trailing: const Icon(Icons.event_available, color: AppTheme.primaryEmerald),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime(2015),
                          lastDate: DateTime(2040),
                        );
                        if (picked != null) {
                          setState(() => endDate = picked);
                        }
                      },
                    ),
                    TextField(controller: tenureCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Total Tenure (Total Months)')),
                    TextField(controller: interestRateCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Interest Rate % per annum')),
                    TextField(controller: dueDayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Payment Due Day of Month (1-31)')),
                  ],

                  if (existing != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('Active')),
                        DropdownMenuItem(value: 'settled', child: Text('Settled / Closed')),
                      ],
                      onChanged: (val) => setState(() => status = val ?? 'active'),
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final db = ref.read(databaseProvider);
                  final name = nameCtrl.text.trim().isEmpty ? (isCreditCard ? 'Credit Card' : 'Debt Loan') : nameCtrl.text.trim();
                  final lender = lenderCtrl.text.trim().isEmpty ? (isCreditCard ? 'Bank' : 'Lender') : lenderCtrl.text.trim();
                  final curr = double.tryParse(currentBalanceCtrl.text.trim()) ?? 0.0;
                  final orig = double.tryParse(originalAmountCtrl.text.trim()) ?? curr;
                  final emi = double.tryParse(emiCtrl.text.trim()) ?? 0.0;
                  final tenure = int.tryParse(tenureCtrl.text.trim()) ?? 12;
                  final rate = double.tryParse(interestRateCtrl.text.trim()) ?? 0.0;
                  final dueDay = int.tryParse(dueDayCtrl.text.trim()) ?? 5;

                  final limit = double.tryParse(creditLimitCtrl.text.trim()) ?? 0.0;
                  final stmtDue = double.tryParse(statementDueCtrl.text.trim()) ?? 0.0;
                  final minDue = double.tryParse(minimumDueCtrl.text.trim()) ?? 0.0;
                  final bDay = int.tryParse(billingDayCtrl.text.trim()) ?? 15;

                  if (existing == null) {
                    await db.into(db.debts).insert(
                          DebtsCompanion.insert(
                            name: name,
                            lenderBorrower: lender,
                            debtType: debtType,
                            originalAmount: isCreditCard ? limit : orig,
                            currentBalance: curr,
                            interestRate: drift.Value(rate),
                            emiAmount: isCreditCard ? stmtDue : emi,
                            tenureMonths: drift.Value(tenure),
                            dueDay: drift.Value(dueDay),
                            startDate: startDate,
                            endDate: drift.Value(endDate),
                            creditLimit: drift.Value(limit),
                            currentMonthDue: drift.Value(stmtDue),
                            minimumDue: drift.Value(minDue),
                            billingDay: drift.Value(bDay),
                          ),
                        );
                  } else {
                    await (db.update(db.debts)..where((d) => d.id.equals(existing.id))).write(
                      DebtsCompanion(
                        name: drift.Value(name),
                        lenderBorrower: drift.Value(lender),
                        debtType: drift.Value(debtType),
                        originalAmount: drift.Value(isCreditCard ? limit : orig),
                        currentBalance: drift.Value(curr),
                        interestRate: drift.Value(rate),
                        emiAmount: drift.Value(isCreditCard ? stmtDue : emi),
                        tenureMonths: drift.Value(tenure),
                        dueDay: drift.Value(dueDay),
                        startDate: drift.Value(startDate),
                        endDate: drift.Value(endDate),
                        creditLimit: drift.Value(limit),
                        currentMonthDue: drift.Value(stmtDue),
                        minimumDue: drift.Value(minDue),
                        billingDay: drift.Value(bDay),
                        status: drift.Value(status),
                      ),
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Save' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAY CREDIT CARD BILL DIALOG
  // ---------------------------------------------------------------------------
  void _showPayCreditCardDialog(BuildContext context, WidgetRef ref, Debt card, String currency) {
    final payAmountCtrl = TextEditingController(text: card.currentMonthDue > 0 ? card.currentMonthDue.toStringAsFixed(0) : card.currentBalance.toStringAsFixed(0));
    final noteCtrl = TextEditingController(text: 'Credit Card Bill Payment');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardDark,
            title: Text('Pay ${card.name} Bill'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Statement Due: ${CurrencyFormatter.format(card.currentMonthDue, currencySymbol: currency)}'),
                  Text('Minimum Due: ${CurrencyFormatter.format(card.minimumDue, currencySymbol: currency)}'),
                  Text('Total Balance: ${CurrencyFormatter.format(card.currentBalance, currencySymbol: currency)}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Full Statement'),
                        selected: payAmountCtrl.text == card.currentMonthDue.toStringAsFixed(0),
                        onSelected: (val) {
                          if (val) setState(() => payAmountCtrl.text = card.currentMonthDue.toStringAsFixed(0));
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Minimum Due'),
                        selected: payAmountCtrl.text == card.minimumDue.toStringAsFixed(0),
                        onSelected: (val) {
                          if (val) setState(() => payAmountCtrl.text = card.minimumDue.toStringAsFixed(0));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: payAmountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Payment Amount')),
                  TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Payment Note')),
                ],
              ),
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
                      note: drift.Value('${card.name} payment: ${noteCtrl.text}'),
                      isActual: const drift.Value(true),
                    ),
                  );

                  // 2. Record Debt Payment
                  await db.into(db.debtPayments).insert(
                    DebtPaymentsCompanion.insert(
                      debtId: card.id,
                      transactionId: drift.Value(txId),
                      amount: amount,
                      paymentDate: DateTime.now(),
                      note: drift.Value(noteCtrl.text.trim()),
                    ),
                  );

                  // 3. Reduce Total Outstanding & Current Month Statement Due
                  final newBalance = (card.currentBalance - amount).clamp(0.0, double.infinity);
                  final newStmtDue = (card.currentMonthDue - amount).clamp(0.0, double.infinity);
                  final newMinDue = (card.minimumDue - amount).clamp(0.0, double.infinity);
                  final isSettled = newBalance <= 0;

                  await (db.update(db.debts)..where((d) => d.id.equals(card.id))).write(
                    DebtsCompanion(
                      currentBalance: drift.Value(newBalance),
                      currentMonthDue: drift.Value(newStmtDue),
                      minimumDue: drift.Value(newMinDue),
                      status: drift.Value(isSettled ? 'settled' : 'active'),
                    ),
                  );

                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Confirm Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PAY STANDARD LOAN EMI DIALOG
  // ---------------------------------------------------------------------------
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
