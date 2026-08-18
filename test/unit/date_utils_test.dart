import 'package:flutter_test/flutter_test.dart';
import 'package:financial_freedom/core/utils/date_utils.dart';
import 'package:financial_freedom/core/constants/enums.dart';

void main() {
  group('AppDateUtils - Month End & Leap Year Recurrence Tests', () {
    test('January 31 -> February 28 (Non-Leap Year 2026)', () {
      final febDate = AppDateUtils.getValidDateForMonth(2026, 2, 31);
      expect(febDate.year, 2026);
      expect(febDate.month, 2);
      expect(febDate.day, 28);
    });

    test('January 31 -> February 29 (Leap Year 2028)', () {
      final febDate = AppDateUtils.getValidDateForMonth(2028, 2, 31);
      expect(febDate.year, 2028);
      expect(febDate.month, 2);
      expect(febDate.day, 29);
    });

    test('March 31 -> April 30', () {
      final aprDate = AppDateUtils.getValidDateForMonth(2026, 4, 31);
      expect(aprDate.year, 2026);
      expect(aprDate.month, 4);
      expect(aprDate.day, 30);
    });

    test('May 31 -> June 30', () {
      final junDate = AppDateUtils.getValidDateForMonth(2026, 6, 31);
      expect(junDate.year, 2026);
      expect(junDate.month, 6);
      expect(junDate.day, 30);
    });

    test('December 31 -> January 31', () {
      final janDate = AppDateUtils.getValidDateForMonth(2027, 1, 31);
      expect(janDate.year, 2027);
      expect(janDate.month, 1);
      expect(janDate.day, 31);
    });

    test('Monthly occurrences generator for day 31 targets correct days', () {
      final occurrences = AppDateUtils.generateMonthlyOccurrences(
        targetDay: 31,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 4, 30),
      );

      expect(occurrences.length, 4);
      expect(occurrences[0], DateTime(2026, 1, 31)); // Jan 31
      expect(occurrences[1], DateTime(2026, 2, 28)); // Feb 28
      expect(occurrences[2], DateTime(2026, 3, 31)); // Mar 31
      expect(occurrences[3], DateTime(2026, 4, 30)); // Apr 30
    });

    test('PaymentStatus calculation for upcoming, due, paid, overdue', () {
      final today = DateTime(2026, 8, 17);

      expect(
        AppDateUtils.calculatePaymentStatus(
          dueDate: DateTime(2026, 8, 20),
          currentDate: today,
          isPaid: false,
        ),
        PaymentStatus.upcoming,
      );

      expect(
        AppDateUtils.calculatePaymentStatus(
          dueDate: DateTime(2026, 8, 17),
          currentDate: today,
          isPaid: false,
        ),
        PaymentStatus.due,
      );

      expect(
        AppDateUtils.calculatePaymentStatus(
          dueDate: DateTime(2026, 8, 10),
          currentDate: today,
          isPaid: false,
        ),
        PaymentStatus.overdue,
      );

      expect(
        AppDateUtils.calculatePaymentStatus(
          dueDate: DateTime(2026, 8, 10),
          currentDate: today,
          isPaid: true,
        ),
        PaymentStatus.paid,
      );
    });
  });
}
