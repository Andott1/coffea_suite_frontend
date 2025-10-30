import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import 'inventory_dashboard.dart';
import 'product_list_screen.dart';
import 'stock_adjustment_screen.dart';

class InventoryBaseScreen extends StatelessWidget {
  const InventoryBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseModuleScreen(
      defaultIndex: 0,
      tabLabels: const ["Overview", "Products", "Stock Adjustments"],
      tabIcons: const [Icons.dashboard, Icons.list_alt, Icons.inventory],
      screens: const [
        InventoryDashboard(),
        ProductListScreen(),
        StockAdjustmentScreen(),
      ],
      adminOnly: const [false, false, true], // 👈 Stock Adjustments admin-only
      showUserMode: true,
      showBackButton: true,
      useTopBar: true,
    );
  }
}
