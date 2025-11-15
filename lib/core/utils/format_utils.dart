import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class FormatUtils {
  /// Formats a number into a readable currency string (with commas and 2 decimals)
  static String formatCurrency(double value, {String symbol = "₱"}) {
    final formatter = NumberFormat.currency(
      locale: 'en_PH', // Comma-separated, 2 decimals
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(value);
  }
}

/// Live currency input formatter that auto-adds commas while typing.
class CurrencyInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat('#,##0.00', 'en_PH');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digits and non-decimal points
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Convert to double, divide by 100 to simulate cents input
    double value = double.tryParse(digits) ?? 0.0;
    value = value / 100;

    // Format with commas and two decimal places
    final newText = _formatter.format(value);

    // Maintain cursor position at end
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
