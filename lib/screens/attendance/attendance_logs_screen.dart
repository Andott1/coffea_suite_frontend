import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/attendance_log_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/session_user.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
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
  String _searchQuery = "";
  String? _selectedEmployeeId;
  DateTime? _startDate;
  DateTime? _endDate;

  // ──────────────────────────────────────────────────────────────────────────
  // FILTER LOGIC
  // ──────────────────────────────────────────────────────────────────────────

  List<AttendanceLogModel> _getFilteredLogs(Box<AttendanceLogModel> box) {
    List<AttendanceLogModel> logs = box.values.toList();
    
    // Sort by Time In (Newest First)
    logs.sort((a, b) => b.timeIn.compareTo(a.timeIn));

    if (_startDate != null && _endDate != null) {
      final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      logs = logs.where((l) => l.date.isAfter(_startDate!) && l.date.isBefore(end)).toList();
    }

    if (_selectedEmployeeId != null) {
      logs = logs.where((l) => l.userId == _selectedEmployeeId).toList();
    }

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
      lastDate: DateTime.now().add(const Duration(days: 1)), 
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

  // ──────────────────────────────────────────────────────────────────────────
  // DIALOG HANDLERS
  // ──────────────────────────────────────────────────────────────────────────
  
  void _showDetailDialog(AttendanceLogModel log) {
    showDialog(
      context: context,
      builder: (_) => _LogDetailDialog(
        log: log,
        onEdit: () {
          Navigator.pop(context); 
          _showEditDialog(log);   
        },
        onApprove: () async {
          log.isVerified = true;
          log.rejectionReason = null;
          await log.save();

          SupabaseSyncService.addToQueue(
            table: 'attendance_logs', 
            action: 'UPDATE', 
            data: {'id': log.id, 'is_verified': true, 'rejection_reason': null}
          );

          if(mounted) {
            Navigator.pop(context);
            DialogUtils.showToast(context, "Proof Verified ✅");
          }
        },
        onReject: () {
          Navigator.pop(context);
          _showRejectionDialog(log);
        },
      ),
    );
  }

  void _showRejectionDialog(AttendanceLogModel log) {
    showDialog(
      context: context,
      builder: (_) => _RejectionReasonDialog(
        onConfirm: (reason) async {
          log.isVerified = false;
          log.rejectionReason = reason;
          await log.save();

          SupabaseSyncService.addToQueue(
            table: 'attendance_logs', 
            action: 'UPDATE', 
            data: {'id': log.id, 'is_verified': false, 'rejection_reason': reason}
          );

          if(mounted) DialogUtils.showToast(context, "Proof Rejected ❌", accentColor: Colors.red);
        }
      )
    );
  }

  void _showEditDialog(AttendanceLogModel log) {
    if (!SessionUser.isManager) {
      DialogUtils.showToast(context, "Only Managers can edit logs.", icon: Icons.lock, accentColor: Colors.red);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => _EditLogDialog(log: log),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MAIN UI BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── HEADER CONTROLS ───
            ContainerCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: BasicSearchBox(
                      hintText: "Search Employee Name...",
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ValueListenableBuilder(
                      valueListenable: HiveService.userBox.listenable(),
                      builder: (context, Box<UserModel> box, _) {
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

            // ─── LOGS TABLE ───
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
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
                          const SizedBox(width: 50), // Space for indicators
                        ],
                      ),
                    ),

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
                              
                              String breakStr = "-";
                              if (log.breakStart != null && log.breakEnd != null) {
                                final diff = log.breakEnd!.difference(log.breakStart!);
                                breakStr = "${diff.inMinutes}m";
                              } else if (log.breakStart != null) {
                                breakStr = "On Break";
                              }

                              return Material(
                                color: Colors.white,
                                child: InkWell(
                                  onTap: () => _showDetailDialog(log),
                                  hoverColor: ThemeConfig.primaryGreen.withValues(alpha: 0.05),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    child: Row(
                                      children: [
                                        _textCell(DateFormat('MMM dd').format(log.date), 2, isDim: true),
                                        
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
                                        
                                        Expanded(
                                          flex: 2,
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: _buildVerificationBadge(log),
                                          ),
                                        ),

                                        SizedBox(
                                          width: 50,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (log.proofImage != null && log.proofImage!.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 4),
                                                  child: Icon(Icons.photo_camera, size: 16, color: Colors.grey[400]),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

  // ──────────────────────────────────────────────────────────────────────────
  // TABLE HELPERS
  // ──────────────────────────────────────────────────────────────────────────

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

  Widget _buildVerificationBadge(AttendanceLogModel log) {
    if (log.rejectionReason != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.red.shade200)),
        child: const Text("REJECTED", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
    if (log.isVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green.shade200)),
        child: const Text("VERIFIED", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
      child: const Text("PENDING", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// SPLIT-VIEW AUDIT DIALOG
// ──────────────────────────────────────────────────────────────────────────

class _LogDetailDialog extends StatelessWidget {
  final AttendanceLogModel log;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _LogDetailDialog({
    required this.log, 
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final user = HiveService.userBox.get(log.userId);
    final bool hasProof = log.proofImage != null && log.proofImage!.isNotEmpty;

    // Image Loader Logic
    Widget imageWidget;
    if (hasProof) {
      if (log.proofImage!.startsWith('http')) {
        imageWidget = Image.network(log.proofImage!, fit: BoxFit.cover);
      } else {
        imageWidget = Image.file(File(log.proofImage!), fit: BoxFit.cover);
      }
    } else {
      imageWidget = Container(
        color: Colors.grey[200],
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_photography, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("No photo evidence", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return DialogBoxTitled(
      title: "Log Details",
      width: 900, // ✅ Wide split view
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
      ],
      child: SizedBox(
        height: 420, // Fixed height container for consistent layout
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── LEFT PANE: EVIDENCE & DATE ───
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  // Photo Container
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                        color: Colors.black,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imageWidget,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date Caption
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today, color: ThemeConfig.primaryGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM dd, yyyy').format(log.date),
                        style: FontConfig.h2(context).copyWith(color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8), // Bottom padding
                ],
              ),
            ),

            const SizedBox(width: 30),

            // ─── RIGHT PANE: RECORD & ACTIONS ───
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. User Header
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: ThemeConfig.primaryGreen,
                        child: Text(user?.fullName[0] ?? "?", style: const TextStyle(color: Colors.white, fontSize: 20)),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.fullName ?? "Unknown User", style: FontConfig.h3(context)),
                          Text(user?.role.name.toUpperCase() ?? "STAFF", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  
                  const Divider(height: 40),

                  // 2. Time Card Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ThemeConfig.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        _timeRow("Clock In", DateFormat('hh:mm a').format(log.timeIn)),
                        const Divider(height: 24),
                        _timeRow("Clock Out", log.timeOut != null ? DateFormat('hh:mm a').format(log.timeOut!) : "-- : --"),
                        const Divider(height: 24),
                        _timeRow(
                          "Total Worked", 
                          log.totalHoursWorked > 0 ? "${log.totalHoursWorked.toStringAsFixed(1)} hrs" : "-", 
                          isBold: true
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Modify Button (Contextual)
                  if (SessionUser.isManager)
                    SizedBox(
                      width: double.infinity,
                      child: BasicButton(
                        label: "Modify Times",
                        type: AppButtonType.secondary,
                        height: 40,
                        icon: Icons.edit,
                        onPressed: onEdit,
                      ),
                    ),

                  const Spacer(),

                  // 4. Status & Verification
                  if (log.rejectionReason != null)
                    _statusBanner("REJECTED: ${log.rejectionReason}", Colors.red)
                  else if (log.isVerified)
                    _statusBanner("VERIFIED RECORD", Colors.green)
                  else ...[
                    const Text("Verification Required:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: BasicButton(
                            label: "Reject",
                            icon: Icons.close,
                            type: AppButtonType.danger,
                            onPressed: SessionUser.isManager ? onReject : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BasicButton(
                            label: "Approve",
                            icon: Icons.check,
                            type: AppButtonType.primary,
                            onPressed: SessionUser.isManager ? onApprove : null,
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 16)),
        Text(
          value, 
          style: TextStyle(
            fontSize: 18, 
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: isBold ? ThemeConfig.primaryGreen : Colors.black87
          )
        ),
      ],
    );
  }

  Widget _statusBanner(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// REJECTION REASON DIALOG
// ──────────────────────────────────────────────────────────────────────────

class _RejectionReasonDialog extends StatefulWidget {
  final Function(String) onConfirm;
  const _RejectionReasonDialog({required this.onConfirm});

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final TextEditingController _customCtrl = TextEditingController();
  String? _selectedReason;

  final List<String> _reasons = [
    "No face visible",
    "Blurry photo",
    "Wrong location",
    "Wearing unauthorized gear",
    "Duplicate submission"
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Reject Proof"),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select a reason:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return FilterChip(
                  label: Text(reason),
                  selected: isSelected,
                  onSelected: (v) => setState(() {
                    _selectedReason = v ? reason : null;
                    if(v) _customCtrl.clear();
                  }),
                  checkmarkColor: Colors.white,
                  selectedColor: Colors.redAccent,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text("Or type custom reason:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _customCtrl,
              onChanged: (v) => setState(() => _selectedReason = null),
              decoration: const InputDecoration(
                hintText: "Enter reason...",
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            final reason = _customCtrl.text.isNotEmpty ? _customCtrl.text : _selectedReason;
            if (reason == null || reason.isEmpty) {
              DialogUtils.showToast(context, "Please select or type a reason.", icon: Icons.warning, accentColor: Colors.orange);
              return;
            }
            Navigator.pop(context);
            widget.onConfirm(reason);
          },
          child: const Text("Reject Log", style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// EDIT TIME DIALOG (Existing)
// ──────────────────────────────────────────────────────────────────────────

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