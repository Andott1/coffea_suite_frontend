import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';
import 'cashier_screen.dart'; // ✅ Import the real CashierScreen
import 'transaction_history_screen.dart'; // ✅ Import
import 'pos_dashboard_screen.dart'; // ✅ Import

class POSBaseScreen extends StatefulWidget {
  const POSBaseScreen({super.key});

  @override
  State<POSBaseScreen> createState() => _POSBaseScreenState();
}

class _POSBaseScreenState extends State<POSBaseScreen> {
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = SystemTabMemory.getLastTab(CoffeaSystem.pos, defaultIndex: 1); // Default to Cashier tab
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.pos, index);
  }

  final List<String> _tabs = const [
    "Dashboard",
    "Cashier",
    "History",
  ];

  final List<Widget> _screens = const [
    POSDashboardScreen(), // ✅ Use real screen
    CashierScreen(),
    TransactionHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.pos,
        tabs: _tabs,
        adminOnlyTabs: const [false, false, false],
        activeIndex: _activeIndex,
        onTabSelected: _onTabChanged,
        showOnlineStatus: true,
        showUserMode: true,
      ),
      body: IndexedStack(
        index: _activeIndex,
        children: _screens,
      ),
    );
  }
}
/// <<END FILE>>