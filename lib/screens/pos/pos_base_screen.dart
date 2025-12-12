import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/widgets/modern_scaffold.dart';
import '../../core/services/session_user.dart'; // ✅ Import
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';

import '../../core/config/permissions_config.dart'; // ✅ Import

// Screens
import 'cashier_screen.dart';
import 'transaction_history_screen.dart';
import 'pos_dashboard_screen.dart';

class POSBaseScreen extends StatefulWidget {
  const POSBaseScreen({super.key});

  @override
  State<POSBaseScreen> createState() => _POSBaseScreenState();
}

class _POSBaseScreenState extends State<POSBaseScreen> {
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
    // 1. Define all potential tabs
    final allTabs = [
      _TabDef(
        title: "Dashboard",
        widget: const POSDashboardScreen(),
        permission: AppPermission.viewPosDashboard // 🔒 Managers/Admins
      ),
      _TabDef(
        title: "Cashier",
        widget: const CashierScreen(),
        permission: AppPermission.accessCashier // 🔓 Everyone
      ),
      _TabDef(
        title: "History",
        widget: const TransactionHistoryScreen(),
        permission: AppPermission.viewPosHistory // 🔒 Managers/Admins
      ),
    ];

    // 2. Filter based on permissions
    final allowedTabs = allTabs.where((tab) {
      if (tab.permission == null) return true;
      return SessionUser.hasPermission(tab.permission!);
    }).toList();

    _currentTabs = allowedTabs.map((e) => e.title).toList();
    _currentScreens = allowedTabs.map((e) => e.widget).toList();

    // 3. Safety Check: Active Index
    // If a Manager (on Tab 2: History) logs out and an Employee logs in (only 1 tab),
    // we must reset the index to 0 to prevent a crash.
    int lastIndex = SystemTabMemory.getLastTab(CoffeaSystem.pos, defaultIndex: 0);
    
    // If we have a stored index that is valid for the current user, use it.
    // Otherwise, default to "Cashier" if available, or just 0.
    if (lastIndex >= _currentTabs.length) {
      // Find index of "Cashier" if possible, else 0
      final cashierIndex = _currentTabs.indexOf("Cashier");
      _activeIndex = cashierIndex != -1 ? cashierIndex : 0;
    } else {
      _activeIndex = lastIndex;
    }
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
        system: CoffeaSystem.pos,
        currentTabs: _currentTabs,
        activeIndex: _activeIndex,
        onTabSelected: (index) {
          setState(() => _activeIndex = index);
          SystemTabMemory.setLastTab(CoffeaSystem.pos, index);
        },
        body: IndexedStack(
          index: _activeIndex,
          children: _currentScreens, // ✅ Dynamic Screens
        ),
      )
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