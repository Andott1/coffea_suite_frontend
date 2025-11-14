import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';

class BasicChipDisplay extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const BasicChipDisplay({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: ThemeConfig.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: ThemeConfig.midGray,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: FontConfig.body(context).copyWith(
          fontWeight: FontWeight.w400,
          color: ThemeConfig.primaryGreen,
        ),
      ),
    );
  }
}
