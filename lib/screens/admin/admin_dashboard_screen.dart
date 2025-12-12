import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/attendance_log_model.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/models/transaction_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/format_utils.dart';

// ✅ Reuse standard widgets for consistency
import 'widgets/flat_dropdown.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _timeRange = "Last 7 Days"; // Placeholder for filter logic

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray, // Standard Admin Background
      body: ValueListenableBuilder(
        valueListenable: HiveService.transactionBox.listenable(),
        builder: (context, Box<TransactionModel> txnBox, _) {
          return ValueListenableBuilder(
            valueListenable: HiveService.ingredientBox.listenable(),
            builder: (context, Box<IngredientModel> ingBox, _) {
              return ValueListenableBuilder(
                valueListenable: HiveService.attendanceBox.listenable(),
                builder: (context, Box<AttendanceLogModel> attBox, _) {
                  
                  // ──────────────── CALCULATION ENGINE ────────────────
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);
                  
                  // 1. SALES METRICS (TODAY)
                  final todayTxns = txnBox.values.where((t) => 
                    !t.isVoid && 
                    t.dateTime.isAfter(todayStart)
                  ).toList();

                  double totalSalesToday = 0;
                  for (var t in todayTxns) {
                    totalSalesToday += t.totalAmount;
                  }
                  int orderCountToday = todayTxns.length;

                  // 2. INVENTORY HEALTH
                  int lowStockCount = 0;
                  int outOfStockCount = 0;
                  for (var i in ingBox.values) {
                    if (i.quantity <= 0) {
                      outOfStockCount++;
                    } else if (i.quantity <= i.reorderLevel) {
                      lowStockCount++;
                    }
                  }

                  // 3. ATTENDANCE SNAPSHOT
                  final activeStaffIds = attBox.values.where((l) => 
                    l.date.year == now.year && 
                    l.date.month == now.month && 
                    l.date.day == now.day &&
                    l.timeOut == null // Still clocked in
                  ).map((l) => l.userId).toSet();
                  
                  final totalStaff = HiveService.userBox.values.where((u) => u.isActive && u.role != UserRoleLevel.admin).length;
                  final presentCount = activeStaffIds.length;

                  // 4. WEEKLY SALES CHART DATA
                  final List<_DailySales> weeklyData = [];
                  for (int i = 6; i >= 0; i--) {
                    final date = now.subtract(Duration(days: i));
                    final startOfDay = DateTime(date.year, date.month, date.day);
                    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

                    final daySales = txnBox.values.where((t) => 
                      !t.isVoid && 
                      t.dateTime.isAfter(startOfDay) && 
                      t.dateTime.isBefore(endOfDay)
                    ).fold(0.0, (sum, t) => sum + t.totalAmount);

                    weeklyData.add(_DailySales(
                      dayLabel: DateFormat('E').format(date),
                      amount: daySales
                    ));
                  }

                  double maxChartY = 100;
                  if (weeklyData.isNotEmpty) {
                    final maxVal = weeklyData.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
                    if (maxVal > 0) maxChartY = maxVal * 1.2;
                  }

                  // ──────────────── UI RENDERING ────────────────
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── 1. HEADER ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Store Overview", style: FontConfig.h2(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEEE, MMMM d, yyyy').format(now),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 200,
                              child: FlatDropdown<String>(
                                value: _timeRange,
                                items: const ["Last 7 Days", "Last 30 Days", "This Month"],
                                label: "Range",
                                icon: Icons.calendar_today,
                                onChanged: (v) => setState(() => _timeRange = v!),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),

                        // ─── 2. KPI ROW ───
                        Row(
                          children: [
                            _buildKpiCard("Today's Sales", FormatUtils.formatCurrency(totalSalesToday), Icons.payments, ThemeConfig.primaryGreen),
                            const SizedBox(width: 16),
                            _buildKpiCard("Orders", "$orderCountToday", Icons.receipt_long, Colors.blue),
                            const SizedBox(width: 16),
                            _buildKpiCard("Staff Active", "$presentCount / $totalStaff", Icons.people, Colors.purple),
                            const SizedBox(width: 16),
                            _buildKpiCard("Alerts", "${lowStockCount + outOfStockCount}", Icons.notifications_active, Colors.orange),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // ─── 3. MAIN CONTENT (SPLIT) ───
                        SizedBox(
                          height: 450, // Fixed height for alignment
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // LEFT: CHART (65%)
                              Expanded(
                                flex: 65,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: _flatDecoration(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text("Revenue Trend", style: FontConfig.h3(context)),
                                          Row(
                                            children: [
                                              _legendItem("Sales", ThemeConfig.primaryGreen),
                                            ],
                                          )
                                        ],
                                      ),
                                      const SizedBox(height: 32),
                                      Expanded(
                                        child: BarChart(
                                          BarChartData(
                                            alignment: BarChartAlignment.spaceAround,
                                            maxY: maxChartY,
                                            barTouchData: BarTouchData(
                                              touchTooltipData: BarTouchTooltipData(
                                                getTooltipColor: (group) => Colors.black87,
                                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                  return BarTooltipItem(
                                                    FormatUtils.formatCurrency(rod.toY),
                                                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                                                  );
                                                }
                                              )
                                            ),
                                            titlesData: FlTitlesData(
                                              show: true,
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  reservedSize: 40,
                                                  getTitlesWidget: (val, meta) {
                                                    if (val.toInt() >= 0 && val.toInt() < weeklyData.length) {
                                                      return Padding(
                                                        padding: const EdgeInsets.only(top: 12.0),
                                                        child: Text(
                                                          weeklyData[val.toInt()].dayLabel, 
                                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              ),
                                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                            ),
                                            borderData: FlBorderData(show: false),
                                            gridData: FlGridData(
                                              show: true,
                                              drawVerticalLine: false,
                                              horizontalInterval: maxChartY / 5,
                                              getDrawingHorizontalLine: (value) => FlLine(
                                                color: Colors.grey[100], 
                                                strokeWidth: 1,
                                                dashArray: [5, 5]
                                              ),
                                            ),
                                            barGroups: weeklyData.asMap().entries.map((e) {
                                              return BarChartGroupData(
                                                x: e.key,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: e.value.amount,
                                                    color: e.key == 6 ? ThemeConfig.primaryGreen : ThemeConfig.primaryGreen.withValues(alpha: 0.3),
                                                    width: 32, // Thicker, modern bars
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                                    backDrawRodData: BackgroundBarChartRodData(
                                                      show: true,
                                                      toY: maxChartY,
                                                      color: Colors.grey[50],
                                                    ),
                                                  )
                                                ]
                                              );
                                            }).toList(),
                                          )
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 24),

                              // RIGHT: STORE PULSE (35%)
                              Expanded(
                                flex: 35,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: _flatDecoration(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Store Status", style: FontConfig.h3(context)),
                                      const SizedBox(height: 20),
                                      
                                      // Inventory Section
                                      _sectionHeader("INVENTORY"),
                                      if (outOfStockCount > 0)
                                        _alertTile("$outOfStockCount items Out of Stock", Icons.error_outline, Colors.red)
                                      else if (lowStockCount > 0)
                                        _alertTile("$lowStockCount items Low Stock", Icons.warning_amber, Colors.orange)
                                      else
                                        _statusTile("Inventory Healthy", Icons.check_circle_outline, Colors.green),

                                      const SizedBox(height: 20),

                                      // Staff Section
                                      _sectionHeader("STAFF"),
                                      _statusTile("$presentCount Active on Floor", Icons.badge_outlined, Colors.blue),
                                      
                                      const Spacer(),
                                      const Divider(),
                                      
                                      // System Info
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text("System Status", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                                              child: const Text("OPERATIONAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                            )
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              );
            }
          );
        }
      ),
    );
  }

  // ──────────────── WIDGET HELPERS ────────────────

  BoxDecoration _flatDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: _flatDecoration(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black87)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title, 
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey, letterSpacing: 1.0)
      ),
    );
  }

  Widget _alertTile(String msg, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(msg, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _statusTile(String msg, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(msg, style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
      ],
    );
  }
}

class _DailySales {
  final String dayLabel;
  final double amount;
  _DailySales({required this.dayLabel, required this.amount});
}