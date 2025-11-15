import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/services/hive_service.dart';
import '../../core/models/product_model.dart';
import '../../core/models/ingredient_usage_model.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';
import 'package:uuid/uuid.dart';

/// ─────────────────────────────────────────────
///  ADMIN PRODUCT TAB
/// ─────────────────────────────────────────────
class AdminProductTab extends StatefulWidget {
  const AdminProductTab({super.key});

  @override
  State<AdminProductTab> createState() => _AdminProductTabState();
}

class _AdminProductTabState extends State<AdminProductTab> {
  // ──────────────── FORM CONTROLLERS ────────────────
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _subCategoryCtrl = TextEditingController();
  final TextEditingController _imageUrlCtrl = TextEditingController();

  bool _showFilters = false;
  String _searchQuery = '';
  String _sortOption = 'Name (A–Z)';
  String _categoryFilter = 'All';
  String _subCategoryFilter = 'All';

  List<PricingEntry> _selectedPricings = [];
  List<IngredientUsageEntry> _selectedIngredients = [];

  // Hive box reference
  late Box<ProductModel> productBox;

  @override
  void initState() {
    super.initState();
    productBox = HiveService.productBox;
  }

  void _showToast(String message) {
    DialogUtils.showToast(context, message);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _subCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    // 1️⃣ FORM VALIDATION
    if (!_formKey.currentState!.validate()) {
      DialogUtils.showToast(context, "Please fill all required fields.");
      return;
    }

    if (_selectedPricings.isEmpty) {
      DialogUtils.showToast(context, "Please add at least one pricing size.");
      return;
    }

    // validate prices
    final invalidPrices = _selectedPricings
        .where((e) => e.price == null || e.price! <= 0)
        .toList();
    if (invalidPrices.isNotEmpty) {
      DialogUtils.showToast(
        context,
        "All selected sizes must have valid prices.",
      );
      return;
    }

    // validate ingredient usage if provided
    for (final ing in _selectedIngredients) {
      if (ing.unit.isEmpty) {
        DialogUtils.showToast(
          context,
          "Unit missing for ingredient: ${ing.ingredientName}",
        );
        return;
      }
    }

    // 2️⃣ BUILD MODELS
    final uuid = const Uuid();
    final productId = uuid.v4();

    final pricesMap = {for (final p in _selectedPricings) p.size: p.price!};

    final ingredientUsageMap = {
      for (final i in _selectedIngredients) i.ingredientId: i.quantities,
    };

    final now = DateTime.now();

    final product = ProductModel(
      id: productId,
      name: _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      subCategory: _subCategoryCtrl.text.trim(),
      pricingType: "size",
      prices: pricesMap,
      ingredientUsage: ingredientUsageMap,
      available: true,
      updatedAt: now,
      imageUrl: _imageUrlCtrl.text.trim(), // <-- new required field
    );

    // 3️⃣ SAVE TO HIVE (Product)
    await HiveService.productBox.put(product.id, product);

    // 4️⃣ SAVE INGREDIENT USAGES (One per ingredient)
    for (final i in _selectedIngredients) {
      final usage = IngredientUsageModel(
        id: uuid.v4(),
        productId: product.id,
        ingredientId: i.ingredientId,
        category: product.category,
        subCategory: product.subCategory,
        unit: i.unit,
        quantities: i.quantities,
        createdAt: now,
        updatedAt: now,
      );

      await HiveService.usageBox.put(usage.id, usage);
    }

    // 5️⃣ RESET FORM
    setState(() {
      _nameCtrl.clear();
      _categoryCtrl.clear();
      _subCategoryCtrl.clear();
      _selectedPricings.clear();
      _selectedIngredients.clear();
    });

    DialogUtils.showToast(context, "✅ Product successfully added!");
  }

  // ──────────────────────────────
  // LEFT PANEL — ADD PRODUCT FORM
  // ──────────────────────────────
  Widget _buildLeftPanel(BuildContext context) {
    return Expanded(
      flex: 3,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(right: 8, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──────────────── ADD PRODUCT BOX ────────────────
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Add New Product", style: FontConfig.h3(context)),
                  const SizedBox(height: 16),

                  // ───── Product Info Section (Phase 1)
                  ProductInfoSection(
                    formKey: _formKey,
                    nameController: _nameCtrl,
                    categoryController: _categoryCtrl,
                    subcategoryController: _subCategoryCtrl,
                  ),

                  // ───── Pricing Section (Phase 2)
                  PricingSection(
                    onChanged: (entries) => _selectedPricings = entries,
                  ),

                  // ───── Ingredient Usage Section (Phase 3)
                  IngredientUsageSection(
                    selectedSizes: _selectedPricings
                        .map((e) => e.size)
                        .toList(),
                    onChanged: (entries) => _selectedIngredients = entries,
                  ),

                  const SizedBox(height: 20),

                  // ───── FORM ACTION BUTTONS (Clear / Add)
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
                          onPressed: () {
                            _nameCtrl.clear();
                            _categoryCtrl.clear();
                            _subCategoryCtrl.clear();
                            _selectedPricings.clear();
                            _selectedIngredients.clear();
                            _showToast("Cleared all form fields");
                            setState(() {});
                          },
                          child: Text(
                            "Clear",
                            style: FontConfig.buttonLarge(context),
                          ),
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 44,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        color: ThemeConfig.lightGray,
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
                          onPressed: _saveProduct,
                          child: Text(
                            "Add",
                            style: FontConfig.buttonLarge(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ──────────────── BACKUP / RESTORE / DELETE BOX ────────────────
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
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.save_outlined,
                            color: ThemeConfig.primaryGreen,
                          ),
                          label: Text(
                            "Backup",
                            style: FontConfig.buttonLarge(
                              context,
                            ).copyWith(color: ThemeConfig.primaryGreen),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConfig.white,
                            side: const BorderSide(
                              color: ThemeConfig.primaryGreen,
                              width: 2,
                            ),
                          ),
                          onPressed: () => _showToast("Backup clicked"),
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
                          icon: const Icon(
                            Icons.restore,
                            color: ThemeConfig.primaryGreen,
                          ),
                          label: Text(
                            "Restore",
                            style: FontConfig.buttonLarge(
                              context,
                            ).copyWith(color: ThemeConfig.primaryGreen),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConfig.white,
                            side: const BorderSide(
                              color: ThemeConfig.primaryGreen,
                              width: 2,
                            ),
                          ),
                          onPressed: () => _showToast("Restore clicked"),
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
                        // Clear products and ingredient usages (matching ingredient tab pattern)
                        await HiveService.productBox.clear();
                        await HiveService.usageBox.clear();

                        DialogUtils.showToast(
                          context,
                          "All products and ingredient usages deleted.",
                        );
                        setState(() {}); // refresh UI
                      },
                      child: Text(
                        "Delete All",
                        style: FontConfig.buttonLarge(context),
                      ),
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

  // ──────────────────────────────
  // RIGHT PANEL — PRODUCT GRID
  // ──────────────────────────────
  Widget _buildRightPanel(BuildContext context) {
    return Expanded(
      flex: 5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ───── SEARCH / SORT / FILTER PANEL ─────
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
                Row(
                  children: [
                    Expanded(flex: 3, child: _buildSearchBar(context)),
                    const SizedBox(width: 20),
                    _buildSortDropdown(context),
                    const SizedBox(width: 20),
                    _buildFilterButton(context),
                  ],
                ),
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

          const SizedBox(height: 10),

          // ───── PRODUCT GRID ─────
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: productBox.listenable(),
              builder: (context, Box<ProductModel> box, _) {
                List<ProductModel> products = box.values.toList();

                // Apply search filter
                if (_searchQuery.isNotEmpty) {
                  products = products
                      .where(
                        (p) => p.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();
                }

                // Apply category / subcategory filters
                if (_categoryFilter != 'All') {
                  products = products
                      .where((p) => p.category == _categoryFilter)
                      .toList();
                }
                if (_subCategoryFilter != 'All') {
                  products = products
                      .where((p) => p.subCategory == _subCategoryFilter)
                      .toList();
                }

                // Apply sorting
                switch (_sortOption) {
                  case 'Name (A–Z)':
                    products.sort((a, b) => a.name.compareTo(b.name));
                    break;
                  case 'Name (Z–A)':
                    products.sort((a, b) => b.name.compareTo(a.name));
                    break;
                  case 'Price (Low–High)':
                    products.sort(
                      (a, b) =>
                          (a.prices.values.isEmpty ? 0 : a.prices.values.first)
                              .compareTo(
                                b.prices.values.isEmpty
                                    ? 0
                                    : b.prices.values.first,
                              ),
                    );
                    break;
                  case 'Price (High–Low)':
                    products.sort(
                      (a, b) =>
                          (b.prices.values.isEmpty ? 0 : b.prices.values.first)
                              .compareTo(
                                a.prices.values.isEmpty
                                    ? 0
                                    : a.prices.values.first,
                              ),
                    );
                    break;
                }

                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      "No products found.",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.only(top: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 370 / 116,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];

                    return GestureDetector(
                      onTap: () => _showToast("Tapped: ${p.name}"),
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
                                  // Product name
                                  Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: ThemeConfig.primaryGreen,
                                    ),
                                  ),

                                  // Category
                                  Text(
                                    p.category,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: ThemeConfig.secondaryGreen,
                                    ),
                                  ),

                                  // Sizes (as displayQuantity equivalent)
                                  Text(
                                    p.prices.isNotEmpty
                                        ? "Sizes: ${p.prices.keys.join(', ')}"
                                        : "Sizes: —",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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

                            // RIGHT COLUMN — Price (as Cost equivalent)
                            SizedBox(
                              width: 118,
                              child: Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  FormatUtils.formatCurrency(
                                    p.prices.isNotEmpty
                                        ? p.prices.values.reduce(
                                            (a, b) => a > b ? a : b,
                                          )
                                        : 0,
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────
  // SEARCH BAR
  // ──────────────────────────────
  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search product...',
        prefixIcon: const Icon(Icons.search, color: ThemeConfig.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: ThemeConfig.primaryGreen,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: ThemeConfig.primaryGreen,
            width: 2,
          ),
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim()),
    );
  }

  // ──────────────────────────────
  // SORT DROPDOWN
  // ──────────────────────────────
  Widget _buildSortDropdown(BuildContext context) {
    const options = [
      'Name (A–Z)',
      'Name (Z–A)',
      'Price (Low–High)',
      'Price (High–Low)',
    ];

    return DropdownButton<String>(
      value: _sortOption,
      items: options
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (val) {
        if (val != null) setState(() => _sortOption = val);
      },
    );
  }

  // ──────────────────────────────
  // FILTER BUTTON
  // ──────────────────────────────
  Widget _buildFilterButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => setState(() => _showFilters = !_showFilters),
      style: ElevatedButton.styleFrom(
        backgroundColor: ThemeConfig.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.filter_alt_outlined, color: Colors.white),
      label: Text(
        _showFilters ? "Hide Filters" : "Show Filters",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ──────────────────────────────
  // FILTER ROW
  // ──────────────────────────────
  Widget _buildFilterRow(BuildContext context) {
    // pull unique categories & subcategories from Hive
    final allProducts = HiveService.productBox.values.toList();
    final categories = [
      'All',
      ...{for (var p in allProducts) p.category}..removeWhere((e) => e.isEmpty),
    ];
    final subcategories = [
      'All',
      ...{for (var p in allProducts) p.subCategory}
        ..removeWhere((e) => e.isEmpty),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _categoryFilter,
              decoration: const InputDecoration(labelText: "Category"),
              items: categories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() {
                _categoryFilter = v!;
              }),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _subCategoryFilter,
              decoration: const InputDecoration(labelText: "Subcategory"),
              items: subcategories
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() {
                _subCategoryFilter = v!;
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────
  // MAIN BUILD
  // ──────────────────────────────
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

/// ─────────────────────────────────────────────
///  PRODUCT INFO SECTION (Phase 1 Implementation)
/// ─────────────────────────────────────────────
class ProductInfoSection extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController subcategoryController;

  const ProductInfoSection({
    super.key,
    required this.formKey,
    required this.nameController,
    required this.categoryController,
    required this.subcategoryController,
  });

  @override
  State<ProductInfoSection> createState() => _ProductInfoSectionState();
}

class _ProductInfoSectionState extends State<ProductInfoSection> {
  List<String> _categories = [];
  List<String> _subcategories = [];

  @override
  void initState() {
    super.initState();
    _loadOptionsFromHive();
  }

  void _loadOptionsFromHive() {
    final products = HiveService.productBox.values.toList();
    setState(() {
      _categories = products
          .map((p) => p.category)
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      _subcategories = products
          .map((p) => p.subCategory)
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PRODUCT NAME
          TextFormField(
            controller: widget.nameController,
            decoration: InputDecoration(
              labelText: "Product Name",
              labelStyle: FontConfig.inputLabel(context),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: ThemeConfig.midGray,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: ThemeConfig.primaryGreen,
                  width: 2,
                ),
              ),
            ),
            validator: (val) => val == null || val.trim().isEmpty
                ? "Product name is required"
                : null,
          ),
          const SizedBox(height: 12),

          // CATEGORY + SUBCATEGORY
          Row(
            children: [
              Expanded(
                child: _HybridDropdownTextField(
                  label: "Category",
                  controller: widget.categoryController,
                  options: _categories,
                  required: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HybridDropdownTextField(
                  label: "Subcategory",
                  controller: widget.subcategoryController,
                  options: _subcategories,
                  required: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────
///  REUSABLE HYBRID DROPDOWN + TEXT FIELD
/// ─────────────────────────────────────────────
class _HybridDropdownTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> options;
  final bool required;

  const _HybridDropdownTextField({
    required this.label,
    required this.controller,
    required this.options,
    this.required = false,
  });

  @override
  State<_HybridDropdownTextField> createState() =>
      _HybridDropdownTextFieldState();
}

class _HybridDropdownTextFieldState extends State<_HybridDropdownTextField> {
  void _showOptionsDialog() async {
    if (widget.options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No existing ${widget.label.toLowerCase()}s found. You can type one manually.',
          ),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ListView(
        children: widget.options.map((option) {
          return ListTile(
            title: Text(option),
            onTap: () => Navigator.pop(context, option),
          );
        }).toList(),
      ),
    );

    if (selected != null) {
      setState(() => widget.controller.text = selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: FontConfig.inputLabel(context),
        suffixIcon: IconButton(
          icon: const Icon(
            Icons.arrow_drop_down,
            color: ThemeConfig.primaryGreen,
          ),
          onPressed: _showOptionsDialog,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: ThemeConfig.midGray, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: ThemeConfig.primaryGreen,
            width: 2,
          ),
        ),
      ),
      validator: widget.required
          ? (val) => val == null || val.trim().isEmpty
                ? "${widget.label} is required"
                : null
          : null,
    );
  }
}

/// ─────────────────────────────────────────────
///  PHASE 2 — PRICING SECTION
/// ─────────────────────────────────────────────
class PricingSection extends StatefulWidget {
  final ValueChanged<List<PricingEntry>> onChanged;
  const PricingSection({super.key, required this.onChanged});

  @override
  State<PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends State<PricingSection> {
  List<String> _availableSizes = [];
  List<PricingEntry> _selectedPricings = [];
  String? _activeSize;

  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSizesFromHive();
  }

  void _loadSizesFromHive() {
    // Pull all existing sizes dynamically from Hive products
    final products = HiveService.productBox.values.toList();
    final sizeSet = <String>{};
    for (final p in products) {
      sizeSet.addAll(p.prices.keys);
    }
    setState(() => _availableSizes = sizeSet.toList()..sort());
  }

  // Opens dialog to select sizes
  Future<void> _showSizeDialog({bool editing = false}) async {
    final selected = Set<String>.from(_selectedPricings.map((e) => e.size));

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final tempSelection = Set<String>.from(selected);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Sizes'),
              content: SizedBox(
                width: 300,
                height: 280,
                child: ListView(
                  children: _availableSizes.map((s) {
                    final isSelected = tempSelection.contains(s);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(s),
                      onChanged: (v) {
                        setStateDialog(() {
                          if (v == true) {
                            tempSelection.add(s);
                          } else {
                            tempSelection.remove(s);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.primaryGreen,
                  ),
                  onPressed: () =>
                      Navigator.pop(context, tempSelection.toList()),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    // ✅ When user confirms
    if (result != null) {
      setState(() {
        _selectedPricings = result.map((s) {
          final existing = _selectedPricings.firstWhere(
            (e) => e.size == s,
            orElse: () => PricingEntry(s),
          );
          return existing;
        }).toList();

        // Default active tab
        if (_selectedPricings.isNotEmpty) {
          _activeSize ??= _selectedPricings.first.size;
        }
      });

      widget.onChanged(_selectedPricings);
    }
  }

  // Handle price input change
  void _onPriceChanged(String value) {
    if (_activeSize == null) return;
    final idx = _selectedPricings.indexWhere((e) => e.size == _activeSize);
    if (idx != -1) {
      final price = double.tryParse(value);
      _selectedPricings[idx].price = price;
      widget.onChanged(_selectedPricings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(color: ThemeConfig.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Pricing", style: FontConfig.h3(context)),
              Row(
                children: [
                  IconButton(
                    tooltip: "Edit selected sizes",
                    onPressed: _selectedPricings.isEmpty
                        ? null
                        : () => _showSizeDialog(editing: true),
                    icon: const Icon(
                      Icons.edit,
                      color: ThemeConfig.primaryGreen,
                    ),
                  ),
                  IconButton(
                    tooltip: "Add new sizes",
                    onPressed: _showSizeDialog,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: ThemeConfig.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Tabs for selected sizes
          if (_selectedPricings.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _selectedPricings.map((entry) {
                  final isActive = entry.size == _activeSize;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeSize = entry.size;
                          _priceController.text = entry.price?.toString() ?? '';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? ThemeConfig.primaryGreen
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: ThemeConfig.primaryGreen,
                            width: 1.8,
                          ),
                        ),
                        child: Text(
                          entry.size,
                          style: TextStyle(
                            color: isActive
                                ? Colors.white
                                : ThemeConfig.primaryGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            const Text(
              "No sizes selected yet.",
              style: TextStyle(color: ThemeConfig.midGray),
            ),

          const SizedBox(height: 16),

          // Price field for active tab
          if (_activeSize != null)
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Price for $_activeSize",
                labelStyle: FontConfig.inputLabel(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: ThemeConfig.midGray,
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: ThemeConfig.primaryGreen,
                    width: 2,
                  ),
                ),
              ),
              onChanged: _onPriceChanged,
            ),
        ],
      ),
    );
  }
}

/// Helper model for selected pricing entries
class PricingEntry {
  final String size;
  double? price;
  PricingEntry(this.size, [this.price]);
}

/// ─────────────────────────────────────────────
///  PHASE 3 — INGREDIENT USAGE SECTION
/// ─────────────────────────────────────────────
class IngredientUsageSection extends StatefulWidget {
  final List<String> selectedSizes;
  final ValueChanged<List<IngredientUsageEntry>> onChanged;

  const IngredientUsageSection({
    super.key,
    required this.selectedSizes,
    required this.onChanged,
  });

  @override
  State<IngredientUsageSection> createState() => _IngredientUsageSectionState();
}

class _IngredientUsageSectionState extends State<IngredientUsageSection> {
  List<IngredientUsageEntry> _selectedIngredients = [];
  List<Map<String, String>> _availableIngredients = [];
  String? _activeIngredientId;

  @override
  void initState() {
    super.initState();
    _loadIngredientsFromHive();
  }

  @override
  void didUpdateWidget(covariant IngredientUsageSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Detect pricing size changes
    if (oldWidget.selectedSizes.join(',') != widget.selectedSizes.join(',')) {
      bool changed = false;

      for (var ing in _selectedIngredients) {
        // Remove outdated sizes
        final removed = ing.quantities.keys
            .where((s) => !widget.selectedSizes.contains(s))
            .toList();
        for (final r in removed) {
          ing.quantities.remove(r);
          changed = true;
        }

        // Add new sizes (with default 0 quantity)
        for (final s in widget.selectedSizes) {
          if (!ing.quantities.containsKey(s)) {
            ing.quantities[s] = 0;
            changed = true;
          }
        }
      }

      if (changed) {
        // ✅ Delay the rebuild until after widget tree updates
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _loadIngredientsFromHive() {
    final ingredients = HiveService.ingredientBox.values.toList();
    setState(() {
      _availableIngredients = ingredients
          .map((i) => {'id': i.id, 'name': i.name, 'baseUnit': i.baseUnit})
          .toList();
    });
  }

  Future<void> _showIngredientDialog({bool editing = false}) async {
    final selectedIds = _selectedIngredients.map((e) => e.ingredientId).toSet();

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final tempSelected = Set<String>.from(selectedIds);
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Ingredients'),
              content: SizedBox(
                width: 300,
                height: 300,
                child: ListView(
                  children: _availableIngredients.map((i) {
                    final id = i['id']!;
                    final isSelected = tempSelected.contains(id);
                    return CheckboxListTile(
                      value: isSelected,
                      title: Text(i['name'] ?? ''),
                      onChanged: (v) {
                        setStateDialog(() {
                          if (v == true) {
                            tempSelected.add(id);
                          } else {
                            tempSelected.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeConfig.primaryGreen,
                  ),
                  onPressed: () =>
                      Navigator.pop(context, tempSelected.toList()),
                  child: const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedIngredients = result.map((id) {
          final existing = _selectedIngredients.firstWhere(
            (e) => e.ingredientId == id,
            orElse: () {
              final ing = _availableIngredients.firstWhere(
                (i) => i['id'] == id,
              );
              return IngredientUsageEntry(
                ingredientId: ing['id']!,
                ingredientName: ing['name']!,
                unit: ing['baseUnit'] ?? '',
                quantities: {for (var s in widget.selectedSizes) s: 0},
              );
            },
          );
          return existing;
        }).toList();

        if (_selectedIngredients.isNotEmpty && _activeIngredientId == null) {
          _activeIngredientId = _selectedIngredients.first.ingredientId;
        }
      });

      widget.onChanged(_selectedIngredients);
    }
  }

  void _onQuantityChanged(String ingredientId, String size, String value) {
    final idx = _selectedIngredients.indexWhere(
      (i) => i.ingredientId == ingredientId,
    );
    if (idx == -1) return;
    final qty = double.tryParse(value) ?? 0;
    _selectedIngredients[idx].quantities[size] = qty;
    widget.onChanged(_selectedIngredients);
  }

  void _onUnitChanged(String ingredientId, String newUnit) {
    final idx = _selectedIngredients.indexWhere(
      (i) => i.ingredientId == ingredientId,
    );
    if (idx == -1) return;
    _selectedIngredients[idx].unit = newUnit;
    widget.onChanged(_selectedIngredients);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(color: ThemeConfig.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Ingredient Usage", style: FontConfig.h3(context)),
              Row(
                children: [
                  IconButton(
                    tooltip: "Edit ingredients",
                    onPressed: _selectedIngredients.isEmpty
                        ? null
                        : () => _showIngredientDialog(editing: true),
                    icon: const Icon(
                      Icons.edit,
                      color: ThemeConfig.primaryGreen,
                    ),
                  ),
                  IconButton(
                    tooltip: "Add ingredients",
                    onPressed: _showIngredientDialog,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: ThemeConfig.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (_selectedIngredients.isEmpty)
            const Text(
              "No ingredients added yet.",
              style: TextStyle(color: ThemeConfig.midGray),
            )
          else
            Column(
              children: [
                // Ingredient tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _selectedIngredients.map((entry) {
                      final isActive =
                          entry.ingredientId == _activeIngredientId;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(
                              () => _activeIngredientId = entry.ingredientId,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? ThemeConfig.primaryGreen
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ThemeConfig.primaryGreen,
                                width: 1.8,
                              ),
                            ),
                            child: Text(
                              entry.ingredientName,
                              style: TextStyle(
                                color: isActive
                                    ? Colors.white
                                    : ThemeConfig.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // Active ingredient editor
                if (_activeIngredientId != null)
                  _buildIngredientEditor(_activeIngredientId!),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientEditor(String ingredientId) {
    final entry = _selectedIngredients.firstWhere(
      (e) => e.ingredientId == ingredientId,
    );

    final availableUnits = _availableIngredients
        .where((i) => i['id'] == ingredientId)
        .map((i) => i['baseUnit'])
        .whereType<String>()
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unit dropdown
        Row(
          children: [
            const Text("Unit:", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: entry.unit.isEmpty ? null : entry.unit,
              hint: const Text("Select unit"),
              items: availableUnits
                  .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                  .toList(),
              onChanged: (v) {
                if (v != null) _onUnitChanged(ingredientId, v);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Per-size usage fields
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.selectedSizes.map((size) {
            return SizedBox(
              width: 110,
              child: TextFormField(
                initialValue: entry.quantities[size]?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: "$size",
                  labelStyle: FontConfig.inputLabel(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                onChanged: (v) => _onQuantityChanged(ingredientId, size, v),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// UI helper model
class IngredientUsageEntry {
  String ingredientId;
  String ingredientName;
  String unit;
  Map<String, double> quantities;
  IngredientUsageEntry({
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.quantities,
  });
}
