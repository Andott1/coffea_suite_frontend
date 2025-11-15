/// <<FILE: lib/core/widgets/item_card.dart>>
import 'package:flutter/material.dart';
import '../../core/models/product_model.dart';

/// A reusable clickable card for grid/list items.
/// Can display product content and trigger actions like dialogs.
class ItemCard extends StatelessWidget {
  final ProductModel? product; // optional product reference
  final VoidCallback? onTap;

  /// Card radius
  final double borderRadius;

  /// Padding inside
  final EdgeInsetsGeometry padding;

  /// Background color
  final Color backgroundColor;

  /// Border color + width
  final Color borderColor;
  final double borderWidth;

  /// Shadow depth
  final double elevation;

  /// Optional custom child, overrides product layout
  final Widget? child;

  const ItemCard({
    super.key,
    this.product,
    this.onTap,
    this.borderRadius = 25,
    this.padding = const EdgeInsets.all(16),
    this.backgroundColor = const Color(0xFFFEFAE0),
    this.borderColor = const Color(0xFF00401B),
    this.borderWidth = 1,
    this.elevation = 3,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      elevation: elevation,
      shadowColor: Colors.black.withOpacity(0.15),
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          child: child ?? _buildProductContent(context),
        ),
      ),
    );
  }

  /// Builds default layout when a product is provided
  Widget _buildProductContent(BuildContext context) {
    if (product == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Center(
            child: Image.asset(
              product!.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.broken_image,
                  size: 50,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product!.name,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
