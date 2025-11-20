import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import 'dialog_box.dart';

/// A dialog box with a title (and optional subtitle) at the top.
/// Wraps DialogBox to keep modal styling consistent.
/// 
/// Usage:
/// 
/// DialogBoxTitled(
///   title: "Ingredient Details",
///   subtitle: "View full information here",
///   child: Column(
///     children: [
///       ...detail rows...
///       ...buttons...
///     ]
///   )
/// )
class DialogBoxTitled extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  /// Width passes through to DialogBox
  final double width;

  /// Internal padding inside the dialog box
  final EdgeInsetsGeometry padding;

  /// Spacing between title/subtitle/content
  final double titleSpacing;

  final List<Widget>? actions;

  final bool dismissOnOutsideTap;

  const DialogBoxTitled({
    super.key,
    required this.title,
    this.actions,
    this.subtitle,
    required this.child,
    this.width = 500,
    this.padding = const EdgeInsets.all(20),
    this.titleSpacing = 10,
    this.dismissOnOutsideTap = true,
  });

  @override
  Widget build(BuildContext context) {
    return DialogBox(
      width: width,
      padding: padding,
      dismissOnOutsideTap: dismissOnOutsideTap,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─────────────────────────────
          // TITLE
          // ─────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // TITLE (Expands to fill space)
              Expanded(
                child: Text(
                  title,
                  style: FontConfig.h3(context)
                      .copyWith(
                        color: ThemeConfig.primaryGreen
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // OPTIONAL ACTION BUTTONS (e.g., close)
              if (actions != null) ...actions!,
            ],
          ),

          // ─────────────────────────────
          // SUBTITLE (OPTIONAL)
          // ─────────────────────────────
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: FontConfig.h2(context).copyWith(
                color: ThemeConfig.midGray,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],

          SizedBox(height: titleSpacing),

          // ─────────────────────────────
          // CONTENT (passed from caller)
          // ─────────────────────────────
          child,
        ],
      ),
    );
  }
}
