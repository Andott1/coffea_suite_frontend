import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';

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
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ThemeConfig.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ingredient.name,
                    style: FontConfig.h3(context)
                        .copyWith(color: ThemeConfig.primaryGreen),
                  ),
                  _detailRow("Category", ingredient.category),
                  _detailRow("Unit", ingredient.unit),
                  _detailRow("Quantity", ingredient.displayString),
                  _detailRow("Cost per Unit", FormatUtils.formatCurrency(ingredient.unitCost)),
                  _detailRow("Cost per Base Unit",
                    "${FormatUtils.formatCurrency(ingredient.costPerBaseUnit)} per ${ingredient.baseUnit}"),
                  _detailRow("Total Value", FormatUtils.formatCurrency(ingredient.totalValue)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // ✅ EDIT BUTTON (Green)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.white,
                          foregroundColor: ThemeConfig.secondaryGreen,
                          side: const BorderSide(color: ThemeConfig.secondaryGreen, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditDialog(ingredient);
                        },
                        child: Text(
                          "Edit",
                          style: FontConfig.buttonLarge(context).copyWith(color: ThemeConfig.secondaryGreen),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // 🟥 DELETE BUTTON (Outlined Red)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeConfig.white,
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent, width: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          await ingredient.delete();
                          DialogUtils.showToast(context, "${ingredient.name} deleted.");
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: Text(
                          "Delete",
                          style: FontConfig.buttonLarge(context).copyWith(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditField(
    BuildContext context,
    String label,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? inputFormatters, // 👈 new optional parameter
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: ThemeConfig.primaryGreen,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: FontConfig.inputLabel(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        prefixText: label.contains("Cost") ? "₱ " : null, // 👈 optional prefix
        prefixStyle: const TextStyle(
          color: ThemeConfig.primaryGreen,
          fontWeight: FontWeight.w600,
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) {
          return "Required";
        }
        return null;
      },
    );
  }

  void _showEditDialog(IngredientModel ingredient) {
    final editFormKey = GlobalKey<FormState>();
    final editName = TextEditingController(text: ingredient.name);
    final editCategory = TextEditingController(text: ingredient.category);
    final editUnit = TextEditingController(text: ingredient.unit);
    final editQuantity =
        TextEditingController(text: ingredient.displayQuantity.toString());
    final editCost =
        TextEditingController(text: ingredient.unitCost.toStringAsFixed(2));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          backgroundColor: Colors.transparent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: 480,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: ThemeConfig.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Form(
                        key: editFormKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Edit Ingredient",
                              style: FontConfig.h3(context)
                                  .copyWith(color: ThemeConfig.primaryGreen),
                            ),
                            const SizedBox(height: 16),

                            // ─── Required Inputs ───
                            _buildEditField(context, "Name *", editName),
                            const SizedBox(height: 10),
                            _buildEditField(context, "Category *", editCategory),
                            const SizedBox(height: 10),
                            _buildEditField(context, "Unit *", editUnit),
                            const SizedBox(height: 10),
                            _buildEditField(context, "Quantity *", editQuantity,
                                type: TextInputType.number),
                            const SizedBox(height: 10),
                            _buildEditField(
                              context,
                              "Unit Cost ₱",
                              editCost,
                              type: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()], // 👈 live formatter only here
                            ),
                            const SizedBox(height: 20),

                            // ─── Buttons ───
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ThemeConfig.white,
                                      foregroundColor: ThemeConfig.primaryGreen,
                                      side: const BorderSide(
                                          color: ThemeConfig.primaryGreen,
                                          width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      "Cancel",
                                      style: FontConfig.buttonLarge(context)
                                          .copyWith(
                                              color: ThemeConfig.primaryGreen),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 3,
                                  height: 44,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 20),
                                  color: ThemeConfig.lightGray,
                                ),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ThemeConfig.primaryGreen,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding:
                                          const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () async {
                                      if (!editFormKey.currentState!.validate())
                                        return;

                                      ingredient
                                        ..name = editName.text.trim()
                                        ..category = editCategory.text.trim()
                                        ..unit = editUnit.text.trim()
                                        ..quantity =
                                            (double.tryParse(editQuantity.text) ??
                                                    0) *
                                                ingredient.conversionFactor
                                        ..unitCost =
                                            double.tryParse(editCost.text.replaceAll(',', '')) ?? 0
                                        ..updatedAt = DateTime.now();

                                      await ingredient.save();
                                      DialogUtils.showToast(
                                          context, "Ingredient updated.");
                                      Navigator.pop(context);
                                      setState(() {});
                                    },
                                    child: Text(
                                      "Save Changes",
                                      style: FontConfig.buttonLarge(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.black54)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🧩 Validate filter values before building dropdowns
    final existingCategories = ingredientBox.values.map((e) => e.category).toSet();
    final existingUnits = ingredientBox.values.map((e) => e.unit).toSet();

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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ThemeConfig.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Add New Ingredient", style: FontConfig.h3(context)),
                            const SizedBox(height: 16),

                            // ──────────────── Input Fields ────────────────
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: "Ingredient Name",
                                labelStyle: FontConfig.inputLabel(context),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Colors.grey),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
                                  ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? "Ingredient Name is Required" : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                labelText: "Category",
                                labelStyle: FontConfig.inputLabel(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.grey),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: (v) => v == null || v.trim().isEmpty ? "Category is Required" : null,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: "Quantity",
                                      labelStyle: FontConfig.inputLabel(context),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Colors.grey),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return "Quantity is required";
                                      }
                                      final value = double.tryParse(v);
                                      if (value == null || value <= 0) {
                                        return "Enter a valid number";
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 1,
                                  child: DropdownButtonFormField<String>(
                                    value: _unitController.text.isEmpty ? null : _unitController.text,
                                    decoration: InputDecoration(
                                      labelText: "Unit",
                                      labelStyle: FontConfig.inputLabel(context),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Colors.grey),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: ingredientBox.values
                                        .map((e) => e.unit)
                                        .where((u) => u.isNotEmpty)
                                        .toSet()
                                        .map(
                                          (unit) => DropdownMenuItem<String>(
                                            value: unit,
                                            child: Text(unit),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _unitController.text = value;
                                        });
                                      }
                                    },
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty ? "Unit is required" : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _costController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              decoration: InputDecoration(
                                labelText: "Unit Cost ₱",
                                labelStyle: FontConfig.inputLabel(context),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.grey),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              validator: null,
                            ),
                            const SizedBox(height: 20),

                            // ──────────────── Buttons Row ────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ThemeConfig.primaryGreen,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: _clearForm,
                                    child: Text("Clear", style: FontConfig.buttonLarge(context)),
                                  ),
                                ),
                                
                                // 🔹 Vertical Separator Line
                                Container(
                                  width: 3,
                                  height: 44, // roughly button height
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  color: ThemeConfig.lightGray, // subtle line
                                ),

                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: ThemeConfig.primaryGreen,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: _addIngredient,
                                    child: Text("Add", style: FontConfig.buttonLarge(context)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ──────────────── SECOND WHITE BOX (Backup/Restore/Delete) ────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: ThemeConfig.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeConfig.white, // white fill
                                  foregroundColor: ThemeConfig.primaryGreen, // text + icon color
                                  surfaceTintColor: Colors.transparent, // avoids Material3 tint
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: ThemeConfig.primaryGreen, width: 2), // green border
                                  ),
                                ),
                                onPressed: () => DialogUtils.showToast(context, "Restore placeholder"),
                                child: Text(
                                  "Restore",
                                  style: FontConfig.buttonLargeInverse(context),
                                ),
                              ),
                            ),

                            // 🔹 Vertical Separator Line
                            Container(
                              width: 3,
                              height: 44, // roughly button height
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              color: ThemeConfig.lightGray, // subtle line/ subtle line
                            ),

                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeConfig.white, // white fill
                                  foregroundColor: ThemeConfig.primaryGreen, // text + icon color
                                  surfaceTintColor: Colors.transparent, // avoids Material3 tint
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: const BorderSide(color: ThemeConfig.primaryGreen, width: 2), // green border
                                  ),
                                ),
                                onPressed: () => DialogUtils.showToast(context, "Backup placeholder"),
                                child:
                                    Text("Backup", style: FontConfig.buttonLargeInverse(context)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeConfig.primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () async {
                              await ingredientBox.clear();
                              DialogUtils.showToast(context, "All ingredients deleted.");
                              setState(() {});
                            },
                            child: Text("Delete All",
                                style: FontConfig.buttonLarge(context)),
                          ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: BoxDecoration(
                      color: ThemeConfig.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MAIN ROW: Search | Sort | Filter
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildSearchBar(context),
                            ),
                            const SizedBox(width: 20),
                            _buildSortDropdown(context),
                            const SizedBox(width: 20),
                            _buildFilterButton(context),
                          ],
                        ),

                        // EXPANDABLE FILTER ROW
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

                        return ingredients.isEmpty
                            ? const Center(
                                child: Text(
                                  "No ingredients found.",
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 370 / 116,
                                ),
                                itemCount: ingredients.length,
                                itemBuilder: (context, index) {
                                  final ing = ingredients[index];
                                  return GestureDetector(
                                    onTap: () => _showIngredientDetails(ing),
                                    child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: ThemeConfig.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // LEFT COLUMN
                                          SizedBox(
                                            width: 208,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                          const Spacer(),

                                          // RIGHT COLUMN — Cost
                                          SizedBox(
                                            width: 118,
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
