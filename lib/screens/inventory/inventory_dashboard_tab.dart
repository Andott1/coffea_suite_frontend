import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/models/inventory_log_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/container_card.dart';

class InventoryDashboardTab extends StatelessWidget {
  const InventoryDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    // Listen to BOTH boxes so the dashboard updates on ANY change (stock add, log entry, product edit)
    return ValueListenableBuilder(
      valueListenable: HiveService.ingredientBox.listenable(),
      builder: (context, Box<IngredientModel> ingBox, _) {
        return ValueListenableBuilder(
          valueListenable: HiveService.logsBox.listenable(),
          builder: (context, Box<InventoryLogModel> logBox, _) {
            
            // ──────────────── CALCULATION LOGIC ────────────────
            final ingredients = ingBox.values.toList();
            
            double totalVal = 0;
            int lowStockCount = 0;
            int outOfStockCount = 0;
            
            // Category Aggregation for Pie Chart
            final Map<String, double> categoryValues = {};

            for (var i in ingredients) {
              totalVal += i.totalValue;
              
              if (i.quantity <= 0) {
                outOfStockCount++;
              } else if (i.quantity <= i.reorderLevel) {
                lowStockCount++;
              }

              // Aggregate value
              categoryValues[i.category] = (categoryValues[i.category] ?? 0) + i.totalValue;
            }

            // Get recent logs
            final recentLogs = logBox.values.toList()
              ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // Newest first
            final top5Logs = recentLogs.take(5).toList();

            // ──────────────── UI LAYOUT ────────────────
            return Scaffold(
              backgroundColor: ThemeConfig.lightGray,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContainerCard(
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          "Overview", 
                          style: FontConfig.h3(context),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 14),

                    // ─── KPI CARDS ───
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            label: "Total Stock Value",
                            value: FormatUtils.formatCurrency(totalVal),
                            icon: Icons.monetization_on,
                            color: ThemeConfig.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            label: "Low Stock Items",
                            value: "$lowStockCount",
                            icon: Icons.warning_amber_rounded,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            label: "Out of Stock",
                            value: "$outOfStockCount",
                            icon: Icons.error_outline,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ─── SPLIT SECTION ───
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT: PIE CHART
                        Expanded(
                          flex: 3,
                          child: ContainerCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Stock Value by Category", style: FontConfig.h3(context)),
                                const SizedBox(height: 30),
                                SizedBox(
                                  height: 300,
                                  child: categoryValues.isEmpty 
                                    ? Center(child: Text("No Data", style: FontConfig.body(context)))
                                    : _ValuePieChart(data: categoryValues, total: totalVal),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 20),

                        // RIGHT: RECENT ACTIVITY
                        Expanded(
                          flex: 2,
                          child: ContainerCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Recent Activity", style: FontConfig.h3(context)),
                                const SizedBox(height: 16),
                                
                                if (top5Logs.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    child: Text("No recent activity.", style: TextStyle(color: Colors.grey[500])),
                                  )
                                else
                                  ...top5Logs.map((log) => _buildActivityItem(log)).toList(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildStatCard(BuildContext context,
      {required String label, required String value, required IconData icon, required Color color}) {
    return ContainerCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: FontConfig.caption(context)),
              Text(
                value,
                style: FontConfig.h2(context).copyWith(
                  fontWeight: FontWeight.w800,
                  color: ThemeConfig.primaryGreen,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(InventoryLogModel log) {
    final isPositive = log.changeAmount >= 0;
    final color = isPositive ? ThemeConfig.primaryGreen : Colors.redAccent;
    final formattedQty = "${isPositive ? '+' : ''}${FormatUtils.formatQuantity(log.changeAmount)} ${log.unit}";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.ingredientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  "${log.userName} • ${_timeAgo(log.dateTime)} • ${log.action}", 
                  style: const TextStyle(fontSize: 12, color: Colors.grey)
                ),
              ],
            ),
          ),
          Text(
            formattedQty,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('MMM dd').format(d);
  }
}

// ─────────────────────────────────────────────────
// 📊 CHART WIDGET
// ─────────────────────────────────────────────────
class _ValuePieChart extends StatefulWidget {
  final Map<String, double> data;
  final double total;

  const _ValuePieChart({required this.data, required this.total});

  @override
  State<_ValuePieChart> createState() => _ValuePieChartState();
}

class _ValuePieChartState extends State<_ValuePieChart> {
  int touchedIndex = -1;

  // Color palette for chart slices
  final List<Color> _colors = [
    const Color(0xFF0D3528), // Primary Green
    const Color(0xFF4D6443), // Secondary
    const Color(0xFF8B6341), // Mocha
    const Color(0xFFD4A373), // Beige
    Colors.orangeAccent,
    Colors.blueAccent,
    Colors.purpleAccent,
  ];

  @override
  Widget build(BuildContext context) {
    // Sort categories by value (High to Low) to make chart readable
    final sortedEntries = widget.data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    // Take top 6, group rest as "Others"
    final topEntries = sortedEntries.take(6).toList();
    final otherValue = sortedEntries.skip(6).fold(0.0, (sum, e) => sum + e.value);
    
    if (otherValue > 0) {
      topEntries.add(MapEntry("Others", otherValue));
    }

    return Row(
      children: [
        // CHART
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(topEntries.length, (i) {
                final isTouched = i == touchedIndex;
                final entry = topEntries[i];
                final percentage = (entry.value / widget.total) * 100;
                final fontSize = isTouched ? 18.0 : 14.0;
                final radius = isTouched ? 110.0 : 100.0;

                return PieChartSectionData(
                  color: _colors[i % _colors.length],
                  value: entry.value,
                  title: '${percentage.toStringAsFixed(0)}%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
                  ),
                );
              }),
            ),
          ),
        ),
        
        const SizedBox(width: 24),

        // LEGEND
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(topEntries.length, (i) {
               final entry = topEntries[i];
               return Padding(
                 padding: const EdgeInsets.symmetric(vertical: 4),
                 child: Row(
                   children: [
                     Container(
                       width: 16, height: 16,
                       decoration: BoxDecoration(
                         color: _colors[i % _colors.length],
                         shape: BoxShape.circle,
                       ),
                     ),
                     const SizedBox(width: 8),
                     Expanded(
                       child: Text(
                         entry.key,
                         style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                         overflow: TextOverflow.ellipsis,
                       ),
                     ),
                   ],
                 ),
               );
            }),
          ),
        ),
      ],
    );
  }
}
