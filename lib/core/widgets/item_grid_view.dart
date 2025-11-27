import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';

/// A generic, reusable grid layout for displaying lists of items.
/// Supports responsive column count and customizable spacing.
///
/// Example:
/// ```dart
/// ItemGridView<IngredientModel>(
///   items: ingredients,
///   itemBuilder: (context, item) => IngredientCard(item: item),
/// )
/// ```
class ItemGridView<T> extends StatelessWidget {
  /// The list of items to render.
  final List<T> items;

  /// The builder that builds each grid item widget.
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// If true, automatically determines the number of columns
  /// based on available width and [minItemWidth].
  final bool responsive;

  /// The minimum width each item should have in responsive mode.
  final double minItemWidth;

  /// Fixed number of columns (ignored when [responsive] = true).
  final int crossAxisCount;

  /// Space between columns.
  final double crossAxisSpacing;

  /// Space between rows.
  final double mainAxisSpacing;

  /// Aspect ratio (width / height) of each grid item.
  final double childAspectRatio;

  /// Padding inside the grid.
  final EdgeInsetsGeometry padding;

  /// Optional widget to show when [items] is empty.
  final Widget? emptyState;

  /// Scroll physics (e.g. disable scrolling inside scrollable parents).
  final ScrollPhysics? physics;

  const ItemGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.responsive = true,
    this.minItemWidth = 360,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 10,
    this.mainAxisSpacing = 10,
    this.childAspectRatio = 1.6,
    this.padding = const EdgeInsets.all(0),
    this.emptyState,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: emptyState ??
            Text(
              "No items found.",
              style: FontConfig.h3(context)
            ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine column count based on available width if responsive
        int effectiveCrossAxisCount = crossAxisCount;
        if (responsive) {
          final availableWidth = constraints.maxWidth;
          effectiveCrossAxisCount =
              (availableWidth / minItemWidth).floor().clamp(1, 6);
        }

        return GridView.builder(
          padding: padding,
          physics: physics,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: effectiveCrossAxisCount,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return itemBuilder(context, item);
          },
        );
      },
    );
  }
}
