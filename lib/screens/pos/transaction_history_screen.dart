import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/transaction_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/session_user.dart'; 
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/basic_dropdown_button.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/dialog_box_titled.dart';
import 'bloc/stock_logic.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _searchQuery = "";
  String _filterStatus = "All"; 
  DateTime? _startDate;
  DateTime? _endDate;

  // ──────────────── FILTER LOGIC ────────────────
  List<TransactionModel> _getFilteredTransactions(Box<TransactionModel> box) {
    List<TransactionModel> list = box.values.toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        return t.id.toLowerCase().contains(q) || 
               t.cashierName.toLowerCase().contains(q);
      }).toList();
    }

    if (_filterStatus == "Voided") {
      list = list.where((t) => t.isVoid).toList();
    } else if (_filterStatus == "Paid") {
      list = list.where((t) => !t.isVoid).toList();
    }

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
      builder: (_) => _TransactionDetailDialog(
        txn: txn,
        onVoid: () {
          Navigator.pop(context); // Close detail first
          _confirmVoid(txn);
        },
      ),
    );
  }

  void _confirmVoid(TransactionModel txn) {
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
              // ✅ Capture Navigator before async gap
              final navigator = Navigator.of(ctx);

              // 1. Restore Inventory
              await StockLogic.restoreStock(txn.items, txn.id);

              // 2. Update Transaction Model
              final newTxn = TransactionModel(
                id: txn.id,
                dateTime: txn.dateTime,
                items: txn.items,
                totalAmount: txn.totalAmount,
                tenderedAmount: txn.tenderedAmount,
                paymentMethod: txn.paymentMethod,
                cashierName: txn.cashierName,
                referenceNo: txn.referenceNo,
                isVoid: true, 
                status: OrderStatus.voided, 
                orderType: txn.orderType,
              );
              
              await HiveService.transactionBox.put(txn.key, newTxn); 

              // 3. Sync
              SupabaseSyncService.addToQueue(
                table: 'transactions',
                action: 'UPSERT',
                data: {
                  'id': newTxn.id,
                  'is_void': true,
                  'status': 'voided',
                  'date_time': newTxn.dateTime.toIso8601String(),
                  'total_amount': newTxn.totalAmount,
                  'tendered_amount': newTxn.tenderedAmount,
                  'payment_method': newTxn.paymentMethod,
                  'cashier_name': newTxn.cashierName,
                  'reference_no': newTxn.referenceNo,
                  'order_type': newTxn.orderType,
                  'items': newTxn.items.map((i) => {
                    'product_name': i.product.name,
                    'variant': i.variant,
                    'qty': i.quantity,
                    'price': i.price,
                    'total': i.total
                  }).toList(),
                }
              );
              
              // ✅ Safe UI Update
              if(mounted) {
                navigator.pop(); // Use captured navigator
                DialogUtils.showToast(context, "Transaction Voided & Stock Restored", accentColor: Colors.red);
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
                  Expanded(
                    child: BasicSearchBox(
                      hintText: "Search Order ID or Cashier...",
                      onChanged: (v) => setState(() => _searchQuery = v),
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
                  ],
                  const SizedBox(width: 16),
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
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
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
                              // _headerCell("", 1), // Removed explicit action column
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
                                  
                                  String summary = "${txn.items.length} Items";
                                  if (txn.items.isNotEmpty) {
                                    summary = "${txn.items[0].quantity}x ${txn.items[0].product.name}";
                                    if (txn.items.length > 1) summary += " +${txn.items.length - 1} more";
                                  }

                                  return Material(
                                    color: Colors.white,
                                    child: InkWell(
                                      // ✅ WHOLE ROW CLICKABLE
                                      onTap: () => _showReceiptDetails(txn),
                                      hoverColor: ThemeConfig.primaryGreen.withValues(alpha: 0.05),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        child: Row(
                                          children: [
                                            _textCell(DateFormat('MM/dd hh:mm a').format(txn.dateTime), 2, isDim: true),
                                            _textCell("#${txn.id.substring(0,8)}", 2, isBold: true),
                                            _textCell(summary, 4),
                                            _textCell(FormatUtils.formatCurrency(txn.totalAmount), 2, isBold: true),
                                            _textCell(txn.paymentMethod, 2),
                                            _statusBadge(txn.isVoid ? "VOID" : "PAID", 2, isVoid: txn.isVoid),
                                          ],
                                        ),
                                      ),
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

// ──────────────────────────────────────────────────────────────────────────
// SPLIT-VIEW RECEIPT DIALOG
// ──────────────────────────────────────────────────────────────────────────

class _TransactionDetailDialog extends StatelessWidget {
  final TransactionModel txn;
  final VoidCallback onVoid;

  const _TransactionDetailDialog({
    required this.txn, 
    required this.onVoid,
  });

  @override
  Widget build(BuildContext context) {
    final subtotal = txn.totalAmount / 1.12;
    final vat = txn.totalAmount - subtotal;

    return DialogBoxTitled(
      title: "Transaction Details",
      width: 900, // Wide for split view
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
      ],
      child: SizedBox(
        height: 500, // Fixed height
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── LEFT: CONTEXT PANE ───
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ThemeConfig.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order ID
                    Text("ORDER ID", style: FontConfig.caption(context)),
                    SelectableText(
                      "#${txn.id}",
                      style: FontConfig.h2(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    _detailRow("Date", DateFormat('MMM dd, yyyy').format(txn.dateTime)),
                    _detailRow("Time", DateFormat('hh:mm a').format(txn.dateTime)),
                    _detailRow("Cashier", txn.cashierName),
                    _detailRow("Type", txn.orderType == "dineIn" ? "Dine-In" : "Take-Out"),
                    
                    const Divider(height: 40),

                    _detailRow("Payment", txn.paymentMethod),
                    if (txn.referenceNo != null)
                      _detailRow("Ref #", txn.referenceNo!),

                    const Spacer(),

                    // Status Badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: txn.isVoid ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        txn.isVoid ? "VOIDED" : "PAID",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 2),
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(width: 20),

            const VerticalDivider(width: 1),

            // ─── RIGHT: RECEIPT PANE ───
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 10, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text("Items (${txn.items.length})", style: FontConfig.h3(context)),
                    const SizedBox(height: 16),

                    // 📜 SCROLLABLE ITEMS LIST
                    Expanded(
                      child: ListView.separated(
                        itemCount: txn.items.length,
                        separatorBuilder: (_,__) => const Divider(),
                        itemBuilder: (context, index) {
                          final item = txn.items[index];
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${item.quantity}x  ${item.product.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    if (item.variant.isNotEmpty)
                                      Text(item.variant, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Text(
                                FormatUtils.formatCurrency(item.total),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const Divider(thickness: 2),
                    const SizedBox(height: 16),

                    // Totals
                    _summaryRow("Subtotal", subtotal),
                    _summaryRow("VAT (12%)", vat),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("TOTAL", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(FormatUtils.formatCurrency(txn.totalAmount), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ThemeConfig.primaryGreen)),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        if (!txn.isVoid && SessionUser.isAdmin) ...[
                          Expanded(
                            child: BasicButton(
                              label: "Void",
                              icon: Icons.block,
                              type: AppButtonType.danger,
                              onPressed: onVoid,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: BasicButton(
                            label: "Print Receipt",
                            icon: Icons.print,
                            type: AppButtonType.secondary,
                            onPressed: () => DialogUtils.showToast(context, "Printing..."),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(FormatUtils.formatCurrency(value), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}