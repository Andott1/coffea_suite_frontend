/// <<FILE: lib/screens/admin/admin_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import 'analytics_screen.dart';
import 'employee_management_screen.dart';
import 'settings_screen.dart';

class AdminBaseScreen extends StatelessWidget {
  const AdminBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseModuleScreen(
      defaultIndex: 0,
      tabLabels: ["Analytics", "Employees", "Products", "Ingredients", "Settings"],
      tabIcons: [
        Icons.bar_chart,
        Icons.people_alt,
        Icons.coffee, 
        Icons.inventory,
        Icons.settings,
      ],
      screens: [
        AnalyticsScreen(),
        EmployeeManagementScreen(),
        SettingsScreen(),
      ],
      adminOnly: [true, true, true, true, true],
      showUserMode: true,
      showBackButton: true,
      useTopBar: true,
    );
  }
}
/// <<END FILE>>