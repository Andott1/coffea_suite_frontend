import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

class ProductAvatar extends StatelessWidget {
  final String name;
  final String category;
  final double size;

  const ProductAvatar({
    super.key,
    required this.name,
    required this.category,
    this.size = 48,
  });

  Color _getBgColor() {
    final cat = category.toLowerCase();
    if (cat.contains('coffee')) return ThemeConfig.coffeeBrown;
    if (cat.contains('meal') || cat.contains('food')) return Colors.orange;
    if (cat.contains('dessert') || cat.contains('pastry')) return Colors.pinkAccent;
    if (cat.contains('drink') || cat.contains('beverage')) return Colors.teal;
    return ThemeConfig.primaryGreen;
  }

  String _getInitials() {
    if (name.isEmpty) return "?";
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getBgColor();
    
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        _getInitials(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}