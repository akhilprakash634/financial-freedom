import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      ('Money Owed To You (Receivables)', Icons.pending_actions, '/receivables', 'Track salary arrears & freelance receivables'),
      ('Income Sources', Icons.attach_money, '/income', 'Manage salary, freelance & other income'),
      ('Recurring Rules', Icons.autorenew, '/recurring-rules', 'Manage monthly salary & expense rules'),
      ('Calendar View', Icons.calendar_month, '/calendar', 'Visual date overview of obligations'),
      ('Monthly Plan', Icons.assessment, '/monthly-plan', 'Budgeting & actual vs planned overview'),
      ('Progress & Milestones', Icons.emoji_events, '/progress', 'Debt elimination milestones'),
      ('App Settings', Icons.settings, '/settings', 'Currency, safety buffer & debt strategy'),
      ('Backup & Privacy', Icons.backup, '/backup', 'Export JSON/CSV & offline privacy'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('More Tools'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: menuItems.length,
        itemBuilder: (context, index) {
          final item = menuItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                child: Icon(item.$2, color: AppTheme.primaryEmerald),
              ),
              title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text(item.$4, style: const TextStyle(fontSize: 12, color: AppTheme.neutralGray)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.neutralGray),
              onTap: () => context.push(item.$3),
            ),
          );
        },
      ),
    );
  }
}
