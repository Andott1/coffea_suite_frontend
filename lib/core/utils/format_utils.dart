import 'dart:math';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class FormatUtils {
  /// Formats a number into a readable currency string (with commas and 2 decimals)
  static String formatCurrency(double value, {String symbol = "₱"}) {
    final formatter = NumberFormat.currency(
      locale: 'en_PH', 
      symbol: symbol,
      decimalDigits: 2,
    );
    return formatter.format(value);
  }

  /// Formats quantity to show decimals only when needed.
  static String formatQuantity(double value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }
  
  static double roundDouble(double value) {
    double mod = pow(10.0, 2).toDouble();
    return ((value * mod).round().toDouble() / mod);
  }
}

/// ✅ UPDATED: Smart Currency Formatter
/// - Auto-adds commas (1000 -> 1,000)
/// - No shifting (Input "5" is "5", not "0.05")
/// - Allows manual decimal entry
class CurrencyInputFormatter extends TextInputFormatter {
  
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Get the new text
    String newText = newValue.text;

    // 2. Handle Empty Case
    if (newText.isEmpty) {
      return newValue;
    }

    // 3. Clean: Remove existing commas to analyze raw input
    String cleanText = newText.replaceAll(',', '');

    // 4. Validate: Allow Digits and ONE optional Dot (max 2 decimal places)
    // Regex explanation:
    // ^        Start
    // \d* Zero or more digits
    // \.?      Optional single dot
    // \d{0,2}  Zero to two decimal digits
    // $        End
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(cleanText)) {
      // If input is invalid (e.g., two dots, letters), reject change
      return oldValue;
    }

    // 5. Split Integer and Decimal parts
    List<String> parts = cleanText.split('.');
    String integerPart = parts[0];
    
    // Handle leading zeros (prevent "05") unless it's just "0"
    if (integerPart.length > 1 && integerPart.startsWith('0')) {
      integerPart = integerPart.substring(1);
    }
    if (integerPart.isEmpty && parts.length > 1) {
      integerPart = "0"; // Handle ".50" -> "0.50"
    }

    // 6. Format Integer Part with Commas
    String formattedInteger = "";
    if (integerPart.isNotEmpty) {
      final formatter = NumberFormat('#,###', 'en_PH');
      formattedInteger = formatter.format(int.parse(integerPart));
    }

    // 7. Reassemble (Integer + Decimal)
    String newFormattedText = formattedInteger;
    // Add decimal part if it exists
    if (parts.length > 1) {
      newFormattedText += ".${parts[1]}";
    } else if (newText.endsWith('.')) {
      // User just typed the dot, keep it
      newFormattedText += ".";
    }

    // 8. Smart Cursor Positioning
    // We count how many "content digits" (0-9 and .) were before the cursor
    // in the raw input, then find that same position in the formatted string.
    
    int initialCursor = newValue.selection.baseOffset;
    int digitsBeforeCursor = 0;
    
    // Count significant chars before the cursor in the USER'S input
    for (int i = 0; i < min(initialCursor, newText.length); i++) {
      if (newText[i].contains(RegExp(r'[0-9.]'))) {
        digitsBeforeCursor++;
      }
    }

    // Traverse the NEW formatted text to place cursor after the same amount of digits
    int newCursorOffset = 0;
    int digitsSeen = 0;
    
    for (int i = 0; i < newFormattedText.length; i++) {
      if (digitsSeen >= digitsBeforeCursor) break;
      
      if (newFormattedText[i].contains(RegExp(r'[0-9.]'))) {
        digitsSeen++;
      }
      newCursorOffset++;
    }

    return TextEditingValue(
      text: newFormattedText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }
}