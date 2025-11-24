import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../utils/format_utils.dart';

class BasicInputField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType inputType;
  final bool isRequired;
  final bool isCurrency;
  final bool isPassword;
  final FocusNode? focusNode; // ✅ Added for explicit focus control

  const BasicInputField({
    super.key,
    required this.label,
    required this.controller,
    this.inputType = TextInputType.text,
    this.isRequired = true,
    this.isCurrency = false,
    this.isPassword = false,
    this.focusNode,
  });

  @override
  State<BasicInputField> createState() => _BasicInputFieldState();
}

class _BasicInputFieldState extends State<BasicInputField> {
  bool _isObscured = true;
  late List<TextInputFormatter> _formatters;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.isPassword;
    
    // ✅ Optimization: Initialize formatters once, not on every build
    _formatters = [];
    if (widget.isCurrency) {
      _formatters.add(CurrencyInputFormatter());
    } else if (widget.inputType == TextInputType.number) {
      _formatters.add(FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode, // ✅ Use passed node if available
      keyboardType: widget.inputType,
      inputFormatters: _formatters,
      obscureText: widget.isPassword ? _isObscured : false,
      style: const TextStyle(
        color: ThemeConfig.primaryGreen,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
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
        prefixText: widget.isCurrency ? "₱ " : null,
        prefixStyle: const TextStyle(
          color: ThemeConfig.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility_off : Icons.visibility,
                  color: ThemeConfig.midGray,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              )
            : null,
      ),
      validator: (v) {
        if (widget.isRequired && (v == null || v.trim().isEmpty)) {
          return "${widget.label} is required";
        }
        return null;
      },
    );
  }
}
