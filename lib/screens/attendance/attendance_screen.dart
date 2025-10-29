import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.white,
      body: Center(
        child: Text(
          "Attendance Time In/Out Coming Soon",
          style: FontConfig.h2(context).copyWith(
            color: ThemeConfig.primaryGreen,
          ),
        ),
      ),
    );
  }
}
