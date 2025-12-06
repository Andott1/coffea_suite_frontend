import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';
import '../../core/services/session_user.dart'; // ✅ Import
import '../../core/config/permissions_config.dart'; // ✅ Import
import 'inventory_list_tab.dart'; 
import 'inventory_dashboard_tab.dart';
import 'inventory_logs_tab.dart';

class InventoryBaseScreen extends StatefulWidget {
  const InventoryBaseScreen({super.key});

  @override
  State<InventoryBaseScreen> createState() => _InventoryBaseScreenState();
}

class _InventoryBaseScreenState extends State<InventoryBaseScreen> {
  late int _activeIndex;
  
  // Dynamic Lists
  late List<String> _currentTabs;
  late List<Widget> _currentScreens;

  @override
  void initState() {
    super.initState();
    _setupTabs();
  }

  void _setupTabs() {
    // 1. Define all possible tabs with their required permissions
    final allTabs = [
      _TabDef(
        title: "Dashboard", 
        widget: const InventoryDashboardTab(), 
        permission: AppPermission.viewInventoryDashboard // 🔒 Restricted
      ),
      _TabDef(
        title: "Inventory List", 
        widget: const InventoryListTab(), 
        permission: AppPermission.viewInventoryList // 🔒 Restricted
      ),
      _TabDef(
        title: "Logs", 
        widget: const InventoryLogsTab(), 
        permission: AppPermission.viewInventoryLogs // 🔒 Restricted
      ),
    ];

    // 2. Filter based on current user permissions
    final allowedTabs = allTabs.where((tab) {
      if (tab.permission == null) return true;
      return SessionUser.hasPermission(tab.permission!);
    }).toList();

    _currentTabs = allowedTabs.map((e) => e.title).toList();
    _currentScreens = allowedTabs.map((e) => e.widget).toList();

    // 3. Safety Check: Active Index
    // If user was on Tab 2 (Logs) but now logs in as Employee (only 1 tab), reset to 0.
    int lastIndex = SystemTabMemory.getLastTab(CoffeaSystem.inventory);
    if (lastIndex >= _currentTabs.length) {
      lastIndex = 0;
    }
    _activeIndex = lastIndex;
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.inventory, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.inventory,
        tabs: _currentTabs, // ✅ Pass dynamic list
        activeIndex: _activeIndex,
        onTabSelected: _onTabChanged,
        showOnlineStatus: true,
        showUserMode: true,
      ),
      body: IndexedStack(
        index: _activeIndex,
        children: _currentScreens, // ✅ Pass dynamic screens
      ),
    );
  }
}

// Simple data class for tab definition
class _TabDef {
  final String title;
  final Widget widget;
  final AppPermission? permission;
  _TabDef({required this.title, required this.widget, this.permission});
}