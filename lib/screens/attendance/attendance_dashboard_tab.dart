import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/attendance_log_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/widgets/container_card.dart';

class AttendanceDashboardTab extends StatelessWidget {
  const AttendanceDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveService.attendanceBox.listenable(),
      builder: (context, Box<AttendanceLogModel> box, _) {
        
        // ──────────────── DATA PROCESSING ────────────────
        final today = DateTime.now();
        final todayLogs = box.values.where((l) =>
          l.date.year == today.year &&
          l.date.month == today.month &&
          l.date.day == today.day
        ).toList();

        // Sort logs: Latest Time In first
        todayLogs.sort((a, b) => b.timeIn.compareTo(a.timeIn));

        final activeUsersCount = HiveService.userBox.values.where((u) => u.isActive).length;

        int onFloor = 0;
        int onBreak = 0;
        int finished = 0;
        
        // "Active Logs" are people currently in the building (Working or Break)
        final List<AttendanceLogModel> activeLogs = [];

        for (var log in todayLogs) {
          if (log.timeOut != null) {
            finished++;
          } else {
            // Still active
            activeLogs.add(log);
            if (log.breakStart != null && log.breakEnd == null) {
              onBreak++;
            } else {
              onFloor++;
            }
          }
        }

        final absent = activeUsersCount - todayLogs.length;

        // ──────────────── UI LAYOUT ────────────────
        return Scaffold(
          backgroundColor: ThemeConfig.lightGray,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── HEADER ───
                ContainerCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Attendance Monitor", style: FontConfig.h3(context)),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(today),
                        style: const TextStyle(color: ThemeConfig.secondaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── KPI CARDS ───
                Row(
                  children: [
                    Expanded(child: _buildStatCard(context, "On Floor", "$onFloor", Icons.work, ThemeConfig.primaryGreen)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard(context, "On Break", "$onBreak", Icons.coffee, Colors.orange)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard(context, "Completed", "$finished", Icons.check_circle, Colors.blue)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard(context, "Absent / Late", "$absent", Icons.person_off, Colors.redAccent)),
                  ],
                ),

                const SizedBox(height: 20),

                // ─── SPLIT VIEW ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── LEFT: VISUAL ROSTER (Active Staff) ───
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Live Floor View", style: FontConfig.h3(context)),
                          const SizedBox(height: 12),
                          
                          activeLogs.isEmpty
                            ? ContainerCard(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(30.0),
                                    child: Text("No employees currently clocked in.", style: TextStyle(color: Colors.grey[400])),
                                  ),
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: activeLogs.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.2, // Rectangular cards
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemBuilder: (context, index) {
                                  final log = activeLogs[index];
                                  final user = HiveService.userBox.get(log.userId);
                                  final isOnBreak = log.breakStart != null && log.breakEnd == null;

                                  return _buildEmployeeCard(context, user, log, isOnBreak);
                                },
                              ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 20),

                    // ─── RIGHT: TODAY'S ACTIVITY FEED ───
                    Expanded(
                      flex: 1,
                      child: ContainerCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Today's Log", style: FontConfig.h3(context)),
                            const SizedBox(height: 16),
                            
                            if (todayLogs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(child: Text("No activity recorded today.")),
                              )
                            else
                              ...todayLogs.map((log) {
                                final user = HiveService.userBox.get(log.userId);
                                return _buildStaffRow(context, user, log);
                              }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────── WIDGETS ────────────────

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return ContainerCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: FontConfig.caption(context)),
              Text(value, style: FontConfig.h2(context).copyWith(fontWeight: FontWeight.w800, fontSize: 24, color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(BuildContext context, UserModel? user, AttendanceLogModel log, bool isOnBreak) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isOnBreak ? Colors.orange.shade200 : ThemeConfig.primaryGreen.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            backgroundColor: isOnBreak ? Colors.orange.shade50 : ThemeConfig.primaryGreen.withValues(alpha: 0.1),
            child: Text(
              user?.fullName.substring(0, 1).toUpperCase() ?? "?",
              style: TextStyle(fontWeight: FontWeight.bold, color: isOnBreak ? Colors.orange : ThemeConfig.primaryGreen),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  user?.fullName ?? "Unknown",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('hh:mm a').format(log.timeIn),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                )
              ],
            ),
          ),
          // Badge
          if (isOnBreak)
            const Icon(Icons.coffee, color: Colors.orange, size: 20)
          else
            const Icon(Icons.circle, color: Colors.green, size: 14)
        ],
      ),
    );
  }

  Widget _buildStaffRow(BuildContext context, UserModel? user, AttendanceLogModel log) {
    final bool isFinished = log.timeOut != null;
    final bool isOnBreak = log.breakStart != null && log.breakEnd == null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ThemeConfig.lightGray)),
      ),
      child: Row(
        children: [
          // Dot Status
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFinished ? Colors.grey : (isOnBreak ? Colors.orange : Colors.green)
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              user?.fullName ?? "Unknown",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            isFinished ? "OUT: ${DateFormat('hh:mm a').format(log.timeOut!)}" 
                       : "IN: ${DateFormat('hh:mm a').format(log.timeIn)}",
            style: TextStyle(
              fontSize: 12,
              color: isFinished ? Colors.grey : Colors.black87,
              fontWeight: isFinished ? FontWeight.normal : FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }
}