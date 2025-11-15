/// <<FILE: lib/screens/attendance/attendance_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';

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

  final List<String> _tabs = const [
    "Time In/Out",
    "Logs",
    "Payroll",
  ];

  final List<Widget> _screens = const [
    AttendanceTimeInOutScreen(),
    AttendanceLogsScreen(),
    AttendancePayrollScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.attendance,
        tabs: _tabs,
        adminOnlyTabs: const [false, false, true],
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

/// -----------------------------
/// TAB 1: Time In / Time Out
/// -----------------------------
class AttendanceTimeInOutScreen extends StatelessWidget {
  const AttendanceTimeInOutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: 12, // placeholder count
        itemBuilder: (context, index) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  "Employee ${index + 1}",
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {},
                      child: const Text("IN"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                      onPressed: () {},
                      child: const Text("OUT"),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// -----------------------------
/// TAB 2: Logs
/// -----------------------------
class AttendanceLogsScreen extends StatelessWidget {
  const AttendanceLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: Text(
            "Attendance Logs Placeholder",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// -----------------------------
/// TAB 3: Payroll
/// -----------------------------
class AttendancePayrollScreen extends StatelessWidget {
  const AttendancePayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: Text(
            "Payroll Overview Placeholder",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// <<END FILE>>