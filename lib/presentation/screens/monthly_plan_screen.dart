import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../providers/app_providers.dart';

class MonthlyPlanScreen extends ConsumerWidget {
  const MonthlyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Financial Plan'),
      ),
      body: snapshotAsync.when(
        data: (snapshot) {
          final expectedIncome = snapshot.confirmedFutureIncome + snapshot.expectedFutureIncome;
          final mandatoryDebts = snapshot.upcomingMandatoryPayments;
          final essentialExpenses = snapshot.plannedEssentialExpenses;
          final buffer = snapshot.minimumCashBuffer;
          final remaining = expectedIncome - (mandatoryDebts + essentialExpenses + buffer);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Monthly Income vs Obligations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      _buildRow('Expected Income', expectedIncome, currency, AppTheme.positiveGreen),
                      const Divider(color: AppTheme.borderDark),
                      _buildRow('Mandatory Debt Payments', -mandatoryDebts, currency, AppTheme.negativeRed),
                      _buildRow('Planned Essential Expenses', -essentialExpenses, currency, AppTheme.warningAmber),
                      _buildRow('Minimum Safety Buffer', -buffer, currency, AppTheme.accentIndigo),
                      const Divider(color: AppTheme.borderDark),
                      _buildRow('Net Surplus / Deficit', remaining, currency, remaining >= 0 ? AppTheme.positiveGreen : AppTheme.negativeRed, isBold: true),
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

  Widget _buildRow(String title, double amount, String currency, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            CurrencyFormatter.format(amount, currencySymbol: currency),
            style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
