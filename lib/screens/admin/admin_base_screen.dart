import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import 'analytics_screen.dart';
import 'employee_management_screen.dart';
import 'settings_screen.dart';

class AdminBaseScreen extends StatelessWidget {
  const AdminBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseModuleScreen(
      defaultIndex: 0,
      tabLabels: const ["Analytics", "Employees", "Settings"],
      tabIcons: const [Icons.bar_chart, Icons.people_alt, Icons.settings],
      screens: const [
        AnalyticsScreen(),
        EmployeeManagementScreen(),
        SettingsScreen(),
      ],
      adminOnly: const [true, true, true], // 👈 Admin-only section
      showUserMode: true,
      showBackButton: true,
      useTopBar: true,
    );
  }
}