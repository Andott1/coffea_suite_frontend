import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/format_utils.dart';

// Models
import '../../core/models/user_model.dart';
import '../../core/models/product_model.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/models/transaction_model.dart';
import '../../core/models/inventory_log_model.dart';
import '../../core/models/attendance_log_model.dart';
import '../../core/models/payroll_record_model.dart';

class DatabaseViewerScreen extends StatefulWidget {
  const DatabaseViewerScreen({super.key});

  @override
  State<DatabaseViewerScreen> createState() => _DatabaseViewerScreenState();
}

class _DatabaseViewerScreenState extends State<DatabaseViewerScreen> {
  String _selectedBox = 'users';

  final Map<String, String> _boxTitles = {
    'users': 'Users',
    'products': 'Products',
    'ingredients': 'Inventory',
    'transactions': 'Sales',
    'attendance_logs': 'Attendance',
    'inventory_logs': 'Stock Logs',
    'payroll_records': 'Payroll',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.storage, color: Colors.black87),
            const SizedBox(width: 12),
            Text(
              "Database Inspector",
              style: FontConfig.h2(context).copyWith(color: Colors.black87),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade300, height: 1),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                "Read-Only View", 
                style: TextStyle(
                  color: Colors.grey.shade500, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 12
                )
              ),
            ),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. TABLE SELECTOR (Tabs) ───
          Container(
            color: const Color(0xFFF5F7FA),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _boxTitles.entries.map((entry) {
                  final isSelected = _selectedBox == entry.key;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedBox = entry.key),
                      backgroundColor: Colors.white,
                      selectedColor: ThemeConfig.primaryGreen,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(
                          color: isSelected ? ThemeConfig.primaryGreen : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          const Divider(height: 1, thickness: 1),

          // ─── 2. DATA TABLE AREA ───
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.grey.shade200,
                iconTheme: const IconThemeData(color: Colors.grey),
              ),
              child: _buildBoxContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxContent() {
    switch (_selectedBox) {
      case 'users': return _buildTable<UserModel>(
        box: HiveService.userBox, 
        columns: ["ID", "FULL NAME", "USERNAME", "ROLE", "RATE", "STATUS"],
        rowBuilder: (u) => [
          _mono(u.id.substring(0, 8)),
          _text(u.fullName),
          _text(u.username),
          _badge(u.role.name.toUpperCase(), Colors.blue),
          _money(u.hourlyRate),
          _status(u.isActive),
        ]
      );
      
      case 'products': return _buildTable<ProductModel>(
        box: HiveService.productBox,
        columns: ["NAME", "CATEGORY", "SUB-CAT", "TYPE", "PRICES", "STATUS"],
        rowBuilder: (p) => [
          _text(p.name, bold: true),
          _text(p.category),
          _text(p.subCategory),
          _text(p.pricingType),
          _text("${p.prices.length} variants"),
          _status(p.available),
        ]
      );

      case 'ingredients': return _buildTable<IngredientModel>(
        box: HiveService.ingredientBox,
        columns: ["NAME", "STOCK", "UNIT", "REORDER @", "COST/UNIT", "LAST UPDATED"],
        rowBuilder: (i) => [
          _text(i.name, bold: true),
          _text(FormatUtils.formatQuantity(i.displayQuantity), 
            color: i.quantity <= i.reorderLevel ? Colors.red : Colors.green
          ),
          _text(i.unit),
          _text("${i.reorderLevel}"),
          _money(i.unitCost),
          _date(i.updatedAt),
        ]
      );

      case 'transactions': return _buildTable<TransactionModel>(
        box: HiveService.transactionBox,
        columns: ["ID", "DATE / TIME", "TOTAL", "PAYMENT", "CASHIER", "STATUS"],
        rowBuilder: (t) => [
          _mono(t.id),
          _date(t.dateTime),
          _money(t.totalAmount, bold: true),
          _text(t.paymentMethod),
          _text(t.cashierName),
          _badge(t.status.name.toUpperCase(), t.isVoid ? Colors.red : Colors.green),
        ]
      );

      case 'attendance_logs': return _buildTable<AttendanceLogModel>(
        box: HiveService.attendanceBox,
        columns: ["DATE", "USER ID", "TIME IN", "TIME OUT", "HOURS", "STATUS"],
        rowBuilder: (l) => [
          _text(DateFormat('yyyy-MM-dd').format(l.date)),
          _mono(l.userId.substring(0, 8)),
          _time(l.timeIn),
          l.timeOut != null ? _time(l.timeOut!) : _text("--", color: Colors.grey),
          _text(l.totalHoursWorked.toStringAsFixed(2)),
          _badge(l.isVerified ? "VERIFIED" : "PENDING", l.isVerified ? Colors.green : Colors.orange),
        ]
      );

      case 'inventory_logs': return _buildTable<InventoryLogModel>(
        box: HiveService.logsBox,
        columns: ["TIME", "ACTION", "ITEM", "CHANGE", "USER", "REASON"],
        rowBuilder: (l) => [
          _date(l.dateTime),
          _badge(l.action.toUpperCase(), _getActionColor(l.action)),
          _text(l.ingredientName),
          _text(
            "${l.changeAmount > 0 ? '+' : ''}${FormatUtils.formatQuantity(l.changeAmount)} ${l.unit}",
            color: l.changeAmount > 0 ? Colors.green : Colors.red,
            bold: true
          ),
          _text(l.userName),
          _text(l.reason),
        ]
      );

      case 'payroll_records': return _buildTable<PayrollRecordModel>(
        box: HiveService.payrollBox,
        columns: ["GENERATED", "USER ID", "PERIOD", "GROSS", "NET PAY", "BY"],
        rowBuilder: (p) => [
          _date(p.generatedAt),
          _mono(p.userId.substring(0, 8)),
          _text("${DateFormat('MM/dd').format(p.periodStart)} - ${DateFormat('MM/dd').format(p.periodEnd)}"),
          _money(p.grossPay),
          _money(p.netPay, bold: true),
          _text(p.generatedBy),
        ]
      );

      default: return const Center(child: Text("Unknown Box"));
    }
  }

  Color _getActionColor(String action) {
    switch(action) {
      case "Restock": return Colors.blue;
      case "Waste": return Colors.red;
      case "Sale": return Colors.green;
      default: return Colors.grey;
    }
  }

  // ──────────────── GENERIC TABLE BUILDER ────────────────

  Widget _buildTable<T>({
    required Box<T> box,
    required List<String> columns,
    required List<Widget> Function(T item) rowBuilder,
  }) {
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box<T> box, _) {
        final items = box.values.toList(); 
        
        if (items.isEmpty) {
          return _buildEmptyState();
        }

        // ✅ KEY FIX: LayoutBuilder + ConstrainedBox(minWidth)
        // This ensures the table stretches to fill the screen width
        return LayoutBuilder(
          builder: (context, constraints) {
            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 52,
                      columnSpacing: 24,
                      horizontalMargin: 24,
                      columns: columns.map((c) => DataColumn(
                        label: Text(
                          c, 
                          style: const TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: Colors.black54, 
                            fontSize: 12
                          )
                        )
                      )).toList(),
                      rows: List.generate(items.length, (index) {
                        // Show newest items at the top
                        final item = items[items.length - 1 - index];
                        final cells = rowBuilder(item);
                        
                        return DataRow(
                          color: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                            if (index.isOdd) return Colors.grey.withValues(alpha: 0.02);
                            return null; 
                          }),
                          cells: cells.map((w) => DataCell(w)).toList(),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_rows_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Table is empty", 
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16)
          ),
        ],
      ),
    );
  }

  // ──────────────── CELL WIDGET HELPERS ────────────────

  Widget _text(String text, {bool bold = false, Color? color}) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        color: color ?? Colors.black87,
        fontSize: 13,
      ),
    );
  }

  Widget _mono(String text) {
    return SelectableText(
      text,
      style: TextStyle(
        fontFamily: 'RobotoMono', 
        fontSize: 12,
        color: Colors.grey.shade700,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _money(double value, {bool bold = false}) {
    return Text(
      FormatUtils.formatCurrency(value),
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: Colors.black87,
        fontSize: 13,
      ),
    );
  }

  Widget _date(DateTime dt) {
    return Text(
      DateFormat('yyyy-MM-dd HH:mm').format(dt),
      style: const TextStyle(fontSize: 12, color: Colors.black54),
    );
  }

  Widget _time(DateTime dt) {
    return Text(
      DateFormat('HH:mm:ss').format(dt),
      style: const TextStyle(fontSize: 12, color: Colors.black54),
    );
  }

  Widget _status(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isActive ? Colors.green : Colors.grey),
      ),
      child: Text(
        isActive ? "ACTIVE" : "INACTIVE",
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green : Colors.grey
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.bold,
          color: color
        ),
      ),
    );
  }
}