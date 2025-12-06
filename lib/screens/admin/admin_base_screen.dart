import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // ✅ Added for Listener
import '../../core/bloc/auth/auth_bloc.dart';     // ✅ Added
import '../../core/bloc/auth/auth_state.dart';    // ✅ Added
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';
import '../../core/services/session_user.dart';
import '../../core/config/permissions_config.dart';

// Screens
import '../../core/widgets/session_listener.dart';
import 'admin_dashboard_screen.dart';
import 'admin_ingredient_tab.dart';
import 'admin_product_tab.dart';
import 'employee_management_screen.dart';
import 'settings_screen.dart';

class AdminBaseScreen extends StatefulWidget {
  const AdminBaseScreen({super.key});

  @override
  State<AdminBaseScreen> createState() => _AdminBaseScreenState();
}

class _AdminBaseScreenState extends State<AdminBaseScreen> {
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
        widget: const AdminDashboardScreen(),
        permission: AppPermission.viewAdminDashboard
      ),
      _TabDef(
        title: "Employees",
        widget: const EmployeeManagementScreen(),
        permission: AppPermission.manageEmployees
      ),
      _TabDef(
        title: "Products",
        widget: const AdminProductTab(),
        permission: AppPermission.manageProducts
      ),
      _TabDef(
        title: "Ingredients",
        widget: const AdminIngredientTab(),
        permission: AppPermission.manageIngredients
      ),
      _TabDef(
        title: "Settings",
        widget: const SettingsScreen(),
        permission: AppPermission.manageSettings
      ),
    ];

    // 2. Filter based on current user permissions
    final allowedTabs = allTabs.where((tab) {
      if (tab.permission == null) return true;
      return SessionUser.hasPermission(tab.permission!);
    }).toList();

    _currentTabs = allowedTabs.map((e) => e.title).toList();
    _currentScreens = allowedTabs.map((e) => e.widget).toList();

    // 3. Security Fallback
    // If a user (e.g. Employee) somehow gets here but has 0 allowed tabs, redirect them.
    if (_currentTabs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
      });
      return;
    }

    // 4. Restore Tab State
    int lastIndex = SystemTabMemory.getLastTab(CoffeaSystem.admin);
    if (lastIndex >= _currentTabs.length) {
      lastIndex = 0;
    }
    _activeIndex = lastIndex;
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.admin, index);
  }

  @override
  Widget build(BuildContext context) {
    return SessionListener(
      onUserChanged: () => setState(() => _setupTabs()),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: MasterTopBar(
          system: CoffeaSystem.admin,
          tabs: _currentTabs, 
          activeIndex: _activeIndex,
          onTabSelected: _onTabChanged,
          showOnlineStatus: true,
          showUserMode: true,
        ),
        body: IndexedStack(
          index: _activeIndex,
          children: _currentScreens, 
        ),
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