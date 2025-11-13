import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';

import '../../core/models/ingredient_model.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';

import '../../core/services/backup_service.dart';

import '../../core/widgets/basic_input_field.dart';

import '../../core/widgets/container_card.dart';
import '../../core/widgets/container_card_titled.dart';

import '../../core/widgets/hybrid_dropdown_field.dart';
import '../../core/widgets/ingredient_backups_dialog.dart';

import '../../core/widgets/item_card.dart';
import '../../core/widgets/item_grid_view.dart';

import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/dialog_box_editable.dart';

import '../../core/widgets/basic_button.dart';

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

  late Box<IngredientModel> ingredientBox;

  @override
  void initState() {
    super.initState();
    ingredientBox = Hive.box<IngredientModel>('ingredients');
  }

  void _addIngredient() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _nameController.text.toLowerCase().replaceAll(' ', '_');
    final ingredient = IngredientModel.auto(
      id: id,
      name: _nameController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? 'Uncategorized'
          : _categoryController.text.trim(),
      unit: _unitController.text.trim(),
      quantity: double.parse(_quantityController.text.trim()),
      unitCost: double.tryParse(
        _costController.text.replaceAll(',', ''),
      ) ?? 0,
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
  }

  void _showIngredientDetails(IngredientModel ingredient) {
    showDialog(
      context: context,
      barrierDismissible: false, // DialogBox handles outside tap close
      builder: (_) {
        return DialogBoxTitled(
          title: ingredient.name,
          width: 480, // matches your old layout
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
                  "${ingredient.displayQuantity.toStringAsFixed(1)} ${ingredient.unit}",
                ),
                _detailRow(
                  "Unit Cost",
                  FormatUtils.formatCurrency(ingredient.unitCost),
                ),
                _detailRow(
                  "Base Cost",
                  "${FormatUtils.formatCurrency(ingredient.costPerBaseUnit)} per ${ingredient.baseUnit}",
                ),
                _detailRow(
                  "Total Value",
                  FormatUtils.formatCurrency(ingredient.totalValue),
                ),

                const SizedBox(height: 20),

                // ACTION BUTTONS
                Row(
                  children: [
                    // EDIT BUTTON → SECONDARY
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

                    // DELETE BUTTON → DANGER
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
                HybridDropdownField(label: "Category", controller: editCategory, options: ingredientBox.values.map((e) => e.category).toSet().toList()),
                const SizedBox(height: 10),
                HybridDropdownField(label: "Unit", controller: editUnit, options: ingredientBox.values.map((e) => e.unit).toSet().toList()),
                const SizedBox(height: 10),
                BasicInputField(label: "Quantity", controller: editQuantity, inputType: TextInputType.number),
                const SizedBox(height: 10),
                BasicInputField(label: "Unit Cost ₱", controller: editCost, inputType: TextInputType.number, isCurrency: true),
              ],
            ),

          onSave: () async {
            ingredient
              ..name = editName.text.trim()
              ..category = editCategory.text.trim()
              ..unit = editUnit.text.trim()
              ..quantity = double.tryParse(editQuantity.text) ?? 0
              ..unitCost = double.tryParse(editCost.text.replaceAll(',', '')) ?? 0
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


  // ──────────────── FILTERING & SORTING FUNCTION ────────────────
  List<IngredientModel> _getFilteredIngredients() {
    List<IngredientModel> list = ingredientBox.values.toList();

    // 🔍 Apply Search
    if (_searchQuery.isNotEmpty) {
      list = list.where((ing) => ing.name.toLowerCase().contains(_searchQuery)).toList();
    }

    // 🧩 Apply Filters
    if (_selectedCategory != null) {
      list = list.where((ing) => ing.category == _selectedCategory).toList();
    }
    if (_selectedUnit != null) {
      list = list.where((ing) => ing.unit == _selectedUnit).toList();
    }

    // ↕️ Apply Sorting
    switch (_selectedSort) {
      case 'Name (A–Z)':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Name (Z–A)':
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'Unit Cost (L–H)':
        list.sort((a, b) => a.unitCost.compareTo(b.unitCost));
        break;
      case 'Unit Cost (H–L)':
        list.sort((a, b) => b.unitCost.compareTo(a.unitCost));
        break;
    }

    return list;
  }

  // ──────────────────────────────────────────────────────────────
  // STATE VARIABLES FOR FILTER BAR UX
  // ──────────────────────────────────────────────────────────────
  bool _showFilters = false;
  String _filterType = "Category";

  // ──────────────────────────────────────────────────────────────
  // BUILDERS FOR SEARCH | SORT | FILTER
  // ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search Ingredient",
          hintStyle:
              FontConfig.inputLabel(context).copyWith(color: ThemeConfig.midGray),
          prefixIcon: const Icon(Icons.search, color: ThemeConfig.midGray),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: ThemeConfig.midGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.trim().toLowerCase());
        },
      ),
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: ThemeConfig.primaryGreen, width: 2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSort,
          icon: const Icon(Icons.arrow_drop_down),
          items: const [
            DropdownMenuItem(value: "Name (A–Z)", child: Text("Name (A–Z)")),
            DropdownMenuItem(value: "Name (Z–A)", child: Text("Name (Z–A)")),
            DropdownMenuItem(
                value: "Unit Cost (L–H)", child: Text("Unit Cost (L–H)")),
            DropdownMenuItem(
                value: "Unit Cost (H–L)", child: Text("Unit Cost (H–L)")),
          ],
          onChanged: (v) => setState(() => _selectedSort = v!),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context) {
    // Count active filters
    int activeFilters = 0;
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) activeFilters++;
    if (_selectedUnit != null && _selectedUnit!.isNotEmpty) activeFilters++;

    // Dynamic label text
    final String labelText = _showFilters
        ? "Hide Filters"
        : activeFilters > 0
            ? "Filters ($activeFilters)"
            : "Filters";

    return ElevatedButton.icon(
      icon: Icon(
        _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
        color: ThemeConfig.primaryGreen,
      ),
      label: Text(
        labelText,
        style: FontConfig.inputLabel(context).copyWith(color: ThemeConfig.primaryGreen),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: ThemeConfig.primaryGreen,
        side: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onPressed: () {
        setState(() => _showFilters = !_showFilters);
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // FILTER ROW (EXPANDS UNDER TOOLBAR)
  // ──────────────────────────────────────────────────────────────
  Widget _buildFilterRow(BuildContext context) {
    final categories = ingredientBox.values.map((e) => e.category).toSet().toList();
    final units = ingredientBox.values.map((e) => e.unit).toSet().toList();
    final List<String> options = _filterType == "Category" ? categories : units;

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 🔹 Label
          Text(
            "Filter by: ",
            style: FontConfig.inputLabel(context).copyWith(color: ThemeConfig.primaryGreen),
          ),
          const SizedBox(width: 10),

          // 🔹 Filter Type Dropdown
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

          // 🔹 Scrollable Options Row
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: options.map((opt) {
                  final isActive = _filterType == "Category"
                      ? _selectedCategory == opt
                      : _selectedUnit == opt;

                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: FilterChip(
                      label: Text(opt),
                      selected: isActive,
                      backgroundColor: Colors.white,
                      selectedColor: ThemeConfig.primaryGreen.withOpacity(0.05),
                      labelStyle: TextStyle(
                        color: isActive
                            ? ThemeConfig.primaryGreen
                            : ThemeConfig.midGray,
                        fontWeight:  isActive
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                      side: BorderSide(
                        color: isActive
                            ? ThemeConfig.primaryGreen
                            : ThemeConfig.midGray,
                        width: isActive ? 2 : 1, // 👈 border width adjustment here
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
          Text(title,
              style: FontConfig.h2(context).copyWith(
              fontWeight: FontWeight.w500,
              color: ThemeConfig.primaryGreen,
            )),
          Text(value,
              style: FontConfig.body(context).copyWith(
              fontWeight: FontWeight.w400,
              color: ThemeConfig.secondaryGreen,
            )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🧩 Validate filter values before building dropdowns
    final existingCategories = ingredientBox.values.map((e) => e.category).toSet();
    final existingUnits = ingredientBox.values.map((e) => e.unit).toSet();
    final isBackupEnabled = ingredientBox.isNotEmpty;

    // 🔹 Reset category filter if no longer valid
    if (_selectedCategory != null && !existingCategories.contains(_selectedCategory)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedCategory = null;
          });
          DialogUtils.showToast(context, "Category filter reset (no more items)");
        }
      });
    }

    // 🔹 Reset unit filter if no longer valid (optional)
    if (_selectedUnit != null && !existingUnits.contains(_selectedUnit)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedUnit = null;
          });
        }
      });
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: FORM PANEL (Refactored)
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  right: 8,
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ──────────────── TOP WHITE BOX ────────────────
                  ContainerCardTitled(
                    title: "Add New Ingredient",
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Input fields
                            BasicInputField(
                              label: "Ingredient Name",
                              controller: _nameController,
                              inputType: TextInputType.text,
                            ),
                            const SizedBox(height: 14),

                            HybridDropdownField(
                              label: "Category",
                              controller: _categoryController,
                              options: ingredientBox.values
                                  .map((e) => e.category)
                                  .where((c) => c.isNotEmpty)
                                  .toSet()
                                  .toList(),
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: BasicInputField(
                                    label: "Quantity",
                                    controller: _quantityController,
                                    inputType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 5,
                                  child: HybridDropdownField(
                                    label: "Unit",
                                    controller: _unitController,
                                    options: ingredientBox.values
                                        .map((e) => e.unit)
                                        .where((u) => u.isNotEmpty)
                                        .toSet()
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 7,
                                  child: BasicInputField(
                                    label: "₱ Unit Cost",
                                    controller: _costController,
                                    inputType: TextInputType.number,
                                    isCurrency: true,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Buttons Row
                            Row(
                              children: [
                                // CLEAR (SECONDARY)
                                Expanded(
                                  child: BasicButton(
                                    label: "Clear",
                                    type: AppButtonType.secondary,
                                    onPressed: _clearForm,
                                  ),
                                ),

                                // Vertical divider
                                Container(
                                  width: 3,
                                  height: 44,
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  color: ThemeConfig.lightGray,
                                ),

                                // ADD (PRIMARY)
                                Expanded(
                                  child: BasicButton(
                                    label: "Add",
                                    type: AppButtonType.primary,
                                    onPressed: _addIngredient,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ──────────────── SECOND WHITE BOX (Backup/Restore/Delete) ────────────────
                  ContainerCard(
                    child: Column(
                      children: [
                        // ─────────────── Backup + Restore Buttons ───────────────
                        Row(
                          children: [
                            // 🔹 BACKUP BUTTON
                            Expanded(
                              child: BasicButton(
                                label: "Backup",
                                type: AppButtonType.secondary,
                                icon: Icons.save_outlined,
                                onPressed: isBackupEnabled
                                    ? () async {
                                        final service = BackupService();
                                        final filename = await showDialog<String?>(
                                          context: context,
                                          builder: (ctx) {
                                            final c = TextEditingController();
                                            return AlertDialog(
                                              title: const Text('Create Backup'),
                                              content: TextField(
                                                controller: c,
                                                decoration: const InputDecoration(
                                                  hintText: 'Enter file name (optional)',
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(ctx).pop(null),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.of(ctx).pop(c.text.trim()),
                                                  child: const Text('Save'),
                                                ),
                                              ],
                                            );
                                          },
                                        );

                                        if (filename != null) {
                                          try {
                                            final entry =
                                                await service.createBackup(fileName: filename);
                                            DialogUtils.showToast(
                                                context, 'Backup created: ${entry.filename}');
                                          } catch (e) {
                                            DialogUtils.showToast(
                                                context, 'Backup failed: $e');
                                          }
                                        }
                                      }
                                    : null,
                              ),
                            ),

                            // 🔹 Divider
                            Container(
                              width: 3,
                              height: 44,
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              color: ThemeConfig.lightGray,
                            ),

                            // 🔹 RESTORE BUTTON
                            Expanded(
                              child: BasicButton(
                                label: "Restore",
                                type: AppButtonType.secondary,
                                icon: Icons.restore,
                                onPressed: () async {
                                  final service = BackupService();
                                  final restored = await showDialog<bool?>(
                                    context: context,
                                    builder: (_) =>
                                        IngredientBackupsDialog(backupService: service),
                                  );

                                  if (restored == true) {
                                    DialogUtils.showToast(context, "Restore completed successfully.");
                                    setState(() {}); // refresh list
                                  }
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ─────────────── DELETE ALL BUTTON ───────────────
                        BasicButton(
                          label: "Delete All",
                          type: AppButtonType.danger,
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

            // RIGHT: INGREDIENT LIST (Search + Sort + Filter with Expandable Filter Row)
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ──────────────── Search + Sort + Filter Container ────────────────
                  ContainerCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─────────────── Search | Sort | Filter Row ───────────────
                        Row(
                          children: [
                            Expanded(flex: 3, child: _buildSearchBar(context)),
                            const SizedBox(width: 20),
                            _buildSortDropdown(context),
                            const SizedBox(width: 20),
                            _buildFilterButton(context),
                          ],
                        ),

                        // ─────────────── Expandable Filter Row ───────────────
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: _buildFilterRow(context),
                          crossFadeState: _showFilters
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 250),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ──────────────── INGREDIENT GRID ────────────────
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final ingredients = _getFilteredIngredients();

                        return ItemGridView<IngredientModel>(
                          items: ingredients,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          minItemWidth: 360, // Responsive behavior target width
                          childAspectRatio: 370 / 116, // Keep same proportions
                          physics: const AlwaysScrollableScrollPhysics(),

                          // Build each ingredient card
                          itemBuilder: (context, ing) {
                            return ItemCard(
                              onTap: () => _showIngredientDetails(ing),

                              child: Row(
                                children: [
                                  // LEFT COLUMN
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          ing.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: ThemeConfig.primaryGreen,
                                          ),
                                        ),
                                        Text(
                                          ing.category,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: ThemeConfig.secondaryGreen,
                                          ),
                                        ),
                                        Text(
                                          "${ing.displayQuantity.toStringAsFixed(1)} ${ing.unit}",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // RIGHT COLUMN — COST
                                  Expanded(
                                    flex: 4,
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        FormatUtils.formatCurrency(ing.unitCost),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: ThemeConfig.primaryGreen,
                                        ),
                                      ),
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
