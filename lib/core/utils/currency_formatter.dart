import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount, {String currencySymbol = '₹', int decimalDigits = 0}) {
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: decimalDigits,
    );
    return formatter.format(amount);
  }

  static String formatCompact(double amount, {String currencySymbol = '₹'}) {
    final formatter = NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }
}
