import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import 'admin_dashboard_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';

class AdminBaseScreen extends StatelessWidget {
  const AdminBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseModuleScreen(
      defaultIndex: 0,
      tabLabels: const [
        "Dashboard",
        "Analytics",
        "Settings",
      ],
      tabIcons: const [
        Icons.dashboard,
        Icons.bar_chart,
        Icons.settings,
      ],
      screens: const [
        AdminDashboardScreen(),
        AnalyticsScreen(),
        SettingsScreen(),
      ],
      showUserMode: true,
    );
  }
}
  