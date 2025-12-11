import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../core/models/user_model.dart';

class EmployeeAvatar extends StatelessWidget {
  final String name;
  final UserRoleLevel role;
  final double size;

  const EmployeeAvatar({
    super.key,
    required this.name,
    required this.role,
    this.size = 48,
  });

  Color _getBgColor() {
    switch (role) {
      case UserRoleLevel.admin: return Colors.purple;
      case UserRoleLevel.manager: return Colors.blue;
      default: return ThemeConfig.primaryGreen;
    }
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
        borderRadius: BorderRadius.circular(12), // Matching ProductAvatar radius
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