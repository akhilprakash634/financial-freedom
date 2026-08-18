import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/navigation_shell.dart';
import '../screens/dashboard_screen.dart';
import '../screens/cash_flow_screen.dart';
import '../screens/debts_screen.dart';
import '../screens/transactions_screen.dart';
import '../screens/more_screen.dart';
import '../screens/income_screen.dart';
import '../screens/receivables_screen.dart';
import '../screens/recurring_rules_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/monthly_plan_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/backup_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return NavigationShell(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/cash-flow',
          builder: (context, state) => const CashFlowScreen(),
        ),
        GoRoute(
          path: '/debts',
          builder: (context, state) => const DebtsScreen(),
        ),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsScreen(),
        ),
        GoRoute(
          path: '/more',
          builder: (context, state) => const MoreScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/receivables',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ReceivablesScreen(),
    ),
    GoRoute(
      path: '/income',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const IncomeScreen(),
    ),
    GoRoute(
      path: '/recurring-rules',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RecurringRulesScreen(),
    ),
    GoRoute(
      path: '/calendar',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/monthly-plan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MonthlyPlanScreen(),
    ),
    GoRoute(
      path: '/progress',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProgressScreen(),
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/backup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BackupScreen(),
    ),
  ],
);
