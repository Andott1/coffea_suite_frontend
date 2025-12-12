import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/transaction_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/container_card.dart';

class POSDashboardScreen extends StatelessWidget {
  const POSDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: HiveService.transactionBox.listenable(),
      builder: (context, Box<TransactionModel> box, _) {
        
        // ──────────────── DATA PROCESSING ────────────────
        final now = DateTime.now();
        final todayTransactions = box.values.where((t) {
          return !t.isVoid && 
                 t.dateTime.year == now.year &&
                 t.dateTime.month == now.month &&
                 t.dateTime.day == now.day;
        }).toList();

        double totalSales = 0;
        int totalOrders = todayTransactions.length;
        
        final List<double> hourlySales = List.filled(24, 0.0);
        
        // ✅ CHANGED: Map to store Count (int) instead of Amount (double)
        final Map<String, int> paymentCounts = {};
        final Map<String, int> productCounts = {};

        for (var t in todayTransactions) {
          totalSales += t.totalAmount;
          hourlySales[t.dateTime.hour] += t.totalAmount;
          
          // Increment transaction count for this payment method
          paymentCounts[t.paymentMethod] = (paymentCounts[t.paymentMethod] ?? 0) + 1;

          for (var item in t.items) {
            productCounts[item.product.name] = (productCounts[item.product.name] ?? 0) + item.quantity;
          }
        }

        final avgTicket = totalOrders > 0 ? totalSales / totalOrders : 0.0;

        // Sort Data
        final topProducts = productCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)); 
        final top5 = topProducts.take(5).toList();

        final sortedPayments = paymentCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        // ──────────────── UI LAYOUT ────────────────
        return Scaffold(
          backgroundColor: ThemeConfig.lightGray,
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. HEADER
                ContainerCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Sales Monitor", style: FontConfig.h3(context)),
                      Text(
                        DateFormat('MMMM dd, yyyy (EEEE)').format(now),
                        style: const TextStyle(color: ThemeConfig.secondaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. KPI CARDS (Fixed Height)
                SizedBox(
                  height: 100,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context, "Total Sales", FormatUtils.formatCurrency(totalSales), 
                          Icons.payments, ThemeConfig.primaryGreen
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          context, "Total Orders", "$totalOrders", 
                          Icons.receipt_long, Colors.orange
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          context, "Avg. Ticket", FormatUtils.formatCurrency(avgTicket), 
                          Icons.analytics, Colors.blue
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. CHARTS SECTION
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT: HOURLY CHART
                      Expanded(
                        flex: 3,
                        child: _buildChartContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hourly Sales Performance", style: FontConfig.h3(context)),
                              const SizedBox(height: 24),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 16, bottom: 8),
                                  child: _HourlyBarChart(hourlyData: hourlySales),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // RIGHT: LISTS (Payment & Products)
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            // Payment Methods List (REPLACED PIE CHART)
                            Expanded(
                              child: _buildChartContainer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Payment Methods", style: FontConfig.h3(context)),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: sortedPayments.isEmpty 
                                        ? Center(child: Text("No Sales Yet", style: TextStyle(color: Colors.grey[400])))
                                        : ListView.builder(
                                            itemCount: sortedPayments.length,
                                            itemBuilder: (ctx, i) {
                                               final entry = sortedPayments[i];
                                               return _buildPaymentRow(entry.key, entry.value, context);
                                            },
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),

                            // Top Products List
                            Expanded(
                              child: _buildChartContainer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Top Products Today", style: FontConfig.h3(context)),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: top5.isEmpty
                                        ? Center(child: Text("No Data", style: TextStyle(color: Colors.grey[400])))
                                        : ListView.builder(
                                            itemCount: top5.length,
                                            itemBuilder: (ctx, i) => _buildTopProductItem(i + 1, top5[i]),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // ✅ NEW: Helper to build Payment Rows (List Style)
  Widget _buildPaymentRow(String method, int count, BuildContext context) {
    String label = method.toUpperCase();
    if (label == "EWALLET") label = "E-WALLET";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 24,
                decoration: BoxDecoration(
                  color: ThemeConfig.primaryGreen,
                  borderRadius: BorderRadius.circular(2)
                ),
              ),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  // Helper to style containers
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: FontConfig.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  style: FontConfig.h2(context).copyWith(
                    fontWeight: FontWeight.w800,
                    color: ThemeConfig.primaryGreen,
                    fontSize: 22,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductItem(int rank, MapEntry<String, int> entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank == 1 ? Colors.amber : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Text("$rank", style: TextStyle(
              fontWeight: FontWeight.bold, 
              fontSize: 12,
              color: rank == 1 ? Colors.white : Colors.grey[600]
            )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
          ),
          Text("${entry.value} sold", style: const TextStyle(color: ThemeConfig.secondaryGreen, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

// ──────────────── CHARTS ────────────────

class _HourlyBarChart extends StatelessWidget {
  final List<double> hourlyData;
  const _HourlyBarChart({required this.hourlyData});

  @override
  Widget build(BuildContext context) {
    double maxY = hourlyData.reduce((a, b) => a > b ? a : b);
    if (maxY == 0) maxY = 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
             getTooltipColor: (group) => ThemeConfig.primaryGreen,
             getTooltipItem: (group, groupIndex, rod, rodIndex) {
               return BarTooltipItem(
                 "${group.x.toString().padLeft(2,'0')}:00\n",
                 const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                 children: [
                   TextSpan(
                     text: FormatUtils.formatCurrency(rod.toY),
                     style: const TextStyle(color: Colors.yellowAccent)
                   )
                 ]
               );
             }
          )
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int hour = value.toInt();
                if (hour % 3 == 0) {
                   return Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Text("$hour:00", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                   );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(24, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: hourlyData[index],
                color: hourlyData[index] > 0 ? ThemeConfig.primaryGreen : Colors.grey[200],
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              )
            ],
          );
        }),
      ),
    );
  }
}