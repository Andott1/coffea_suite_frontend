import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/enums/coffea_system.dart';
import 'package:flutter/material.dart';

import '../../core/utils/system_tab_memory.dart';
import '../../core/services/session_user.dart'; // ✅ Import
import '../../core/config/permissions_config.dart'; // ✅ Import

import '../../core/widgets/modern_scaffold.dart';
import '../../core/models/tab_definition.dart';

// Screens
import 'attendance_dashboard_tab.dart';
import 'attendance_logs_screen.dart';
import 'payroll_screen.dart';
import 'time_clock_screen.dart';

class AttendanceBaseScreen extends StatefulWidget {
  const AttendanceBaseScreen({super.key});

  @override
  State<AttendanceBaseScreen> createState() => _AttendanceBaseScreenState();
}

class _AttendanceBaseScreenState extends State<AttendanceBaseScreen> {
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
    // 1. Define all possible tabs with permissions
    final allTabs = [
      TabDefinition(
        title: "Dashboard",
        widget: const AttendanceDashboardTab(),
        permission: AppPermission.viewAttendanceDashboard
      ),
      TabDefinition(
        title: "Time Clock",
        widget: const TimeClockScreen(),
        permission: AppPermission.accessTimeClock
      ),
      TabDefinition(
        title: "Logs",
        widget: const AttendanceLogsScreen(),
        permission: AppPermission.viewAttendanceLogs
      ),
      TabDefinition(
        title: "Payroll",
        widget: const PayrollScreen(),
        permission: AppPermission.managePayroll
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
    // If Admin (on Tab 3: Payroll) logs out -> Employee logs in (only 1 tab),
    // we must prevent crash by resetting index.
    int lastIndex = SystemTabMemory.getLastTab(CoffeaSystem.attendance, defaultIndex: 0);
    
    // Smart Default: If "Time Clock" exists, try to default to that for Employees
    int timeClockIndex = _currentTabs.indexOf("Time Clock");
    
    if (lastIndex >= _currentTabs.length) {
      _activeIndex = timeClockIndex != -1 ? timeClockIndex : 0;
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
        system: CoffeaSystem.attendance,
        currentTabs: _currentTabs,
        activeIndex: _activeIndex,
        onTabSelected: (index) {
          setState(() => _activeIndex = index);
          SystemTabMemory.setLastTab(CoffeaSystem.attendance, index);
        },
        body: IndexedStack(
          index: _activeIndex,
          children: _currentScreens, // ✅ Dynamic Screens
        ),
      )
    );
  }
}