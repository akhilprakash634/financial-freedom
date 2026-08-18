import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../services/backup_service.dart';
import '../providers/app_providers.dart';

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Backup & Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.security, color: AppTheme.primaryEmerald, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🔒 100% Offline & Private.\nYour financial data is stored securely on your local device only and is never uploaded anywhere.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.download, color: AppTheme.primaryEmerald),
              title: const Text('Export Complete Data (JSON)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Generates full database backup in JSON format'),
              onTap: () async {
                final db = ref.read(databaseProvider);
                final jsonStr = await BackupService.exportToJson(db);
                await Clipboard.setData(ClipboardData(text: jsonStr));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON Backup copied to Clipboard!')),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.table_chart, color: AppTheme.accentIndigo),
              title: const Text('Export Transactions (CSV)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Export ledger activity to CSV table'),
              onTap: () async {
                final db = ref.read(databaseProvider);
                final csvStr = await BackupService.exportTransactionsToCsv(db);
                await Clipboard.setData(ClipboardData(text: csvStr));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV Export copied to Clipboard!')),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
