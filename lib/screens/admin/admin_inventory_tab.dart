import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/utils/dialog_utils.dart';

class AdminInventoryTab extends StatefulWidget {
  const AdminInventoryTab({super.key});

  @override
  State<AdminInventoryTab> createState() => _AdminInventoryTabState();
}

class _AdminInventoryTabState extends State<AdminInventoryTab> {
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
      quantity: double.tryParse(_quantityController.text.trim()) ?? 0,
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

    // 🔍 Search by ingredient name
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((ing) => ing.name.toLowerCase().contains(_searchQuery))
          .toList();
    }

    // 🧩 Filter by category
    if (_selectedCategory != null) {
      list = list
          .where((ing) => ing.category == _selectedCategory)
          .toList();
    }

    // 🧩 Filter by unit
    if (_selectedUnit != null) {
      list = list
          .where((ing) => ing.unit == _selectedUnit)
          .toList();
    }

    // ↕️ Sorting logic
    switch (_selectedSort) {
      case 'Name (A–Z)':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Name (Z–A)':
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'Unit Cost (Low–High)':
        list.sort((a, b) => a.unitCost.compareTo(b.unitCost));
        break;
      case 'Unit Cost (High–Low)':
        list.sort((a, b) => b.unitCost.compareTo(a.unitCost));
        break;
    }

    return list;
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

    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // LEFT: FORM PANEL (Refactored)
            Expanded(
              flex: 3,
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
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (v) =>
                                v == null || v.trim().isEmpty ? "Required" : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _categoryController,
                            decoration: InputDecoration(
                              labelText: "Category",
                              labelStyle: FontConfig.inputLabel(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
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
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: _unitController,
                                  decoration: InputDecoration(
                                    labelText: "Unit",
                                    labelStyle: FontConfig.inputLabel(context),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
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
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
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
                              const SizedBox(width: 10),
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
                                  backgroundColor: ThemeConfig.primaryGreen,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => DialogUtils.showToast(context, "Restore placeholder"),
                                child:
                                    Text("Restore", style: FontConfig.buttonLarge(context)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: ThemeConfig.primaryGreen,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => DialogUtils.showToast(context, "Backup placeholder"),
                                child:
                                    Text("Backup", style: FontConfig.buttonLarge(context)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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

            const SizedBox(width: 20),

            // RIGHT: INGREDIENT LIST (Search + Filter + Sort Functional)
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ──────────────── Search + Filter Row ────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                                hintText: "Search ingredient...",
                                hintStyle: FontConfig.inputLabel(context)
                                    .copyWith(color: Colors.grey[600]),
                                prefixIcon: const Icon(Icons.search, size: 22),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.grey),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                              ),
                              onChanged: (value) {
                                setState(() => _searchQuery = value.trim().toLowerCase());
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // 🧩 Filter: Category
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            hint: Text("Filter by Category",
                                style: FontConfig.inputLabel(context)),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text("All Categories")),
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
                        const SizedBox(width: 8),

                        // 🧩 Filter: Unit
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedUnit,
                            hint: Text("Filter by Unit",
                                style: FontConfig.inputLabel(context)),
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: Text("All Units")),
                              ...ingredientBox.values
                                  .map((e) => e.unit)
                                  .toSet()
                                  .map((unit) => DropdownMenuItem<String>(
                                        value: unit,
                                        child: Text(unit),
                                      ))
                                  .toList(),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedUnit = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // 🧭 Sort Button
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSort,
                            hint: Text("Sort By", style: FontConfig.inputLabel(context)),
                            items: const [
                              DropdownMenuItem(value: "Name (A–Z)", child: Text("Name (A–Z)")),
                              DropdownMenuItem(value: "Name (Z–A)", child: Text("Name (Z–A)")),
                              DropdownMenuItem(value: "Unit Cost (Low–High)", child: Text("Unit Cost (Low–High)")),
                              DropdownMenuItem(value: "Unit Cost (High–Low)", child: Text("Unit Cost (High–Low)")),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedSort = value);
                              }
                            },
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 23, vertical: 8),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 23,
                                  mainAxisSpacing: 20,
                                  childAspectRatio: 370 / 106,
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
                                                const SizedBox(height: 6),
                                                Text(
                                                  ing.category,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.black54,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  "${ing.displayQuantity.toStringAsFixed(1)} ${ing.unit}",
                                                  style: const TextStyle(
                                                    fontSize: 14,
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
