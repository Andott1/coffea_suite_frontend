import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';

import '../../core/models/ingredient_model.dart';
import '../../core/models/product_model.dart'; // ✅ NEW IMPORT
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';

import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/basic_toggle_button.dart';
import '../../core/widgets/container_card.dart';

import '../../core/widgets/item_card.dart';
import '../../core/widgets/item_grid_view.dart';
import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/dialog_box_editable.dart';

import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_dropdown_button.dart';
import '../../core/widgets/basic_input_field.dart'; 
import '../../core/widgets/hybrid_dropdown_field.dart';

import 'ingredient_form_dialog.dart';

class AdminIngredientTab extends StatefulWidget {
  const AdminIngredientTab({super.key});

  @override
  State<AdminIngredientTab> createState() => _AdminIngredientTabState();
}

class _AdminIngredientTabState extends State<AdminIngredientTab> {
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedUnit;
  String _selectedSort = 'Name (A–Z)';
  bool _showFilters = false;
  String _filterType = "Category";
  
  bool _isEditMode = false;

  late Box<IngredientModel> ingredientBox;

  @override
  void initState() {
    super.initState();
    ingredientBox = HiveService.ingredientBox;
  }

  // ──────────────── ACTIONS ────────────────

  void _openAddDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const IngredientFormDialog(),
    );
  }

  void _showIngredientDetails(IngredientModel ingredient) {
    showDialog(
      context: context,
      builder: (_) {
        return DialogBoxTitled(
          title: ingredient.name,
          subtitle: ingredient.category,
          width: 480, 
          actions: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.grey),
              tooltip: "Edit Item",
              onPressed: () {
                Navigator.pop(context);
                _showEditDialog(ingredient);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: ThemeConfig.primaryGreen),
              onPressed: () => Navigator.pop(context),
            )
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow("Unit", ingredient.unit),
              _detailRow("Purchase Size", "${FormatUtils.formatQuantity(ingredient.purchaseSize)} ${ingredient.unit}"),
              _detailRow("Base Unit", ingredient.baseUnit),
              const Divider(),
              _detailRow("Unit Cost", FormatUtils.formatCurrency(ingredient.unitCost)),
              _detailRow("Cost Logic", "${FormatUtils.formatCurrency(ingredient.costPerBaseUnit * ingredient.conversionFactor)} / 1 ${ingredient.unit}"),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(IngredientModel ingredient) {
    final formKey = GlobalKey<FormState>();
    final editName = TextEditingController(text: ingredient.name);
    final editCategory = TextEditingController(text: ingredient.category);
    final editUnit = TextEditingController(text: ingredient.unit);
    final editQuantity = TextEditingController(text: ingredient.displayQuantity.toString());
    final editCost = TextEditingController(text: ingredient.unitCost.toStringAsFixed(2));
    final editPurchaseSize = TextEditingController(text: FormatUtils.formatQuantity(ingredient.purchaseSize));
    
    final displayReorder = ingredient.reorderLevel / ingredient.conversionFactor;
    final editReorder = TextEditingController(text: FormatUtils.formatQuantity(displayReorder));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogBoxEditable(
          title: "Edit Ingredient",
          formKey: formKey,
          width: 600,
          onCancel: () => Navigator.pop(context),
          child: Column(
            children: [
              BasicInputField(label: "Name", controller: editName),
              const SizedBox(height: 10),
              Row(
                children: [
                   Expanded(
                    child: HybridDropdownField(
                      label: "Category", 
                      controller: editCategory, 
                      options: ingredientBox.values.map((e) => e.category).toSet().toList()
                    )
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: HybridDropdownField(
                      label: "Unit", 
                      controller: editUnit, 
                      options: ingredientBox.values.map((e) => e.unit).toSet().toList()
                    )
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: BasicInputField(label: "Current Stock", controller: editQuantity, inputType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: BasicInputField(label: "Alert @", controller: editReorder, inputType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: BasicInputField(label: "Purchase Size", controller: editPurchaseSize, inputType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: BasicInputField(label: "Unit Cost ₱", controller: editCost, inputType: TextInputType.number, isCurrency: true)),
                ],
              ),
            ],
          ),
          onSave: () async {
            double factor = ingredient.conversionFactor;
            ingredient
              ..name = editName.text.trim()
              ..category = editCategory.text.trim()
              ..unit = editUnit.text.trim()
              ..quantity = (double.tryParse(editQuantity.text) ?? 0) * factor
              ..unitCost = double.tryParse(editCost.text.replaceAll(',', '')) ?? 0
              ..purchaseSize = double.tryParse(editPurchaseSize.text) ?? 1.0
              ..reorderLevel = (double.tryParse(editReorder.text) ?? 0) * factor
              ..updatedAt = DateTime.now();

            await ingredient.save();
            
            SupabaseSyncService.addToQueue(
                table: 'ingredients',
                action: 'UPSERT',
                data: ingredient.toJson()
            );

            if (mounted) {
              DialogUtils.showToast(context, "Ingredient updated.");
              Navigator.pop(context);
            }
          },
      ),
    );
  }

  // ✅ NEW: Safer Delete with Dependency Check
  Future<void> _deleteIngredient(IngredientModel ingredient) async {
    // 1. CHECK DEPENDENCIES
    final products = HiveService.productBox.values;
    final affectedProducts = products.where((p) {
      return p.ingredientUsage.containsKey(ingredient.name); 
    }).toList();

    // 2. SHOW WARNING IF USED
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

    // 3. EXECUTE DELETION AND CASCADING UPDATES
    final id = ingredient.id;
    await ingredient.delete();
    
    // A. Queue Ingredient Deletion
    SupabaseSyncService.addToQueue(
      table: 'ingredients', 
      action: 'DELETE', 
      data: {'id': id}
    );

    // B. Disable Affected Products & Queue Updates
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

  List<IngredientModel> _getFilteredIngredients() {
    List<IngredientModel> list = ingredientBox.values.toList();
    if (_searchQuery.isNotEmpty) {
      list = list.where((ing) => ing.name.toLowerCase().contains(_searchQuery)).toList();
    }
    if (_selectedCategory != null) {
      list = list.where((ing) => ing.category == _selectedCategory).toList();
    }
    if (_selectedUnit != null) {
      list = list.where((ing) => ing.unit == _selectedUnit).toList();
    }
    switch (_selectedSort) {
      case 'Name (A–Z)': list.sort((a, b) => a.name.compareTo(b.name)); break;
      case 'Name (Z–A)': list.sort((a, b) => b.name.compareTo(a.name)); break;
      case 'Unit Cost (L–H)': list.sort((a, b) => a.unitCost.compareTo(b.unitCost)); break;
      case 'Unit Cost (H–L)': list.sort((a, b) => b.unitCost.compareTo(a.unitCost)); break;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──────────────── HEADER SECTION ────────────────
            ContainerCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 3, child: _buildSearchBar(context)),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildSortDropdown(context)),
                      const SizedBox(width: 16),
                      Expanded(flex: 1, child: _buildFilterButton(context)),
                      const SizedBox(width: 16),
                      
                      BasicButton(
                        label: _isEditMode ? "Done" : "Manage",
                        icon: _isEditMode ? Icons.check : Icons.edit,
                        type: _isEditMode ? AppButtonType.secondary : AppButtonType.neutral,
                        fullWidth: false,
                        onPressed: () => setState(() => _isEditMode = !_isEditMode),
                      ),
                      const SizedBox(width: 12),

                      BasicButton(
                        label: "New Item",
                        icon: Icons.add,
                        type: AppButtonType.primary,
                        fullWidth: false,
                        onPressed: _openAddDialog,
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: _buildFilterRow(context),
                    crossFadeState: _showFilters ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 250),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ──────────────── LIST HEADERS ────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                children: [
                  const SizedBox(width: 50), 
                  Expanded(flex: 4, child: Text("INGREDIENT NAME", style: FontConfig.caption(context))),
                  Expanded(flex: 2, child: Text("CATEGORY", style: FontConfig.caption(context))),
                  Expanded(flex: 3, child: Text("CONFIG (SIZE / UNIT)", style: FontConfig.caption(context))),
                  Expanded(flex: 2, child: Text("UNIT COST", style: FontConfig.caption(context))),
                  SizedBox(width: _isEditMode ? 96 : 48), 
                ],
              ),
            ),

            // ──────────────── FULL WIDTH LIST ────────────────
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: ingredientBox.listenable(),
                builder: (context, _, __) {
                  final ingredients = _getFilteredIngredients();

                  if (ingredients.isEmpty) {
                    return Center(
                      child: Text("No ingredients found.", style: FontConfig.body(context)),
                    );
                  }

                  return ListView.separated(
                    itemCount: ingredients.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ing = ingredients[index];
                      return _buildIngredientRow(ing);
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

  Widget _buildIngredientRow(IngredientModel ing) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _showIngredientDetails(ing), 
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40, 
                height: 40,
                decoration: BoxDecoration(
                  color: ThemeConfig.primaryGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.science, color: ThemeConfig.primaryGreen, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: Text(ing.name, style: FontConfig.body(context).copyWith(fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text(ing.category, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500))),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Icon(Icons.straighten, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text("${FormatUtils.formatQuantity(ing.purchaseSize)} ${ing.unit}", style: const TextStyle(color: Colors.black87)),
                  ],
                ),
              ),
              Expanded(flex: 2, child: Text(FormatUtils.formatCurrency(ing.unitCost), style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen))),

              if (_isEditMode) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                  tooltip: "Edit",
                  onPressed: () => _showEditDialog(ing),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: "Delete",
                  onPressed: () => _deleteIngredient(ing),
                ),
              ] else ...[
                 const SizedBox(width: 48),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return BasicSearchBox(
      hintText: "Search ingredient...",
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    return BasicDropdownButton<String>(
      width: double.infinity,
      value: _selectedSort,
      items: const ["Name (A-Z)", "Name (Z-A)", "Unit Cost (L-H)", "Unit Cost (H-L)"],
      onChanged: (value) => setState(() => _selectedSort = value!),
    );
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedUnit != null) count++;
    return count;
  }

  Widget _buildFilterButton(BuildContext context) {
    return BasicToggleButton(
      expanded: _showFilters,
      label: "Filter",
      badgeCount: _activeFiltersCount,
      onPressed: () => setState(() => _showFilters = !_showFilters),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    final categories = ingredientBox.values.map((e) => e.category).toSet().toList();
    final units = ingredientBox.values.map((e) => e.unit).toSet().toList();
    final List<String> options = _filterType == "Category" ? categories : units;
    
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Filter by: ", style: FontConfig.inputLabel(context).copyWith(color: ThemeConfig.primaryGreen)),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _filterType,
            borderRadius: BorderRadius.circular(12),
            items: const [
              DropdownMenuItem(value: "Category", child: Text("Category")),
              DropdownMenuItem(value: "Unit", child: Text("Unit")),
            ],
            onChanged: (v) => setState(() => _filterType = v!),
          ),
          const SizedBox(width: 10),
          const Text(":"),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: options.map((opt) {
                  final isActive = _filterType == "Category" ? _selectedCategory == opt : _selectedUnit == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilterChip(
                      label: Text(opt),
                      selected: isActive,
                      backgroundColor: Colors.white,
                      selectedColor: ThemeConfig.primaryGreen.withOpacity(0.05),
                      labelStyle: TextStyle(
                        color: isActive ? ThemeConfig.primaryGreen : ThemeConfig.midGray,
                        fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                      ),
                      side: BorderSide(
                        color: isActive ? ThemeConfig.primaryGreen : ThemeConfig.midGray,
                        width: isActive ? 2 : 1,
                      ),
                      onSelected: (v) {
                        setState(() {
                          if (_filterType == "Category") {
                            _selectedCategory = v ? opt : null;
                          } else {
                            _selectedUnit = v ? opt : null;
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: FontConfig.body(context).copyWith(fontWeight: FontWeight.w600, color: ThemeConfig.primaryGreen)),
          Text(value, style: FontConfig.body(context).copyWith(color: Colors.black87)),
        ],
      ),
    );
  }
}