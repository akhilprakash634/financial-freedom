import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/services/cash_flow_engine.dart';
import '../providers/app_providers.dart';

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(financialSnapshotProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';

    final incomeAsync = ref.watch(incomeSourcesStreamProvider);
    final debtsAsync = ref.watch(debtsStreamProvider);
    final rulesAsync = ref.watch(recurringRulesStreamProvider);
    final currentDate = ref.watch(currentDateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Flow Timeline'),
      ),
      body: snapshotAsync.when(
        data: (snapshot) {
          final startingCash = snapshot.actualCash;
          final forecast = CashFlowEngine.forecastCashFlow(
            startingActualCash: startingCash,
            currentDate: currentDate,
            incomeSources: incomeAsync.value ?? [],
            activeDebts: debtsAsync.value ?? [],
            recurringRules: rulesAsync.value ?? [],
          );

          return Column(
            children: [
              // Summary Header Card
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Starting Cash', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(startingCash, currencySymbol: currency),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 36, color: AppTheme.borderDark),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Lowest Projected', style: TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(forecast.lowestProjectedBalance, currencySymbol: currency),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: forecast.lowestProjectedBalance < snapshot.minimumCashBuffer
                                  ? AppTheme.negativeRed
                                  : AppTheme.positiveGreen,
                            ),
                          ),
                          if (forecast.lowestProjectedBalanceDate != null)
                            Text(
                              DateFormat('MMM dd').format(forecast.lowestProjectedBalanceDate!),
                              style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Timeline Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.timeline, size: 18, color: AppTheme.neutralGray),
                    SizedBox(width: 8),
                    Text('Projected Cash Flow Events', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.neutralGray)),
                  ],
                ),
              ),

              // Timeline Events List
              Expanded(
                child: forecast.timeline.isEmpty
                    ? const Center(child: Text('No upcoming scheduled cash flow events found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: forecast.timeline.length,
                        itemBuilder: (context, index) {
                          final event = forecast.timeline[index];
                          final isPositive = event.amount > 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isPositive
                                    ? AppTheme.positiveGreen.withOpacity(0.2)
                                    : AppTheme.negativeRed.withOpacity(0.2),
                                child: Icon(
                                  isPositive ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isPositive ? AppTheme.positiveGreen : AppTheme.negativeRed,
                                ),
                              ),
                              title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                '${DateFormat('EEE, MMM dd').format(event.date)} • ${event.confidenceStatus}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isPositive ? '+' : ''}${CurrencyFormatter.format(event.amount, currencySymbol: currency)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isPositive ? AppTheme.positiveGreen : AppTheme.negativeRed,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Bal: ${CurrencyFormatter.format(event.projectedBalanceAfter, currencySymbol: currency)}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.neutralGray),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
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
}
