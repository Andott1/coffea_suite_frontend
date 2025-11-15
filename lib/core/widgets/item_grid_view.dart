/// <<FILE: lib/core/widgets/item_grid_view.dart>>
import 'package:flutter/material.dart';
import '../../config/font_config.dart';

/// A generic, reusable grid layout for displaying lists of items.
/// Works with ItemCard for product UI.
class ItemGridView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// If true, adjusts the number of columns based on available width
  final bool responsive;

  /// Minimum width of each item for responsive layout
  final double minItemWidth;

  /// Default grid settings if not responsive
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;

  final EdgeInsetsGeometry padding;
  final Widget? emptyState;
  final ScrollPhysics? physics;

  const ItemGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.responsive = true,
    this.minItemWidth = 185,
    this.crossAxisCount = 4,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    this.childAspectRatio = 1.1,
    this.padding = const EdgeInsets.only(top: 10, right: 5),
    this.emptyState,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: emptyState ?? Text("No items found.", style: FontConfig.h3(context)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        int effectiveCount = crossAxisCount;

        if (responsive) {
          effectiveCount = (constraints.maxWidth / minItemWidth).floor().clamp(1, 6);
        }

        return GridView.builder(
          padding: padding,
          physics: physics,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: effectiveCount,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return itemBuilder(context, item); // Pass item to builder
          },
        );
      },
    );
  }
}
