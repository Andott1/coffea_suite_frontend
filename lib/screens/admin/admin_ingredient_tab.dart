import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/utils/dialog_utils.dart';

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
      unitCost: double.tryParse(_costController.text.trim()) ?? 0,
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
                    style: FontConfig.h2(context)
                        .copyWith(color: ThemeConfig.primaryGreen),
                  ),
                  const SizedBox(height: 10),
                  _detailRow("Category", ingredient.category),
                  _detailRow("Unit", ingredient.unit),
                  _detailRow("Quantity", ingredient.displayString),
                  _detailRow("Cost per Unit", "₱${ingredient.unitCost.toStringAsFixed(2)}"),
                  _detailRow("Cost per Base Unit",
                      "₱${ingredient.costPerBaseUnit.toStringAsFixed(3)} per ${ingredient.baseUnit}"),
                  _detailRow("Total Value",
                      "₱${ingredient.totalValue.toStringAsFixed(2)}"),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditDialog(ingredient);
                        },
                        child: const Text(
                          "Edit",
                          style: TextStyle(color: ThemeConfig.primaryGreen),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () async {
                          await ingredient.delete();
                          DialogUtils.showToast(
                              context, "${ingredient.name} deleted.");
                          Navigator.pop(context);
                          setState(() {});
                        },
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: Colors.redAccent),
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

  void _showEditDialog(IngredientModel ingredient) {
    final editName = TextEditingController(text: ingredient.name);
    final editCategory = TextEditingController(text: ingredient.category);
    final editUnit = TextEditingController(text: ingredient.unit);
    final editQuantity =
        TextEditingController(text: ingredient.displayQuantity.toString());
    final editCost =
        TextEditingController(text: ingredient.unitCost.toStringAsFixed(2));

    showDialog(
      context: context,
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
                children: [
                  Text("Edit Ingredient",
                      style: FontConfig.h2(context)
                          .copyWith(color: ThemeConfig.primaryGreen)),
                  const SizedBox(height: 16),
                  _inputField("Name", editName),
                  _inputField("Category", editCategory),
                  _inputField("Unit", editUnit),
                  _inputField("Quantity", editQuantity, type: TextInputType.number),
                  _inputField("Unit Cost (₱)", editCost,
                      type: TextInputType.number),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      ingredient
                        ..name = editName.text
                        ..category = editCategory.text
                        ..unit = editUnit.text
                        ..quantity =
                            (double.tryParse(editQuantity.text) ?? 0) *
                                ingredient.conversionFactor
                        ..unitCost = double.tryParse(editCost.text) ?? 0
                        ..updatedAt = DateTime.now();

                      await ingredient.save();
                      DialogUtils.showToast(context, "Ingredient updated.");
                      Navigator.pop(context);
                      setState(() {});
                    },
                    child: const Text("Save Changes",
                        style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
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

  // ──────────────── Filter Pill Builder ────────────────
  Widget _buildFilterPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      splashColor: ThemeConfig.primaryGreen.withOpacity(0.2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? ThemeConfig.primaryGreen.withOpacity(0.1)
              : Colors.white,
          border: Border.all(
            color: active
                ? ThemeConfig.primaryGreen
                : Colors.grey.withOpacity(0.6),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: active
                    ? ThemeConfig.primaryGreen
                    : Colors.grey[700]),
            const SizedBox(width: 6),
            Text(
              label,
              style: FontConfig.inputLabel(context).copyWith(
                fontWeight: FontWeight.w600,
                color: active
                    ? ThemeConfig.primaryGreen
                    : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── Filter Dialog Helper ────────────────
  Future<String?> _showFilterDialog(
    BuildContext context, {
    required String title,
    required List<String> options,
    String? currentValue,
  }) async {
    return await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: FontConfig.h2(context)),
          content: SizedBox(
            width: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (context, index) {
                final option = options[index];
                final isSelected = option == currentValue;
                return ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  tileColor: isSelected
                      ? ThemeConfig.primaryGreen.withOpacity(0.1)
                      : null,
                  leading: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? ThemeConfig.primaryGreen
                        : Colors.grey,
                  ),
                  title: Text(
                    option,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? ThemeConfig.primaryGreen
                          : Colors.black87,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, option),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel"),
            ),
          ],
        );
      },
    );
  }

  Widget _inputField(String label, TextEditingController controller,
      {TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "Required";
          }
          return null;
        },
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
    final ingredients = ingredientBox.values.toList();
    
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
                                labelText: "Ingredient Name*",
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
                                labelText: "Category*",
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
                                      labelText: "Quantity*",
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

            // RIGHT: INGREDIENT LIST (Search + Filter + Sort Functional)
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ──────────────── Search + Filter Row (Dropdowns in pill-shaped containers) ────────────────
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
                    child: Row(
                      children: [
                        // 🔍 Search Box
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 48,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Search Ingredient",
                                hintStyle: FontConfig.inputLabel(context)
                                    .copyWith(color: ThemeConfig.midGray),
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(left: 10),
                                  child: Icon(
                                    Icons.search,
                                    size: 22,
                                    color: ThemeConfig.midGray, // 👈 change this to any color
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: Colors.grey),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                              ),
                              onChanged: (value) {
                                setState(() => _searchQuery = value.trim().toLowerCase());
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 20),

                        // 🧩 Category Dropdown (Pill-style)
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: ThemeConfig.primaryGreen, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              // ✅ Only use _selectedCategory if it still exists, else null
                              value: ingredientBox.values
                                      .map((e) => e.category)
                                      .toSet()
                                      .contains(_selectedCategory)
                                  ? _selectedCategory
                                  : null,
                              hint: Row(
                                children: [
                                  const Icon(Icons.category_outlined,
                                      color: Colors.grey, size: 20),
                                  const SizedBox(width: 6),
                                  Text("Category", style: FontConfig.inputLabel(context)),
                                ],
                              ),
                              icon: const Icon(Icons.arrow_drop_down),
                              borderRadius: BorderRadius.circular(12),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text("All Categories"),
                                ),
                                ...ingredientBox.values
                                    .map((e) => e.category)
                                    .toSet()
                                    .map((category) => DropdownMenuItem<String>(
                                          value: category,
                                          child: Text(category),
                                        ))
                                    .toList(),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedCategory = value);
                              },
                            ),
                          ),
                        ),

                        const SizedBox(width: 20),

                        // 🔃 Sort Dropdown (Pill-style)
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: ThemeConfig.primaryGreen, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSort,
                              hint: Row(
                                children: [
                                  const Icon(Icons.sort, color: Colors.grey, size: 20),
                                  const SizedBox(width: 6),
                                  Text("Sort By", style: FontConfig.inputLabel(context)),
                                ],
                              ),
                              icon: const Icon(Icons.arrow_drop_down),
                              borderRadius: BorderRadius.circular(12),
                              items: const [
                                DropdownMenuItem(value: "Name (A–Z)", child: Text("Name (A–Z)")),
                                DropdownMenuItem(value: "Name (Z–A)", child: Text("Name (Z–A)")),
                                DropdownMenuItem(
                                    value: "Unit Cost (L–H)",
                                    child: Text("Unit Cost (L–H)")),
                                DropdownMenuItem(
                                    value: "Unit Cost (H–L)",
                                    child: Text("Unit Cost (H–L)")),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedSort = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),


                  const SizedBox(height: 20),

                  // ──────────────── Ingredient Cards Grid ────────────────
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final ingredients = _getFilteredIngredients();

                        return ingredients.isEmpty
                            ? const Center(
                                child: Text("No ingredients found.",
                                    style: TextStyle(fontSize: 16)),
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
                                          const Spacer(),

                                          // RIGHT COLUMN — Cost anchored bottom-right
                                          SizedBox(
                                            width: 118,
                                            child: Align(
                                              alignment: Alignment.bottomRight,
                                              child: Text(
                                                "₱${ing.unitCost.toStringAsFixed(2)}",
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
