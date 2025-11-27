import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import 'container_card.dart';

/// A reusable card layout with a built-in section title.
/// Ideal for admin panels or grouped content sections.
class ContainerCardTitled extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  final String? subtitle;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry contentPadding;
  final CrossAxisAlignment crossAxisAlignment;
  final bool centerTitle;

  const ContainerCardTitled({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.subtitle,
    this.titlePadding = const EdgeInsets.only(bottom: 16),
    this.contentPadding = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget titleBlock({required bool centered}) {
      final textColumn = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FontConfig.h3(context)
                .copyWith(color: ThemeConfig.primaryGreen),
            textAlign: centered ? TextAlign.center : TextAlign.start,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: FontConfig.h2(context).copyWith(
                color: ThemeConfig.midGray,
                fontWeight: FontWeight.w400,
              ),
              textAlign: centered ? TextAlign.center : TextAlign.start,
            ),
          ],
        ],
      );

      return textColumn;
    }

    Widget header;
    if (centerTitle) {
      // Centered title while keeping action aligned right (if provided)
      header = Padding(
        padding: titlePadding,
        child: SizedBox(
          width: double.infinity,
          // Use a Stack so the title stays centered even with an action on the right
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center title + subtitle
              Align(
                alignment: Alignment.center,
                child: titleBlock(centered: true),
              ),

              // Right-side action (if any)
              if (action != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: action!,
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      // Default: left-aligned title, action on the right
      header = Padding(
        padding: titlePadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + optional subtitle block
            Expanded(
              child: titleBlock(centered: false),
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: action!,
              ),
          ],
        ),
      );
    }

    return ContainerCard(
      child: Column(
        crossAxisAlignment: crossAxisAlignment,
        children: [
          // Header (either centered-stack or the original row)
          header,

          // Body (Your custom child widget)
          Padding(
            padding: contentPadding,
            child: child,
          ),
        ],
      ),
    );
  }
}
