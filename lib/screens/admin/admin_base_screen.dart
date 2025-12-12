import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/enums/coffea_system.dart';
import '../../core/utils/system_tab_memory.dart';
import '../../core/services/session_user.dart';
import '../../core/config/permissions_config.dart';

// ✅ NEW IMPORTS
import '../../core/widgets/modern_scaffold.dart';
import '../../core/models/tab_definition.dart';

// Screens
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
  late List<String> _currentTabs;
  late List<Widget> _currentScreens;

  @override
  void initState() {
    super.initState();
    _setupTabs();
  }

  void _setupTabs() {
    // 1. Define tabs
    final allTabs = [
      TabDefinition(
        title: "Dashboard",
        widget: AdminDashboardScreen(),
        permission: AppPermission.viewAdminDashboard
      ),
      TabDefinition(
        title: "Employees",
        widget: EmployeeManagementScreen(),
        permission: AppPermission.manageEmployees
      ),
      TabDefinition(
        title: "Products",
        widget: AdminProductTab(),
        permission: AppPermission.manageProducts
      ),
      TabDefinition(
        title: "Ingredients",
        widget: AdminIngredientTab(),
        permission: AppPermission.manageIngredients
      ),
      TabDefinition(
        title: "Settings",
        widget: SettingsScreen(),
        permission: AppPermission.manageSettings
      ),
    ];

    // 2. Filter based on permissions
    final allowedTabs = allTabs.where((tab) {
      if (tab.permission == null) return true;
      return SessionUser.hasPermission(tab.permission!);
    }).toList();

    _currentTabs = allowedTabs.map((e) => e.title).toList();
    _currentScreens = allowedTabs.map((e) => e.widget).toList();

    // 3. Security Fallback
    if (_currentTabs.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/');
      });
      return;
    }

    // 4. Restore State
    int lastIndex = SystemTabMemory.getLastTab(CoffeaSystem.admin);
    if (lastIndex >= _currentTabs.length) {
      lastIndex = 0;
    }
    _activeIndex = lastIndex;
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Replaced Scaffold with ModernScaffold
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          setState(() => _setupTabs());
        }
      },
      child: ModernScaffold(
        system: CoffeaSystem.admin,
        currentTabs: _currentTabs,
        activeIndex: _activeIndex,
        onTabSelected: (index) {
          setState(() => _activeIndex = index);
          SystemTabMemory.setLastTab(CoffeaSystem.admin, index);
        },
        // We use IndexedStack to preserve state of complex screens (like forms)
        body: IndexedStack(
          index: _activeIndex,
          children: _currentScreens,
        ),
      ),
    );
  }
}