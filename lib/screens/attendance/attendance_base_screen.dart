import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';
import 'attendance_dashboard_tab.dart'; // ✅ Import Dashboard
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

  @override
  void initState() {
    super.initState();
    _activeIndex = SystemTabMemory.getLastTab(CoffeaSystem.attendance);
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.attendance, index);
  }

  // ✅ UPDATED TABS LIST
  final List<String> _tabs = const [
    "Dashboard",  // 0
    "Time Clock", // 1
    "Logs",       // 2
    "Payroll",    // 3
  ];

  // ✅ UPDATED ADMIN PERMISSIONS
  // Dashboard is allowed for everyone? Usually yes, or Manager+. 
  // Let's assume Manager+ for Dashboard, Employees go straight to Time Clock.
  // But for now, let's leave it visible to all who can access this module.
  final List<bool> _adminOnlyTabs = const [
    false, // Dashboard (Visible)
    false, // Time Clock (Visible)
    false, // Logs (Visible, but edits restricted inside)
    true,  // Payroll (Restricted)
  ];

  final List<Widget> _screens = const [
    AttendanceDashboardTab(), // ✅ Tab 0
    TimeClockScreen(),        // ✅ Tab 1
    AttendanceLogsScreen(),   // ✅ Tab 2
    PayrollScreen(),          // ✅ Tab 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.attendance,
        tabs: _tabs,
        adminOnlyTabs: _adminOnlyTabs,
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
