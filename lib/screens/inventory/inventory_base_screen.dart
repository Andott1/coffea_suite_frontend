import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import 'inventory_dashboard.dart';
import 'product_list_screen.dart';
import 'product_edit_screen.dart';
import 'stock_adjustment_screen.dart';

class InventoryBaseScreen extends StatelessWidget {
  const InventoryBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseModuleScreen(
      defaultIndex: 0,
      tabLabels: const [
        "Overview",
        "Product List",
        "Edit Product",
        "Stock Adjustments",
      ],
      tabIcons: const [
        Icons.dashboard,
        Icons.list_alt,
        Icons.edit,
        Icons.inventory,
      ],
      screens: [
        InventoryDashboard(),
        ProductListScreen(),
        ProductEditScreen(),
        StockAdjustmentScreen(),
      ],
      showUserMode: true,
    );
  }
}
