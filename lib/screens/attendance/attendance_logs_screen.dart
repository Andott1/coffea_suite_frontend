import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/attendance_log_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/session_user.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart'; // Assuming you have this or remove if unused
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_dropdown_button.dart';
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/dialog_box_titled.dart';

class AttendanceLogsScreen extends StatefulWidget {
  const AttendanceLogsScreen({super.key});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  // ──────────────── STATE ────────────────
  String _searchQuery = "";
  String? _selectedEmployeeId;
  DateTime? _startDate;
  DateTime? _endDate;

  // ──────────────── FILTERS ────────────────
  
  List<AttendanceLogModel> _getFilteredLogs(Box<AttendanceLogModel> box) {
    List<AttendanceLogModel> logs = box.values.toList();
    
    // Sort: Newest first
    logs.sort((a, b) => b.date.compareTo(a.date));

    // 1. Date Filter
    if (_startDate != null && _endDate != null) {
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      logs = logs.where((l) => l.date.isAfter(_startDate!) && l.date.isBefore(end)).toList();
    }

    // 2. Employee Filter (Dropdown)
    if (_selectedEmployeeId != null) {
      logs = logs.where((l) => l.userId == _selectedEmployeeId).toList();
    }

    // 3. Search (Employee Name)
    if (_searchQuery.isNotEmpty) {
      final userBox = HiveService.userBox;
      logs = logs.where((l) {
        final user = userBox.get(l.userId);
        return user != null && user.fullName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return logs;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)), // Allow today
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: ThemeConfig.primaryGreen,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      }
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  // ──────────────── EDIT DIALOG ────────────────
  
  void _showEditDialog(AttendanceLogModel log) {
    // Only Admins or Managers can edit logs
    if (!SessionUser.isManager) {
      DialogUtils.showToast(context, "Only Managers can edit logs.", icon: Icons.lock, accentColor: Colors.red);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _EditLogDialog(log: log),
    );
  }

  // ──────────────── UI ────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── CONTROL PANEL ───
            ContainerCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Search
                  Expanded(
                    flex: 2,
                    child: BasicSearchBox(
                      hintText: "Search Employee Name...",
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Employee Dropdown (Dynamic)
                  Expanded(
                    flex: 2,
                    child: ValueListenableBuilder(
                      valueListenable: HiveService.userBox.listenable(),
                      builder: (context, Box<UserModel> box, _) {
                        // Create a map for the dropdown
                        final users = box.values.toList();
                        return DropdownButtonFormField<String>(
                          value: _selectedEmployeeId,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            hintText: "All Employees",
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text("All Employees")),
                            ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.fullName))),
                          ],
                          onChanged: (v) => setState(() => _selectedEmployeeId = v),
                        );
                      }
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Date Picker
                  BasicButton(
                    label: _startDate == null 
                        ? "Date Range" 
                        : "${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}",
                    icon: Icons.calendar_today,
                    type: AppButtonType.secondary,
                    fullWidth: false,
                    onPressed: _pickDateRange,
                  ),
                  if (_startDate != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.clear, color: Colors.red),
                      onPressed: () => setState(() { _startDate = null; _endDate = null; }),
                    )
                  ]
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── TABLE ───
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: ThemeConfig.lightGray)),
                      ),
                      child: Row(
                        children: [
                          _headerCell("Date", 2),
                          _headerCell("Employee", 3),
                          _headerCell("Time In", 2),
                          _headerCell("Break", 2),
                          _headerCell("Time Out", 2),
                          _headerCell("Total Hrs", 2),
                          _headerCell("Status", 2),
                          const SizedBox(width: 48), // Action spacer
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: HiveService.attendanceBox.listenable(),
                        builder: (context, Box<AttendanceLogModel> box, _) {
                          final logs = _getFilteredLogs(box);

                          if (logs.isEmpty) {
                            return Center(child: Text("No logs found.", style: FontConfig.body(context)));
                          }

                          return ListView.separated(
                            itemCount: logs.length,
                            separatorBuilder: (_,__) => const Divider(height: 1, color: ThemeConfig.lightGray),
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              final user = HiveService.userBox.get(log.userId);
                              
                              // Calculated Break Duration
                              String breakStr = "-";
                              if (log.breakStart != null && log.breakEnd != null) {
                                final diff = log.breakEnd!.difference(log.breakStart!);
                                breakStr = "${diff.inMinutes}m";
                              } else if (log.breakStart != null) {
                                breakStr = "On Break";
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                child: Row(
                                  children: [
                                    _textCell(DateFormat('MMM dd').format(log.date), 2, isDim: true),
                                    
                                    // Employee Name + Role
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(user?.fullName ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen)),
                                          Text(user?.role.name.toUpperCase() ?? "", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                    ),

                                    _textCell(DateFormat('hh:mm a').format(log.timeIn), 2),
                                    
                                    _textCell(breakStr, 2, color: breakStr == "On Break" ? Colors.orange : null),
                                    
                                    _textCell(log.timeOut != null ? DateFormat('hh:mm a').format(log.timeOut!) : "--", 2),
                                    
                                    _textCell(log.totalHoursWorked > 0 ? "${log.totalHoursWorked.toStringAsFixed(1)} hrs" : "-", 2, isBold: true),
                                    
                                    // Status Badge
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _buildStatusBadge(log),
                                      ),
                                    ),

                                    // Edit Action
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                                      onPressed: () => _showEditDialog(log),
                                    )
                                  ],
                                ),
                              );
                            },
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── HELPERS ────────────────

  Widget _headerCell(String label, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(color: ThemeConfig.midGray, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _textCell(String text, int flex, {bool isBold = false, bool isDim = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? (isDim ? Colors.grey[600] : ThemeConfig.primaryGreen),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AttendanceLogModel log) {
    Color bg;
    Color text;
    String label;

    if (log.timeOut == null) {
      // Check if it's from a previous day (Incomplete)
      final isToday = DateUtils.isSameDay(log.date, DateTime.now());
      if (!isToday) {
        bg = Colors.red.shade50; text = Colors.red; label = "MISSING OUT";
      } else {
        bg = Colors.blue.shade50; text = Colors.blue; label = "ACTIVE";
      }
    } else {
      // Completed logs
      switch (log.status) {
        case AttendanceStatus.late:
          bg = Colors.orange.shade50; text = Colors.orange; label = "LATE";
          break;
        case AttendanceStatus.overtime:
          bg = Colors.purple.shade50; text = Colors.purple; label = "OVERTIME";
          break;
        default:
          bg = Colors.green.shade50; text = Colors.green; label = "ON TIME";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: text, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ──────────────── PRIVATE: EDIT DIALOG ────────────────

class _EditLogDialog extends StatefulWidget {
  final AttendanceLogModel log;
  const _EditLogDialog({required this.log});

  @override
  State<_EditLogDialog> createState() => _EditLogDialogState();
}

class _EditLogDialogState extends State<_EditLogDialog> {
  late DateTime _timeIn;
  DateTime? _timeOut;

  @override
  void initState() {
    super.initState();
    _timeIn = widget.log.timeIn;
    _timeOut = widget.log.timeOut;
  }

  Future<void> _pickTime(bool isTimeIn) async {
    final initial = isTimeIn ? _timeIn : (_timeOut ?? DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (picked != null) {
      setState(() {
        final newDt = DateTime(
          widget.log.date.year, widget.log.date.month, widget.log.date.day,
          picked.hour, picked.minute
        );
        
        if (isTimeIn) {
          _timeIn = newDt;
        } else {
          _timeOut = newDt;
        }
      });
    }
  }

  void _save() async {
    widget.log.timeIn = _timeIn;
    widget.log.timeOut = _timeOut;
    // Recalculate status based on simple 9AM rule logic if needed, 
    // or just leave as manual override.
    // For now, just save.
    await widget.log.save();
    if(mounted) {
      Navigator.pop(context);
      DialogUtils.showToast(context, "Log updated successfully");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogBoxTitled(
      title: "Edit Time Log",
      subtitle: DateFormat('MMMM dd, yyyy').format(widget.log.date),
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeRow("Time In", _timeIn, () => _pickTime(true)),
          const SizedBox(height: 16),
          _buildTimeRow("Time Out", _timeOut, () => _pickTime(false)),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(
                child: BasicButton(
                  label: "Cancel",
                  type: AppButtonType.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BasicButton(
                  label: "Save Changes",
                  type: AppButtonType.primary,
                  onPressed: _save,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimeRow(String label, DateTime? time, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen)),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: ThemeConfig.midGray),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Text(
                  time == null ? "-- : --" : DateFormat('hh:mm a').format(time),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.access_time, size: 18, color: ThemeConfig.primaryGreen)
              ],
            ),
          ),
        )
      ],
    );
  }
}