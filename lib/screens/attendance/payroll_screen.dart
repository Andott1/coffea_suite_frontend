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
import '../../core/utils/format_utils.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/container_card.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  // ──────────────── STATE ────────────────
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = "";
  
  // Cached calculations
  Map<String, _PayrollEntry> _payrollData = {};
  double _totalPayrollCost = 0;

  @override
  void initState() {
    super.initState();
    // Security Check
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!SessionUser.isAdmin) {
        // This tab should be hidden by MasterTopBar, but double check security
      }
    });
  }

  // ──────────────── LOGIC ────────────────

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
      _generatePayroll();
    }
  }

  void _generatePayroll() {
    if (_startDate == null || _endDate == null) return;

    final logsBox = HiveService.attendanceBox;
    final usersBox = HiveService.userBox;

    // 1. Filter Logs in Range
    final endRange = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
    final logs = logsBox.values.where((l) => 
      l.date.isAfter(_startDate!.subtract(const Duration(seconds: 1))) && 
      l.date.isBefore(endRange)
    ).toList();

    // 2. Group by User
    final Map<String, _PayrollEntry> data = {};
    double totalCost = 0;

    for (var log in logs) {
      // Skip incomplete logs or zero hours
      if (log.totalHoursWorked <= 0) continue;

      final user = usersBox.get(log.userId);
      if (user == null) continue;

      // Logic: Use snapshot rate from log if available (historical accuracy), 
      // fallback to current user rate.
      final rate = log.hourlyRateSnapshot > 0 ? log.hourlyRateSnapshot : user.hourlyRate;
      final pay = log.totalHoursWorked * rate;

      if (!data.containsKey(user.id)) {
        data[user.id] = _PayrollEntry(
          user: user,
          totalHours: 0,
          grossPay: 0,
          deductions: 0, // Placeholder logic
        );
      }

      data[user.id]!.totalHours += log.totalHoursWorked;
      data[user.id]!.grossPay += pay;
      totalCost += pay;
    }

    setState(() {
      _payrollData = data;
      _totalPayrollCost = totalCost;
    });
  }

  void _markAsPaid() {
    DialogUtils.showToast(context, "Payroll marked as PAID (Feature Pending Database Update)");
    // TODO: Add 'isPaid' field to AttendanceLogModel to lock these records
  }

  @override
  Widget build(BuildContext context) {
    if (!SessionUser.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access Denied: Admin Only")),
      );
    }

    // Filter displayed list by search
    final displayedEntries = _payrollData.values.where((e) => 
      e.user.fullName.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── CONTROL PANEL ───
            ContainerCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      // Date Picker
                      Expanded(
                        flex: 2,
                        child: BasicButton(
                          label: _startDate == null 
                              ? "Select Pay Period" 
                              : "${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)}",
                          icon: Icons.date_range,
                          type: AppButtonType.primary,
                          onPressed: _pickDateRange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Search
                      Expanded(
                        flex: 3,
                        child: BasicSearchBox(
                          hintText: "Search Employee...",
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      
                      const SizedBox(width: 16),

                      // Mark Paid Action
                      Expanded(
                        flex: 2,
                        child: BasicButton(
                          label: "Mark as Paid",
                          icon: Icons.check_circle_outline,
                          type: AppButtonType.secondary,
                          onPressed: _payrollData.isEmpty ? null : _markAsPaid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── SUMMARY & LIST ───
            if (_payrollData.isNotEmpty) ...[
              // Summary Card
              ContainerCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: ThemeConfig.primaryGreen,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TOTAL PAYROLL COST", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Gross Calculation", style: TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    Text(
                      FormatUtils.formatCurrency(_totalPayrollCost),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
            ],

            // ─── TABLE ───
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
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
                          _headerCell("Employee", 3),
                          _headerCell("Role", 2),
                          _headerCell("Total Hours", 2),
                          _headerCell("Rate/Hr", 2),
                          _headerCell("Gross Pay", 2),
                          _headerCell("Deductions", 2),
                          _headerCell("Net Pay", 2),
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: _startDate == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.date_range, size: 48, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text("Select a date range to generate payroll.", style: TextStyle(color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : displayedEntries.isEmpty
                            ? Center(child: Text("No attendance records found for this period.", style: TextStyle(color: Colors.grey[500])))
                            : ListView.separated(
                                itemCount: displayedEntries.length,
                                separatorBuilder: (_,__) => const Divider(height: 1, color: ThemeConfig.lightGray),
                                itemBuilder: (context, index) {
                                  final entry = displayedEntries[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    child: Row(
                                      children: [
                                        _textCell(entry.user.fullName, 3, isBold: true),
                                        _textCell(entry.user.role.name.toUpperCase(), 2, isDim: true),
                                        _textCell("${entry.totalHours.toStringAsFixed(1)} hrs", 2),
                                        _textCell(FormatUtils.formatCurrency(entry.user.hourlyRate), 2),
                                        _textCell(FormatUtils.formatCurrency(entry.grossPay), 2, color: Colors.black87, isBold: true),
                                        _textCell("- ${FormatUtils.formatCurrency(entry.deductions)}", 2, color: Colors.redAccent),
                                        _textCell(FormatUtils.formatCurrency(entry.netPay), 2, color: ThemeConfig.primaryGreen, isBold: true),
                                      ],
                                    ),
                                  );
                                },
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
}

// ──────────────── PRIVATE MODEL ────────────────
class _PayrollEntry {
  final UserModel user;
  double totalHours;
  double grossPay;
  double deductions;

  _PayrollEntry({
    required this.user,
    required this.totalHours,
    required this.grossPay,
    this.deductions = 0.0,
  });

  double get netPay => grossPay - deductions;
}