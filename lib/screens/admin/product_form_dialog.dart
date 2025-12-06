import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme_config.dart';
import '../../core/models/product_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_dropdown_button.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/hybrid_dropdown_field.dart';
import 'widgets/pricing_editor_widget.dart';
import 'widgets/recipe_matrix_widget.dart';

class ProductFormDialog extends StatefulWidget {
  final ProductModel? product; // Null if creating new

  const ProductFormDialog({super.key, this.product});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Basic Info
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _subCategoryCtrl = TextEditingController();
  String _pricingType = "size";
  bool _isAvailable = true;

  // Pricing State
  final Map<String, TextEditingController> _priceCtrls = {};

  // Recipe State
  final Map<String, Map<String, TextEditingController>> _usageCtrls = {};

  late Box<ProductModel> _productBox;

  @override
  void initState() {
    super.initState();
    _productBox = HiveService.productBox;
    
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

  // ──────────────── LOGIC ────────────────
  
  void _addSize(String size) {
    if (_priceCtrls.containsKey(size)) return;
    setState(() {
      _priceCtrls[size] = TextEditingController();
      // Add column to all ingredient rows
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

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_priceCtrls.isEmpty) {
      DialogUtils.showToast(context, "Please add at least one size/variant.");
      return;
    }

    // 1. Compile Prices
    final Map<String, double> prices = {};
    for (var entry in _priceCtrls.entries) {
      final val = double.tryParse(entry.value.text.replaceAll(',', ''));
      if (val == null) {
        DialogUtils.showToast(context, "Invalid price for ${entry.key}");
        return;
      }
      prices[entry.key] = val;
    }

    // 2. Compile Usage
    final Map<String, Map<String, double>> usage = {};
    for (var ingEntry in _usageCtrls.entries) {
      final ingName = ingEntry.key;
      final sizeMap = <String, double>{};
      
      for (var sizeEntry in ingEntry.value.entries) {
        final val = double.tryParse(sizeEntry.value.text);
        if (val != null && val > 0) {
          sizeMap[sizeEntry.key] = val;
        }
      }
      if (sizeMap.isNotEmpty) usage[ingName] = sizeMap;
    }

    // 3. Create/Update Model
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

    // 4. Save & Sync
    await _productBox.put(id, product);
    SupabaseSyncService.addToQueue(
      table: 'products', 
      action: 'UPSERT', 
      data: product.toJson() // Ensure toJson handles JSONB maps correctly
    );

    if (mounted) {
      DialogUtils.showToast(context, "Product saved successfully!");
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = _productBox.values.map((p) => p.category).toSet().toList();
    final subCategories = _productBox.values.map((p) => p.subCategory).toSet().toList();

    return DialogBoxTitled(
      title: widget.product == null ? "Create Product" : "Edit Product",
      width: 800, // Wider for matrix
      actions: [
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
      ],
      child: SizedBox(
        height: 600,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(right: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── SECTION 1: BASIC INFO ───
                ContainerCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                       BasicInputField(label: "Product Name", controller: _nameCtrl),
                       const SizedBox(height: 12),
                       Row(
                         children: [
                          const Text("Product Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                           Switch(
                             value: _isAvailable, 
                             activeColor: ThemeConfig.primaryGreen,
                             onChanged: (v) => setState(() => _isAvailable = v)
                           ),
                           const SizedBox(width: 8),
                           Text(
                             _isAvailable ? "Active (Visible)" : "Inactive (Hidden)",
                             style: TextStyle(
                               color: _isAvailable ? ThemeConfig.primaryGreen : Colors.grey,
                               fontWeight: FontWeight.bold
                             ),
                           )
                         ],
                       ),
                       const SizedBox(height: 12),
                       Row(
                         children: [
                          Expanded(
                            child: HybridDropdownField(label: "Category", controller: _categoryCtrl, options: categories),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: HybridDropdownField(label: "Sub Category", controller: _subCategoryCtrl, options: subCategories),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _pricingType,
                              decoration: const InputDecoration(labelText: "Pricing Type", border: OutlineInputBorder()),
                              items: const [
                                DropdownMenuItem(value: "size", child: Text("Size Based (oz)")),
                                DropdownMenuItem(value: "variant", child: Text("Variant Based (Slice/Piece)")),
                              ],
                              onChanged: (v) => setState(() {
                                _pricingType = v!;
                                // Warning: Should clear sizes? For UX let's keep them but user can edit
                              }),
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── SECTION 2: PRICING ───
                ContainerCard(
                  padding: const EdgeInsets.all(16),
                  child: PricingEditorWidget(
                    pricingType: _pricingType,
                    priceControllers: _priceCtrls,
                    onAddSize: _addSize,
                    onRemoveSize: _removeSize,
                  ),
                ),

                const SizedBox(height: 16),

                // ─── SECTION 3: RECIPE MATRIX ───
                ContainerCard(
                  padding: const EdgeInsets.all(16),
                  child: RecipeMatrixWidget(
                    sizes: _priceCtrls.keys.toList()..sort(),
                    usageControllers: _usageCtrls,
                    onAddIngredient: _addIngredientRow,
                    onRemoveIngredient: _removeIngredientRow,
                  ),
                ),

                const SizedBox(height: 24),

                // ─── FOOTER ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BasicButton(
                      label: "Cancel", 
                      type: AppButtonType.secondary,
                      fullWidth: false,
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    BasicButton(
                      label: "Save Product", 
                      type: AppButtonType.primary,
                      fullWidth: false,
                      onPressed: _save,
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}