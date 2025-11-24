import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';

import '../../core/models/product_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';

import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/basic_toggle_button.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_dropdown_button.dart';

// ✅ Import the new Dialog
import 'product_form_dialog.dart';

class AdminProductTab extends StatefulWidget {
  const AdminProductTab({super.key});

  @override
  State<AdminProductTab> createState() => _AdminProductTabState();
}

class _AdminProductTabState extends State<AdminProductTab> {
  String _searchQuery = '';
  String _selectedSort = 'Name (A–Z)';
  String? _selectedCategory;
  bool _showFilters = false;
  bool _isEditMode = false; // Manage Mode

  late Box<ProductModel> productBox;

  @override
  void initState() {
    super.initState();
    productBox = HiveService.productBox;
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ProductFormDialog(), // ✅ New Dialog
    );
  }

  void _openEditDialog(ProductModel product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProductFormDialog(product: product), // ✅ Reuse for Edit
    );
  }

  Future<void> _deleteProduct(ProductModel product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Delete ${product.name}? This cannot be undone."),
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

  List<ProductModel> _getFilteredProducts() {
    List<ProductModel> list = productBox.values.toList();
    if (_searchQuery.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_selectedCategory != null) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    switch (_selectedSort) {
      case 'Name (A–Z)': list.sort((a, b) => a.name.compareTo(b.name)); break;
      case 'Name (Z–A)': list.sort((a, b) => b.name.compareTo(a.name)); break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── HEADER ───
            ContainerCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 4, child: BasicSearchBox(
                        hintText: "Search Products...", 
                        onChanged: (v) => setState(() => _searchQuery = v))
                      ),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: BasicDropdownButton<String>(
                        value: _selectedSort,
                        items: const ["Name (A–Z)", "Name (Z–A)"],
                        onChanged: (v) => setState(() => _selectedSort = v!),
                      )),
                      const SizedBox(width: 16),
                      BasicButton(
                        label: _isEditMode ? "Done" : "Manage",
                        icon: _isEditMode ? Icons.check : Icons.edit,
                        type: _isEditMode ? AppButtonType.secondary : AppButtonType.neutral,
                        fullWidth: false,
                        onPressed: () => setState(() => _isEditMode = !_isEditMode),
                      ),
                      const SizedBox(width: 16),
                      BasicButton(
                        label: "New Product",
                        icon: Icons.add,
                        type: AppButtonType.primary,
                        fullWidth: false,
                        onPressed: _openAddDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── LIST HEADERS ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 50),
                  Expanded(flex: 4, child: Text("PRODUCT NAME", style: FontConfig.caption(context))),
                  Expanded(flex: 2, child: Text("CATEGORY", style: FontConfig.caption(context))),
                  Expanded(flex: 3, child: Text("VARIANTS / PRICES", style: FontConfig.caption(context))),
                  Expanded(flex: 1, child: Text("STATUS", style: FontConfig.caption(context))),
                  SizedBox(width: _isEditMode ? 96 : 48),
                ],
              ),
            ),

            // ─── LIST VIEW ───
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: productBox.listenable(),
                builder: (context, _, __) {
                  final products = _getFilteredProducts();

                  if (products.isEmpty) return const Center(child: Text("No products found."));

                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_,__) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final prod = products[index];
                      return _buildProductRow(prod);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(ProductModel prod) {
    final lowPrice = prod.prices.values.isEmpty 
        ? 0.0 
        : prod.prices.values.reduce((a, b) => a < b ? a : b);
    final highPrice = prod.prices.values.isEmpty 
        ? 0.0 
        : prod.prices.values.reduce((a, b) => a > b ? a : b);

    final priceString = lowPrice == highPrice 
        ? FormatUtils.formatCurrency(lowPrice)
        : "${FormatUtils.formatCurrency(lowPrice)} - ${FormatUtils.formatCurrency(highPrice)}";

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _openEditDialog(prod), // Tap opens edit directly or details
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: prod.isDrink ? Colors.brown.shade100 : Colors.orange.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  prod.isDrink ? Icons.local_cafe : Icons.restaurant, 
                  color: prod.isDrink ? Colors.brown : Colors.orange,
                  size: 20
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(flex: 4, child: Text(prod.name, style: const TextStyle(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text(prod.category, style: const TextStyle(color: Colors.grey))),
              
              Expanded(
                flex: 3, 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(priceString, style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen)),
                    Text("${prod.prices.length} variants", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                )
              ),

              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: prod.available ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4)
                  ),
                  child: Text(
                    prod.available ? "Active" : "Inactive",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: prod.available ? Colors.green : Colors.grey),
                  ),
                ),
              ),

              if (_isEditMode) ...[
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _openEditDialog(prod)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduct(prod)),
              ] else ...[
                const SizedBox(width: 48),
              ]
            ],
          ),
        ),
      ),
    );
  }
}