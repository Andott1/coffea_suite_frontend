import 'package:coffea_suite_frontend/core/models/product_model.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';

import '../../core/services/hive_service.dart';
import '../../core/utils/dialog_utils.dart';

import '../../core/utils/format_utils.dart';
import '../../core/widgets/basic_chip_display.dart';
import '../../core/widgets/basic_dropdown_button.dart';
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/basic_toggle_button.dart';
import '../../core/widgets/container_card_titled.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/dialog_box_editable.dart';
import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/hybrid_dropdown_field.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/item_grid_view.dart';

class AdminProductTab extends StatefulWidget {
  const AdminProductTab({super.key});

  @override
  State<AdminProductTab> createState() => _AdminProductTabState();
}

class _AdminProductTabState extends State<AdminProductTab> {
  //SEARCH, SORT, AND FILTER FIELDS
  String _searchQuery = '';
  String _selectedSort = 'Name (A–Z)';
  String? _selectedCategory;
  String? _selectedSubCategory;

  // ─────────────────────────────
  // AVAILABLE SIZES STATE
  // ─────────────────────────────
  List<String> _availableSizes = [];   // From seeded/loaded products
  List<String> _selectedSizes = [];    // User selected sizes for THIS product

  String _pricingType = "size";

  // Required for future Pricing section
  final Map<String, TextEditingController> _sizePriceCtrls = {};

  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _subCategoryCtrl = TextEditingController();

  // For selected ingredients:
  List<String> _selectedIngredients = [];

  // For each ingredient → each size → quantity controller:
  Map<String, Map<String, TextEditingController>> _ingredientQtyCtrls = {};

  late Box<ProductModel> productBox;

  @override
  void initState() {
    super.initState();
    productBox = Hive.box<ProductModel>('products');
    _loadAvailableSizes();
  }

  

  void _loadAvailableSizes() {
    final allKeys = productBox.values
        .expand((p) => p.prices.keys)
        .where((k) => k != null && k.trim().isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    // Define lists
    const sizeKeys = ["12oz", "16oz", "22oz", "HOT"];
    const variantKeys = ["Regular", "Single", "Piece", "Cup"];

    // Filter
    List<String> filtered = _pricingType == "size"
        ? allKeys.where(sizeKeys.contains).toList()
        : allKeys.where(variantKeys.contains).toList();

    filtered.sort();

    setState(() {
      _availableSizes = filtered;
    });
  }

  void _clearForm() {
    _nameCtrl.clear();
    _categoryCtrl.clear();
    _subCategoryCtrl.clear();
    
    // Clear size selections
    for (final ctrl in _sizePriceCtrls.values) {
      ctrl.dispose();
    }
    _sizePriceCtrls.clear();
    _selectedSizes.clear();
    _selectedIngredients.clear();

    DialogUtils.showToast(context, "Form cleared");
    setState(() {});
  }

  void _addProduct() async {
    // ─────────────────────────────
    // FORM VALIDATION
    // ─────────────────────────────
    if (!_formKey.currentState!.validate()) {
      DialogUtils.showToast(context, "Please fill all required fields.");
      return;
    }

    if (_pricingType.isEmpty) {
      DialogUtils.showToast(context, "Please select a pricing type.");
      return;
    }

    if (_selectedSizes.isEmpty) {
      DialogUtils.showToast(context, "Please add at least one ${_pricingType == "size" ? "size" : "variant"}.");
      return;
    }

    // Validate pricing inputs
    for (final size in _selectedSizes) {
      final txt = _sizePriceCtrls[size]?.text.trim() ?? "";
      if (txt.isEmpty) {
        DialogUtils.showToast(context, "Price for '$size' is required.");
        return;
      }
      if (double.tryParse(txt.replaceAll(",", "")) == null) {
        DialogUtils.showToast(context, "Invalid price for '$size'.");
        return;
      }
    }

    // Validate ingredient usage inputs (if any)
    for (final ing in _selectedIngredients) {
      for (final size in _selectedSizes) {
        final txt = _ingredientQtyCtrls[ing]?[size]?.text.trim() ?? "";
        if (txt.isEmpty) {
          DialogUtils.showToast(context, "Usage for '$ing' ($size) is required.");
          return;
        }
        if (double.tryParse(txt.replaceAll(",", "")) == null) {
          DialogUtils.showToast(context, "Invalid usage for '$ing' ($size).");
          return;
        }
      }
    }

    // ─────────────────────────────
    // BUILD PRICES MAP
    // ─────────────────────────────
    final Map<String, double> prices = {};
    for (final size in _selectedSizes) {
      final value = double.parse(_sizePriceCtrls[size]!
          .text
          .replaceAll(",", "")
          .trim());
      prices[size] = value;
    }

    // ─────────────────────────────
    // BUILD INGREDIENT USAGE MAP
    // ─────────────────────────────
    final Map<String, Map<String, double>> ingredientUsage = {};
    for (final ing in _selectedIngredients) {
      final inner = <String, double>{};
      for (final size in _selectedSizes) {
        final value = double.parse(_ingredientQtyCtrls[ing]![size]!
            .text
            .replaceAll(",", "")
            .trim());
        inner[size] = value;
      }
      ingredientUsage[ing] = inner;
    }

    // ─────────────────────────────
    // CREATE PRODUCT MODEL
    // ─────────────────────────────
    final newProduct = ProductModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      subCategory: _subCategoryCtrl.text.trim(),
      pricingType: _pricingType,                // <── IMPORTANT FIX
      prices: prices,
      ingredientUsage: ingredientUsage,
      available: true,
      updatedAt: DateTime.now(),
    );

    // ─────────────────────────────
    // SAVE TO HIVE
    // ─────────────────────────────
    await productBox.add(newProduct);

    DialogUtils.showToast(context, "Product added successfully!");

    // ─────────────────────────────
    // CLEAR FORM
    // ─────────────────────────────
    _clearForm();

    // Refresh UI
    setState(() {});
  }

  void _ensurePriceController(String size) {
    if (!_sizePriceCtrls.containsKey(size)) {
      _sizePriceCtrls[size] = TextEditingController();
    }
  }

  void _ensureIngredientQtyCtrl(String ingName, String size) {
    if (!_ingredientQtyCtrls.containsKey(ingName)) {
      _ingredientQtyCtrls[ingName] = {};
    }
    if (!_ingredientQtyCtrls[ingName]!.containsKey(size)) {
      _ingredientQtyCtrls[ingName]![size] = TextEditingController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      resizeToAvoidBottomInset: true,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ────────────────────────────────────────────
            // LEFT PANEL
            // ────────────────────────────────────────────
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
                    // ───────────────────────
                    // ADD NEW PRODUCT
                    // ───────────────────────
                    ContainerCardTitled(
                      title: "Add New Product",
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BasicInputField(
                              label: "Product Name",
                              controller: _nameCtrl,
                            ),
                            const SizedBox(height: 14),

                            Row(
                              children: [
                                Expanded(
                                  child: HybridDropdownField(
                                    label: "Category",
                                    controller: _categoryCtrl,
                                    options: productBox.values
                                        .map((p) => p.category)
                                        .where((c) => c != null && c.toString().isNotEmpty)
                                        .cast<String>()
                                        .toSet()
                                        .toList(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: HybridDropdownField(
                                    label: "Subcategory",
                                    controller: _subCategoryCtrl,
                                    options: productBox.values
                                        .map((p) => p.subCategory)
                                        .where((c) => c != null && c.toString().isNotEmpty)
                                        .cast<String>()
                                        .toSet()
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Pricing Type",
                                  style: FontConfig.h2(context),
                                ),
                                
                                const SizedBox(width: 6),

                                BasicDropdownButton<String>(
                                  width: 220,
                                  value: _pricingType,
                                  items: const ["size", "variant"],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _pricingType = value;

                                      // Reset selections when switching pricing type
                                      _selectedSizes.clear();

                                      // Clear price controllers
                                      for (final c in _sizePriceCtrls.values) {
                                        c.dispose();
                                      }
                                      _sizePriceCtrls.clear();
                                    });
                                  },
                                ),
                              ]
                            ),

                            // ─────────────────────────────
                            // AVAILABLE SIZES HEADER
                            // ─────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Available Sizes",
                                  style: FontConfig.h2(context),
                                ),
                                Row(  
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: ThemeConfig.primaryGreen),
                                      onPressed: _showEditSizesDialog,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: ThemeConfig.primaryGreen),
                                      onPressed: _showAddSizeDialog,
                                    ),
                                  ],
                                ),
                              ],
                            ),


                            // ─────────────────────────────
                            // SIZE CHIPS DISPLAY
                            // ─────────────────────────────
                            _selectedSizes.isEmpty
                                ? Text(
                                    "No sizes selected.",
                                    style: FontConfig.body(context).copyWith(color: ThemeConfig.midGray),
                                  )
                                : Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    
                                    children: _selectedSizes.map((size) {
                                      return BasicChipDisplay(label: size);
                                    }).toList(),
                                  ),

                            const SizedBox(height: 14),

                            // ─────────────────────────────
                            // PRICING HEADER
                            // ─────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Pricing",
                                  style: FontConfig.h2(context),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // ─────────────────────────────
                            // PRICING FORM LIST
                            // ─────────────────────────────
                            _selectedSizes.isEmpty
                                ? Text(
                                    "Add at least one size to set pricing.",
                                    style: FontConfig.body(context).copyWith(color: ThemeConfig.midGray),
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: _selectedSizes.map((size) {
                                      // Ensure controller exists for each size
                                      _ensurePriceController(size);

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 14),
                                        child: Row(
                                          children: [
                                            // Size Label (left)
                                            SizedBox(
                                              width: 80,
                                              child: Text(
                                                "$size:",
                                                style: FontConfig.body(context).copyWith(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                  color: ThemeConfig.secondaryGreen,
                                                ),
                                              ),
                                            ),

                                            // Price input (right)
                                            Expanded(
                                              child: BasicInputField(
                                                label: "₱ Price",
                                                controller: _sizePriceCtrls[size]!,
                                                inputType: TextInputType.number,
                                                isCurrency: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),

                            const SizedBox(height: 20),

                            // ─────────────────────────────
                            // INGREDIENT USAGE HEADER
                            // ─────────────────────────────
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Ingredient Usage",
                                  style: FontConfig.h2(context),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: ThemeConfig.primaryGreen),
                                      onPressed: _showEditIngredientsDialog,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, color: ThemeConfig.primaryGreen),
                                      onPressed: _showAddIngredientDialog,
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // ─────────────────────────────
                            // SELECTED INGREDIENT CHIPS
                            // ─────────────────────────────
                            _selectedIngredients.isEmpty
                                ? Text(
                                    "No ingredients added.",
                                    style: FontConfig.body(context).copyWith(color: ThemeConfig.midGray),
                                  )
                                : Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: _selectedIngredients
                                        .map((ing) => BasicChipDisplay(label: ing))
                                        .toList(),
                                  ),

                            const SizedBox(height: 16),

                            // ─────────────────────────────
                            // INGREDIENT USAGE FORM
                            // ─────────────────────────────
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _selectedIngredients.map((ingredientName) {
                                // Ingredient info
                                final ingModel = HiveService.ingredientBox.values
                                    .firstWhere((i) => i.name == ingredientName);

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 18),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: ThemeConfig.lightGray),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Ingredient Title
                                      Text(
                                        ingredientName,
                                        style: FontConfig.h3(context).copyWith(
                                          color: ThemeConfig.primaryGreen,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),

                                      const SizedBox(height: 10),

                                      // SIZE-QUANTITY INPUTS
                                      Column(
                                        children: _selectedSizes.map((size) {
                                          // Ensure controller exists
                                          _ensureIngredientQtyCtrl(ingredientName, size);

                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 80,
                                                  child: Text(
                                                    "$size:",
                                                    style: FontConfig.body(context).copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: ThemeConfig.secondaryGreen,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),

                                                Expanded(
                                                  child: BasicInputField(
                                                    label: "Qty (${ingModel.baseUnit})",
                                                    controller:
                                                        _ingredientQtyCtrls[ingredientName]![size]!,
                                                    inputType: TextInputType.number,
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
                              }).toList(),
                            ),

                            Row(
                              children: [
                                // CLEAR BUTTON
                                Expanded(
                                  child: BasicButton(
                                    label: "Clear",
                                    type: AppButtonType.secondary,
                                    onPressed: _clearForm,
                                  ),
                                ),

                                // Divider
                                Container(
                                  width: 3,
                                  height: 44,
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  color: ThemeConfig.lightGray,
                                ),

                                // ADD BUTTON
                                Expanded(
                                  child: BasicButton(
                                    label: "Add",
                                    type: AppButtonType.primary,
                                    onPressed: _addProduct,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ───────────────────────
                    // BACKUP / RESTORE / DELETE BOX
                    // ───────────────────────
                    ContainerCard(
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // BACKUP BUTTON (placeholder)
                              Expanded(
                                child: BasicButton(
                                  label: "Backup",
                                  type: AppButtonType.secondary,
                                  icon: Icons.save_outlined,
                                  onPressed: () {
                                    DialogUtils.showToast(
                                        context, "Backup (placeholder)");
                                  },
                                ),
                              ),

                              // Divider
                              Container(
                                width: 3,
                                height: 44,
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                color: ThemeConfig.lightGray,
                              ),

                              // RESTORE BUTTON (placeholder)
                              Expanded(
                                child: BasicButton(
                                  label: "Restore",
                                  type: AppButtonType.secondary,
                                  icon: Icons.restore,
                                  onPressed: () {
                                    DialogUtils.showToast(
                                        context, "Restore (placeholder)");
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // DELETE ALL (FULL WIDTH)
                          BasicButton(
                            label: "Delete All",
                            type: AppButtonType.danger,
                            onPressed: () async {
                              await productBox.clear();
                              DialogUtils.showToast(
                                  context, "All products deleted");
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

            // ────────────────────────────────────────────
            // RIGHT PANEL (placeholder for now)
            // ────────────────────────────────────────────
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
                            Expanded(flex: 9, child: _buildSearchBar(context)),

                            const SizedBox(width: 20),

                            Expanded(flex: 5, child: _buildSortDropdown(context)),

                            const SizedBox(width: 20),

                             Expanded(flex: 3, child: _buildFilterButton(context)),
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

                  // ──────────────── PRODUCT GRID ────────────────
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final products = _getFilteredProducts();

                        return ItemGridView<ProductModel>(
                          items: products,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          minItemWidth: 360, // Responsive behavior target width
                          childAspectRatio: 370 / 150, // Keep same proportions
                          physics: const AlwaysScrollableScrollPhysics(),

                          // Build each product card
                          itemBuilder: (context, prod) {
                            return ItemCard(
                              onTap: () => _showProductDetails(prod),

                              child: Row(
                                children: [
                                  // ─────────────────────────────
                                  // LEFT SIDE INFORMATION
                                  // ─────────────────────────────
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // PRODUCT NAME
                                        Text(
                                          prod.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: ThemeConfig.primaryGreen,
                                          ),
                                        ),

                                        // CATEGORY
                                        Text(
                                          prod.category,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: ThemeConfig.secondaryGreen,
                                          ),
                                        ),

                                        // SUBCATEGORY
                                        Text(
                                          prod.subCategory,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: ThemeConfig.secondaryGreen,
                                          ),
                                        ),

                                        // AVAILABLE SIZES (FROM PRICE MAP KEYS)
                                        Text(
                                          "Sizes: ${prod.prices.keys.join(' · ')}",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ─────────────────────────────
                                  // RIGHT SIDE (HIGHEST PRICE)
                                  // ─────────────────────────────
                                  Expanded(
                                    flex: 4,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        FormatUtils.formatCurrency(
                                          (prod.prices.values.isEmpty)
                                              ? 0
                                              : prod.prices.values.reduce((a, b) => a > b ? a : b),
                                        ),
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

  Future<void> _showAddIngredientDialog() async {
    final ingredientBox = HiveService.ingredientBox;
    final ingredientNames = ingredientBox.values
        .map((i) => i.name)
        .toSet()
        .toList();

    String? selectedIngredient;
    final dropdownCtrl = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxTitled(
          title: "Add Ingredient",
          width: 380,
          actions: [
            IconButton(
              icon: const Icon(Icons.close,
                  size: 22, color: ThemeConfig.primaryGreen),
              onPressed: () => Navigator.pop(context, null),
            )
          ],
          child: Column(
            children: [
              HybridDropdownField(
                label: "Ingredient",
                controller: dropdownCtrl,
                options: ingredientNames,
              ),
              const SizedBox(height: 16),
              BasicButton(
                label: "Add",
                type: AppButtonType.primary,
                onPressed: () {
                  final ing = dropdownCtrl.text.trim();
                  if (ing.isEmpty) {
                    DialogUtils.showToast(
                        context, "Ingredient cannot be empty.");
                    return;
                  }
                  Navigator.pop(context, ing);
                },
              )
            ],
          ),
        );
      },
    );

    if (result == null || result.isEmpty) return;
    if (_selectedIngredients.contains(result)) {
      DialogUtils.showToast(context, "Ingredient already added.");
      return;
    }

    setState(() {
      _selectedIngredients.add(result);
    });
  }

  Future<void> _showEditIngredientsDialog() async {
    final temp = List<String>.from(_selectedIngredients);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxTitled(
          title: "Edit Ingredients",
          width: 420,
          actions: [
            IconButton(
              icon: const Icon(Icons.close,
                  size: 22, color: ThemeConfig.primaryGreen),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          child: StatefulBuilder(
            builder: (context, setInner) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (temp.isEmpty)
                    Text("No ingredients selected.",
                        style: FontConfig.body(context)
                            .copyWith(color: ThemeConfig.midGray))
                  else
                    Column(
                      children: temp.map((ing) {
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ing,
                              style: FontConfig.body(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: ThemeConfig.secondaryGreen),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () {
                                setInner(() => temp.remove(ing));
                              },
                            )
                          ],
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

                  BasicButton(
                    label: "Save",
                    type: AppButtonType.primary,
                    onPressed: () {
                      setState(() {
                        // Dispose controllers for removed ingredients
                        final removed = _selectedIngredients
                            .where((i) => !temp.contains(i))
                            .toList();

                        for (final ing in removed) {
                          _ingredientQtyCtrls[ing]
                              ?.values
                              .forEach((c) => c.dispose());
                          _ingredientQtyCtrls.remove(ing);
                        }

                        _selectedIngredients = temp;
                      });

                      Navigator.pop(context);
                    },
                  )
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showProductDetails(ProductModel product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxTitled(
          title: product.name,
          width: 520,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, size: 24, color: ThemeConfig.primaryGreen),
              splashRadius: 18,
              onPressed: () => Navigator.pop(context),
            )
          ],

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ──────────────────────────────
              // SCROLLABLE PRODUCT INFO
              // ──────────────────────────────
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 480,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // BASIC INFO
                      _detailRow("Category", product.category),
                      _detailRow("Subcategory", product.subCategory),
                      _detailRow("Pricing Type", product.pricingType),

                      const SizedBox(height: 20),

                      // PRICES
                      Text(
                        "Prices",
                        style: FontConfig.h2(context).copyWith(
                          color: ThemeConfig.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: product.prices.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${entry.key}:",
                                  style: FontConfig.body(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: ThemeConfig.secondaryGreen,
                                  ),
                                ),
                                Text(
                                  FormatUtils.formatCurrency(entry.value),
                                  style: FontConfig.body(context).copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: ThemeConfig.primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      // INGREDIENT USAGE
                      Text(
                        "Ingredient Usage",
                        style: FontConfig.h2(context).copyWith(
                          color: ThemeConfig.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (product.ingredientUsage.isEmpty)
                        Text(
                          "No ingredient usage defined.",
                          style: FontConfig.body(context).copyWith(
                            color: ThemeConfig.midGray,
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: product.ingredientUsage.entries.map((entry) {
                            final ingredientName = entry.key;
                            final sizeMap = entry.value;

                            final ingModel = HiveService.ingredientBox.values.firstWhere(
                              (i) => i.name == ingredientName,
                              orElse: () => HiveService.ingredientBox.values.first,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: ThemeConfig.lightGray),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ingredientName,
                                    style: FontConfig.h3(context).copyWith(
                                      color: ThemeConfig.secondaryGreen,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Column(
                                    children: sizeMap.entries.map((sz) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              "${sz.key}:",
                                              style: FontConfig.body(context).copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: ThemeConfig.secondaryGreen,
                                              ),
                                            ),
                                            Text(
                                              "${sz.value} ${ingModel.baseUnit}",
                                              style: FontConfig.body(context).copyWith(
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
              // ──────────────────────────────
              // FIXED ACTION BUTTONS
              // ──────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: BasicButton(
                      label: "Edit",
                      type: AppButtonType.secondary,
                      onPressed: () {
                        Navigator.pop(context);
                        DialogUtils.showToast(
                          context,
                          "Edit feature under maintenance!",
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: BasicButton(
                      label: "Delete",
                      type: AppButtonType.danger,
                      onPressed: () async {
                        await product.delete();
                        DialogUtils.showToast(context, "${product.name} deleted.");
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

  Future<void> _showAddSizeDialog() async {
    final controller = TextEditingController();

    // Only allow valid entries for current type
    const sizeKeys = ["12oz", "16oz", "22oz", "HOT"];
    const variantKeys = ["Regular", "Single", "Piece", "Cup"];

    final allowed = _pricingType == "size" ? sizeKeys : variantKeys;

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxTitled(
          title: "Add ${_pricingType == "size" ? "Size" : "Variant"}",
          width: 380,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: ThemeConfig.primaryGreen),
              onPressed: () => Navigator.pop(context, null),
            ),
          ],
          child: Column(
            children: [
              BasicInputField(
                label: _pricingType == "size" ? "Size (e.g. 12oz)" : "Variant",
                controller: controller,
              ),
              const SizedBox(height: 16),
              BasicButton(
                label: "Add",
                type: AppButtonType.primary,
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) {
                    DialogUtils.showToast(context, "Cannot be empty.");
                    return;
                  }
                  if (!allowed.contains(value)) {
                    DialogUtils.showToast(context,
                        "Invalid: '$value' is not allowed for $_pricingType pricing.");
                    return;
                  }
                  Navigator.pop(context, value);
                },
              ),
            ],
          ),
        );
      },
    );

    if (result == null || result.isEmpty) return;

    if (_selectedSizes.contains(result)) {
      DialogUtils.showToast(context, "Already added.");
      return;
    }

    setState(() {
      _selectedSizes.add(result);
    });
  }

  Future<void> _showEditSizesDialog() async {
    // Work on a temporary list so changes are not applied until saved
    final temp = List<String>.from(_selectedSizes);
    final sizeKeys = ["12oz", "16oz", "22oz", "HOT"];
    final variantKeys = ["Regular", "Single", "Piece", "Cup"];
    final allowed = _pricingType == "size" ? sizeKeys : variantKeys;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxTitled(
          title: "Edit Available Sizes",
          width: 420,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, size: 22, color: ThemeConfig.primaryGreen),
              padding: EdgeInsets.zero,
              splashRadius: 18,
              onPressed: () => Navigator.pop(context),
            ),
          ],
          child: StatefulBuilder(
            builder: (context, setInner) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ───────────────────────────────
                  // CURRENTLY SELECTED SIZES
                  // ───────────────────────────────
                  Text(
                    "Selected Sizes",
                    style: FontConfig.h2(context).copyWith(
                      color: ThemeConfig.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  
                  const SizedBox(height: 10),

                  temp.isEmpty
                      ? Text(
                          "No sizes selected.",
                          style: FontConfig.body(context)
                              .copyWith(color: ThemeConfig.midGray),
                        )
                      : Column(
                          children: temp.map((size) {
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: ThemeConfig.midGray,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(size,
                                      style: FontConfig.body(context).copyWith(
                                        color: ThemeConfig.secondaryGreen,
                                        fontWeight: FontWeight.w500,
                                      )),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.redAccent),
                                    splashRadius: 18,
                                    onPressed: () {
                                      setInner(() => temp.remove(size));
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 20),

                  // ───────────────────────────────
                  // ADD FROM KNOWN SIZES
                  // ───────────────────────────────
                  if (_availableSizes.isNotEmpty) ...[
                    Text(
                      "Add From Existing Sizes",
                      style: FontConfig.h2(context).copyWith(
                        color: ThemeConfig.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 5,
                      runSpacing: 10,
                      children: allowed
                          .where((s) => !temp.contains(s))
                          .map((s) => ActionChip(
                                label: Text(s),
                                onPressed: () => setInner(() => temp.add(s)),
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 26),

                  // ───────────────────────────────
                  // SAVE BUTTON
                  // ───────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: BasicButton(
                          label: "Save",
                          type: AppButtonType.primary,
                          onPressed: () {
                            setState(() {
                              // Remove controllers for removed sizes
                              final removed = _selectedSizes
                                  .where((s) => !temp.contains(s))
                                  .toList();
                              for (final r in removed) {
                                _sizePriceCtrls[r]?.dispose();
                                _sizePriceCtrls.remove(r);
                              }

                              _selectedSizes = temp;

                              // No need for active tab now (tab system removed)
                            });

                            Navigator.pop(context);
                          },
                        ),
                      )
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showAddSizeDialogForEdit(
    List<String> editSizes,
    String pricingType,
    Map<String, TextEditingController> editPriceCtrls,
    Map<String, Map<String, TextEditingController>> editIngredientCtrls,
  ) async {
    final controller = TextEditingController();

    // Allowed keys
    const sizeKeys = ["12oz", "16oz", "22oz", "HOT"];
    const variantKeys = ["Regular", "Single", "Piece", "Cup"];
    final allowed = pricingType == "size" ? sizeKeys : variantKeys;

    final result = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxTitled(
          title: "Add ${pricingType == "size" ? "Size" : "Variant"}",
          width: 380,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: ThemeConfig.primaryGreen),
              onPressed: () => Navigator.pop(context, null),
            ),
          ],
          child: Column(
            children: [
              BasicInputField(
                label: pricingType == "size" ? "Size (e.g. 12oz)" : "Variant",
                controller: controller,
              ),
              const SizedBox(height: 16),
              BasicButton(
                label: "Add",
                type: AppButtonType.primary,
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isEmpty) {
                    DialogUtils.showToast(context, "Cannot be empty.");
                    return;
                  }
                  if (!allowed.contains(value)) {
                    DialogUtils.showToast(context,
                        "Invalid: '$value' is not allowed for $pricingType pricing.");
                    return;
                  }
                  Navigator.pop(context, value);
                },
              ),
            ],
          ),
        );
      },
    );

    if (result == null || result.isEmpty) return;

    if (editSizes.contains(result)) {
      DialogUtils.showToast(context, "Already added.");
      return;
    }

    // Add size + controllers for price + ingredient usage
    setState(() {
      editSizes.add(result);
      editPriceCtrls[result] = TextEditingController();

      for (final ing in editIngredientCtrls.keys) {
        editIngredientCtrls[ing]![result] = TextEditingController();
      }
    });
  }

  Future<void> _showEditSizesDialogForEdit(
    List<String> editSizes,
    String pricingType,
    Map<String, TextEditingController> editPriceCtrls,
    Map<String, Map<String, TextEditingController>> editIngredientCtrls,
  ) async {

    final temp = List<String>.from(editSizes);

    const sizeKeys = ["12oz", "16oz", "22oz", "HOT"];
    const variantKeys = ["Regular", "Single", "Piece", "Cup"];
    final allowed = pricingType == "size" ? sizeKeys : variantKeys;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxTitled(
          title: "Edit ${pricingType == "size" ? "Sizes" : "Variants"}",
          width: 420,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, size: 22, color: ThemeConfig.primaryGreen),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          child: StatefulBuilder(
            builder: (context, setInner) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selected list
                  Text(
                    "Selected ${pricingType == "size" ? "Sizes" : "Variants"}",
                    style: FontConfig.h2(context).copyWith(
                      color: ThemeConfig.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  temp.isEmpty
                      ? Text(
                          "No entries.",
                          style: FontConfig.body(context).copyWith(color: ThemeConfig.midGray),
                        )
                      : Column(
                          children: temp.map((value) {
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: ThemeConfig.midGray,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    value,
                                    style: FontConfig.body(context).copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: ThemeConfig.secondaryGreen,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () {
                                      setInner(() => temp.remove(value));
                                    },
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                  const SizedBox(height: 14),

                  // Add from allowed list
                  Text(
                    "Add Existing",
                    style: FontConfig.h2(context).copyWith(
                      color: ThemeConfig.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 6,
                    runSpacing: 10,
                    children: allowed
                        .where((s) => !temp.contains(s))
                        .map((s) {
                          return ActionChip(
                            label: Text(s),
                            onPressed: () {
                              setInner(() => temp.add(s));
                            },
                          );
                        }).toList(),
                  ),

                  const SizedBox(height: 24),

                  BasicButton(
                    label: "Save",
                    type: AppButtonType.primary,
                    onPressed: () {
                      // Remove controllers for removed sizes
                      final removed = editSizes.where((s) => !temp.contains(s)).toList();
                      for (final r in removed) {
                        editPriceCtrls[r]?.dispose();
                        editPriceCtrls.remove(r);

                        for (final ing in editIngredientCtrls.keys) {
                          editIngredientCtrls[ing]?[r]?.dispose();
                          editIngredientCtrls[ing]?.remove(r);
                        }
                      }

                      setState(() {
                        editSizes
                          ..clear()
                          ..addAll(temp);
                      });

                      Navigator.pop(context);
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showEditDialog(ProductModel product) {
    // Controllers prefilled with existing data
    final formKey = GlobalKey<FormState>();

    final editName = TextEditingController(text: product.name);
    final editCategory = TextEditingController(text: product.category);
    final editSubCategory = TextEditingController(text: product.subCategory);

    // Pricing type
    String pricingType = product.pricingType;

    // Sizes / variants
    List<String> editSizes = product.prices.keys.toList();

    // Price controllers
    final Map<String, TextEditingController> editPriceCtrls = {};
    for (final size in editSizes) {
      editPriceCtrls[size] =
          TextEditingController(text: product.prices[size]?.toString());
    }

    // Ingredient Usage controllers
    Map<String, Map<String, TextEditingController>> editIngredientCtrls = {};
    for (final ing in product.ingredientUsage.keys) {
      editIngredientCtrls[ing] = {};
      for (final size in editSizes) {
        final qty = product.ingredientUsage[ing]?[size] ?? 0;
        editIngredientCtrls[ing]![size] =
            TextEditingController(text: qty.toString());
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return DialogBoxTitled(
          title: "Edit Product",
          width: 520,
          actions: [
            IconButton(
              icon: const Icon(Icons.close, size: 24, color: ThemeConfig.primaryGreen),
              splashRadius: 18,
              onPressed: () => Navigator.pop(context),
            ),
          ],
          child: SizedBox(
            height: 520,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 6),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 14),
                    // ─────────────────────────
                    // BASIC INFO
                    // ─────────────────────────
                    BasicInputField(
                      label: "Product Name",
                      controller: editName,
                    ),
                    const SizedBox(height: 14),

                    HybridDropdownField(
                      label: "Category",
                      controller: editCategory,
                      options: productBox.values
                          .map((p) => p.category)
                          .where((c) => c.isNotEmpty)
                          .toSet()
                          .toList(),
                    ),

                    const SizedBox(height: 12),

                    HybridDropdownField(
                      label: "Subcategory",
                      controller: editSubCategory,
                      options: productBox.values
                          .map((p) => p.subCategory)
                          .where((c) => c.isNotEmpty)
                          .toSet()
                          .toList(),
                    ),

                    const SizedBox(height: 20),

                    // ─────────────────────────
                    // PRICING TYPE
                    // ─────────────────────────
                    Text("Pricing Type", style: FontConfig.h3(context)),
                    const SizedBox(height: 6),

                    BasicDropdownButton<String>(
                      width: 200,
                      value: pricingType,
                      items: const ["size", "variant"],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {});
                        pricingType = value;

                        // Reset sizes when switching type
                        editSizes.clear();
                        editPriceCtrls.clear();
                        editIngredientCtrls.clear();
                      },
                    ),

                    const SizedBox(height: 20),

                    // ─────────────────────────
                    // SIZES / VARIANTS
                    // ─────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Available ${pricingType == "size" ? "Sizes" : "Variants"}",
                            style: FontConfig.h3(context)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: ThemeConfig.primaryGreen),
                              onPressed: () =>
                                  _showEditSizesDialogForEdit(editSizes, pricingType, editPriceCtrls, editIngredientCtrls),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: ThemeConfig.primaryGreen),
                              onPressed: () =>
                                  _showAddSizeDialogForEdit(editSizes, pricingType, editPriceCtrls, editIngredientCtrls),
                            ),
                          ],
                        )
                      ],
                    ),

                    editSizes.isEmpty
                        ? Text(
                            "No entries.",
                            style: FontConfig.body(context).copyWith(color: ThemeConfig.midGray),
                          )
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: editSizes.map((s) => BasicChipDisplay(label: s)).toList(),
                          ),

                    const SizedBox(height: 20),

                    // ─────────────────────────
                    // PRICES
                    // ─────────────────────────
                    Text("Prices", style: FontConfig.h3(context)),
                    const SizedBox(height: 10),

                    Column(
                      children: editSizes.map((size) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 80,
                                child: Text(
                                  "$size:",
                                  style: FontConfig.body(context).copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: ThemeConfig.secondaryGreen,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: BasicInputField(
                                  label: "₱ Price",
                                  controller: editPriceCtrls[size]!,
                                  inputType: TextInputType.number,
                                  isCurrency: true,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ─────────────────────────
                    // INGREDIENT USAGE
                    // ─────────────────────────
                    Text("Ingredient Usage", style: FontConfig.h3(context)),
                    const SizedBox(height: 10),

                    Column(
                      children: editIngredientCtrls.keys.map((ing) {
                        final unit = HiveService.ingredientBox.values
                            .firstWhere((i) => i.name == ing)
                            .baseUnit;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: ThemeConfig.lightGray),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ing,
                                style: FontConfig.h3(context).copyWith(
                                  color: ThemeConfig.secondaryGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 10),

                              Column(
                                children: editSizes.map((size) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 80,
                                          child: Text(
                                            "$size:",
                                            style: FontConfig.body(context).copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: ThemeConfig.secondaryGreen,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: BasicInputField(
                                            label: "Qty ($unit)",
                                            controller: editIngredientCtrls[ing]![size]!,
                                            inputType: TextInputType.number,
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
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // ─────────────────────────
                    // SAVE BUTTON
                    // ─────────────────────────
                    BasicButton(
                      label: "Save Changes",
                      type: AppButtonType.primary,
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) {
                          DialogUtils.showToast(context, "Please fill all fields.");
                          return;
                        }

                        if (editSizes.isEmpty) {
                          DialogUtils.showToast(context, "Add at least one size/variant.");
                          return;
                        }

                        // Build pricing map
                        final newPrices = <String, double>{};
                        for (final size in editSizes) {
                          final txt = editPriceCtrls[size]!.text.replaceAll(",", "");
                          final parsed = double.tryParse(txt);
                          if (parsed == null) {
                            DialogUtils.showToast(context, "Invalid price for $size.");
                            return;
                          }
                          newPrices[size] = parsed;
                        }

                        // Build ingredient usage
                        final newUsage = <String, Map<String, double>>{};
                        for (final ing in editIngredientCtrls.keys) {
                          newUsage[ing] = {};
                          for (final size in editSizes) {
                            final txt = editIngredientCtrls[ing]![size]!.text.replaceAll(",", "");
                            final parsed = double.tryParse(txt);
                            if (parsed == null) {
                              DialogUtils.showToast(context, "Invalid qty for $ing ($size).");
                              return;
                            }
                            newUsage[ing]![size] = parsed;
                          }
                        }

                        // Apply updates
                        product
                          ..name = editName.text.trim()
                          ..category = editCategory.text.trim()
                          ..subCategory = editSubCategory.text.trim()
                          ..pricingType = pricingType
                          ..prices = newPrices
                          ..ingredientUsage = newUsage
                          ..updatedAt = DateTime.now();

                        await product.save();

                        DialogUtils.showToast(context, "Product updated.");
                        Navigator.pop(context);
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  // ──────────────── FILTERING & SORTING FUNCTION ────────────────
  List<ProductModel> _getFilteredProducts() {
    List<ProductModel> list = productBox.values.toList();

    // 🔍 Apply Search
    if (_searchQuery.isNotEmpty) {
      list = list.where((prod) => prod.name.toLowerCase().contains(_searchQuery)).toList();
    }

    // 🧩 Apply Filters
    if (_selectedCategory != null) {
      list = list.where((prod) => prod.category == _selectedCategory).toList();
    }
    if (_selectedSubCategory != null) {
      list = list.where((prod) => prod.subCategory == _selectedSubCategory).toList();
    }

    // ↕️ Apply Sorting
    switch (_selectedSort) {
      case 'Name (A–Z)':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Name (Z–A)':
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
    }

    return list;
  }

  bool _showFilters = false;
  String _filterType = "Category";

  // ──────────────────────────────────────────────────────────────
  // HELPER BUILDERS SECTION (REFACTOR LATER AS IT SCALES)
  // ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar(BuildContext context) {
    return BasicSearchBox(
      hintText: "Search Product...",
      onChanged: (value) {
        setState(() => _searchQuery = value);
      },
    );
  }

  Widget _buildSortDropdown(BuildContext context) {
    return BasicDropdownButton<String>(
      width:200,
      value: _selectedSort,
      items: const [
        "Name (A-Z)",
        "Name (Z-A)",
      ],
      onChanged: (value) {
        setState(() => _selectedSort = value!);
      },
    );
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedCategory != null) count++;
    if (_selectedSubCategory != null) count++;
    return count;
  }

  Widget _buildFilterButton(BuildContext context) {
    return BasicToggleButton(
      expanded: _showFilters,
      label: "Filter",
      badgeCount: _activeFiltersCount,
      onPressed: () {
        setState(() => _showFilters = !_showFilters);
      },
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    final categories = productBox.values.map((e) => e.category).toSet().toList();
    final subCategories = productBox.values.map((e) => e.subCategory).toSet().toList();
    final List<String> options = _filterType == "Category" ? categories : subCategories;

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
              DropdownMenuItem(value: "SubCategory", child: Text("Sub Category")),
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
                      : _selectedSubCategory == opt;

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
                            _selectedSubCategory = v ? opt : null;
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
}
