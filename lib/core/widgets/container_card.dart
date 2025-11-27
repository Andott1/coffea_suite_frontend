import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class ContainerCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final Color backgroundColor;
  final List<BoxShadow>? boxShadow;
  final bool expand; // for animated expansion
  final Duration animationDuration;
  final CrossAxisAlignment crossAxisAlignment;

  const ContainerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 16,
    this.backgroundColor = ThemeConfig.white,
    this.boxShadow,
    this.expand = false,
    this.animationDuration = const Duration(milliseconds: 250),
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveShadow = boxShadow ??
        [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ];

    // Expand animation only affects vertical expansion (height)
    return AnimatedContainer(
      duration: animationDuration,
      curve: Curves.easeInOut,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: effectiveShadow,
      ),
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [child],
      ),
    );
  }
}
