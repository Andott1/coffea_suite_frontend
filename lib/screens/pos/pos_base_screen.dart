import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import 'pos_dashboard.dart';
import 'cashier_screen.dart';
import 'transaction_history_screen.dart';

class POSBaseScreen extends StatelessWidget {
  const POSBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseModuleScreen(
      defaultIndex: 1,
      tabLabels: const ["Dashboard", "Cashier", "History"],
      tabIcons: const [Icons.dashboard, Icons.point_of_sale, Icons.history],
      screens: const [
        POSDashboard(),
        CashierScreen(),
        TransactionHistoryScreen(),
      ],
      adminOnly: const [true, false, false], // 👈 Dashboard only for Admin
      showUserMode: true,
      showBackButton: true,
      useTopBar: true,
    );
  }
}
