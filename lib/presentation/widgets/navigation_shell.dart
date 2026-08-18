import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class NavigationShell extends StatelessWidget {
  final Widget child;

  const NavigationShell({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/cash-flow')) return 1;
    if (location.startsWith('/debts')) return 2;
    if (location.startsWith('/transactions')) return 3;
    if (location.startsWith('/more')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/cash-flow');
        break;
      case 2:
        context.go('/debts');
        break;
      case 3:
        context.go('/transactions');
        break;
      case 4:
        context.go('/more');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final isWideScreen = MediaQuery.of(context).size.width >= 640;

    const destinations = [
      (Icon(Icons.dashboard_outlined), Icon(Icons.dashboard), 'Home'),
      (Icon(Icons.timeline_outlined), Icon(Icons.timeline), 'Cash Flow'),
      (Icon(Icons.credit_score_outlined), Icon(Icons.credit_score), 'Debts'),
      (Icon(Icons.receipt_long_outlined), Icon(Icons.receipt_long), 'Transactions'),
      (Icon(Icons.grid_view_outlined), Icon(Icons.grid_view), 'More'),
    ];

    if (isWideScreen) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _onItemTapped(index, context),
              labelType: NavigationRailLabelType.all,
              backgroundColor: AppTheme.cardDark,
              selectedIconTheme: const IconThemeData(color: AppTheme.primaryEmerald),
              selectedLabelTextStyle: const TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold, fontSize: 12),
              unselectedIconTheme: const IconThemeData(color: AppTheme.neutralGray),
              unselectedLabelTextStyle: const TextStyle(color: AppTheme.neutralGray, fontSize: 12),
              destinations: destinations.map((d) {
                return NavigationRailDestination(
                  icon: d.$1,
                  selectedIcon: d.$2,
                  label: Text(d.$3),
                );
              }).toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1, color: AppTheme.borderDark),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => _onItemTapped(index, context),
        items: destinations.map((d) {
          return BottomNavigationBarItem(
            icon: d.$1,
            activeIcon: d.$2,
            label: d.$3,
          );
        }).toList(),
      ),
    );
  }
}
