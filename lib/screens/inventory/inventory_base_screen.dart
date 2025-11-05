import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import 'inventory_dashboard.dart';
import 'product_list_screen.dart';
import 'stock_adjustment_screen.dart';

class InventoryBaseScreen extends StatelessWidget {
  const InventoryBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BaseModuleScreen(
      defaultIndex: 0,
      tabLabels: ["Overview", "Products", "Stock Adjustments"],
      tabIcons: [Icons.dashboard, Icons.list_alt, Icons.inventory],
      screens: [
        InventoryDashboard(),
        ProductListScreen(),
        StockAdjustmentScreen(),
      ],
      adminOnly: [false, false, true], // 👈 Stock Adjustments admin-only
      showUserMode: true,
      showBackButton: true,
      useTopBar: true,
    );
  }
}
