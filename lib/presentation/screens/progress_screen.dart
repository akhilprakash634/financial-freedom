import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../providers/app_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debtsAsync = ref.watch(debtsStreamProvider);
    final settingsAsync = ref.watch(settingsFutureProvider);
    final currency = settingsAsync.value?.primaryCurrency ?? '₹';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debt Elimination Milestones'),
      ),
      body: debtsAsync.when(
        data: (debts) {
          final originalTotal = debts.fold(0.0, (sum, d) => sum + d.originalAmount);
          final currentTotal = debts.where((d) => d.status == 'active').fold(0.0, (sum, d) => sum + d.currentBalance);
          final eliminated = (originalTotal - currentTotal).clamp(0.0, double.infinity);
          final progressRatio = originalTotal > 0 ? (eliminated / originalTotal).clamp(0.0, 1.0) : 1.0;

          final milestones = [
            ('First Debt Settled', debts.any((d) => d.status == 'settled')),
            ('₹25,000 Debt Paid Off', eliminated >= 25000),
            ('₹50,000 Debt Paid Off', eliminated >= 50000),
            ('₹1,000,000 Debt Paid Off', eliminated >= 100000),
            ('25% Debt Free', progressRatio >= 0.25),
            ('50% Debt Free', progressRatio >= 0.50),
            ('75% Debt Free', progressRatio >= 0.75),
            ('100% DEBT FREE!', progressRatio >= 1.0),
          ];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Total Debt Payoff Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progressRatio,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                        backgroundColor: AppTheme.borderDark,
                        color: AppTheme.primaryEmerald,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Eliminated: ${CurrencyFormatter.format(eliminated, currencySymbol: currency)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.positiveGreen)),
                          Text('${(progressRatio * 100).toStringAsFixed(1)}% Free', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentIndigo)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Milestones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              ...milestones.map((m) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        m.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: m.$2 ? AppTheme.positiveGreen : AppTheme.neutralGray,
                      ),
                      title: Text(
                        m.$1,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: m.$2 ? Colors.white : AppTheme.neutralGray,
                          decoration: m.$2 ? TextDecoration.none : TextDecoration.none,
                        ),
                      ),
                    ),
                  )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
