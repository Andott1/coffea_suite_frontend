import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

/// A reusable clickable card for grid/list items.
/// Uses Material + elevation for proper shadow and ripple behavior.
/// Ideal for ingredients, products, employees, and other item listings.
class ItemCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// Controls the roundness of the corners.
  final double borderRadius;

  /// Padding for the inner content.
  final EdgeInsetsGeometry padding;

  /// Elevation (shadow intensity). Default matches your design.
  final double elevation;

  const ItemCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(20),
    this.elevation = 3, // subtle but visible shadow
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      // background color of the card
      color: ThemeConfig.white,

      // Material's built-in shadow system (correct layering)
      elevation: elevation,
      shadowColor: Colors.black.withValues(alpha: 0.2),

      // Ensures InkWell uses the same clipping
      borderRadius: BorderRadius.circular(borderRadius),

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),

        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
