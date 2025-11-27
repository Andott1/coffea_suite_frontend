import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/attendance_log_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/payroll_record_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/session_user.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/basic_toggle_button.dart'; // Using toggle logic for tabs

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // ──────────────── STATE: PENDING ────────────────
  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = "";
  Map<String, _PayrollEntry> _pendingData = {};
  double _pendingTotalCost = 0;

  // ──────────────── STATE: HISTORY ────────────────
  String _historySearch = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!SessionUser.isAdmin) {
        // Security check handled by base screen usually
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ──────────────── LOGIC: PENDING GENERATION ────────────────

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
      _generatePendingPayroll();
    }
  }

  void _generatePendingPayroll() {
    if (_startDate == null || _endDate == null) return;

    final logsBox = HiveService.attendanceBox;
    final usersBox = HiveService.userBox;

    final endRange = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
    
    // FILTER: Only logs in range AND NOT PAID YET
    final logs = logsBox.values.where((l) => 
      l.date.isAfter(_startDate!.subtract(const Duration(seconds: 1))) && 
      l.date.isBefore(endRange) &&
      l.payrollId == null // 🔒 UNPAID ONLY
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
          logs: [], 
        );
      }

      data[user.id]!.totalHours += log.totalHoursWorked;
      data[user.id]!.grossPay += pay;
      data[user.id]!.logs.add(log); 
      totalCost += pay;
    }

    setState(() {
      _pendingData = data;
      _pendingTotalCost = totalCost;
    });
  }

  // ──────────────── LOGIC: DIALOGS ────────────────

  void _openPendingDetail(_PayrollEntry entry) {
    showDialog(
      context: context,
      builder: (_) => _PayrollDetailDialog(
        entry: entry, 
        startDate: _startDate!, 
        endDate: _endDate!,
        isReadOnly: false,
      ),
    ).then((_) => _generatePendingPayroll()); // Refresh on close
  }

  void _openHistoryDetail(PayrollRecordModel record) {
    showDialog(
      context: context,
      builder: (_) => _PayrollDetailDialog.fromRecord(record),
    );
  }

  // ──────────────── UI BUILD ────────────────

  @override
  Widget build(BuildContext context) {
    if (!SessionUser.isAdmin) {
      return const Scaffold(body: Center(child: Text("Access Denied: Admin Only")));
    }

    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Column(
        children: [
          // ─── TAB HEADER ───
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: ThemeConfig.primaryGreen,
              unselectedLabelColor: Colors.grey,
              indicatorColor: ThemeConfig.primaryGreen,
              tabs: const [
                Tab(text: "Pending / Calculator"),
                Tab(text: "History / Ledger"),
              ],
            ),
          ),

          // ─── TAB VIEWS ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingView(),
                _buildHistoryView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── VIEW: PENDING ────────────────
  Widget _buildPendingView() {
    // Auto-refresh trigger (safe)
    return ValueListenableBuilder(
      valueListenable: HiveService.attendanceBox.listenable(),
      builder: (context, _, __) {
        // Note: We don't call _generatePendingPayroll here directly to avoid loops,
        // but the "Mark Paid" dialog triggers a refresh on close.
        
        final displayedEntries = _pendingData.values.where((e) => 
          e.user.fullName.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Controls
              ContainerCard(
                child: Row(
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
              ),

              const SizedBox(height: 20),

              // Summary
              if (_pendingData.isNotEmpty) ...[
                ContainerCard(
                  padding: const EdgeInsets.all(20),
                  backgroundColor: ThemeConfig.primaryGreen,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("ESTIMATED UNPAID PAYROLL", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Pending generation", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      Text(
                        FormatUtils.formatCurrency(_pendingTotalCost),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      _buildHeaderRow(["Employee", "Role", "Total Hours", "Rate/Hr", "Gross Pay", "Action"], [3, 2, 2, 2, 2, 1]),
                      Expanded(
                        child: _startDate == null
                          ? Center(child: Text("Select a date range.", style: TextStyle(color: Colors.grey[500])))
                          : displayedEntries.isEmpty
                              ? Center(child: Text("No unpaid records found for this period.", style: TextStyle(color: Colors.grey[500])))
                              : ListView.separated(
                                  itemCount: displayedEntries.length,
                                  separatorBuilder: (_,__) => const Divider(height: 1, color: ThemeConfig.lightGray),
                                  itemBuilder: (context, index) {
                                    final entry = displayedEntries[index];
                                    return Material(
                                      color: Colors.white,
                                      child: InkWell(
                                        onTap: () => _openPendingDetail(entry),
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
                                                child: Align(alignment: Alignment.centerLeft, child: Icon(Icons.chevron_right, color: Colors.grey[400])),
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
        );
      }
    );
  }

  // ──────────────── VIEW: HISTORY ────────────────
  Widget _buildHistoryView() {
    return ValueListenableBuilder(
      valueListenable: HiveService.payrollBox.listenable(),
      builder: (context, Box<PayrollRecordModel> box, _) {
        
        // Filter & Sort
        final records = box.values.toList();
        records.sort((a, b) => b.generatedAt.compareTo(a.generatedAt)); // Newest first

        final filteredRecords = _historySearch.isEmpty 
            ? records 
            : records.where((r) {
                final user = HiveService.userBox.get(r.userId);
                return user != null && user.fullName.toLowerCase().contains(_historySearch.toLowerCase());
              }).toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Search
              BasicSearchBox(
                hintText: "Search History...",
                onChanged: (v) => setState(() => _historySearch = v),
              ),
              const SizedBox(height: 20),

              // Table
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      _buildHeaderRow(["Date Paid", "Employee", "Period Covered", "Net Pay", "Paid By"], [2, 3, 3, 2, 2]),
                      Expanded(
                        child: filteredRecords.isEmpty
                            ? const Center(child: Text("No payroll history found."))
                            : ListView.separated(
                                itemCount: filteredRecords.length,
                                separatorBuilder: (_,__) => const Divider(height: 1, color: ThemeConfig.lightGray),
                                itemBuilder: (context, index) {
                                  final rec = filteredRecords[index];
                                  final user = HiveService.userBox.get(rec.userId);
                                  
                                  return Material(
                                    color: Colors.white,
                                    child: InkWell(
                                      onTap: () => _openHistoryDetail(rec),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        child: Row(
                                          children: [
                                            _textCell(DateFormat('MMM dd, yyyy').format(rec.generatedAt), 2, isDim: true),
                                            _textCell(user?.fullName ?? "Unknown", 3, isBold: true),
                                            _textCell("${DateFormat('MMM dd').format(rec.periodStart)} - ${DateFormat('MMM dd').format(rec.periodEnd)}", 3),
                                            _textCell(FormatUtils.formatCurrency(rec.netPay), 2, color: Colors.green, isBold: true),
                                            _textCell(rec.generatedBy, 2, isDim: true),
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
        );
      }
    );
  }

  // ──────────────── HELPERS ────────────────

  Widget _buildHeaderRow(List<String> labels, List<int> flexes) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ThemeConfig.lightGray)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          return Expanded(
            flex: flexes[i],
            child: Text(
              labels[i].toUpperCase(),
              style: const TextStyle(color: ThemeConfig.midGray, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          );
        }),
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
  final List<AttendanceLogModel> logs; 

  _PayrollEntry({
    required this.user,
    required this.totalHours,
    required this.grossPay,
    required this.logs,
  });
}

class _Adjustment {
  String label;
  double amount;
  _Adjustment(this.label, this.amount);
}

// ──────────────────────────────────────────────────────────────────────────
// SPLIT-VIEW PAYROLL DIALOG (Handles Both Modes)
// ──────────────────────────────────────────────────────────────────────────

class _PayrollDetailDialog extends StatefulWidget {
  final _PayrollEntry entry;
  final DateTime startDate;
  final DateTime endDate;
  final bool isReadOnly;
  final List<_Adjustment> initialAdjustments;

  const _PayrollDetailDialog({
    required this.entry,
    required this.startDate,
    required this.endDate,
    this.isReadOnly = false,
    this.initialAdjustments = const [],
  });

  // ✅ Factory for History Mode
  static Widget fromRecord(PayrollRecordModel record) {
    final user = HiveService.userBox.get(record.userId)!;
    
    // Fetch locked logs
    final logs = HiveService.attendanceBox.values
        .where((l) => l.payrollId == record.id)
        .toList();

    // Parse Adjustments
    List<_Adjustment> adjustments = [];
    try {
      final List<dynamic> json = jsonDecode(record.adjustmentsJson);
      adjustments = json.map((j) => _Adjustment(j['label'], (j['amount'] as num).toDouble())).toList();
    } catch (_) {}

    return _PayrollDetailDialog(
      entry: _PayrollEntry(
        user: user,
        totalHours: record.totalHours,
        grossPay: record.grossPay,
        logs: logs,
      ),
      startDate: record.periodStart,
      endDate: record.periodEnd,
      isReadOnly: true,
      initialAdjustments: adjustments,
    );
  }

  @override
  State<_PayrollDetailDialog> createState() => _PayrollDetailDialogState();
}

class _PayrollDetailDialogState extends State<_PayrollDetailDialog> {
  late List<_Adjustment> _adjustments;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _adjustments = List.from(widget.initialAdjustments);
  }

  double get _totalAdjustments => _adjustments.fold(0, (sum, item) => sum + item.amount);
  double get _netPay => widget.entry.grossPay + _totalAdjustments;

  void _markAsPaid() async {
    setState(() => _isLoading = true);

    final user = widget.entry.user;
    final payrollId = const Uuid().v4();
    final now = DateTime.now();

    // 1. Create Master Record
    final record = PayrollRecordModel(
      id: payrollId,
      userId: user.id,
      periodStart: widget.startDate,
      periodEnd: widget.endDate,
      totalHours: widget.entry.totalHours,
      grossPay: widget.entry.grossPay,
      netPay: _netPay,
      adjustmentsJson: jsonEncode(_adjustments.map((a) => {
        'label': a.label, 
        'amount': a.amount
      }).toList()),
      generatedAt: now,
      generatedBy: SessionUser.current?.username ?? 'Admin',
    );

    // 2. Save Locally
    await HiveService.payrollBox.put(record.id, record);

    // 3. Sync
    SupabaseSyncService.addToQueue(
      table: 'payroll_records',
      action: 'UPSERT',
      data: {
        'id': record.id,
        'user_id': record.userId,
        'period_start': record.periodStart.toIso8601String(),
        'period_end': record.periodEnd.toIso8601String(),
        'total_hours': record.totalHours,
        'gross_pay': record.grossPay,
        'net_pay': record.netPay,
        'adjustments_json': record.adjustmentsJson,
        'generated_at': record.generatedAt.toIso8601String(),
        'generated_by': record.generatedBy,
      }
    );

    // 4. Lock Logs
    for (var log in widget.entry.logs) {
      log.payrollId = payrollId;
      await log.save();

      SupabaseSyncService.addToQueue(
        table: 'attendance_logs',
        action: 'UPDATE',
        data: {
          'id': log.id,
          'payroll_id': payrollId,
        }
      );
    }

    if (mounted) {
      Navigator.pop(context);
      DialogUtils.showToast(context, "Payroll Finalized & Logs Locked 🔒");
    }
  }

  void _addAdjustment() {
    if (widget.isReadOnly) return;

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
                BasicInputField(label: "Description", controller: labelCtrl),
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

  @override
  Widget build(BuildContext context) {
    final user = widget.entry.user;
    final sortedLogs = List<AttendanceLogModel>.from(widget.entry.logs)
      ..sort((a, b) => a.date.compareTo(b.date));

    return DialogBoxTitled(
      title: widget.isReadOnly ? "Payroll Record (Locked)" : "Generate Payroll",
      width: 1000, 
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
      ],
      child: SizedBox(
        height: 550,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── LEFT PANE: SHIFT HISTORY ───
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

            // ─── RIGHT PANE: SUMMARY & MATH ───
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  _mathRow("Total Hours", "${widget.entry.totalHours.toStringAsFixed(1)} hrs"),
                  _mathRow("Hourly Rate", FormatUtils.formatCurrency(user.hourlyRate)),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  _mathRow("Gross Pay", FormatUtils.formatCurrency(widget.entry.grossPay), isBold: true),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Adjustments", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      if (!widget.isReadOnly)
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Add"),
                          onPressed: _addAdjustment,
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                    ],
                  ),

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
                                  if (!widget.isReadOnly)
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.red),
                                      onPressed: () => setState(() => _adjustments.removeAt(index)),
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
                      if (!widget.isReadOnly) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: BasicButton(
                            label: _isLoading ? "Saving..." : "Mark Paid",
                            icon: Icons.check_circle,
                            type: AppButtonType.primary,
                            onPressed: _isLoading ? null : _markAsPaid,
                          ),
                        ),
                      ]
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