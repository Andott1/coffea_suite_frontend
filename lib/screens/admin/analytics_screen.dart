import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.white,
      body: Center(
        child: Text(
          "Analytics Module Coming Soon",
          style: FontConfig.h2(context).copyWith(
            color: ThemeConfig.primaryGreen,
          ),
        ),
      ),
    );
  }
}
