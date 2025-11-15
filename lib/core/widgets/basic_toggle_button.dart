import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';

class BasicToggleButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;

  final String label;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  /// Optional width override (same as BasicDropdownButton)
  final double? width;

  final bool enabled;

  final int badgeCount;

  const BasicToggleButton({
    super.key,
    required this.expanded,
    required this.onPressed,
    this.label = "Toggle",
    this.height = 48,
    this.borderRadius = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.width,
    this.enabled = true,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !enabled;

    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Ink(
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                width: 2,
                color: isDisabled
                    ? ThemeConfig.midGray.withOpacity(0.4)
                    : ThemeConfig.primaryGreen,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        label,
                        style: FontConfig.inputLabel(context).copyWith(
                          color: isDisabled
                              ? ThemeConfig.midGray.withOpacity(0.4)
                              : ThemeConfig.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // ──────────────────────────────
                      // BADGE for # of active filters
                      // ──────────────────────────────
                      if (badgeCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          "($badgeCount)",
                          style: FontConfig.body(context).copyWith(
                            fontSize: FontConfig.body(context).fontSize! * 0.9,
                            color: ThemeConfig.primaryGreen.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: expanded ? 0.5 : 0.0,
                  child: Icon(
                    Icons.arrow_drop_down,
                    size: 26,
                    color: isDisabled
                        ? ThemeConfig.midGray.withOpacity(0.4)
                        : ThemeConfig.primaryGreen,
                  ),
                ),
              ],
            )
          ),
        ),
      ),
    );
  }
}
