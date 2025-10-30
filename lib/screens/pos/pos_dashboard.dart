import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';

class POSDashboard extends StatelessWidget {
  const POSDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Dashboard Module Coming Soon",
          style: FontConfig.h2(context).copyWith(color: ThemeConfig.secondaryGreen),
        ),
      ),
    );
  }
}
