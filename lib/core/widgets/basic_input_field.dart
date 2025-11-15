import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../utils/format_utils.dart';

/// A reusable basic input field for text or numeric values.
/// Used for ingredient name, quantity, and unit cost.
class BasicInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType inputType;
  final bool isRequired;
  final bool isCurrency; // for ₱ prefix and live formatter

  const BasicInputField({
    super.key,
    required this.label,
    required this.controller,
    this.inputType = TextInputType.text,
    this.isRequired = true,
    this.isCurrency = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine input formatters
    final List<TextInputFormatter> formatters = [];
    if (isCurrency) {
      formatters.add(CurrencyInputFormatter());
    } else if (inputType == TextInputType.number) {
      formatters.add(FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')));
    }

    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      inputFormatters: formatters,
      style: const TextStyle(
        color: ThemeConfig.primaryGreen,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: FontConfig.inputLabel(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixText: isCurrency ? "₱ " : null,
        prefixStyle: const TextStyle(
          color: ThemeConfig.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
      validator: (v) {
        if (isRequired && (v == null || v.trim().isEmpty)) {
          return "$label is required";
        }
        return null;
      },
    );
  }
}
