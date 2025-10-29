import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Admin Dashboard Coming Soon",
          style: FontConfig.h2(context).copyWith(color: ThemeConfig.secondaryGreen),
        ),
      ),
    );
  }
}
