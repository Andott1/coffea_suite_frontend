/// <<FILE: lib/screens/attendance/attendance_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';

class AttendanceBaseScreen extends StatefulWidget {
  const AttendanceBaseScreen({super.key});

  @override
  State<AttendanceBaseScreen> createState() => _AttendanceBaseScreenState();
}

class _AttendanceBaseScreenState extends State<AttendanceBaseScreen> {
  int activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.attendance,
        tabs: const ["Time In/Out", "Logs", "Payroll"],
        activeIndex: activeTab,
        onTabSelected: (index) {
          setState(() => activeTab = index);
        },
        showOnlineStatus: true,
        showUserMode: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            return Card(
              elevation: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, size: 30, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text("Employee ${index + 1}"),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(onPressed: () {}, child: const Text("IN")),
                      const SizedBox(width: 6),
                      ElevatedButton(onPressed: () {}, child: const Text("OUT")),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
/// <<END FILE>>