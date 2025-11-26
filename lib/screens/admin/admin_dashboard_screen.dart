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
import '../../core/widgets/container_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
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
                for (var t in todayTxns) totalSalesToday += t.totalAmount;
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
                  l.date.day == now.day
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

                // Safe MaxY calculation
                double maxChartY = 100;
                if (weeklyData.isNotEmpty) {
                  final maxVal = weeklyData.map((e) => e.amount).reduce((a, b) => a > b ? a : b);
                  if (maxVal > 0) maxChartY = maxVal * 1.2;
                }

                // ──────────────── UI RENDERING ────────────────
                return Scaffold(
                  backgroundColor: ThemeConfig.lightGray,
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TITLE & DATE
                        ContainerCard(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("Store Overview", style: FontConfig.h3(context)),
                              Text(
                                DateFormat('MMMM dd, yyyy (EEEE)').format(now),
                                style: const TextStyle(color: ThemeConfig.secondaryGreen, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),

                        // ─── KPI ROW ───
                        // Fixed height ensures consistent layout
                        SizedBox(
                          height: 110,
                          child: Row(
                            children: [
                              Expanded(child: _buildStatCard(context, "Today's Sales", FormatUtils.formatCurrency(totalSalesToday), Icons.payments, ThemeConfig.primaryGreen)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard(context, "Active Orders", "$orderCountToday", Icons.receipt_long, Colors.blue)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard(context, "Staff Present", "$presentCount / $totalStaff", Icons.people, Colors.purple)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildStatCard(context, "Inventory Alerts", "${lowStockCount + outOfStockCount}", Icons.warning_amber, Colors.orange)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ─── CHARTS AREA ───
                        SizedBox(
                          height: 400,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // LEFT: WEEKLY TREND
                              Expanded(
                                flex: 3,
                                // ✅ FIX: Use _buildChartContainer instead of ContainerCard to allow Expanded children
                                child: _buildChartContainer(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Sales Trend (Last 7 Days)", style: FontConfig.h3(context)),
                                      const SizedBox(height: 30),
                                      Expanded(
                                        child: BarChart(
                                          BarChartData(
                                            alignment: BarChartAlignment.spaceAround,
                                            maxY: maxChartY,
                                            barTouchData: BarTouchData(
                                              touchTooltipData: BarTouchTooltipData(
                                                getTooltipColor: (group) => ThemeConfig.primaryGreen,
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
                                                  getTitlesWidget: (val, meta) {
                                                    if (val.toInt() >= 0 && val.toInt() < weeklyData.length) {
                                                      return Padding(
                                                        padding: const EdgeInsets.only(top: 8.0),
                                                        child: Text(weeklyData[val.toInt()].dayLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                                            gridData: const FlGridData(show: false),
                                            barGroups: weeklyData.asMap().entries.map((e) {
                                              return BarChartGroupData(
                                                x: e.key,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: e.value.amount,
                                                    color: e.key == 6 ? ThemeConfig.primaryGreen : ThemeConfig.primaryGreen.withValues(alpha: 0.3),
                                                    width: 24,
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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

                              const SizedBox(width: 20),

                              // RIGHT: ALERTS LIST
                              Expanded(
                                flex: 2,
                                // ✅ FIX: Use _buildChartContainer here too
                                child: _buildChartContainer(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Needs Attention", style: FontConfig.h3(context)),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: ListView(
                                          children: [
                                            if (outOfStockCount > 0)
                                              _buildAlertTile("$outOfStockCount items OUT OF STOCK", Icons.error, Colors.red),
                                            if (lowStockCount > 0)
                                              _buildAlertTile("$lowStockCount items running low", Icons.warning, Colors.orange),
                                            if (outOfStockCount == 0 && lowStockCount == 0)
                                              const Padding(
                                                padding: EdgeInsets.all(20.0),
                                                child: Center(child: Text("Inventory looks good! ✅", style: TextStyle(color: Colors.grey))),
                                              ),
                                            
                                            const Divider(),
                                            const SizedBox(height: 8),
                                            
                                            Text("Quick Stats", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            _buildMiniRow("Total Staff", "$totalStaff registered"),
                                            _buildMiniRow("Avg Order Value", FormatUtils.formatCurrency(orderCountToday > 0 ? totalSalesToday / orderCountToday : 0)),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }
            );
          }
        );
      }
    );
  }

  // ✅ NEW: Custom container to avoid the Column wrapper in ContainerCard
  Widget _buildChartContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return ContainerCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: FontConfig.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(value, style: FontConfig.h2(context).copyWith(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTile(String msg, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildMiniRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DailySales {
  final String dayLabel;
  final double amount;
  _DailySales({required this.dayLabel, required this.amount});
}