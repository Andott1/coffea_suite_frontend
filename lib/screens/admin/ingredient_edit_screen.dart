import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';

import '../../core/models/ingredient_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';

import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/mode_switcher_field.dart';

class IngredientEditScreen extends StatefulWidget {
  final IngredientModel? ingredient;

  const IngredientEditScreen({super.key, this.ingredient});

  @override
  State<IngredientEditScreen> createState() => _IngredientEditScreenState();
}

class _IngredientEditScreenState extends State<IngredientEditScreen> {
  final _formKey = GlobalKey<FormState>();

  // ──────────────── STATE ────────────────
  // Identity
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(); // e.g. "mL", "g"

  // Logic
  final _quantityCtrl = TextEditingController();
  final _reorderCtrl = TextEditingController();
  final _purchaseSizeCtrl = TextEditingController(text: "1");
  final _costCtrl = TextEditingController();

  late Box<IngredientModel> _ingredientBox;

  // Computed helper for "Live Preview" of cost
  double get _calculatedBaseCost {
    final cost = double.tryParse(_costCtrl.text.replaceAll(',', '')) ?? 0;
    final size = double.tryParse(_purchaseSizeCtrl.text) ?? 1;
    if (size == 0) return 0;
    return cost / size;
  }

  @override
  void initState() {
    super.initState();
    _ingredientBox = HiveService.ingredientBox;

    if (widget.ingredient != null) {
      _initEditMode();
    }
  }

  void _initEditMode() {
    final i = widget.ingredient!;
    _nameCtrl.text = i.name;
    _categoryCtrl.text = i.category;
    _unitCtrl.text = i.unit;
    
    // Convert base quantity back to display quantity for editing
    // (e.g. stored 3000 mL -> display 3.0 L if factor is 1000)
    _quantityCtrl.text = i.displayQuantity.toString();
    
    final displayReorder = i.reorderLevel / i.conversionFactor;
    _reorderCtrl.text = FormatUtils.formatQuantity(displayReorder);

    _purchaseSizeCtrl.text = FormatUtils.formatQuantity(i.purchaseSize);
    _costCtrl.text = FormatUtils.formatCurrency(i.unitCost).replaceAll('₱', '').trim();
  }

  // ──────────────── DATA HELPERS ────────────────
  List<String> get _categories {
    return _ingredientBox.values.map((i) => i.category).where((c) => c.isNotEmpty).toSet().toList()..sort();
  }

  List<String> get _units {
    return _ingredientBox.values.map((i) => i.unit).where((u) => u.isNotEmpty).toSet().toList()..sort();
  }

  // ──────────────── SAVE LOGIC ────────────────
  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final name = _nameCtrl.text.trim();
      final category = _categoryCtrl.text.trim();
      final unit = _unitCtrl.text.trim();
      
      final qtyRaw = double.tryParse(_quantityCtrl.text) ?? 0;
      final reorderRaw = double.tryParse(_reorderCtrl.text) ?? 0;
      final costRaw = double.tryParse(_costCtrl.text.replaceAll(',', '')) ?? 0;
      final sizeRaw = double.tryParse(_purchaseSizeCtrl.text) ?? 1.0;

      IngredientModel ingredient;

      if (widget.ingredient == null) {
        // CREATE NEW (Uses Factory logic for auto-conversion)
        ingredient = IngredientModel.create(
          name: name,
          category: category.isEmpty ? 'Uncategorized' : category,
          unit: unit,
          quantity: qtyRaw,
          reorderRaw: reorderRaw,
          unitCost: costRaw,
          purchaseSize: sizeRaw,
        );
      } else {
        // UPDATE EXISTING
        // Note: Changing unit might mess up stock if conversion factor changes.
        // For this implementation, we assume re-applying the factor logic.
        final i = widget.ingredient!;
        final newFactor = IngredientModel.getFactor(unit);
        
        i.name = name;
        i.category = category;
        i.unit = unit;
        i.conversionFactor = newFactor;
        i.baseUnit = (unit == 'kg' || unit == 'g') ? 'g' : ((unit == 'L' || unit == 'mL') ? 'mL' : unit);
        
        // Recalculate base values using new factor
        i.quantity = qtyRaw * newFactor;
        i.reorderLevel = reorderRaw * newFactor;
        
        i.unitCost = costRaw;
        i.purchaseSize = sizeRaw;
        i.updatedAt = DateTime.now();
        
        ingredient = i;
      }

      await _ingredientBox.put(ingredient.id, ingredient);
      
      SupabaseSyncService.addToQueue(
        table: 'ingredients', 
        action: 'UPSERT', 
        data: ingredient.toJson()
      );

      if (mounted) {
        DialogUtils.showToast(context, "Ingredient saved successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showToast(context, "Error: $e", icon: Icons.error);
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
          widget.ingredient == null ? "Create New Ingredient" : "Edit Ingredient",
          style: FontConfig.h2(context).copyWith(color: Colors.black87),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BasicButton(
              label: "Save Item",
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
                      // IMAGE PLACEHOLDER
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
                            Icon(Icons.inventory_2, size: 40, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text("Ingredient Icon", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text("Identity", style: FontConfig.caption(context)),
                      const SizedBox(height: 12),
                      
                      BasicInputField(label: "Item Name", controller: _nameCtrl),
                      const SizedBox(height: 16),
                      
                      ModeSwitcherField(
                        label: "Category",
                        controller: _categoryCtrl,
                        options: _categories,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      ModeSwitcherField(
                        label: "Unit of Measurement (e.g. mL, g, pcs)",
                        controller: _unitCtrl,
                        options: _units,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ─── RIGHT PANE (60% - Logic) ───
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. STOCK CONTROL
                    Text("Stock Control", style: FontConfig.h3(context)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: BasicInputField(
                              label: "Current Quantity", 
                              controller: _quantityCtrl, 
                              inputType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: BasicInputField(
                              label: "Low Stock Alert @", 
                              controller: _reorderCtrl, 
                              inputType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 2. COSTING
                    Text("Purchasing & Costing", style: FontConfig.h3(context)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: BasicInputField(
                                  label: "Standard Purchase Size", 
                                  controller: _purchaseSizeCtrl, 
                                  inputType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: BasicInputField(
                                  label: "Cost per Size ₱", 
                                  controller: _costCtrl, 
                                  inputType: TextInputType.number,
                                  isCurrency: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // MATH PREVIEW
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThemeConfig.primaryGreen.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ThemeConfig.primaryGreen.withValues(alpha: 0.2))
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Calculated Unit Cost:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                AnimatedBuilder(
                                  animation: Listenable.merge([_purchaseSizeCtrl, _costCtrl]),
                                  builder: (context, _) {
                                    return Text(
                                      "${FormatUtils.formatCurrency(_calculatedBaseCost)} / 1 ${_unitCtrl.text}",
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: ThemeConfig.primaryGreen, fontSize: 16),
                                    );
                                  }
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}