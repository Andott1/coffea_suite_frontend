import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';

class InventoryDashboard extends StatelessWidget {
  const InventoryDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Admin Dashboard Module Coming Soon",
          style: FontConfig.h2(context).copyWith(color: ThemeConfig.secondaryGreen),
        ),
      ),
    );
  }
}
