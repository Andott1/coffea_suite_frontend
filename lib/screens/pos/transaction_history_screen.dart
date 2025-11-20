/// <<FILE: lib/screens/pos/transaction_history_screen.dart>>
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/transaction_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/session_user.dart'; // For Admin check
import '../../core/utils/format_utils.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/basic_dropdown_button.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/dialog_box_titled.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _searchQuery = "";
  String _filterStatus = "All"; // All, Paid, Voided
  DateTime? _startDate;
  DateTime? _endDate;

  // ──────────────── FILTER LOGIC ────────────────
  List<TransactionModel> _getFilteredTransactions(Box<TransactionModel> box) {
    List<TransactionModel> list = box.values.toList().reversed.toList(); // Newest first

    // 1. Search (Order ID or Cashier)
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        return t.id.toLowerCase().contains(q) || 
               t.cashierName.toLowerCase().contains(q);
      }).toList();
    }

    // 2. Status Filter
    if (_filterStatus == "Voided") {
      list = list.where((t) => t.isVoid).toList();
    } else if (_filterStatus == "Paid") {
      list = list.where((t) => !t.isVoid).toList();
    }

    // 3. Date Filter
    if (_startDate != null && _endDate != null) {
      final endOfRange = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
      list = list.where((t) {
        return t.dateTime.isAfter(_startDate!) && t.dateTime.isBefore(endOfRange);
      }).toList();
    }

    return list;
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

  // ──────────────── ACTIONS ────────────────
  
  void _showReceiptDetails(TransactionModel txn) {
    showDialog(
      context: context,
      builder: (_) => DialogBoxTitled(
        title: "Order #${txn.id}",
        subtitle: DateFormat('MMMM dd, yyyy • hh:mm a').format(txn.dateTime),
        width: 450,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          )
        ],
        child: Column(
          children: [
            // Items List
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              height: 300,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: txn.items.length,
                separatorBuilder: (_,__) => const Divider(),
                itemBuilder: (ctx, i) {
                  final item = txn.items[i];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${item.quantity}x ${item.product.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(item.variant, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Text(FormatUtils.formatCurrency(item.total)),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Totals
            _summaryRow("Subtotal", txn.totalAmount / 1.12),
            _summaryRow("VAT (12%)", txn.totalAmount - (txn.totalAmount / 1.12)),
            const Divider(),
            _summaryRow("TOTAL", txn.totalAmount, isBold: true),
            
            const SizedBox(height: 20),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: BasicButton(
                    label: "Reprint Receipt",
                    icon: Icons.print,
                    type: AppButtonType.secondary,
                    onPressed: () => DialogUtils.showToast(context, "Printing..."),
                  ),
                ),
                if (!txn.isVoid) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: BasicButton(
                      label: "Void Order",
                      icon: Icons.block,
                      type: AppButtonType.danger,
                      onPressed: () {
                         Navigator.pop(context); // Close detail first
                        _confirmVoid(txn);
                      },
                    ),
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  void _confirmVoid(TransactionModel txn) {
    // Security Check
    if (!SessionUser.isAdmin) {
      DialogUtils.showToast(context, "Admin access required to void.", icon: Icons.lock, accentColor: Colors.red);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Void"),
        content: const Text("Are you sure you want to void this transaction? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              // TODO: Add logic to RESTORE inventory stock here if needed
              // For now, just marking the transaction as void
              
              // We need to update the Hive object. Since TransactionModel fields are final,
              // we might need to delete and re-add, OR make isVoid mutable.
              // Assuming we can't mutate final fields, we'll handle this by re-saving or handling logic.
              // Ideally TransactionModel 'isVoid' should be mutable or we use Hive's .save() with a new object.
              // Simpler approach for now: Delete old, add new with isVoid=true (preserving ID).
              // But wait! Hive objects are mutable if fields aren't final. 
              // Check TransactionModel definition. If final, we replace.
              
              // Since fields are final in our model definition, we replace the entry:
              final newTxn = TransactionModel(
                id: txn.id,
                dateTime: txn.dateTime,
                items: txn.items,
                totalAmount: txn.totalAmount,
                tenderedAmount: txn.tenderedAmount,
                paymentMethod: txn.paymentMethod,
                cashierName: txn.cashierName,
                referenceNo: txn.referenceNo,
                isVoid: true, // ✅ SET TO TRUE
                status: txn.status,
              );
              
              await HiveService.transactionBox.put(txn.key, newTxn); // Use Hive key to replace in-place
              
              if(mounted) {
                Navigator.pop(ctx);
                DialogUtils.showToast(context, "Transaction Voided", accentColor: Colors.red);
              }
            }, 
            child: const Text("VOID ORDER", style: TextStyle(color: Colors.white))
          )
        ],
      )
    );
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
              child: Row(
                children: [
                  // Search
                  Expanded(
                    child: BasicSearchBox(
                      hintText: "Search Order ID or Cashier...",
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Date Filter
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
                  ],
                  const SizedBox(width: 16),
                  
                  // Status Filter
                  BasicDropdownButton<String>(
                    width: 180,
                    value: _filterStatus,
                    items: const ["All", "Paid", "Voided"],
                    onChanged: (v) => setState(() => _filterStatus = v!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ──────────────── TRANSACTION TABLE ────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: ValueListenableBuilder(
                  valueListenable: HiveService.transactionBox.listenable(),
                  builder: (context, Box<TransactionModel> box, _) {
                    final transactions = _getFilteredTransactions(box);

                    return Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: ThemeConfig.lightGray)),
                          ),
                          child: Row(
                            children: [
                              _headerCell("Time", 2),
                              _headerCell("Order ID", 2),
                              _headerCell("Items Summary", 4),
                              _headerCell("Total", 2),
                              _headerCell("Payment", 2),
                              _headerCell("Status", 2),
                              _headerCell("", 1), // Action Icon
                            ],
                          ),
                        ),
                        
                        // List
                        Expanded(
                          child: transactions.isEmpty 
                            ? Center(child: Text("No transactions found", style: FontConfig.body(context)))
                            : ListView.separated(
                                itemCount: transactions.length,
                                separatorBuilder: (c, i) => const Divider(height: 1, color: ThemeConfig.lightGray),
                                itemBuilder: (context, index) {
                                  final txn = transactions[index];
                                  
                                  // Summarize Items
                                  String summary = "${txn.items.length} Items";
                                  if (txn.items.isNotEmpty) {
                                    summary = "${txn.items[0].quantity}x ${txn.items[0].product.name}";
                                    if (txn.items.length > 1) summary += " +${txn.items.length - 1} more";
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    child: Row(
                                      children: [
                                        _textCell(DateFormat('MM/dd hh:mm a').format(txn.dateTime), 2, isDim: true),
                                        _textCell("#${txn.id.substring(0,8)}", 2, isBold: true),
                                        _textCell(summary, 4),
                                        _textCell(FormatUtils.formatCurrency(txn.totalAmount), 2, isBold: true),
                                        _textCell(txn.paymentMethod, 2),
                                        _statusBadge(txn.isVoid ? "VOID" : "PAID", 2, isVoid: txn.isVoid),
                                        
                                        // View Action
                                        Expanded(
                                          flex: 1,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: IconButton(
                                              icon: const Icon(Icons.visibility, color: ThemeConfig.primaryGreen),
                                              onPressed: () => _showReceiptDetails(txn),
                                            ),
                                          ),
                                        )
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

  Widget _summaryRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(FormatUtils.formatCurrency(value), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
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

  Widget _textCell(String text, int flex, {bool isBold = false, bool isDim = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: isDim ? Colors.grey[600] : ThemeConfig.primaryGreen,
          fontSize: 14,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _statusBadge(String status, int flex, {bool isVoid = false}) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isVoid ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: isVoid ? Colors.red : Colors.green,
              fontSize: 11, 
              fontWeight: FontWeight.bold
            ),
          ),
        ),
      ),
    );
  }
}
/// <<END FILE>>