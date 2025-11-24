import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

/// The base reusable dialog container.
/// Provides:
/// - Dimmed background
/// - Centered modal
/// - Rounded corners
/// - Shadow
/// - Customizable width
/// - Automatic handling of keyboard inset & safe area
///
/// This widget contains **NO TITLE and NO BUTTONS**.
/// Other widgets like DialogBoxTitled or DialogBoxEditable should wrap around this.
class DialogBox extends StatelessWidget {
  final Widget child;

  /// Width of the dialog content.
  final double width;

  /// Padding *inside* the dialog box.
  final EdgeInsetsGeometry padding;

  /// Border radius for consistent styling across dialogs.
  final double borderRadius;

  /// Whether tapping outside closes the dialog.
  final bool dismissOnOutsideTap;

  const DialogBox({
    super.key,
    required this.child,
    this.width = 500,
    this.padding = const EdgeInsets.all(24),
    this.borderRadius = 16,
    this.dismissOnOutsideTap = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Close dialog when tapping outside
      onTap: dismissOnOutsideTap ? () => Navigator.pop(context) : null,
      child: Stack(
        children: [
          // Dimmed background
          AnimatedOpacity(
            opacity: 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),

          // Dialog content (centered)
          Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside
              child: Material(
                color: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: width,
                  padding: padding,
                  decoration: BoxDecoration(
                    color: ThemeConfig.white,
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
