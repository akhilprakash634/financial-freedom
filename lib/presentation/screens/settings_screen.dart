import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../core/theme/app_theme.dart';
import '../../data/database/app_database.dart';
import '../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          final currencyCtrl = TextEditingController(text: settings.primaryCurrency);
          final bufferCtrl = TextEditingController(text: settings.minimumCashBuffer.toStringAsFixed(0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Financial Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: currencyCtrl,
                        decoration: const InputDecoration(labelText: r'Primary Currency Symbol (e.g. ₹, $, €, £)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: bufferCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Minimum Cash Safety Buffer'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          final db = ref.read(databaseProvider);
                          final cur = currencyCtrl.text.isEmpty ? '₹' : currencyCtrl.text;
                          final buf = double.tryParse(bufferCtrl.text) ?? 10000.0;

                          await (db.update(db.financialSettings)..where((s) => s.id.equals(settings.id))).write(
                            FinancialSettingsCompanion(
                              primaryCurrency: drift.Value(cur),
                              minimumCashBuffer: drift.Value(buf),
                            ),
                          );

                          ref.invalidate(settingsFutureProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Settings updated successfully!')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryEmerald,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save Settings'),
                      ),
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
}
