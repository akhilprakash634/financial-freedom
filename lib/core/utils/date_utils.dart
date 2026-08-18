import '../../core/constants/enums.dart';

class AppDateUtils {
  /// Returns the maximum number of days in a given year and month.
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month];
  }

  /// Clamps target day of month to valid day range for specified year and month.
  static int clampDayOfMonth(int year, int month, int targetDay) {
    final maxDays = daysInMonth(year, month);
    return targetDay > maxDays ? maxDays : (targetDay < 1 ? 1 : targetDay);
  }

  /// Calculates the last valid date for a target day of month in a given month.
  /// For instance, day 31 in February 2026 returns Feb 28, 2026.
  /// Day 31 in April 2026 returns April 30, 2026.
  static DateTime getValidDateForMonth(int year, int month, int targetDay) {
    final day = clampDayOfMonth(year, month, targetDay);
    return DateTime(year, month, day);
  }

  /// Returns true if two dates represent the same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Strips time components and returns a DateTime at 00:00:00.
  static DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Resolves the PaymentStatus based on due date and paid status.
  static PaymentStatus calculatePaymentStatus({
    required DateTime dueDate,
    required DateTime currentDate,
    required bool isPaid,
    bool isCancelled = false,
  }) {
    if (isPaid) return PaymentStatus.paid;
    if (isCancelled) return PaymentStatus.cancelled;

    final due = dateOnly(dueDate);
    final today = dateOnly(currentDate);

    if (due.isBefore(today)) {
      return PaymentStatus.overdue;
    } else if (isSameDay(due, today)) {
      return PaymentStatus.due;
    } else {
      return PaymentStatus.upcoming;
    }
  }

  /// Generates recurring dates for a monthly rule targeting a specific day of month.
  static List<DateTime> generateMonthlyOccurrences({
    required int targetDay,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final occurrences = <DateTime>[];
    var currentYear = startDate.year;
    var currentMonth = startDate.month;

    final end = dateOnly(endDate);

    while (true) {
      final validDate = getValidDateForMonth(currentYear, currentMonth, targetDay);
      if (validDate.isAfter(end)) break;

      if (!validDate.isBefore(dateOnly(startDate))) {
        occurrences.add(validDate);
      }

      currentMonth++;
      if (currentMonth > 12) {
        currentMonth = 1;
        currentYear++;
      }
    }

    return occurrences;
  }
}
