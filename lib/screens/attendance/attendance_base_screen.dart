import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';
import '../../core/services/session_user.dart'; // ✅ Import
import '../../core/config/permissions_config.dart'; // ✅ Import

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
      _TabDef(
        title: "Dashboard",
        widget: const AttendanceDashboardTab(),
        permission: AppPermission.viewAttendanceDashboard // 🔒 Manager+
      ),
      _TabDef(
        title: "Time Clock",
        widget: const TimeClockScreen(),
        permission: AppPermission.accessTimeClock // 🔓 Everyone
      ),
      _TabDef(
        title: "Logs",
        widget: const AttendanceLogsScreen(),
        permission: AppPermission.viewAttendanceLogs // 🔒 Manager+
      ),
      _TabDef(
        title: "Payroll",
        widget: const PayrollScreen(),
        permission: AppPermission.managePayroll // 🔒 Admin Only
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

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.attendance, index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.attendance,
        tabs: _currentTabs, // ✅ Dynamic Tabs
        activeIndex: _activeIndex,
        onTabSelected: _onTabChanged,
        showOnlineStatus: true,
        showUserMode: true,
      ),
      body: IndexedStack(
        index: _activeIndex,
        children: _currentScreens, // ✅ Dynamic Screens
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