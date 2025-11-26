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
import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/basic_input_field.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = "";
  
  Map<String, _PayrollEntry> _payrollData = {};
  double _totalPayrollCost = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!SessionUser.isAdmin) {
        // Security check
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

    final endRange = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
    final logs = logsBox.values.where((l) => 
      l.date.isAfter(_startDate!.subtract(const Duration(seconds: 1))) && 
      l.date.isBefore(endRange)
    ).toList();

    final Map<String, _PayrollEntry> data = {};
    double totalCost = 0;

    for (var log in logs) {
      if (log.totalHoursWorked <= 0) continue;

      final user = usersBox.get(log.userId);
      if (user == null) continue;

      final rate = log.hourlyRateSnapshot > 0 ? log.hourlyRateSnapshot : user.hourlyRate;
      final pay = log.totalHoursWorked * rate;

      if (!data.containsKey(user.id)) {
        data[user.id] = _PayrollEntry(
          user: user,
          totalHours: 0,
          grossPay: 0,
          logs: [], // Initialize list
        );
      }

      data[user.id]!.totalHours += log.totalHoursWorked;
      data[user.id]!.grossPay += pay;
      data[user.id]!.logs.add(log); // ✅ Store log reference
      totalCost += pay;
    }

    setState(() {
      _payrollData = data;
      _totalPayrollCost = totalCost;
    });
  }

  void _openPayrollDetail(_PayrollEntry entry) {
    showDialog(
      context: context,
      builder: (_) => _PayrollDetailDialog(
        entry: entry, 
        startDate: _startDate!, 
        endDate: _endDate!
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!SessionUser.isAdmin) {
      return const Scaffold(body: Center(child: Text("Access Denied: Admin Only")));
    }

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
                      Expanded(
                        flex: 3,
                        child: BasicSearchBox(
                          hintText: "Search Employee...",
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── SUMMARY ───
            if (_payrollData.isNotEmpty) ...[
              ContainerCard(
                padding: const EdgeInsets.all(20),
                backgroundColor: ThemeConfig.primaryGreen,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("ESTIMATED GROSS PAYROLL", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text("Before adjustments", style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                          _headerCell("Action", 1), // View Detail
                        ],
                      ),
                    ),

                    // List
                    Expanded(
                      child: _startDate == null
                        ? Center(child: Text("Select a date range.", style: TextStyle(color: Colors.grey[500])))
                        : displayedEntries.isEmpty
                            ? Center(child: Text("No records found.", style: TextStyle(color: Colors.grey[500])))
                            : ListView.separated(
                                itemCount: displayedEntries.length,
                                separatorBuilder: (_,__) => const Divider(height: 1, color: ThemeConfig.lightGray),
                                itemBuilder: (context, index) {
                                  final entry = displayedEntries[index];
                                  return Material(
                                    color: Colors.white,
                                    child: InkWell(
                                      onTap: () => _openPayrollDetail(entry),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        child: Row(
                                          children: [
                                            _textCell(entry.user.fullName, 3, isBold: true),
                                            _textCell(entry.user.role.name.toUpperCase(), 2, isDim: true),
                                            _textCell("${entry.totalHours.toStringAsFixed(1)} hrs", 2),
                                            _textCell(FormatUtils.formatCurrency(entry.user.hourlyRate), 2),
                                            _textCell(FormatUtils.formatCurrency(entry.grossPay), 2, color: ThemeConfig.primaryGreen, isBold: true),
                                            Expanded(
                                              flex: 1,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Icon(Icons.chevron_right, color: Colors.grey[400]),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
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
  final List<AttendanceLogModel> logs; // ✅ Added Logs List

  _PayrollEntry({
    required this.user,
    required this.totalHours,
    required this.grossPay,
    required this.logs,
  });
}

class _Adjustment {
  String label;
  double amount; // Negative for deduction, Positive for bonus
  _Adjustment(this.label, this.amount);
}

// ──────────────────────────────────────────────────────────────────────────
// SPLIT-VIEW PAYROLL DIALOG
// ──────────────────────────────────────────────────────────────────────────

class _PayrollDetailDialog extends StatefulWidget {
  final _PayrollEntry entry;
  final DateTime startDate;
  final DateTime endDate;

  const _PayrollDetailDialog({
    required this.entry,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<_PayrollDetailDialog> createState() => _PayrollDetailDialogState();
}

class _PayrollDetailDialogState extends State<_PayrollDetailDialog> {
  final List<_Adjustment> _adjustments = [];

  double get _totalAdjustments => _adjustments.fold(0, (sum, item) => sum + item.amount);
  double get _netPay => widget.entry.grossPay + _totalAdjustments;

  void _addAdjustment() {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    bool isDeduction = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Adjustment"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Toggle
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("Deduction (-)")),
                        selected: isDeduction,
                        selectedColor: Colors.red.shade100,
                        labelStyle: TextStyle(color: isDeduction ? Colors.red : Colors.grey),
                        onSelected: (v) => setState(() => isDeduction = true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text("Bonus (+)")),
                        selected: !isDeduction,
                        selectedColor: Colors.green.shade100,
                        labelStyle: TextStyle(color: !isDeduction ? Colors.green : Colors.grey),
                        onSelected: (v) => setState(() => isDeduction = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BasicInputField(label: "Description (e.g. Cash Advance)", controller: labelCtrl),
                const SizedBox(height: 10),
                BasicInputField(label: "Amount", controller: amountCtrl, inputType: TextInputType.number, isCurrency: true),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  final amt = double.tryParse(amountCtrl.text.replaceAll(',', '')) ?? 0;
                  if (amt > 0 && labelCtrl.text.isNotEmpty) {
                    final finalAmt = isDeduction ? -amt : amt;
                    this.setState(() {
                      _adjustments.add(_Adjustment(labelCtrl.text, finalAmt));
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text("Add"),
              )
            ],
          );
        }
      )
    );
  }

  void _removeAdjustment(int index) {
    setState(() {
      _adjustments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.entry.user;
    
    // Sort logs by date
    final sortedLogs = List<AttendanceLogModel>.from(widget.entry.logs)
      ..sort((a, b) => a.date.compareTo(b.date));

    return DialogBoxTitled(
      title: "Payroll Details",
      width: 1000, // Wide Split View
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
      ],
      child: SizedBox(
        height: 550,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── LEFT PANE: SHIFT HISTORY (Flex 3) ───
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text("Shift History", style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text("${sortedLogs.length} shifts", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: sortedLogs.length,
                        separatorBuilder: (_,__) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = sortedLogs[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // Date
                                SizedBox(
                                  width: 100,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(DateFormat('MMM dd').format(log.date), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text(DateFormat('EEE').format(log.date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                // Time
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${DateFormat('HH:mm').format(log.timeIn)} - ${log.timeOut != null ? DateFormat('HH:mm').format(log.timeOut!) : '?'}",
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      if (log.status != null)
                                        Text(log.status.name.toUpperCase(), style: TextStyle(fontSize: 10, color: log.status.index > 0 ? Colors.orange : Colors.green)),
                                    ],
                                  ),
                                ),
                                // Hours
                                Text(
                                  "${log.totalHoursWorked.toStringAsFixed(1)} hrs",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen),
                                ),
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

            const SizedBox(width: 24),

            // ─── RIGHT PANE: SUMMARY & MATH (Flex 2) ───
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. User Info
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: ThemeConfig.primaryGreen,
                        radius: 24,
                        child: Text(user.fullName[0], style: const TextStyle(color: Colors.white, fontSize: 20)),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName, style: FontConfig.h3(context).copyWith(fontSize: 18)),
                          Text(user.role.name.toUpperCase(), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // 2. Base Pay
                  _mathRow("Total Hours", "${widget.entry.totalHours.toStringAsFixed(1)} hrs"),
                  _mathRow("Hourly Rate", FormatUtils.formatCurrency(user.hourlyRate)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  _mathRow("Gross Pay", FormatUtils.formatCurrency(widget.entry.grossPay), isBold: true),

                  const SizedBox(height: 24),

                  // 3. Adjustments Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Adjustments", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Add"),
                        onPressed: _addAdjustment,
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                      ),
                    ],
                  ),

                  // 4. Adjustments List (Scrollable if many)
                  Expanded(
                    child: _adjustments.isEmpty
                      ? Container(
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 10),
                          child: const Text("No adjustments", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        )
                      : ListView.builder(
                          itemCount: _adjustments.length,
                          itemBuilder: (context, index) {
                            final adj = _adjustments[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                                    onPressed: () => _removeAdjustment(index),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(adj.label, style: const TextStyle(fontSize: 14))),
                                  Text(
                                    FormatUtils.formatCurrency(adj.amount), 
                                    style: TextStyle(
                                      color: adj.amount >= 0 ? Colors.green : Colors.red, 
                                      fontWeight: FontWeight.bold
                                    )
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ),

                  const Divider(),

                  // 5. Net Pay
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ThemeConfig.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("NET PAY", style: FontConfig.h3(context).copyWith(fontSize: 18)),
                        Text(
                          FormatUtils.formatCurrency(_netPay),
                          style: FontConfig.h3(context).copyWith(fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 6. Actions
                  Row(
                    children: [
                      Expanded(
                        child: BasicButton(
                          label: "Print Payslip",
                          icon: Icons.print,
                          type: AppButtonType.secondary,
                          onPressed: () => DialogUtils.showToast(context, "Printing Payslip..."),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BasicButton(
                          label: "Mark Paid",
                          icon: Icons.check_circle,
                          type: AppButtonType.primary,
                          onPressed: () {
                            Navigator.pop(context);
                            DialogUtils.showToast(context, "Marked as PAID (DB Pending)");
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mathRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: isBold ? Colors.black87 : Colors.grey[700], fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.w500)),
        ],
      ),
    );
  }
}