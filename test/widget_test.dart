import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:financial_freedom/main.dart';

void main() {
  testWidgets('FinancialFreedomApp launches and renders Command Center title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FinancialFreedomApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify main app bar title is present
    expect(find.text('Financial Command Center'), findsOneWidget);
  });
}
