import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';

import '../../core/models/ingredient_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';

import 'widgets/flat_search_field.dart';
import 'widgets/flat_dropdown.dart';
import 'widgets/flat_action_button.dart';
import 'widgets/ingredient_list_item.dart';

// ✅ Import the new screen
import 'ingredient_edit_screen.dart';

class AdminIngredientTab extends StatefulWidget {
  const AdminIngredientTab({super.key});

  @override
  State<AdminIngredientTab> createState() => _AdminIngredientTabState();
}

class _AdminIngredientTabState extends State<AdminIngredientTab> {
  String _searchQuery = '';
  String _categoryFilter = "All Categories";
  String _sortOrder = "Name (A-Z)";
  
  late Box<IngredientModel> ingredientBox;

  @override
  void initState() {
    super.initState();
    ingredientBox = HiveService.ingredientBox;
  }

  // ──────────────── ACTIONS ────────────────

  void _openAddDialog() {
    // ✅ NAVIGATE TO NEW SCREEN
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IngredientEditScreen()),
    );
  }

  void _showEditDialog(IngredientModel ingredient) {
    // ✅ NAVIGATE TO NEW SCREEN WITH DATA
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IngredientEditScreen(ingredient: ingredient)),
    );
  }

  Future<void> _deleteIngredient(IngredientModel ingredient) async {
    final products = HiveService.productBox.values;
    final affectedProducts = products.where((p) {
      return p.ingredientUsage.containsKey(ingredient.name); 
    }).toList();

    bool? confirm;
    if (affectedProducts.isNotEmpty) {
       confirm = await showDialog<bool>(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text("⚠️ Dependency Warning"),
           content: Text(
             "This ingredient is used in ${affectedProducts.length} products.\n\n"
             "Deleting it will mark the following products as UNAVAILABLE:\n"
             "${affectedProducts.take(3).map((p) => "- ${p.name}").join("\n")}"
             "${affectedProducts.length > 3 ? "\n...and ${affectedProducts.length - 3} more." : ""}\n\n"
             "Do you want to proceed?"
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
             ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
               onPressed: () => Navigator.pop(ctx, true),
               child: const Text("Delete & Disable Products", style: TextStyle(color: Colors.white))
             )
           ],
         )
       );
    } else {
       confirm = await showDialog<bool>(
         context: context,
         builder: (ctx) => AlertDialog(
           title: const Text("Confirm Delete"),
           content: Text("Are you sure you want to delete ${ingredient.name}?"),
           actions: [
             TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
             ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
               onPressed: () => Navigator.pop(ctx, true),
               child: const Text("Delete", style: TextStyle(color: Colors.white))
             )
           ],
         )
       );
    }
     
    if (confirm != true) return;

    final id = ingredient.id;
    await ingredient.delete();
    
    SupabaseSyncService.addToQueue(
      table: 'ingredients', 
      action: 'DELETE', 
      data: {'id': id}
    );

    for (var product in affectedProducts) {
      product.available = false;
      await product.save();
      
      SupabaseSyncService.addToQueue(
         table: 'products', 
         action: 'UPSERT', 
         data: product.toJson()
      );
    }

    if(mounted) {
      DialogUtils.showToast(
        context, 
        affectedProducts.isNotEmpty 
            ? "Deleted. ${affectedProducts.length} products marked unavailable."
            : "Ingredient deleted."
      );
    }
  }

  // ──────────────── FILTER LOGIC ────────────────

  List<IngredientModel> _getFilteredIngredients() {
    List<IngredientModel> list = ingredientBox.values.toList();
    
    if (_searchQuery.isNotEmpty) {
      list = list.where((ing) => ing.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    if (_categoryFilter != "All Categories") {
      list = list.where((ing) => ing.category == _categoryFilter).toList();
    }
    
    switch (_sortOrder) {
      case 'Name (A-Z)': list.sort((a, b) => a.name.compareTo(b.name)); break;
      case 'Name (Z-A)': list.sort((a, b) => b.name.compareTo(a.name)); break;
      case 'Stock (Low-High)': list.sort((a, b) => a.quantity.compareTo(b.quantity)); break;
      case 'Cost (Low-High)': list.sort((a, b) => a.unitCost.compareTo(b.unitCost)); break;
      case 'Cost (High-Low)': list.sort((a, b) => b.unitCost.compareTo(a.unitCost)); break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: ValueListenableBuilder(
        valueListenable: ingredientBox.listenable(),
        builder: (context, _, __) {
          final allIngredients = ingredientBox.values;
          final displayedIngredients = _getFilteredIngredients();
          final categories = ["All Categories", ...allIngredients.map((e) => e.category).toSet().toList()..sort()];

          final totalCount = allIngredients.length;
          final lowStockCount = allIngredients.where((i) => i.quantity > 0 && i.quantity <= i.reorderLevel).length;
          final outStockCount = allIngredients.where((i) => i.quantity <= 0).length;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // ─── 1. STATS BAR ───
                Row(
                  children: [
                    _buildStatCard("Total Items", "$totalCount", Icons.science, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard("Low Stock", "$lowStockCount", Icons.warning_amber, Colors.orange),
                    const SizedBox(width: 16),
                    _buildStatCard("Out of Stock", "$outStockCount", Icons.error_outline, Colors.red),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── 2. TOOLBAR ───
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: FlatSearchField(
                        hintText: "Search ingredients...",
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    Expanded(
                      flex: 3,
                      child: FlatDropdown<String>(
                        value: _categoryFilter,
                        items: categories,
                        label: "Category",
                        icon: Icons.filter_alt,
                        onChanged: (v) => setState(() => _categoryFilter = v!),
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      flex: 3,
                      child: FlatDropdown<String>(
                        value: _sortOrder,
                        items: const ["Name (A-Z)", "Name (Z-A)", "Stock (Low-High)", "Cost (Low-High)", "Cost (High-Low)"],
                        label: "Sort By",
                        icon: Icons.sort,
                        onChanged: (v) => setState(() => _sortOrder = v!),
                      ),
                    ),
                    const SizedBox(width: 16),

                    FlatActionButton(
                      label: "Add Item",
                      icon: Icons.add,
                      onPressed: _openAddDialog,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ─── 3. LIST HEADER ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 72),
                      Expanded(flex: 3, child: Text("INGREDIENT INFO", style: FontConfig.caption(context))),
                      Expanded(flex: 2, child: Text("STOCK LEVEL", style: FontConfig.caption(context))),
                      Expanded(flex: 2, child: Text("UNIT COST", style: FontConfig.caption(context))),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),

                // ─── 4. CONTENT LIST ───
                Expanded(
                  child: displayedIngredients.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: displayedIngredients.length,
                        itemBuilder: (context, index) {
                          final ingredient = displayedIngredients[index];
                          return IngredientListItem(
                            ingredient: ingredient,
                            onEdit: () => _showEditDialog(ingredient),
                            onDelete: () => _deleteIngredient(ingredient),
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No ingredients found",
            style: TextStyle(fontSize: 18, color: Colors.grey[500], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
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
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}