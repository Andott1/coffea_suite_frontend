import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';

class EmployeeManagementScreen extends StatelessWidget {
  const EmployeeManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.white,
      body: Center(
        child: Text(
          "Employee Management Module Coming Soon",
          style: FontConfig.h2(context).copyWith(
            color: ThemeConfig.primaryGreen,
          ),
        ),
      ),
    );
  }
}
