/// <<FILE: lib/screens/admin/admin_ingredient_tab.dart>>
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';

import '../../core/models/ingredient_model.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';

import '../../core/services/backup_service.dart';
import '../../core/widgets/basic_input_field.dart';

import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/basic_toggle_button.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/container_card_titled.dart';

import '../../core/widgets/hybrid_dropdown_field.dart';
import '../../core/widgets/ingredient_backups_dialog.dart';

import '../../core/widgets/item_card.dart';
import '../../core/widgets/item_grid_view.dart';

import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/dialog_box_editable.dart';

import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_dropdown_button.dart';

class AdminIngredientTab extends StatefulWidget {
  const AdminIngredientTab({super.key});

  @override
  State<AdminIngredientTab> createState() => _AdminIngredientTabState();
}

class _AdminIngredientTabState extends State<AdminIngredientTab> {
  // ──────────────── Search, Filter & Sort State ────────────────
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedUnit;
  String _selectedSort = 'Name (A–Z)';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _costController = TextEditingController();
  final _purchaseSizeController = TextEditingController(text: '1');
  
  // ✅ NEW: Reorder Point Controller
  final _reorderPointController = TextEditingController(text: '0');

  late Box<IngredientModel> ingredientBox;

  @override
  void initState() {
    super.initState();
    ingredientBox = Hive.box<IngredientModel>('ingredients');
  }

  void _addIngredient() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _nameController.text.toLowerCase().replaceAll(' ', '_');
    final unit = _unitController.text.trim();
    
    // Helper to get conversion factor locally to apply to reorder level
    // (Logic copied from IngredientModel presets for consistency)
    double factor = 1.0;
    if (unit == 'kg' || unit == 'L') factor = 1000.0;

    final rawReorderInput = double.tryParse(_reorderPointController.text.trim()) ?? 0;

    final ingredient = IngredientModel.auto(
      id: id,
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? 'Uncategorized'
          : _categoryController.text.trim(),
      unit: unit,
      quantity: double.parse(_quantityController.text.trim()),
      unitCost: double.tryParse(_costController.text.replaceAll(',', '')) ?? 0,
      purchaseSize: double.tryParse(_purchaseSizeController.text.replaceAll(',', '')) ?? 1.0,
      
      // ✅ FIX: Save Reorder Level in Base Units (e.g. Input 2L -> Save 2000mL)
      // We manually apply factor here because .auto() doesn't automatically convert this specific field
      reorderLevel: rawReorderInput * factor, 
    );

    await ingredientBox.put(id, ingredient);
    DialogUtils.showToast(context, "Ingredient added successfully!");
    _clearForm();
    setState(() {});
  }

  void _clearForm() {
    _nameController.clear();
    _categoryController.clear();
    _unitController.clear();
    _quantityController.clear();
    _costController.clear();
    _purchaseSizeController.text = "1";
    _reorderPointController.text = "0"; // Reset
  }

  void _showIngredientDetails(IngredientModel ingredient) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (_) {
        return DialogBoxTitled(
          title: ingredient.name,
          width: 480, 
          actions: [
            IconButton(
              icon: const Icon(Icons.close, size: 24, color: ThemeConfig.primaryGreen),
              padding: EdgeInsets.zero,
              splashRadius: 18,
              onPressed: () => Navigator.pop(context),
            )
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow("Category", ingredient.category),
              _detailRow("Unit", ingredient.unit),
              _detailRow(
                "Quantity",
                "${FormatUtils.formatQuantity(ingredient.displayQuantity)} ${ingredient.unit}",
              ),
              _detailRow("Standard Size", "${FormatUtils.formatQuantity(ingredient.purchaseSize)} per unit"),
              
              // ✅ Show Low Stock Alert
              _detailRow(
                "Low Stock Alert", 
                "${FormatUtils.formatQuantity(ingredient.reorderLevel / ingredient.conversionFactor)} ${ingredient.unit}"
              ),
              
              const Divider(),

              // ✅ UPDATE: Clearer Cost Labels
              _detailRow(
                "Cost per Item", // Changed from "Unit Cost"
                "${FormatUtils.formatCurrency(ingredient.unitCost)} / ${FormatUtils.formatQuantity(ingredient.purchaseSize)} ${ingredient.unit}",
              ),
              
              // ✅ OPTIONAL: Show Cost per specific unit for sanity check
              _detailRow(
                "Cost Logic",
                "${FormatUtils.formatCurrency(ingredient.costPerBaseUnit * ingredient.conversionFactor)} per 1 ${ingredient.unit}",
              ),
              
              const SizedBox(height: 8),
              
              _detailRow(
                "Total Value",
                FormatUtils.formatCurrency(ingredient.totalValue),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: BasicButton(
                      label: "Edit",
                      type: AppButtonType.secondary,
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditDialog(ingredient);
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: BasicButton(
                      label: "Delete",
                      type: AppButtonType.danger,
                      onPressed: () async {
                        await ingredient.delete();
                        DialogUtils.showToast(context, "${ingredient.name} deleted.");
                        Navigator.pop(context);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
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
    
    // ✅ Load existing Alert Level (Convert Base -> Main Unit for display)
    // e.g., Stored 2000 -> Display 2
    final displayReorder = ingredient.reorderLevel / ingredient.conversionFactor;
    final editReorder = TextEditingController(text: FormatUtils.formatQuantity(displayReorder));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxEditable(
          title: "Edit Ingredient",
          formKey: formKey,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, size: 24, color: ThemeConfig.primaryGreen),
              padding: EdgeInsets.zero,
              splashRadius: 18,
              onPressed: () => Navigator.pop(context),
            )
          ],
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
                  Expanded(
                    child: BasicInputField(
                      label: "Quantity", 
                      controller: editQuantity, 
                      inputType: TextInputType.number
                    )
                  ),
                  const SizedBox(width: 10),
                  // ✅ Reorder Level Input
                  Expanded(
                    child: BasicInputField(
                      label: "Alert @", 
                      controller: editReorder, 
                      inputType: TextInputType.number
                    )
                  ),
                ],
              ),
              
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: BasicInputField(
                      label: "Purchase Size", 
                      controller: editPurchaseSize, 
                      inputType: TextInputType.number
                    )
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BasicInputField(
                      label: "Unit Cost ₱", 
                      controller: editCost, 
                      inputType: TextInputType.number, 
                      isCurrency: true
                    )
                  ),
                ],
              ),
            ],
          ),
          onSave: () async {
            // Recalculate conversion in case Unit changed
            // Note: Changing unit on existing items is risky logic-wise, but we handle simple cases here.
            double factor = ingredient.conversionFactor; 
            
            // Update fields
            ingredient
              ..name = editName.text.trim()
              ..category = editCategory.text.trim()
              ..unit = editUnit.text.trim()
              ..quantity = (double.tryParse(editQuantity.text) ?? 0) * factor // Store as Base
              ..unitCost = double.tryParse(editCost.text.replaceAll(',', '')) ?? 0
              ..purchaseSize = double.tryParse(editPurchaseSize.text) ?? 1.0
              // ✅ Save Reorder Level (Display Input * Factor = Base Storage)
              ..reorderLevel = (double.tryParse(editReorder.text) ?? 0) * factor
              ..updatedAt = DateTime.now();

            await ingredient.save();
            DialogUtils.showToast(context, "Ingredient updated.");
            Navigator.pop(context);
            setState(() {});
          },
        );
      },
    );
  }

  // ... (Filtering, Sorting, Builders remain unchanged below) ...
  
  List<IngredientModel> _getFilteredIngredients() {
    // ... (Same as before)
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

  bool _showFilters = false;
  String _filterType = "Category";

  Widget _buildSearchBar(BuildContext context) {
    return BasicSearchBox(
      hintText: "Search ingredient...",
      onChanged: (value) => setState(() => _searchQuery = value),
    );
  }
  
  // ... (Sort Dropdown, Filter Button, Filter Row, Detail Row remain same) ...
  
  Widget _buildSortDropdown(BuildContext context) {
    return BasicDropdownButton<String>(
      width: 200,
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: FontConfig.h2(context).copyWith(fontWeight: FontWeight.w500, color: ThemeConfig.primaryGreen)),
          Text(value, style: FontConfig.body(context).copyWith(fontWeight: FontWeight.w400, color: ThemeConfig.secondaryGreen)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBackupEnabled = ingredientBox.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──────────────── LEFT: FORM PANEL ────────────────
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ContainerCardTitled(
                      title: "Add New Ingredient",
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name
                            BasicInputField(label: "Ingredient Name", controller: _nameController),
                            const SizedBox(height: 14),

                            // Category + Unit Row
                            Row(
                              children: [
                                Expanded(
                                  child: HybridDropdownField(
                                    label: "Category",
                                    controller: _categoryController,
                                    options: ingredientBox.values.map((e) => e.category).where((c) => c.isNotEmpty).toSet().toList(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: HybridDropdownField(
                                    label: "Unit",
                                    controller: _unitController,
                                    options: ingredientBox.values.map((e) => e.unit).where((u) => u.isNotEmpty).toSet().toList(),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            
                            // ✅ Reorder Level Row
                            Row(
                              children: [
                                Expanded(
                                  child: BasicInputField(
                                    label: "Quantity",
                                    controller: _quantityController,
                                    inputType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: BasicInputField(
                                    label: "Low Stock Alert @",
                                    controller: _reorderPointController,
                                    inputType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Purchase Size + Cost Row
                            Row(
                              children: [
                                Expanded(
                                  child: BasicInputField(
                                    label: "Std. Purchase Size", // e.g. 750
                                    controller: _purchaseSizeController,
                                    inputType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: BasicInputField(
                                    label: "Unit Cost ₱",
                                    controller: _costController,
                                    inputType: TextInputType.number,
                                    isCurrency: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: BasicButton(
                                    label: "Clear", type: AppButtonType.secondary, onPressed: _clearForm
                                  ),
                                ),
                                Container(width: 3, height: 44, margin: const EdgeInsets.symmetric(horizontal: 20), color: ThemeConfig.lightGray),
                                Expanded(
                                  child: BasicButton(
                                    label: "Add", type: AppButtonType.primary, onPressed: _addIngredient
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Backup Panel (Unchanged)
                    ContainerCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: BasicButton(
                                  label: "Backup", type: AppButtonType.secondary, icon: Icons.save_outlined,
                                  onPressed: isBackupEnabled ? () async {
                                      final service = BackupService();
                                      final filename = await showDialog<String?>(
                                        context: context,
                                        builder: (ctx) {
                                          final c = TextEditingController();
                                          return AlertDialog(
                                            title: const Text('Create Backup'),
                                            content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Enter file name (optional)')),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
                                              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(c.text.trim()), child: const Text('Save')),
                                            ],
                                          );
                                        },
                                      );
                                      if (filename != null) {
                                        try {
                                          final entry = await service.createBackup(fileName: filename);
                                          DialogUtils.showToast(context, 'Backup created: ${entry.filename}');
                                        } catch (e) {
                                          DialogUtils.showToast(context, 'Backup failed: $e');
                                        }
                                      }
                                    } : null,
                                ),
                              ),
                              Container(width: 3, height: 44, margin: const EdgeInsets.symmetric(horizontal: 20), color: ThemeConfig.lightGray),
                              Expanded(
                                child: BasicButton(
                                  label: "Restore", type: AppButtonType.secondary, icon: Icons.restore,
                                  onPressed: () async {
                                    final service = BackupService();
                                    final restored = await showDialog<bool?>(context: context, builder: (_) => IngredientBackupsDialog(backupService: service));
                                    if (restored == true) {
                                      DialogUtils.showToast(context, "Restore completed successfully.");
                                      setState(() {});
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          BasicButton(
                            label: "Delete All", type: AppButtonType.danger,
                            onPressed: () async {
                              await ingredientBox.clear();
                              DialogUtils.showToast(context, "All ingredients deleted.");
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),

            // ──────────────── RIGHT: INGREDIENT LIST ────────────────
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContainerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(flex: 9, child: _buildSearchBar(context)),
                            const SizedBox(width: 20),
                            Expanded(flex: 5, child: _buildSortDropdown(context)),
                            const SizedBox(width: 20),
                            Expanded(flex: 3, child: _buildFilterButton(context)),
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
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final ingredients = _getFilteredIngredients();
                        return ItemGridView<IngredientModel>(
                          items: ingredients,
                          crossAxisSpacing: 14, mainAxisSpacing: 14,
                          minItemWidth: 360, childAspectRatio: 370 / 116,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemBuilder: (context, ing) {
                            return ItemCard(
                              onTap: () => _showIngredientDetails(ing),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(ing.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ThemeConfig.primaryGreen)),
                                        Text(ing.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ThemeConfig.secondaryGreen)),
                                        Text(
                                          "${FormatUtils.formatQuantity(ing.displayQuantity)} ${ing.unit}",
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(FormatUtils.formatCurrency(ing.unitCost), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ThemeConfig.primaryGreen)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
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
}
/// <<END FILE>>