import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';
import 'inventory_list_tab.dart'; 
import 'inventory_dashboard_tab.dart'; // ✅ NEW
import 'inventory_logs_tab.dart';      // ✅ NEW

class InventoryBaseScreen extends StatefulWidget {
  const InventoryBaseScreen({super.key});

  @override
  State<InventoryBaseScreen> createState() => _InventoryBaseScreenState();
}

class _InventoryBaseScreenState extends State<InventoryBaseScreen> {
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = SystemTabMemory.getLastTab(CoffeaSystem.inventory);
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.inventory, index);
  }

  final List<String> _tabs = const [
    "Dashboard",      // ✅ Tab 0
    "Inventory List", // ✅ Tab 1
    "Logs",           // ✅ Tab 2
  ];

  final List<Widget> _screens = const [
    InventoryDashboardTab(), // ✅ Dashboard
    InventoryListTab(),      // ✅ Inventory List
    InventoryLogsTab(),      // ✅ Logs Table
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.inventory,
        tabs: _tabs,
        // Managers/Admins can see everything in Inventory usually
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