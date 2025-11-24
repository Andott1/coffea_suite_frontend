import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';

class NumericPad extends StatelessWidget {
  final Function(String) onInput;
  final VoidCallback onClear;
  final VoidCallback onBackspace;

  const NumericPad({
    super.key,
    required this.onInput,
    required this.onClear,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate button sizes based on available space
        final btnHeight = (constraints.maxHeight - 30) / 4; // 4 rows, minus spacing
        
        return Column(
          children: [
            _buildRow(['7', '8', '9'], btnHeight),
            const SizedBox(height: 10),
            _buildRow(['4', '5', '6'], btnHeight),
            const SizedBox(height: 10),
            _buildRow(['1', '2', '3'], btnHeight),
            const SizedBox(height: 10),
            _buildBottomRow(btnHeight),
          ],
        );
      }
    );
  }

  Widget _buildRow(List<String> keys, double height) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: keys.map((k) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _PadButton(
                label: k, 
                onTap: () => onInput(k),
                color: Colors.white,
                textColor: ThemeConfig.primaryGreen,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomRow(double height) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // CLEAR BUTTON
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _PadButton(
                label: "C", 
                onTap: onClear, 
                color: Colors.red.shade50,
                textColor: Colors.red,
              ),
            ),
          ),
          // ZERO
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _PadButton(
                label: "0", 
                onTap: () => onInput("0"),
                color: Colors.white,
                textColor: ThemeConfig.primaryGreen,
              ),
            ),
          ),
          // DOT (Decimal)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _PadButton(
                label: ".", 
                onTap: () => onInput("."),
                color: Colors.white,
                textColor: ThemeConfig.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color textColor;

  const _PadButton({
    required this.label,
    required this.onTap,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
/// <<END FILE>>