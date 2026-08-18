import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);

    final currency = settingsAsync.value?.primaryCurrency ?? '₹';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Command Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(currentDateProvider.notifier).state = DateTime.now();
            },
            tooltip: 'Recalculate Today',
          ),
        ],
      ),
      body: snapshotAsync.when(
        data: (snapshot) {
          final isNegativeSafe = snapshot.safeToSpendNow < 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(currentDateProvider.notifier).state = DateTime.now();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Cash Flow Warning Banner (if cash insufficient before next confirmed income)
                if (snapshot.hasCashFlowWarning)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0x33EF4444),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                            SizedBox(width: 8),
                            Text('🔴 Cash Flow Warning', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your current actual cash (${CurrencyFormatter.format(snapshot.actualCash, currencySymbol: currency)}) is lower than upcoming mandatory obligations before your next confirmed income.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                // 2. Primary Financial Header Cards (Responsive Stack/Row)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;
                    final cashCard = _buildMetricCard(
                      context,
                      title: 'Actual Cash',
                      value: CurrencyFormatter.format(snapshot.actualCash, currencySymbol: currency),
                      subtitle: 'In bank & wallets',
                      color: const Color(0xFF10B981),
                      icon: Icons.account_balance_wallet,
                    );
                    final safeCard = _buildMetricCard(
                      context,
                      title: 'Safe To Spend Now',
                      value: CurrencyFormatter.format(snapshot.safeToSpendNow, currencySymbol: currency),
                      subtitle: isNegativeSafe ? '⚠️ Deficit before income' : 'Before next income',
                      color: isNegativeSafe ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                      icon: isNegativeSafe ? Icons.warning_amber : Icons.verified_user,
                    );

                    if (isNarrow) {
                      return Column(
                        children: [
                          cashCard,
                          const SizedBox(height: 12),
                          safeCard,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: cashCard),
                        const SizedBox(width: 12),
                        Expanded(child: safeCard),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 3. Money Owed To You & Salary Arrears
                Card(
                  color: AppTheme.cardDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
                  ),
                  child: InkWell(
                    onTap: () => context.push('/receivables'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.pending_actions, color: Color(0xFF38BDF8), size: 20),
                                    SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Money Owed To You',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    CurrencyFormatter.format(snapshot.moneyOwedToMe, currencySymbol: currency),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.neutralGray),
                                ],
                              ),
                            ],
                          ),
                          if (snapshot.salaryArrears > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0x22EF4444),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Salary Arrears (${snapshot.salaryArrearsMonths} mos pending)',
                                      style: const TextStyle(fontSize: 13, color: Colors.white),
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(snapshot.salaryArrears, currencySymbol: currency),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Responsive Next Income & Affordability Breakdown
                Card(
                  color: AppTheme.cardDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 360;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isNarrow) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Next Confirmed Income', style: TextStyle(color: AppTheme.neutralGray, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.format(snapshot.nextConfirmedIncomeAmount, currencySymbol: currency),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                  ),
                                  if (snapshot.nextConfirmedIncomeDate != null)
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(snapshot.nextConfirmedIncomeDate!),
                                      style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Next Expected Income', style: TextStyle(color: AppTheme.neutralGray, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.format(snapshot.nextExpectedIncomeAmount, currencySymbol: currency),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEAB308)),
                                  ),
                                  if (snapshot.nextExpectedIncomeDate != null)
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(snapshot.nextExpectedIncomeDate!),
                                      style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray),
                                    ),
                                ],
                              ),
                            ] else ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Next Confirmed Income', style: TextStyle(color: AppTheme.neutralGray, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyFormatter.format(snapshot.nextConfirmedIncomeAmount, currencySymbol: currency),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                        if (snapshot.nextConfirmedIncomeDate != null)
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(snapshot.nextConfirmedIncomeDate!),
                                            style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 45, color: const Color(0xFF334155)),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Next Expected Income', style: TextStyle(color: AppTheme.neutralGray, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          CurrencyFormatter.format(snapshot.nextExpectedIncomeAmount, currencySymbol: currency),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFEAB308)),
                                        ),
                                        if (snapshot.nextExpectedIncomeDate != null)
                                          Text(
                                            DateFormat('MMM dd, yyyy').format(snapshot.nextExpectedIncomeDate!),
                                            style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 24, color: Color(0xFF334155)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Required Before Next Income', style: TextStyle(color: AppTheme.neutralGray, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyFormatter.format(snapshot.mandatoryPaymentsBeforeNextConfirmedIncome, currencySymbol: currency),
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Monthly Disposable', style: TextStyle(color: AppTheme.neutralGray, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text(
                                        CurrencyFormatter.format(snapshot.monthlyDisposableAmount, currencySymbol: currency),
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                                      ),
                                    ],
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

                // 5. Financial Reality Section
                Card(
                  color: AppTheme.cardDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Financial Reality Summary',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        _buildRealityRow('Cash Flow Status', snapshot.financialRealityIndicators['Cash Flow'] ?? '🟢'),
                        _buildRealityRow('Debt Burden', snapshot.financialRealityIndicators['Debt Burden'] ?? '🟢'),
                        _buildRealityRow('Income Reliability', snapshot.financialRealityIndicators['Income Reliability'] ?? '🟢'),
                        _buildRealityRow('Safety Buffer', snapshot.financialRealityIndicators['Safety Buffer'] ?? '🟢'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 6. Actionable Priorities Box
                Card(
                  color: AppTheme.cardDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.task_alt, color: Color(0xFF10B981), size: 20),
                            SizedBox(width: 8),
                            Text('Today\'s Actions & Priorities', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...snapshot.todayActions.map((action) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                  Expanded(
                                    child: Text(action, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 7. Debt & Obligation Summary Header with Minimum Due
                Card(
                  color: AppTheme.cardDark,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Debt & Obligation Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: _buildDebtStat('Total Outstanding', CurrencyFormatter.format(snapshot.totalDebt, currencySymbol: currency))),
                            Expanded(child: _buildDebtStat('Full Monthly Bill & EMI', CurrencyFormatter.format(snapshot.totalMonthlyDebtPayment, currencySymbol: currency))),
                            Expanded(child: _buildDebtStat('Compulsory Minimum Due', CurrencyFormatter.format(snapshot.minimumRequiredDebtPayment, currencySymbol: currency))),
                          ],
                        ),
                        const Divider(height: 24, color: Color(0xFF334155)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Next Debt Target', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                  Text(snapshot.nextDebtTarget, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6366F1))),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('Debt-Free Date', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                                Text(
                                  snapshot.projectedDebtFreeDate != null
                                      ? DateFormat('MMM yyyy').format(snapshot.projectedDebtFreeDate!)
                                      : 'Debt Free!',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error loading dashboard: $err')),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Card(
      color: AppTheme.cardDark,
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
                    title,
                    style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray)),
          ],
        ),
      ),
    );
  }

  Widget _buildDebtStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildRealityRow(String label, String statusIndicator) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(statusIndicator, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
