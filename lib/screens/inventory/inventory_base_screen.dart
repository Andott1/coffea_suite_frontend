import '../../core/widgets/modern_scaffold.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/tab_definition.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_state.dart';
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
      TabDefinition(
        title: "Dashboard", 
        widget: const InventoryDashboardTab(), 
        permission: AppPermission.viewInventoryDashboard // 🔒 Restricted
      ),
      TabDefinition(
        title: "Inventory List", 
        widget: const InventoryListTab(), 
        permission: AppPermission.viewInventoryList // 🔒 Restricted
      ),
      TabDefinition(
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          setState(() => _setupTabs());
        }
      },
      child: ModernScaffold(
        system: CoffeaSystem.inventory,
        currentTabs: _currentTabs,
        activeIndex: _activeIndex,
        onTabSelected: (index) {
          setState(() => _activeIndex = index);
          SystemTabMemory.setLastTab(CoffeaSystem.inventory, index);
        },
        body: IndexedStack(
          index: _activeIndex,
          children: _currentScreens, // ✅ Dynamic Screens
        ),
      )
    );
  }
}