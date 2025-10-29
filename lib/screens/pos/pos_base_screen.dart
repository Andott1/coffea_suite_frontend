import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import '../inventory/inventory_dashboard.dart';
import 'pos_dashboard.dart';
import '../admin/analytics_screen.dart';
import '../admin/settings_screen.dart';

class POSBaseScreen extends StatelessWidget {
  const POSBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseModuleScreen(
      defaultIndex: 1, // Default to "Cashier"
      tabLabels: const [
        "Dashboard",
        "Cashier",
        "Inventory",
        "Analytics",
        "Settings",
      ],
      tabIcons: const [
        Icons.dashboard,
        Icons.point_of_sale,
        Icons.inventory_2,
        Icons.bar_chart,
        Icons.settings,
      ],
      screens: const [
        AdminDashboardScreen(),
        POSDashboard(),
        InventoryDashboard(),
        AnalyticsScreen(),
        SettingsScreen(),
      ],
    );
  }
}
