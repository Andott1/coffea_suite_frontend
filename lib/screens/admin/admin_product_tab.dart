import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/dialog_utils.dart';

import 'package:hive/hive.dart';
import '../../core/models/product_model.dart';
import '../../core/models/ingredient_usage_model.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/services/hive_service.dart';

class AdminProductTab extends StatefulWidget {
  const AdminProductTab({super.key});

  @override
  State<AdminProductTab> createState() => _AdminProductTabState();
}

class _AdminProductTabState extends State<AdminProductTab>
    with TickerProviderStateMixin {
  // ─────────────────────────── Controllers ───────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedCategory;
  String? _selectedSubCategory;

  // ─────────────────────────── Price Tabs ───────────────────────────
  late TabController _priceTabController;
  final List<String> _priceTabs = [
    '12oz', '16oz', '22oz', 'HOT', 'Regular', 'Single', 'Piece', 'Cup'
  ];

  // Price input controllers per tab
  late Map<String, TextEditingController> _priceControllers;

  // ─────────────────────────── Filters ───────────────────────────
  String _searchQuery = '';
  String _selectedSort = 'Name (A–Z)';
  String? _selectedFilterCategory;
  String? _selectedFilterSubCategory;
  bool _showFilters = false;
  String _filterType = "Category";

  late Box<ProductModel> productBox;

    // ───── Ingredient Usage state ─────
  bool _isEditingUsage = false;

  // selected ingredient ids (order preserved for tabs)
  final List<String> _selectedIngredientIds = [];

  // unit per ingredientId (e.g. 'g', 'mL')
  final Map<String, String> _ingredientUnits = {};

  // controllers: ingredientId -> sizeKey -> TextEditingController
  final Map<String, Map<String, TextEditingController>> _ingredientUsageControllers = {};

  // Unit options
  final List<String> _unitOptions = ['mg', 'g', 'mL', 'L', 'pcs'];

  TabController? _ingredientTabController;

  @override
  void initState() {
    super.initState();
    productBox = HiveService.productBox; // ✅ Access shared box
    _priceTabController = TabController(length: _priceTabs.length, vsync: this);
    _priceControllers = {
      for (var size in _priceTabs) size: TextEditingController()
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final map in _ingredientUsageControllers.values) {
      for (final c in map.values) {
        c.dispose();
      }
    }
    _priceTabController.dispose();
    _ingredientTabController?.dispose();
    super.dispose();
  }

  // Multi-select dialog to pick ingredients from ingredientBox
  Future<List<String>?> _showIngredientSelectDialog(BuildContext context) {
    final ingredients = HiveService.ingredientBox.values.toList();
    final Map<String, bool> _tempSelection = {
      for (final ing in ingredients) ing.id: _selectedIngredientIds.contains(ing.id)
    };

    return showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Select Ingredients"),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        itemCount: ingredients.length,
                        separatorBuilder: (_, __) => const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final ing = ingredients[i];
                          return CheckboxListTile(
                            value: _tempSelection[ing.id] ?? false,
                            title: Text(ing.name),
                            subtitle: Text(ing.unit ?? ''),
                            onChanged: (v) {
                              setState(() {
                                _tempSelection[ing.id] = v ?? false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final selected = _tempSelection.entries
                        .where((e) => e.value)
                        .map((e) => e.key)
                        .toList();
                    Navigator.of(context).pop(selected);
                  },
                  child: const Text("Add Selected"),
                ),
              ],
            );
          },
        );
      },
    );
    }

  // ─────────────────────────── UI HELPERS ───────────────────────────
  Widget _buildTextField(
      BuildContext context, String label, TextEditingController controller,
      {TextInputType type = TextInputType.text,
      List<TextInputFormatter>? formatters}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      inputFormatters: formatters,
      style: const TextStyle(
          color: ThemeConfig.primaryGreen,
          fontWeight: FontWeight.w500,
          fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: FontConfig.inputLabel(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: ThemeConfig.midGray, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: ThemeConfig.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        prefixText: label.contains("₱") ? "₱ " : null,
      ),
      validator: (v) =>
          v == null || v.trim().isEmpty ? "Required field" : null,
    );
  }

  // ─────────────────────────── LEFT PANEL ───────────────────────────
  Widget _buildLeftPanel(BuildContext context) {
    return Expanded(
      flex: 3,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───────────── Add Product Form ─────────────
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
                    Text("Add New Product", style: FontConfig.h3(context)),
                    const SizedBox(height: 16),

                    // Product Name
                    _buildTextField(context, "Product Name *", _nameController),
                    const SizedBox(height: 10),

                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: "Category *",
                        labelStyle: FontConfig.inputLabel(context),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Drinks", child: Text("Drinks")),
                        DropdownMenuItem(value: "Meals", child: Text("Meals")),
                        DropdownMenuItem(value: "Desserts", child: Text("Desserts")),
                      ],
                      onChanged: (v) {
                        setState(() {
                          _selectedCategory = v;
                          _selectedSubCategory = null;
                        });
                      },
                      validator: (v) =>
                          v == null ? "Please select a category" : null,
                    ),
                    const SizedBox(height: 10),

                    // Sub Category Dropdown (Dynamic)
                    DropdownButtonFormField<String>(
                      value: _selectedSubCategory,
                      decoration: InputDecoration(
                        labelText: "Sub Category *",
                        labelStyle: FontConfig.inputLabel(context),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: _getSubCategoryItems(),
                      onChanged: (v) =>
                          setState(() => _selectedSubCategory = v),
                      validator: (v) =>
                          v == null ? "Please select a subcategory" : null,
                    ),
                    const SizedBox(height: 16),

                    // Pricing Tabs
                    Text("Pricing", style: FontConfig.inputLabel(context)),
                    const SizedBox(height: 10),

                    _buildPriceTabs(context),
                    const SizedBox(height: 20),

                    _buildIngredientUsageSection(context),
                    const SizedBox(height: 20),

                    // Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _clearForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeConfig.white,
                              foregroundColor: ThemeConfig.primaryGreen,
                              side: const BorderSide(
                                  color: ThemeConfig.primaryGreen, width: 2),
                            ),
                            child: Text("Clear",
                                style: FontConfig.buttonLarge(context)
                                    .copyWith(color: ThemeConfig.primaryGreen)),
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
                            onPressed: _addProduct,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeConfig.primaryGreen,
                            ),
                            child: Text("Add",
                                style: FontConfig.buttonLarge(context)),
                                
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ───────────── Backup / Restore / Delete Section ─────────────
            _buildBackupSection(context),
          ],
        ),
      ),
    );
  }

  // Pricing tabs UI
  Widget _buildPriceTabs(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _priceTabController,
          labelColor: ThemeConfig.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ThemeConfig.primaryGreen,
          isScrollable: true,
          tabs: _priceTabs.map((t) => Tab(text: t)).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: TabBarView(
            controller: _priceTabController,
            children: _priceTabs.map((t) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildTextField(
                  context,
                  "₱ Price for $t",
                  _priceControllers[t]!,
                  type: TextInputType.number,
                  formatters: [CurrencyInputFormatter()],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientUsageTabContent(BuildContext context, String ingredientId) {
    final unit = _ingredientUnits[ingredientId] ?? 'g';
    final controllers = _ingredientUsageControllers[ingredientId] ?? {};
    final activeSizes = _priceTabs
        .where((s) => _priceControllers[s]?.text.trim().isNotEmpty ?? false)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unit selector
          Row(
            children: [
              Text("Unit:", style: FontConfig.inputLabel(context)),
              const SizedBox(width: 8),
              DropdownButton<String>(
                key: ValueKey('unit_dropdown_$ingredientId'),
                value: _unitOptions.contains(unit) ? unit : _unitOptions.first,
                items: _unitOptions
                    .toSet()
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _ingredientUnits[ingredientId] = v);
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (activeSizes.isEmpty)
            Row(
              children: const [
                Icon(Icons.info_outline, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        "No active price sizes. Please set price(s) first.",
                        style: TextStyle(color: Colors.black54))),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: activeSizes.map((sizeKey) {
                final controller = controllers[sizeKey]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text("$sizeKey:",
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText:
                                "Amount (${_ingredientUnits[ingredientId] ?? 'g'})",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientTabs(BuildContext context) {
    if (_selectedIngredientIds.isEmpty) {
      return const Text("No ingredients linked yet.");
    }

    // Ensure controller matches ingredient count
    if (_ingredientTabController == null ||
        _ingredientTabController!.length != _selectedIngredientIds.length) {
      _ingredientTabController?.dispose();
      _ingredientTabController = TabController(
        length: _selectedIngredientIds.length,
        vsync: this,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ───── Tabs Header ─────
        TabBar(
          controller: _ingredientTabController,
          isScrollable: true,
          labelColor: ThemeConfig.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: ThemeConfig.primaryGreen,
          indicator: BoxDecoration(
            color: ThemeConfig.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          tabs: _selectedIngredientIds.map((ingredientId) {
            final ing = HiveService.ingredientBox.get(ingredientId);
            final name = ing?.name ?? ingredientId;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (_isEditingUsage) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        _removeIngredientTab(ingredientId);
                      },
                      child: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 10),

        // ───── Tab Contents ─────
        SizedBox(
          height: 220,
          child: TabBarView(
            controller: _ingredientTabController,
            children: _selectedIngredientIds.map((ingredientId) {
              return _buildIngredientUsageTabContent(context, ingredientId);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientUsageSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeConfig.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: title + edit + add
          Row(
            children: [
              Expanded(child: Text("Ingredient Usage", style: FontConfig.inputLabel(context))),
              const SizedBox(width: 8),
              // Edit toggle
              OutlinedButton.icon(
                icon: Icon(_isEditingUsage ? Icons.check : Icons.edit, color: ThemeConfig.primaryGreen),
                label: Text(_isEditingUsage ? "Done" : "Edit", style: TextStyle(color: ThemeConfig.primaryGreen)),
                onPressed: () => setState(() => _isEditingUsage = !_isEditingUsage),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ThemeConfig.primaryGreen),
                  backgroundColor: ThemeConfig.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Add Ingredients"),
                onPressed: () async {
                  final selected = await _showIngredientSelectDialog(context);
                  DialogUtils.showToast(context, "Dialog returned ${selected?.length ?? 0} selected.");
                  if (selected != null && selected.isNotEmpty) {
                    _addSelectedIngredients(selected);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: ThemeConfig.primaryGreen),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tabs or empty message
          _selectedIngredientIds.isEmpty
              ? const Text("No ingredients linked yet.")
              : _buildIngredientTabs(context),
        ],
      ),
    );
  }


  // Dynamic subcategory list
  List<DropdownMenuItem<String>> _getSubCategoryItems() {
    if (_selectedCategory == "Drinks") {
      return ["Coffee", "Non-Coffee", "Carbonated", "Frappe"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList();
    } else if (_selectedCategory == "Meals") {
      return ["Ricemeal", "Snack"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList();
    } else if (_selectedCategory == "Desserts") {
      return ["Pastry", "Chilled Desserts"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList();
    }
    return [];
  }

  List<DropdownMenuItem<String>> _getSubCategoryItemsFor(String category) {
    if (category == "Drinks") {
      return ["Coffee", "Non-Coffee", "Carbonated", "Frappe"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList();
    } else if (category == "Meals") {
      return ["Ricemeal", "Snack"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList();
    } else if (category == "Desserts") {
      return ["Pastry", "Chilled Desserts"]
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList();
    }
    return [];
  }

  void _clearForm() {
    _nameController.clear();
    _selectedCategory = null;
    _selectedSubCategory = null;
    for (final c in _priceControllers.values) {
      c.clear();
    }
    setState(() {});
  }

  void _addProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final category = _selectedCategory ?? '';
    final subCategory = _selectedSubCategory ?? '';

    // ──────────────── Collect pricing ────────────────
    final prices = <String, double>{};
    for (final entry in _priceControllers.entries) {
      final text = entry.value.text.trim();
      if (text.isNotEmpty) {
        final value = double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
        if (value > 0) prices[entry.key] = value;
      }
    }

    if (prices.isEmpty) {
      DialogUtils.showToast(context, "Please input at least one price before adding.");
      return;
    }

    // ──────────────── Generate ID (match seed naming convention) ────────────────
    String idPrefix;
    if (category == "Drinks") {
      idPrefix = subCategory.toLowerCase().replaceAll(' ', '_');
    } else {
      idPrefix = category.toLowerCase().replaceAll(' ', '_');
    }

    final id = "${idPrefix}_${name.toLowerCase().replaceAll(' ', '_')}";

    // ──────────────── Check duplicates ────────────────
    if (HiveService.productBox.containsKey(id)) {
      DialogUtils.showToast(context, "Product already exists!");
      return;
    }

    // ──────────────── Determine pricing type ────────────────
    final pricingType = (category == "Drinks") ? "size" : "variant";

    // ──────────────── Build ingredient usage ────────────────
    final Map<String, Map<String, double>> aggregatedUsage = {};
    final ingredientUsageBox = HiveService.usageBox;

    for (final ingredientId in _selectedIngredientIds) {
      final controllers = _ingredientUsageControllers[ingredientId];
      if (controllers == null) continue;

      final unit = _ingredientUnits[ingredientId] ?? 'g';
      final Map<String, double> qtyMap = {};

      // Only include sizes that are priced and have numeric input
      for (final size in _priceTabs) {
        final hasPrice = _priceControllers[size]?.text.trim().isNotEmpty ?? false;
        if (!hasPrice) continue;

        final text = controllers[size]?.text.trim() ?? '';
        if (text.isEmpty) continue;

        final val = double.tryParse(text.replaceAll(RegExp(r'[^0-9.]'), ''));
        if (val != null && val > 0) {
          qtyMap[size] = val;
        }
      }

      if (qtyMap.isNotEmpty) {
        aggregatedUsage[ingredientId] = qtyMap;

        // Unique and consistent ID pattern: productId_ingredientId
        final usageId = "${id}_$ingredientId";

        final usageModel = IngredientUsageModel(
          id: usageId,
          productId: id,
          ingredientId: ingredientId,
          category: category,
          subCategory: subCategory,
          unit: unit,
          quantities: qtyMap,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          modifiedBy: null,
        );

        await ingredientUsageBox.put(usageId, usageModel);
      }
    }

    // ──────────────── Build and Save Product ────────────────
    final newProduct = ProductModel(
      id: id,
      name: name,
      category: category,
      subCategory: subCategory,
      pricingType: pricingType,
      prices: prices,
      ingredientUsage: aggregatedUsage,
      available: true,
      updatedAt: DateTime.now(),
    );

    try {
      await HiveService.productBox.put(id, newProduct);
      DialogUtils.showToast(context, "✅ Product added successfully!");
      _clearForm();
      setState(() {});
    } catch (e) {
      DialogUtils.showToast(context, "❌ Failed to add product: $e");
    }
  }

  void _removeIngredientTab(String ingredientId) {
    // Dispose text controllers
    _ingredientUsageControllers[ingredientId]?.values.forEach((c) => c.dispose());
    _ingredientUsageControllers.remove(ingredientId);
    _ingredientUnits.remove(ingredientId);
    _selectedIngredientIds.remove(ingredientId);

    // Rebuild tab controller safely
    _ingredientTabController?.dispose();
    _ingredientTabController = (_selectedIngredientIds.isNotEmpty)
        ? TabController(length: _selectedIngredientIds.length, vsync: this)
        : null;

    setState(() {});
  }

  void _addSelectedIngredients(List<String> ids) {
    if (ids.isEmpty) {
      DialogUtils.showToast(context, "No ingredients selected.");
      return;
    }

    // normalize incoming ids
    final normalized = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    int added = 0;
    for (final rawId in normalized) {
      final id = rawId; // already trimmed
      // ensure ingredient exists in the ingredientBox
      if (!HiveService.ingredientBox.containsKey(id)) {
        // skip unknown id, but log for dev
        print("Warning: ingredient id not found in box: $id");
        continue;
      }

      if (_selectedIngredientIds.contains(id)) {
        // already added -> skip
        continue;
      }

      // add to selected list
      _selectedIngredientIds.add(id);
      added++;

      // init default unit from ingredient model if available
      final ingModel = HiveService.ingredientBox.get(id);
      _ingredientUnits[id] = (ingModel != null && (ingModel.unit?.isNotEmpty ?? false))
          ? ingModel!.unit!
          : 'g';

      // init controllers for known price tabs (create new controllers only if not exist)
      _ingredientUsageControllers[id] ??= {
        for (final s in _priceTabs) s: TextEditingController()
      };
    }

    if (added == 0) {
      DialogUtils.showToast(context, "No new ingredients were added (they may already be linked).");
      return;
    }

    // rebuild TabController safely
    try {
      _ingredientTabController?.dispose();
    } catch (e) {
      // ignore
    }
    _ingredientTabController = TabController(
      length: _selectedIngredientIds.length,
      vsync: this,
    );

    // animate to last added tab for immediate feedback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_ingredientTabController != null && _selectedIngredientIds.isNotEmpty) {
          final idx = _selectedIngredientIds.length - 1;
          _ingredientTabController!.animateTo(idx);
        }
      } catch (e) {
        // ignore animation errors
      }
    });

    setState(() {});
    DialogUtils.showToast(context, "Added $added ingredient(s).");
  }

  Future<void> _showProductDetailsDialog(BuildContext context, ProductModel product) async {
    final ingredientUsages = HiveService.usageBox.values
        .where((u) => u.productId == product.id)
        .toList();

    final availableSizes = product.prices.keys.toList();
    final tabController = TabController(length: availableSizes.length, vsync: this);

    await showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 700,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ───────── Header ─────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(product.name, style: FontConfig.h3(context)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text("${product.category} • ${product.subCategory}",
                    style: FontConfig.inputLabel(context)
                        .copyWith(color: ThemeConfig.secondaryGreen)),

                const Divider(height: 30),

                // ───────── Prices Section ─────────
                Text("Prices", style: FontConfig.inputLabel(context)),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: product.prices.entries.map((e) {
                    return Text("${e.key}: ₱${e.value.toStringAsFixed(2)}",
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w500));
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ───────── Ingredients per Size ─────────
                if (availableSizes.isNotEmpty) ...[
                  TabBar(
                    controller: tabController,
                    isScrollable: true,
                    labelColor: ThemeConfig.primaryGreen,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: ThemeConfig.primaryGreen,
                    tabs: availableSizes.map((s) => Tab(text: s)).toList(),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 220,
                    child: TabBarView(
                      controller: tabController,
                      children: availableSizes.map((size) {
                        final sizeUsages = ingredientUsages
                            .where((u) => u.quantities.containsKey(size))
                            .toList();

                        if (sizeUsages.isEmpty) {
                          return const Center(
                              child: Text("No ingredients linked for this size."));
                        }

                        return ListView.separated(
                          itemCount: sizeUsages.length,
                          separatorBuilder: (_, __) => const Divider(height: 10),
                          itemBuilder: (_, i) {
                            final usage = sizeUsages[i];
                            final ingredient = HiveService.ingredientBox.get(usage.ingredientId);
                            final name = ingredient?.name ?? usage.ingredientId;
                            final qty = usage.quantities[size] ?? 0;
                            final unit = usage.unit;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500, fontSize: 15)),
                                ),
                                Text("$qty $unit",
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 15)),
                              ],
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 25),

                // ───────── Buttons ─────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditProductDialog(context, product);
                      },
                      icon: const Icon(Icons.edit, color: ThemeConfig.primaryGreen),
                      label: const Text("Edit",
                          style: TextStyle(color: ThemeConfig.primaryGreen)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (dctx) {
                            return AlertDialog(
                              title: const Text("Delete Product"),
                              content: Text("Are you sure you want to delete '${product.name}'?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dctx).pop(false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () => Navigator.of(dctx).pop(true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            );
                          },
                        );

                        if (confirm == true) {
                          final ingredientUsages = HiveService.usageBox.values.where((u) => u.productId == product.id).toList();
                          await HiveService.productBox.delete(product.id);
                          for (final usage in ingredientUsages) {
                            await HiveService.usageBox.delete(usage.id);
                          }
                          DialogUtils.showToast(context, "Product deleted.");
                          Navigator.pop(context); // close details dialog
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.delete_forever),
                      label: const Text("Delete"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditProductDialog(BuildContext context, ProductModel product) async {
    // Controllers + states
    final nameController = TextEditingController(text: product.name);
    String category = product.category;
    String subCategory = product.subCategory;

    // Price controllers
    final Map<String, TextEditingController> priceControllers = {
      for (final size in _priceTabs)
        size: TextEditingController(
            text: product.prices[size]?.toStringAsFixed(2) ?? '')
    };

    // Prefill ingredient usage
    _selectedIngredientIds.clear();
    _ingredientUnits.clear();
    _ingredientUsageControllers.clear();

    final usageBox = HiveService.usageBox;
    final existingUsages =
        usageBox.values.where((u) => u.productId == product.id).toList();

    for (final usage in existingUsages) {
      final ingId = usage.ingredientId;
      _selectedIngredientIds.add(ingId);
      _ingredientUnits[ingId] = usage.unit;
      _ingredientUsageControllers[ingId] = {
        for (final s in _priceTabs)
          s: TextEditingController(
            text: usage.quantities[s]?.toString() ?? '',
          ),
      };
    }

    _ingredientTabController?.dispose();
    _ingredientTabController =
        TabController(length: _selectedIngredientIds.length, vsync: this);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final subCategoryItems = _getSubCategoryItemsFor(category);
              final validSubCategories = subCategoryItems
                  .map((item) => item.value as String)
                  .toSet()
                  .toList();

              if (!validSubCategories.contains(subCategory)) {
                subCategory = validSubCategories.isNotEmpty ? validSubCategories.first : '';
              }


              return Container(
                width: 720,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ───────── Header ─────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Edit Product", style: FontConfig.h3(context)),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ───────── Product Info ─────────
                    _buildTextField(ctx, "Product Name", nameController),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: const [
                        DropdownMenuItem(value: "Drinks", child: Text("Drinks")),
                        DropdownMenuItem(value: "Meals", child: Text("Meals")),
                        DropdownMenuItem(value: "Desserts", child: Text("Desserts")),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          category = v!;
                          subCategory = _getSubCategoryItemsFor(category).first.value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: subCategory,
                      decoration: InputDecoration(
                        labelText: "Sub Category",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      items: subCategoryItems,
                      onChanged: (v) => setDialogState(() => subCategory = v!),
                    ),

                    const SizedBox(height: 18),
                    Text("Pricing", style: FontConfig.inputLabel(context)),
                    const SizedBox(height: 8),

                    // ───────── Pricing Tabs (reused from Add Product) ─────────
                    TabBar(
                      controller: _priceTabController,
                      labelColor: ThemeConfig.primaryGreen,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: ThemeConfig.primaryGreen,
                      isScrollable: true,
                      tabs: _priceTabs.map((t) => Tab(text: t)).toList(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 70,
                      child: TabBarView(
                        controller: _priceTabController,
                        children: _priceTabs.map((t) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: _buildTextField(
                              ctx,
                              "₱ Price for $t",
                              priceControllers[t]!,
                              type: TextInputType.number,
                              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ───────── Ingredient Usage Section ─────────
                    Expanded(
                      child: SingleChildScrollView(
                        child: _buildIngredientUsageSection(context),
                      ),
                    ),

                    const Divider(height: 30),

                    // ───────── Save Button ─────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ThemeConfig.primaryGreen),
                          ),
                          child: const Text("Cancel",
                              style: TextStyle(color: ThemeConfig.primaryGreen)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text("Save Changes"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: ThemeConfig.primaryGreen),
                          onPressed: () async {
                            // Gather prices
                            final updatedPrices = <String, double>{};
                            for (final entry in priceControllers.entries) {
                              final val = entry.value.text.trim();
                              if (val.isNotEmpty) {
                                final parsed = double.tryParse(val);
                                if (parsed != null && parsed > 0) {
                                  updatedPrices[entry.key] = parsed;
                                }
                              }
                            }

                            // Update ingredient usage
                            final ingredientUsageBox = HiveService.usageBox;
                            final Map<String, Map<String, double>> aggregatedUsage = {};

                            for (final ingId in _selectedIngredientIds) {
                              final controllers = _ingredientUsageControllers[ingId];
                              if (controllers == null) continue;

                              final unit = _ingredientUnits[ingId] ?? 'g';
                              final Map<String, double> qtyMap = {};

                              for (final size in _priceTabs) {
                                final txt = controllers[size]?.text.trim() ?? '';
                                if (txt.isEmpty) continue;
                                final val = double.tryParse(txt);
                                if (val != null && val > 0) qtyMap[size] = val;
                              }

                              if (qtyMap.isNotEmpty) {
                                aggregatedUsage[ingId] = qtyMap;

                                final usageId = "${product.id}_$ingId";
                                final newUsage = IngredientUsageModel(
                                  id: usageId,
                                  productId: product.id,
                                  ingredientId: ingId,
                                  category: category,
                                  subCategory: subCategory,
                                  unit: unit,
                                  quantities: qtyMap,
                                  createdAt: DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );
                                await ingredientUsageBox.put(usageId, newUsage);
                              }
                            }

                            // Update product itself
                            final updatedProduct = ProductModel(
                              id: product.id,
                              name: nameController.text.trim(),
                              category: category,
                              subCategory: subCategory,
                              pricingType: product.pricingType,
                              prices: updatedPrices,
                              ingredientUsage: aggregatedUsage,
                              available: product.available,
                              updatedAt: DateTime.now(),
                            );

                            await HiveService.productBox.put(product.id, updatedProduct);
                            DialogUtils.showToast(context, "Product updated successfully!");
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBackupSection(BuildContext context) {
    return Container(
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
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined,
                      color: ThemeConfig.primaryGreen),
                  label: Text("Backup",
                      style: FontConfig.buttonLarge(context)
                          .copyWith(color: ThemeConfig.primaryGreen)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.white,
                    side: const BorderSide(
                        color: ThemeConfig.primaryGreen, width: 2),
                  ),
                  onPressed: () {
                    DialogUtils.showToast(context, "Backup feature coming soon.");
                  },
                ),
              ),
              Container(
                width: 3,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: ThemeConfig.lightGray,
              ),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.restore,
                      color: ThemeConfig.primaryGreen),
                  label: Text("Restore",
                      style: FontConfig.buttonLarge(context)
                          .copyWith(color: ThemeConfig.primaryGreen)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.white,
                    side: const BorderSide(
                        color: ThemeConfig.primaryGreen, width: 2),
                  ),
                  onPressed: () {
                    DialogUtils.showToast(context, "Restore feature coming soon.");
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                DialogUtils.showToast(context, "Delete All feature coming soon.");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.primaryGreen,
              ),
              child: Text("Delete All",
                  style: FontConfig.buttonLarge(context)),
            ),
          ),
        ],
      ),
    );
  }

    // ─────────────────────────── RIGHT PANEL ───────────────────────────
    Widget _buildRightPanel(BuildContext context) {
      return Expanded(
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

            // ──────────────── PRODUCT GRID (Placeholder for now) ────────────────
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: productBox.listenable(),
                builder: (context, Box<ProductModel> box, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: ThemeConfig.lightGray.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _buildProductGrid(context),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    // ─────────────────────────── Search Bar ───────────────────────────
    Widget _buildSearchBar(BuildContext context) {
      return SizedBox(
        height: 48,
        child: TextField(
          decoration: InputDecoration(
            hintText: "Search Product...",
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

    // ─────────────────────────── Sort Dropdown ───────────────────────────
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
              DropdownMenuItem(value: "Price (L–H)", child: Text("Price (L–H)")),
              DropdownMenuItem(value: "Price (H–L)", child: Text("Price (H–L)")),
            ],
            onChanged: (v) => setState(() => _selectedSort = v!),
          ),
        ),
      );
    }

    // ─────────────────────────── Filter Button ───────────────────────────
    Widget _buildFilterButton(BuildContext context) {
      int activeFilters = 0;
      if (_selectedFilterCategory != null && _selectedFilterCategory!.isNotEmpty) activeFilters++;
      if (_selectedFilterSubCategory != null && _selectedFilterSubCategory!.isNotEmpty) activeFilters++;

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
        onPressed: () => setState(() => _showFilters = !_showFilters),
      );
    }

    // ─────────────────────────── Filter Row ───────────────────────────
    Widget _buildFilterRow(BuildContext context) {
      final categories = ["Drinks", "Meals", "Desserts"];
      final subCategories = [
        "Coffee",
        "Non-Coffee",
        "Carbonated",
        "Frappe",
        "Ricemeal",
        "Snack",
        "Pastry",
        "Chilled Desserts"
      ];

      final options = _filterType == "Category" ? categories : subCategories;

      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text("Filter by:",
                style: FontConfig.inputLabel(context)
                    .copyWith(color: ThemeConfig.primaryGreen)),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _filterType,
              borderRadius: BorderRadius.circular(12),
              items: const [
                DropdownMenuItem(value: "Category", child: Text("Category")),
                DropdownMenuItem(value: "Subcategory", child: Text("Subcategory")),
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
                    final isActive = _filterType == "Category"
                        ? _selectedFilterCategory == opt
                        : _selectedFilterSubCategory == opt;

                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: FilterChip(
                        label: Text(opt),
                        selected: isActive,
                        backgroundColor: Colors.white,
                        selectedColor: ThemeConfig.primaryGreen.withOpacity(0.08),
                        labelStyle: TextStyle(
                          color: isActive
                              ? ThemeConfig.primaryGreen
                              : ThemeConfig.midGray,
                          fontWeight: isActive
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                        side: BorderSide(
                          color: isActive
                              ? ThemeConfig.primaryGreen
                              : ThemeConfig.midGray,
                          width: isActive ? 2 : 1,
                        ),
                        onSelected: (v) {
                          setState(() {
                            if (_filterType == "Category") {
                              _selectedFilterCategory = v ? opt : null;
                            } else {
                              _selectedFilterSubCategory = v ? opt : null;
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

    // ─────────────────────────── PRODUCT FILTER & SORT ───────────────────────────
    List<ProductModel> _getFilteredProducts() {
      List<ProductModel> list = productBox.values.toList();

      // 🔍 Search Filter
      if (_searchQuery.isNotEmpty) {
        list = list.where(
          (p) => p.name.toLowerCase().contains(_searchQuery),
        ).toList();
      }

      // 🧩 Category Filter
      if (_selectedFilterCategory != null && _selectedFilterCategory!.isNotEmpty) {
        list = list.where((p) => p.category == _selectedFilterCategory).toList();
      }

      // 🧩 Subcategory Filter
      if (_selectedFilterSubCategory != null && _selectedFilterSubCategory!.isNotEmpty) {
        list = list.where((p) => p.subCategory == _selectedFilterSubCategory).toList();
      }

      // ↕️ Sorting
      switch (_selectedSort) {
        case 'Name (A–Z)':
          list.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'Name (Z–A)':
          list.sort((a, b) => b.name.compareTo(a.name));
          break;
        case 'Price (L–H)':
          list.sort((a, b) => _getMaxPrice(a).compareTo(_getMaxPrice(b)));
          break;
        case 'Price (H–L)':
          list.sort((a, b) => _getMaxPrice(b).compareTo(_getMaxPrice(a)));
          break;
      }

      return list;
    }

    // Helper to get the highest price (for sorting & display)
    double _getMaxPrice(ProductModel product) {
      if (product.prices.isEmpty) return 0;
      return product.prices.values.reduce((a, b) => a > b ? a : b);
    }

    // ─────────────────────────── Product Grid ───────────────────────────
    Widget _buildProductGrid(BuildContext context) {
    final products = _getFilteredProducts();

    if (products.isEmpty) {
      return const Center(
        child: Text("No products found.", style: TextStyle(fontSize: 16)),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 370 / 116,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return _buildProductCard(context, p);
      },
    );
  }

    // ─────────────────────────── Product Card ───────────────────────────
    Widget _buildProductCard(BuildContext context, ProductModel product) {
      final double maxPrice = _getMaxPrice(product);

      // Extract available sizes/variants (keys from prices map)
      final availableSizes = product.prices.keys.toList();

      return GestureDetector(
        onTap: () => _showProductDetailsDialog(context, product),
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
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ThemeConfig.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${product.category} · ${product.subCategory}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: ThemeConfig.secondaryGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 🧩 Sizes Row
                    Text(
                      "Sizes: ${availableSizes.join(', ')}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // RIGHT COLUMN — Max Price
              SizedBox(
                width: 118,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    FormatUtils.formatCurrency(maxPrice),
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
    }

  

  // ─────────────────────────── MAIN BUILD ───────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeftPanel(context),
            const SizedBox(width: 20),
            _buildRightPanel(context),
          ],
        ),
      ),
    );
  }
}
