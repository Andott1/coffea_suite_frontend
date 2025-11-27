import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';

enum AppButtonType {
  primary,
  secondary,
  danger,
  neutral,
}

class BasicButton extends StatelessWidget {
  final String label;
  final AppButtonType type;
  final VoidCallback? onPressed;
  final IconData? icon;

  final bool fullWidth;
  final double height;
  final EdgeInsetsGeometry padding;

  final double? fontSize;

  const BasicButton({
    super.key,
    required this.label,
    required this.type,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    final radius = BorderRadius.circular(10);

    // Determine which icon to show
    final IconData? finalIcon = isDisabled
        ? Icons.lock   // Always show lock when disabled
        : icon;        // Otherwise, show original icon

    switch (type) {
      case AppButtonType.primary:
        return _buildPrimary(radius, context, isDisabled, finalIcon);

      case AppButtonType.secondary:
      case AppButtonType.danger:
      case AppButtonType.neutral:
        return _buildOutlined(radius, context, isDisabled, finalIcon);
    }
  }

  // ─────────────────────────────────────────────
  // PRIMARY BUTTON (solid)
  // ─────────────────────────────────────────────
  Widget _buildPrimary(BorderRadius radius, BuildContext context,
      bool isDisabled, IconData? finalIcon) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? ThemeConfig.midGray.withValues(alpha: 0.4)
              : ThemeConfig.primaryGreen,
          elevation: isDisabled ? 0 : 2,
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: fullWidth ? EdgeInsets.zero : padding,
        ),
        child: _buildContent(
          context,
          textColor: isDisabled ? Colors.white70 : Colors.white,
          iconData: finalIcon,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // OUTLINED BUTTONS (secondary, danger, neutral)
  // ─────────────────────────────────────────────
  Widget _buildOutlined(BorderRadius radius, BuildContext context,
      bool isDisabled, IconData? finalIcon) {
    late Color borderColor;
    late Color textColor;

    switch (type) {
      case AppButtonType.secondary:
        borderColor = ThemeConfig.primaryGreen;
        textColor = ThemeConfig.primaryGreen;
        break;

      case AppButtonType.danger:
        borderColor = Colors.redAccent;
        textColor = Colors.redAccent;
        break;

      case AppButtonType.neutral:
      default:
        borderColor = ThemeConfig.midGray;
        textColor = ThemeConfig.midGray;
        break;
    }

    if (isDisabled) {
      borderColor = ThemeConfig.midGray.withValues(alpha: 0.3);
      textColor = ThemeConfig.midGray.withValues(alpha: 0.4);
    }

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: height,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor, width: 2),
          shape: RoundedRectangleBorder(borderRadius: radius),
          padding: fullWidth ? EdgeInsets.zero : padding,
        ),
        child: _buildContent(
          context,
          textColor: textColor,
          iconData: finalIcon,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SHARED CONTENT (Text + Optional Icon)
  // ─────────────────────────────────────────────
  Widget _buildContent(
    BuildContext context, {
    required Color textColor,
    required IconData? iconData,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconData != null) ...[
          Icon(iconData, color: textColor, size: fontSize != null ? fontSize! + 4 : 20),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: FontConfig.buttonLarge(context).copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
