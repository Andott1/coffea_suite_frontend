import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/inventory_log_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/dialog_utils.dart'; 
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/basic_dropdown_button.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/basic_button.dart'; // ✅ Using BasicButton
import '../../core/services/backup_service.dart'; // ✅ Import
import '../../core/widgets/backups_list_dialog.dart'; // ✅ Import

class InventoryLogsTab extends StatefulWidget {
  const InventoryLogsTab({super.key});

  @override
  State<InventoryLogsTab> createState() => _InventoryLogsTabState();
}

class _InventoryLogsTabState extends State<InventoryLogsTab> {
  String _searchQuery = "";
  String _filterType = "All Actions";
  DateTime? _startDate;
  DateTime? _endDate;
  
  bool _showActions = false; 

  // ──────────────── ACTIONS ────────────────
  
  Future<void> _exportLogs() async {
    try {
      final path = await BackupService().exportLogsToCSV();
      if (mounted) {
        DialogUtils.showToast(context, "CSV Saved to: $path");
        // In a real app, you might want to use Share.shareXFiles here to open it
      }
    } catch (e) {
      DialogUtils.showToast(context, "Export failed: $e", icon: Icons.error);
    }
  }

  Future<void> _backupLogs() async {
    try {
      final entry = await BackupService().createBackup(type: 'logs');
      if (mounted) {
        DialogUtils.showToast(context, "Backup created: ${entry.filename}");
      }
    } catch (e) {
      DialogUtils.showToast(context, "Backup failed: $e", icon: Icons.error);
    }
  }

  Future<void> _restoreLogs() async {
    // Open the reusable Restore Dialog
    await showDialog(
      context: context,
      builder: (_) => BackupsListDialog(
        backupService: BackupService(), 
        type: 'logs',
      ),
    );
    
    // The UI automatically listens to Hive boxes, so no manual setState needed 
    // if the box was cleared and repopulated properly.
    if (mounted) setState(() {}); 
  }

  // ──────────────── FILTER LOGIC ────────────────
  List<InventoryLogModel> _getFilteredLogs(Box<InventoryLogModel> box) {
    List<InventoryLogModel> logs = box.values.toList().reversed.toList();

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      logs = logs.where((log) {
        return log.ingredientName.toLowerCase().contains(q) ||
               log.userName.toLowerCase().contains(q) ||
               log.reason.toLowerCase().contains(q);
      }).toList();
    }

    if (_filterType != "All Actions") {
      logs = logs.where((log) => log.action == _filterType).toList();
    }

    if (_startDate != null && _endDate != null) {
      final endOfRange = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      logs = logs.where((log) {
        return log.dateTime.isAfter(_startDate!) && log.dateTime.isBefore(endOfRange);
      }).toList();
    }

    return logs;
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ──────────────── CONTROL PANEL ────────────────
            ContainerCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // ─── ROW 1: MAIN CONTROLS ───
                  Row(
                    children: [
                      // Search
                      Expanded(
                        child: BasicSearchBox(
                          hintText: "Search log (Item, User, Reason)...",
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // ✅ Date Filter (Using BasicButton)
                      BasicButton(
                        label: _startDate == null 
                            ? "Date Range" 
                            : "${DateFormat('MM/dd').format(_startDate!)} - ${DateFormat('MM/dd').format(_endDate!)}",
                        icon: Icons.calendar_today,
                        type: AppButtonType.secondary,
                        fullWidth: false, // Important for inline buttons
                        onPressed: _pickDateRange,
                      ),

                      if (_startDate != null) ...[
                         const SizedBox(width: 8),
                         IconButton(
                           icon: const Icon(Icons.clear, color: Colors.red),
                           onPressed: () => setState(() { _startDate = null; _endDate = null; }),
                         )
                      ],
                      
                      const SizedBox(width: 16),
                      
                      // Action Dropdown
                      BasicDropdownButton<String>(
                        width: 200,
                        value: _filterType,
                        items: const ["All Actions", "Restock", "Waste", "Correction"],
                        onChanged: (v) => setState(() => _filterType = v!),
                      ),

                      const SizedBox(width: 16),

                      // Toggle Button
                      IconButton(
                        onPressed: () => setState(() => _showActions = !_showActions),
                        icon: AnimatedRotation(
                          turns: _showActions ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down, color: ThemeConfig.primaryGreen),
                        ),
                        tooltip: "More Actions",
                        style: IconButton.styleFrom(
                          backgroundColor: _showActions ? ThemeConfig.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),

                  // ─── ROW 2: EXPANDABLE ACTIONS ───
                  AnimatedCrossFade(
                    firstChild: const SizedBox(width: double.infinity), 
                    secondChild: Column(
                      children: [
                        const SizedBox(height: 16),

                        ValueListenableBuilder(
                          valueListenable: HiveService.logsBox.listenable(),
                          builder: (context, Box<InventoryLogModel> box, _) {
                            final count = _getFilteredLogs(box).length;
                            
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Record Count
                                Text(
                                  "$count Records Found",
                                  style: FontConfig.body(context).copyWith(
                                    color: ThemeConfig.midGray, 
                                    fontWeight: FontWeight.w600
                                  ),
                                ),

                                // ✅ Action Buttons (Using BasicButton)
                                Row(
                                  children: [
                                    BasicButton(
                                      label: "Export CSV", 
                                      icon: Icons.download_rounded, 
                                      type: AppButtonType.secondary,
                                      fullWidth: false,
                                      height: 40, // Compact height for toolbar
                                      onPressed: _exportLogs,
                                    ),
                                    const SizedBox(width: 12),
                                    BasicButton(
                                      label: "Backup", 
                                      icon: Icons.save, 
                                      type: AppButtonType.secondary,
                                      fullWidth: false,
                                      height: 40,
                                      onPressed: _backupLogs,
                                    ),
                                    const SizedBox(width: 12),
                                    BasicButton(
                                      label: "Restore", 
                                      icon: Icons.restore, 
                                      type: AppButtonType.danger, // Distinctive style
                                      fullWidth: false,
                                      height: 40,
                                      onPressed: _restoreLogs,
                                    ),
                                  ],
                                )
                              ],
                            );
                          }
                        ),
                      ],
                    ),
                    crossFadeState: _showActions ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ──────────────── LOG TABLE (Unchanged) ────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: ValueListenableBuilder(
                  valueListenable: HiveService.logsBox.listenable(),
                  builder: (context, Box<InventoryLogModel> box, _) {
                    final logs = _getFilteredLogs(box);

                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: ThemeConfig.lightGray)),
                          ),
                          child: Row(
                            children: [
                              _headerCell("Date / Time", 2),
                              _headerCell("Item Name", 3),
                              _headerCell("Action", 2),
                              _headerCell("Qty Change", 2),
                              _headerCell("User", 2),
                              _headerCell("Reason / Note", 3),
                            ],
                          ),
                        ),
                        Expanded(
                          child: logs.isEmpty 
                            ? Center(child: Text("No logs found", style: FontConfig.body(context)))
                            : ListView.separated(
                                itemCount: logs.length,
                                separatorBuilder: (c, i) => const Divider(height: 1, color: ThemeConfig.lightGray),
                                itemBuilder: (context, index) {
                                  final log = logs[index];
                                  final isPositive = log.changeAmount >= 0;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    child: Row(
                                      children: [
                                        _textCell(DateFormat('MMM dd, hh:mm a').format(log.dateTime), 2, isDim: true),
                                        _textCell(log.ingredientName, 3, isBold: true),
                                        _badgeCell(log.action, 2),
                                        _textCell(
                                          "${isPositive ? '+' : ''}${FormatUtils.formatQuantity(log.changeAmount)} ${log.unit}", 
                                          2, 
                                          color: isPositive ? ThemeConfig.primaryGreen : Colors.redAccent, 
                                          isBold: true
                                        ),
                                        _textCell(log.userName, 2),
                                        _textCell(log.reason, 3, isDim: true),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ),
                      ],
                    );
                  },
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
        style: const TextStyle(color: ThemeConfig.primaryGreen, fontWeight: FontWeight.w700, fontSize: 12),
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

  Widget _badgeCell(String action, int flex) {
    Color bg;
    Color text;
    
    switch(action) {
      case "Restock": bg = Colors.green.shade50; text = Colors.green; break;
      case "Waste": bg = Colors.red.shade50; text = Colors.red; break;
      case "Correction": bg = Colors.orange.shade50; text = Colors.orange; break;
      default: bg = Colors.blue.shade50; text = Colors.blue; break;
    }

    return Expanded(
      flex: flex,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
          child: Text(
            action.toUpperCase(),
            style: TextStyle(color: text, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
/// <<END FILE>>