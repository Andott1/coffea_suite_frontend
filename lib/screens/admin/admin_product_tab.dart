import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';

import '../../core/models/product_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';

// ✅ Import New Widgets
import 'widgets/flat_search_field.dart';
import 'widgets/flat_dropdown.dart';
import 'widgets/flat_action_button.dart';
import 'widgets/product_list_item.dart';
import 'product_edit_screen.dart';

class AdminProductTab extends StatefulWidget {
  const AdminProductTab({super.key});

  @override
  State<AdminProductTab> createState() => _AdminProductTabState();
}

class _AdminProductTabState extends State<AdminProductTab> {
  // ──────────────── STATE ────────────────
  String _searchQuery = '';
  String _categoryFilter = "All Categories";
  String _sortOrder = "Name (A-Z)";
  
  late Box<ProductModel> productBox;

  @override
  void initState() {
    super.initState();
    productBox = HiveService.productBox;
  }

  // ──────────────── LOGIC: FILTER & SORT ────────────────
  List<ProductModel> _getFilteredProducts() {
    List<ProductModel> list = productBox.values.toList();
    
    // 1. Search
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    // 2. Filter
    if (_categoryFilter != "All Categories") {
      list = list.where((p) => p.category == _categoryFilter).toList();
    }
    
    // 3. Sort
    switch (_sortOrder) {
      case "Name (A-Z)":
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case "Name (Z-A)":
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
      case "Price (Low-High)":
        list.sort((a, b) => _getLowestPrice(a).compareTo(_getLowestPrice(b)));
        break;
      case "Price (High-Low)":
        list.sort((a, b) => _getLowestPrice(b).compareTo(_getLowestPrice(a)));
        break;
    }
    
    return list;
  }

  double _getLowestPrice(ProductModel p) {
    if (p.prices.isEmpty) return 0;
    return p.prices.values.reduce((a, b) => a < b ? a : b);
  }

  // ──────────────── ACTIONS ────────────────
  void _openAddDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductEditScreen()),
    );
  }

  void _openEditDialog(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductEditScreen(product: product)),
    );
  }

  Future<void> _toggleStatus(ProductModel product) async {
    product.available = !product.available;
    product.updatedAt = DateTime.now();
    await product.save();
    SupabaseSyncService.addToQueue(table: 'products', action: 'UPSERT', data: product.toJson());
    if (mounted) DialogUtils.showToast(context, "Product ${product.available ? 'Activated' : 'Hidden'}");
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Product?"),
        content: Text("Permanently delete ${product.name}? This cannot be undone."),
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

    if (confirm == true) {
       final id = product.id;
       await product.delete();
       SupabaseSyncService.addToQueue(
         table: 'products', 
         action: 'DELETE', 
         data: {'id': id}
       );
       if(mounted) DialogUtils.showToast(context, "Product deleted");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: ValueListenableBuilder(
        valueListenable: productBox.listenable(),
        builder: (context, _, __) {
          final allProducts = productBox.values;
          final displayedProducts = _getFilteredProducts();
          
          // Dynamic Category List
          final categories = ["All Categories", ...allProducts.map((e) => e.category).toSet().toList()..sort()];

          // Stats
          final totalCount = allProducts.length;
          final activeCount = allProducts.where((p) => p.available).length;
          final hiddenCount = totalCount - activeCount;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // ─── 1. STATS OVERVIEW ───
                Row(
                  children: [
                    _buildStatCard("Total Products", "$totalCount", Icons.inventory_2, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard("Active", "$activeCount", Icons.check_circle, ThemeConfig.primaryGreen),
                    const SizedBox(width: 16),
                    _buildStatCard("Hidden", "$hiddenCount", Icons.visibility_off, Colors.grey),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── 2. NEW TOOLBAR ───
                Row(
                  children: [
                    // Search (Flexible width)
                    Expanded(
                      flex: 4,
                      child: FlatSearchField(
                        hintText: "Search products...",
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Filter (Categories)
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

                    // Sort (Name/Price)
                    Expanded(
                      flex: 3,
                      child: FlatDropdown<String>(
                        value: _sortOrder,
                        items: const ["Name (A-Z)", "Name (Z-A)", "Price (Low-High)", "Price (High-Low)"],
                        label: "Sort By",
                        icon: Icons.sort,
                        onChanged: (v) => setState(() => _sortOrder = v!),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Add Button
                    FlatActionButton(
                      label: "Add Product",
                      icon: Icons.add,
                      onPressed: _openAddDialog,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ─── 3. COLUMN HEADERS ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 72), // Avatar gap
                      Expanded(flex: 3, child: Text("PRODUCT INFO", style: FontConfig.caption(context))),
                      Expanded(flex: 2, child: Text("PRICE RANGE", style: FontConfig.caption(context))),
                      const SizedBox(width: 50), // Actions gap
                    ],
                  ),
                ),

                // ─── 4. PRODUCT LIST ───
                Expanded(
                  child: displayedProducts.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: displayedProducts.length,
                        itemBuilder: (context, index) {
                          final product = displayedProducts[index];
                          return ProductListItem(
                            product: product,
                            onEdit: () => _openEditDialog(product),
                            onToggleStatus: () => _toggleStatus(product),
                            onDelete: () => _deleteProduct(product),
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
            "No products found",
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
          border: Border.all(color: Colors.grey.shade300),
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