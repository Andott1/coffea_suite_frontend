import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

class IngredientAvatar extends StatelessWidget {
  final String name;
  final String category;
  final double size;

  const IngredientAvatar({
    super.key,
    required this.name,
    required this.category,
    this.size = 48,
  });

  Color _getBgColor() {
    final cat = category.toLowerCase();
    if (cat.contains('dairy') || cat.contains('milk')) return Colors.lightBlue;
    if (cat.contains('syrup') || cat.contains('sauce')) return Colors.amber;
    if (cat.contains('bean') || cat.contains('coffee')) return ThemeConfig.coffeeBrown;
    if (cat.contains('tea') || cat.contains('leaf')) return Colors.green;
    if (cat.contains('powder') || cat.contains('dry')) return Colors.brown.shade300;
    if (cat.contains('fruit') || cat.contains('fresh')) return Colors.redAccent;
    return Colors.grey;
  }

  String _getInitials() {
    if (name.isEmpty) return "?";
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    // Use first two letters of first word if only one word, else initials
    if (parts.length == 1 && parts[0].length > 1) {
      return parts[0].substring(0, 2).toUpperCase();
    }
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