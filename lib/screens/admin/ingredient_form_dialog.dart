import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../config/theme_config.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/dialog_box_editable.dart';
import '../../core/widgets/hybrid_dropdown_field.dart';

class IngredientFormDialog extends StatefulWidget {
  const IngredientFormDialog({super.key});

  @override
  State<IngredientFormDialog> createState() => _IngredientFormDialogState();
}

class _IngredientFormDialogState extends State<IngredientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _unitController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reorderPointController = TextEditingController(text: '0');
  final _purchaseSizeController = TextEditingController(text: '1');
  final _costController = TextEditingController();

  late Box<IngredientModel> _ingredientBox;

  @override
  void initState() {
    super.initState();
    _ingredientBox = HiveService.ingredientBox;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _reorderPointController.dispose();
    _purchaseSizeController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // 1. Create Model (Logic delegated to Model Factory)
      final ingredient = IngredientModel.create(
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty 
            ? 'Uncategorized' 
            : _categoryController.text.trim(),
        unit: _unitController.text.trim(),
        quantity: double.parse(_quantityController.text.trim()),
        reorderRaw: double.tryParse(_reorderPointController.text.trim()) ?? 0,
        unitCost: double.tryParse(_costController.text.replaceAll(',', '')) ?? 0,
        purchaseSize: double.tryParse(_purchaseSizeController.text.replaceAll(',', '')) ?? 1.0,
      );

      // 2. Save Local
      await _ingredientBox.put(ingredient.id, ingredient);

      // 3. Sync Cloud
      SupabaseSyncService.addToQueue(
        table: 'ingredients',
        action: 'UPSERT',
        data: {
          'id': ingredient.id,
          'name': ingredient.name,
          'category': ingredient.category,
          'unit': ingredient.unit,
          'quantity': ingredient.quantity,
          'reorder_level': ingredient.reorderLevel,
          'unit_cost': ingredient.unitCost,
          'purchase_size': ingredient.purchaseSize,
          'base_unit': ingredient.baseUnit,
          'conversion_factor': ingredient.conversionFactor,
          'is_custom_conversion': ingredient.isCustomConversion,
          'updated_at': ingredient.updatedAt.toIso8601String(),
        },
      );

      if (mounted) {
        DialogUtils.showToast(context, "Ingredient added successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showToast(context, "Error: $e", icon: Icons.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gather autocomplete options dynamically
    final categories = _ingredientBox.values
        .map((e) => e.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    
    final units = _ingredientBox.values
        .map((e) => e.unit)
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();

    return DialogBoxEditable(
      title: "Add New Ingredient",
      formKey: _formKey,
      onSave: _save,
      onCancel: () => Navigator.pop(context),
      width: 600,
      child: Column(
        children: [
          BasicInputField(label: "Ingredient Name", controller: _nameController),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: HybridDropdownField(
                  label: "Category",
                  controller: _categoryController,
                  options: categories,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: HybridDropdownField(
                  label: "Unit",
                  controller: _unitController,
                  options: units,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BasicInputField(
                  label: "Quantity", 
                  controller: _quantityController, 
                  inputType: TextInputType.number
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BasicInputField(
                  label: "Low Stock Alert @", 
                  controller: _reorderPointController, 
                  inputType: TextInputType.number
                )
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BasicInputField(
                  label: "Std. Purchase Size", 
                  controller: _purchaseSizeController, 
                  inputType: TextInputType.number
                )
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BasicInputField(
                  label: "Unit Cost ₱", 
                  controller: _costController, 
                  inputType: TextInputType.number, 
                  isCurrency: true
                )
              ),
            ],
          ),
        ],
      ),
    );
  }
}