import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/services/cash_flow_engine.dart';
import '../providers/app_providers.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';
    final currentDate = ref.watch(currentDateProvider);

    final incomeAsync = ref.watch(incomeSourcesStreamProvider);
    final debtsAsync = ref.watch(debtsStreamProvider);
    final rulesAsync = ref.watch(recurringRulesStreamProvider);

    final forecast = CashFlowEngine.forecastCashFlow(
      startingActualCash: 0.0,
      currentDate: currentDate,
      incomeSources: incomeAsync.value ?? [],
      activeDebts: debtsAsync.value ?? [],
      recurringRules: rulesAsync.value ?? [],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Calendar'),
      ),
      body: forecast.timeline.isEmpty
          ? const Center(child: Text('No events scheduled on calendar.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: forecast.timeline.length,
              itemBuilder: (context, index) {
                final item = forecast.timeline[index];
                final isIncome = item.amount > 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isIncome
                          ? AppTheme.positiveGreen.withValues(alpha: 0.2)
                          : AppTheme.negativeRed.withValues(alpha: 0.2),
                      child: Icon(
                        isIncome ? Icons.event_available : Icons.event_busy,
                        color: isIncome ? AppTheme.positiveGreen : AppTheme.negativeRed,
                      ),
                    ),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(DateFormat('EEEE, MMM dd, yyyy').format(item.date)),
                    trailing: Text(
                      '${isIncome ? '+' : ''}${CurrencyFormatter.format(item.amount, currencySymbol: currency)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isIncome ? AppTheme.positiveGreen : AppTheme.negativeRed,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
