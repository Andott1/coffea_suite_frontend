import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/product_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/mode_switcher_field.dart';
import 'widgets/pricing_editor_widget.dart';
import 'widgets/recipe_cards_widget.dart';

class ProductEditScreen extends StatefulWidget {
  final ProductModel? product; // Null if creating new

  const ProductEditScreen({super.key, this.product});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // ──────────────── STATE ────────────────
  // Identity
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _subCategoryCtrl = TextEditingController();
  bool _isAvailable = true;

  // Configuration
  String _pricingType = "size";
  final Map<String, TextEditingController> _priceCtrls = {};
  final Map<String, Map<String, TextEditingController>> _usageCtrls = {};

  late Box<ProductModel> _productBox;

  @override
  void initState() {
    super.initState();
    _productBox = HiveService.productBox;
    _tabController = TabController(length: 2, vsync: this);

    if (widget.product != null) {
      _initEditMode();
    }
  }

  void _initEditMode() {
    final p = widget.product!;
    _nameCtrl.text = p.name;
    _categoryCtrl.text = p.category;
    _subCategoryCtrl.text = p.subCategory;
    _pricingType = p.pricingType;
    _isAvailable = p.available;

    // Load Prices
    for (var entry in p.prices.entries) {
      _priceCtrls[entry.key] = TextEditingController(text: entry.value.toString());
    }

    // Load Usage
    for (var entry in p.ingredientUsage.entries) {
      final ing = entry.key;
      _usageCtrls[ing] = {};
      for (var sizeEntry in entry.value.entries) {
        _usageCtrls[ing]![sizeEntry.key] = TextEditingController(text: sizeEntry.value.toString());
      }
    }
  }

  // ──────────────── DATA HELPERS ────────────────
  
  List<String> get _categories {
    return _productBox.values.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList()..sort();
  }

  List<String> get _filteredSubCategories {
    final currentCat = _categoryCtrl.text;
    if (currentCat.isEmpty) return [];
    return _productBox.values
        .where((p) => p.category == currentCat)
        .map((p) => p.subCategory)
        .where((s) => s.isNotEmpty)
        .toSet().toList()..sort();
  }

  // "Crowdsourced" variants for the autocomplete
  List<String> get _relevantSuggestions {
    final Set<String> keys = {};
    final relevantProducts = _productBox.values.where((p) => p.pricingType == _pricingType);
    for (var p in relevantProducts) {
      keys.addAll(p.prices.keys);
    }
    return keys.toList()..sort();
  }

  // ──────────────── LOGIC: PRICING & RECIPES ────────────────

  Future<void> _onPricingTypeChanged(String? newValue) async {
    if (newValue == null || newValue == _pricingType) return;

    // 1. Safety Check: If data exists, warn user
    if (_priceCtrls.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Change Pricing Strategy?"),
          content: const Text(
            "Switching strategies will clear all current variants, prices, and recipe ingredients.\n\n"
            "This action cannot be undone.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Clear & Switch", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    // 2. Perform Switch
    setState(() {
      _pricingType = newValue;
      _priceCtrls.clear();
      _usageCtrls.clear();
    });
  }

  void _addSize(String size) {
    if (_priceCtrls.containsKey(size)) return;
    setState(() {
      _priceCtrls[size] = TextEditingController();
      // Add column to all existing ingredient rows
      for (var ing in _usageCtrls.keys) {
        _usageCtrls[ing]![size] = TextEditingController();
      }
    });
  }

  void _removeSize(String size) {
    setState(() {
      _priceCtrls.remove(size);
      for (var ing in _usageCtrls.keys) {
        _usageCtrls[ing]?.remove(size);
      }
    });
  }

  void _addIngredientRow(String ingredient) {
    if (_usageCtrls.containsKey(ingredient)) return;
    setState(() {
      _usageCtrls[ingredient] = {};
      // Initialize cell for every existing size
      for (var size in _priceCtrls.keys) {
        _usageCtrls[ingredient]![size] = TextEditingController();
      }
    });
  }

  void _removeIngredientRow(String ingredient) {
    setState(() => _usageCtrls.remove(ingredient));
  }

  // ──────────────── SAVE LOGIC ────────────────

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate Pricing
    if (_priceCtrls.isEmpty) {
      DialogUtils.showToast(context, "Please add at least one variant.", icon: Icons.warning, accentColor: Colors.orange);
      _tabController.animateTo(0); 
      return;
    }

    // Compile Prices
    final Map<String, double> prices = {};
    for (var entry in _priceCtrls.entries) {
      final val = double.tryParse(entry.value.text.replaceAll(',', ''));
      if (val == null) {
        DialogUtils.showToast(context, "Invalid price for ${entry.key}", icon: Icons.error);
        return;
      }
      prices[entry.key] = val;
    }

    // Compile Usage
    final Map<String, Map<String, double>> usage = {};
    for (var ingEntry in _usageCtrls.entries) {
      final ingName = ingEntry.key;
      final sizeMap = <String, double>{};
      for (var sizeEntry in ingEntry.value.entries) {
        final val = double.tryParse(sizeEntry.value.text);
        if (val != null && val > 0) sizeMap[sizeEntry.key] = val;
      }
      if (sizeMap.isNotEmpty) usage[ingName] = sizeMap;
    }

    // Save
    final id = widget.product?.id ?? const Uuid().v4();
    final product = ProductModel(
      id: id,
      name: _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      subCategory: _subCategoryCtrl.text.trim(),
      pricingType: _pricingType,
      prices: prices,
      ingredientUsage: usage,
      available: _isAvailable,
      updatedAt: DateTime.now(),
    );

    await _productBox.put(id, product);
    SupabaseSyncService.addToQueue(table: 'products', action: 'UPSERT', data: product.toJson());

    if (mounted) {
      DialogUtils.showToast(context, "Product saved successfully!");
      Navigator.pop(context);
    }
  }

  // ──────────────── UI BUILD ────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.product == null ? "Create New Product" : "Edit Product",
          style: FontConfig.h2(context).copyWith(color: Colors.black87),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BasicButton(
              label: "Save Product",
              icon: Icons.check,
              type: AppButtonType.primary,
              fullWidth: false,
              onPressed: _save,
            ),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── LEFT PANE (40% - Identity) ───
            Expanded(
              flex: 4,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: Colors.grey.shade200)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. IMAGE PLACEHOLDER (Fixed Height 180)
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text("Add Image (Feature Coming Soon!)", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text("Identity", style: FontConfig.caption(context)),
                      const SizedBox(height: 12),
                      
                      // 2. NAME + ACTIVE SWITCH
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: BasicInputField(label: "Product Name", controller: _nameCtrl),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            height: 56, // Standard input height
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _isAvailable ? Colors.green.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _isAvailable ? Colors.green.shade200 : Colors.grey.shade300)
                            ),
                            child: Row(
                              children: [
                                Switch(
                                  value: _isAvailable, 
                                  activeColor: ThemeConfig.primaryGreen,
                                  onChanged: (v) => setState(() => _isAvailable = v)
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _isAvailable ? "Active" : "Hidden",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _isAvailable ? ThemeConfig.primaryGreen : Colors.grey
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),

                      const SizedBox(height: 16),
                      
                      // 3. CATEGORIES (Select or Create)
                      ModeSwitcherField(
                        label: "Category",
                        controller: _categoryCtrl,
                        options: _categories,
                        onChanged: (val) => setState(() => _subCategoryCtrl.clear()),
                      ),
                      const SizedBox(height: 16),
                      ModeSwitcherField(
                        label: "Sub-Category",
                        controller: _subCategoryCtrl,
                        options: _filteredSubCategories,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── RIGHT PANE (60% - Logic) ───
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: ThemeConfig.primaryGreen,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: ThemeConfig.primaryGreen,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      tabs: const [
                        Tab(text: "Pricing & Variants", icon: Icon(Icons.attach_money)),
                        Tab(text: "Recipe & Ingredients", icon: Icon(Icons.science)),
                      ],
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: PRICING
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // STRATEGY SELECTOR
                              Text("Pricing Strategy", style: FontConfig.h3(context)),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    RadioListTile<String>(
                                      title: const Text("Size Based Pricing"),
                                      subtitle: const Text("e.g. 12oz, 16oz (Best for drinks)"),
                                      value: "size",
                                      groupValue: _pricingType,
                                      activeColor: ThemeConfig.primaryGreen,
                                      onChanged: _onPricingTypeChanged, // ✅ Safe Switch
                                    ),
                                    const Divider(height: 1),
                                    RadioListTile<String>(
                                      title: const Text("Variant Based Pricing"),
                                      subtitle: const Text("e.g. Single, Box (Best for food)"),
                                      value: "variant",
                                      groupValue: _pricingType,
                                      activeColor: ThemeConfig.primaryGreen,
                                      onChanged: _onPricingTypeChanged, // ✅ Safe Switch
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 30),
                              const Divider(),
                              const SizedBox(height: 20),

                              // EDITOR
                              PricingEditorWidget(
                                pricingType: _pricingType,
                                priceControllers: _priceCtrls,
                                onAddSize: _addSize,
                                onRemoveSize: _removeSize,
                                existingVariants: _relevantSuggestions, // ✅ Learned Autocomplete
                              ),
                            ],
                          ),
                        ),

                        // TAB 2: RECIPE
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RecipeCardsWidget(
                                sizes: _priceCtrls.keys.toList()..sort(),
                                usageControllers: _usageCtrls,
                                onAddIngredient: _addIngredientRow,
                                onRemoveIngredient: _removeIngredientRow,
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}