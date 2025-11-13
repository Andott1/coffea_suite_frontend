import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import 'container_card.dart';

/// A reusable card layout with a built-in section title.
/// Ideal for admin panels or grouped content sections.
///
/// Example usage:
/// ```dart
/// ContainerCardTitled(
///   title: "Add New Ingredient",
///   child: AddIngredientForm(),
/// )
/// ```
class ContainerCardTitled extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  final String? subtitle;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry contentPadding;
  final CrossAxisAlignment crossAxisAlignment;

  const ContainerCardTitled({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.subtitle,
    this.titlePadding = const EdgeInsets.only(bottom: 16),
    this.contentPadding = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return ContainerCard(
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          // 🔹 Header (Title + Optional Action)
          Padding(
            padding: titlePadding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + optional subtitle block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: FontConfig.h3(context)
                            .copyWith(color: ThemeConfig.primaryGreen),
                      ),
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
                    ],
                  ),
                ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: action!,
                  ),
              ],
            ),
          ),

          // 🔹 Body (Your custom child widget)
          Padding(
            padding: contentPadding,
            child: child,
          ),
        ],
      ),
    );
  }
}
