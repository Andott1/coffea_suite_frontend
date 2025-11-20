/// <<FILE: lib/screens/inventory/inventory_list_tab.dart>>
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/basic_dropdown_button.dart'; // Reusing your custom dropdown
import '../../core/widgets/container_card.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/item_grid_view.dart';
import 'stock_adjustment_dialog.dart';

class InventoryListTab extends StatefulWidget {
  const InventoryListTab({super.key});

  @override
  State<InventoryListTab> createState() => _InventoryListTabState();
}

class _InventoryListTabState extends State<InventoryListTab> {
  // ──────────────── STATE ────────────────
  String _searchQuery = '';
  String _selectedSort = 'Name (A–Z)';
  
  // 2-Step Filter State
  String _filterType = 'Category'; // 'Category' or 'Unit'
  String? _selectedFilterValue;    // Holds the actual value (e.g. "Dairy" or "kg")
  
  String? _statusFilter; 

  Box<IngredientModel> get box => HiveService.ingredientBox;

  // ──────────────── LOGIC ────────────────
  
  Color _getStatusColor(IngredientModel item) {
    if (item.quantity == 0) return Colors.redAccent;
    if (item.quantity <= item.reorderLevel) return Colors.orangeAccent;
    return ThemeConfig.primaryGreen;
  }

  String _getStatusLabel(IngredientModel item) {
    if (item.quantity == 0) return "Out of Stock";
    if (item.quantity <= item.reorderLevel) return "Low Stock";
    return "Good";
  }

  List<IngredientModel> _getFilteredItems() {
    List<IngredientModel> items = box.values.toList();

    // 1. Search
    if (_searchQuery.isNotEmpty) {
      items = items.where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }

    // 2. The 2-Step Filter Logic
    if (_selectedFilterValue != null) {
      if (_filterType == 'Category') {
        items = items.where((i) => i.category == _selectedFilterValue).toList();
      } else if (_filterType == 'Unit') {
        items = items.where((i) => i.unit == _selectedFilterValue).toList();
      }
    }

    // 3. Status Filter
    if (_statusFilter != null) {
      items = items.where((i) {
        if (_statusFilter == 'critical') return i.quantity == 0;
        if (_statusFilter == 'low') return i.quantity > 0 && i.quantity <= i.reorderLevel;
        if (_statusFilter == 'good') return i.quantity > i.reorderLevel;
        return true;
      }).toList();
    }

    // 4. Sort
    items.sort((a, b) {
      // Calculate Ratio: (Display Qty / Purchase Size)
      // This effectively gives us "How many bottles/packs do we have left?"
      double getRatio(IngredientModel i) {
        if (i.purchaseSize <= 0) return i.quantity; // Fallback if data is bad
        return i.displayQuantity / i.purchaseSize;
      }

      switch (_selectedSort) {
        case 'Name (A–Z)': 
          return a.name.compareTo(b.name);

        case 'Stock Level (Lowest)': 
          // Sorts by "Least amount of full units left"
          // e.g. 0.1 bottles comes before 2.0 bottles
          return getRatio(a).compareTo(getRatio(b));

        case 'Stock Level (Highest)': 
          // Sorts by "Most stocked items"
          return getRatio(b).compareTo(getRatio(a));

        default: 
          return 0;
      }
    });

    return items;
  }

  // ──────────────── WIDGETS ────────────────

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context); 

    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ────────────────────────────────────────────
            // LEFT SIDEBAR (COMMAND CENTER)
            // ────────────────────────────────────────────
            SizedBox(
              width: r.wp(25).clamp(260.0, 320.0), 
              // ✅ FIX: Wrap entire column in ScrollView to handle keyboard overflow safely
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20), // Add padding for scrolling comfort
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // ─── TOP CONTROLS ───
                    ContainerCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Search
                          Text("Search, Sort, Filter", style: FontConfig.h2(context)),
                          const SizedBox(height: 8),

                          BasicSearchBox(
                            hintText: "Search...",
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Sort
                          Text("Sort Order", style: FontConfig.caption(context)),
                          const SizedBox(height: 8),

                          BasicDropdownButton<String>(
                            value: _selectedSort,
                            width: double.infinity,
                            items: const [
                              'Name (A–Z)', 
                              'Stock Level (Lowest)', // Renamed for clarity
                              'Stock Level (Highest)'
                            ],
                            onChanged: (v) => setState(() => _selectedSort = v!),
                          ),

                          const SizedBox(height: 20),
                          
                          // Filter By
                          Text("Filter By", style: FontConfig.caption(context)),
                          const SizedBox(height: 8),
                          BasicDropdownButton<String>(
                            value: _filterType,
                            width: double.infinity,
                            items: const ['Category', 'Unit'],
                            onChanged: (v) {
                              if (v == null || v == _filterType) return;
                              setState(() {
                                _filterType = v;
                                _selectedFilterValue = null; 
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          // Options Scroll
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildFilterChip("All", null),
                                ..._getFilterOptions().map((opt) {
                                  return _buildFilterChip(opt, opt);
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // ─── STATUS SUMMARY ───
                    // ❌ Removed 'Expanded' here. Just let it stack naturally.
                    ValueListenableBuilder(
                      valueListenable: box.listenable(),
                      builder: (context, _, __) {
                        final all = box.values;
                        final critical = all.where((i) => i.quantity == 0).length;
                        final low = all.where((i) => i.quantity > 0 && i.quantity <= i.reorderLevel).length;
                        final good = all.where((i) => i.quantity > i.reorderLevel).length;

                        return ContainerCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Stock Status", style: FontConfig.h2(context)),
                              const SizedBox(height: 14),
                              
                              _buildStatusRow("Critical Out", critical, Colors.redAccent, 'critical'),
                              _buildStatusRow("Low Stock", low, Colors.orangeAccent, 'low'),
                              _buildStatusRow("Good Stock", good, ThemeConfig.primaryGreen, 'good'),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 20),

            // ────────────────────────────────────────────
            // RIGHT MAIN GRID
            // ────────────────────────────────────────────
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, _, __) {
                  final items = _getFilteredItems();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Count
                      ContainerCard(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _statusFilter != null 
                                  ? "${_statusFilter!.toUpperCase()} ITEMS" 
                                  : (_selectedFilterValue?.toUpperCase() ?? "ALL INVENTORY"),
                              style: FontConfig.h2(context),
                            ),
                            Text(
                              "${items.length} Items Found",
                              style: FontConfig.body(context).copyWith(color: ThemeConfig.secondaryGreen),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // GRID
                      Expanded(
                        child: ItemGridView<IngredientModel>(
                          items: items,
                          minItemWidth: 200,
                          childAspectRatio: 1.1, 
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          itemBuilder: (context, item) => _buildInventoryCard(item),
                        ),
                      ),
                    ],
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── HELPERS ────────────────

  /// Dynamically fetches unique values based on Filter Type
  Set<String> _getFilterOptions() {
    if (_filterType == 'Category') {
      return box.values.map((e) => e.category).where((s) => s.isNotEmpty).toSet();
    } else {
      return box.values.map((e) => e.unit).where((s) => s.isNotEmpty).toSet();
    }
  }

  Widget _buildFilterChip(String label, String? value) {
    final isSelected = _selectedFilterValue == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilterValue = value),
        backgroundColor: Colors.white,
        selectedColor: ThemeConfig.primaryGreen.withOpacity(0.15),
        labelStyle: TextStyle(
          color: isSelected ? ThemeConfig.primaryGreen : ThemeConfig.midGray,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
        side: BorderSide(
          color: isSelected ? ThemeConfig.primaryGreen : Colors.grey[300]!,
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color, String filterKey) {
    final isSelected = _statusFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = isSelected ? null : filterKey;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: color) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.circle, color: color, size: 14),
                const SizedBox(width: 10),
                Text(label, style: FontConfig.body(context)),
              ],
            ),
            Text(
              count.toString(),
              style: FontConfig.h3(context).copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(IngredientModel item) {
    final color = _getStatusColor(item);
    return ItemCard(
      padding: EdgeInsets.zero,
      onTap: () {
        // ✅ FIX: Open the new dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => StockAdjustmentDialog(ingredient: item),
        ).then((_) {
          // Refresh UI when dialog closes (to show updated stock)
          if(mounted) setState((){});
        });
      },
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FontConfig.h3(context).copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.category,
                      style: FontConfig.caption(context),
                    ),
                  ],
                ),

                Center(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: FormatUtils.formatQuantity(item.displayQuantity),
                          style: TextStyle(
                            fontSize: 36, 
                            fontWeight: FontWeight.w800,
                            color: ThemeConfig.primaryGreen,
                            fontFamily: 'Roboto'
                          ),
                        ),
                        TextSpan(text: "\n${item.unit}",
                          style: FontConfig.body(context).copyWith(color: ThemeConfig.secondaryGreen),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusLabel(item).toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0, top: 0, bottom: 0,
            child: Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
/// <<END FILE>>