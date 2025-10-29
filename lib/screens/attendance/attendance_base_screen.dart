import 'package:flutter/material.dart';
import '../../core/widgets/base_module_screen.dart';
import 'attendance_screen.dart';
import 'attendance_logs_screen.dart';
import 'payroll_screen.dart';

class AttendanceBaseScreen extends StatelessWidget {
  const AttendanceBaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseModuleScreen(
      defaultIndex: 0,
      tabLabels: const [
        "Time In/Out",
        "Attendance Logs",
        "Payroll",
      ],
      tabIcons: const [
        Icons.access_time,
        Icons.list_alt,
        Icons.payments,
      ],
      screens: [
        AttendanceScreen(),
        AttendanceLogsScreen(),
        PayrollScreen(),
      ],
      showUserMode: false, // Attendance kiosk doesn’t need role switching
    );
  }
}
