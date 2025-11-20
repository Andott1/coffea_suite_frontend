/// <<FILE: lib/screens/inventory/inventory_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';
import 'inventory_list_tab.dart'; // ✅ Import New Tab

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
    "Inventory List", // Renamed for clarity
    "Logs",           // Renamed from "Stock Adjustments" per discussion
  ];

  final List<Widget> _screens = const [
    InventoryListTab(),           // ✅ The new layout
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.inventory,
        tabs: _tabs,
        adminOnlyTabs: const [false, false], // Logs should be visible to all usually? Or Manager only? Assuming all for now.
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