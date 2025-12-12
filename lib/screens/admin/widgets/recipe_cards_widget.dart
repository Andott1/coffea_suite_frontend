import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../config/font_config.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/widgets/basic_dropdown_button.dart';
import '../../../core/widgets/basic_button.dart';

class RecipeCardsWidget extends StatefulWidget {
  final List<String> sizes; // The Variants (e.g., 12oz, 16oz)
  final Map<String, Map<String, TextEditingController>> usageControllers; // Ingredient -> { Size -> Qty }
  final Function(String) onAddIngredient;
  final Function(String) onRemoveIngredient;

  const RecipeCardsWidget({
    super.key,
    required this.sizes,
    required this.usageControllers,
    required this.onAddIngredient,
    required this.onRemoveIngredient,
  });

  @override
  State<RecipeCardsWidget> createState() => _RecipeCardsWidgetState();
}

class _RecipeCardsWidgetState extends State<RecipeCardsWidget> {
  
  // Reuse the same dialog logic, it works well
  void _showAddDialog() async {
    final ingredientBox = HiveService.ingredientBox;
    final allIngredients = ingredientBox.values
        .map((i) => i.name)
        .where((name) => !widget.usageControllers.containsKey(name))
        .toSet()
        .toList()
      ..sort();

    String? selectedIngredient;

    if (allIngredients.isEmpty) {
      await showDialog(
        context: context, 
        builder: (ctx) => AlertDialog(
          title: const Text("No Ingredients Available"),
          content: const Text("All existing ingredients are already in this recipe."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
          ],
        )
      );
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Add Ingredient"),
            content: SizedBox(
              width: 350,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BasicDropdownButton<String>(
                    value: selectedIngredient,
                    items: allIngredients,
                    width: double.infinity,
                    onChanged: (val) => setDialogState(() => selectedIngredient = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: ThemeConfig.primaryGreen),
                onPressed: selectedIngredient == null 
                    ? null 
                    : () => Navigator.pop(ctx, selectedIngredient), 
                child: const Text("Add", style: TextStyle(color: Colors.white))
              ),
            ],
          );
        }
      )
    );

    if (selected != null && selected.isNotEmpty) {
      widget.onAddIngredient(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sizes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange.shade200),
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12)
        ),
        child: Column(
          children: [
            Icon(Icons.warning_amber_rounded, size: 40, color: Colors.orange.shade400),
            const SizedBox(height: 10),
            const Text(
              "No Pricing Defined",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 4),
            const Text(
              "Go to the 'Pricing' tab and add sizes (e.g. 12oz) first.",
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── HEADER ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Ingredients Used", style: FontConfig.h3(context)),
                const SizedBox(height: 4),
                Text(
                  "Define how much of each ingredient is used per variant.", 
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)
                ),
              ],
            ),
            BasicButton(
              label: "Add Ingredient",
              icon: Icons.add,
              type: AppButtonType.secondary,
              fullWidth: false,
              height: 40,
              onPressed: _showAddDialog,
            ),
          ],
        ),
        
        const SizedBox(height: 20),

        // ─── CARDS LIST ───
        if (widget.usageControllers.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50
            ),
            child: const Text("No ingredients added yet.", style: TextStyle(color: Colors.grey)),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.usageControllers.length,
            separatorBuilder: (_,__) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final ingredientName = widget.usageControllers.keys.elementAt(index);
              final sizeMap = widget.usageControllers[ingredientName]!;

              // Lookup Unit for display
              String unit = "units";
              try {
                final ing = HiveService.ingredientBox.values.firstWhere((i) => i.name == ingredientName);
                unit = ing.baseUnit;
              } catch (_) {}

              return _buildIngredientCard(ingredientName, unit, sizeMap);
            },
          ),
      ],
    );
  }

  Widget _buildIngredientCard(String name, String unit, Map<String, TextEditingController> sizeMap) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5, offset: const Offset(0, 2))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CARD HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: ThemeConfig.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.science, size: 20, color: ThemeConfig.primaryGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "$name ($unit)", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                tooltip: "Remove Ingredient",
                onPressed: () => widget.onRemoveIngredient(name),
              ),
            ],
          ),
          
          const Divider(height: 24),

          // INPUTS WRAP
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: widget.sizes.map((size) {
              final ctrl = sizeMap[size];
              
              return SizedBox(
                width: 100, // Compact fixed width for neat alignment
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(size, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: ThemeConfig.secondaryGreen)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 1.5)),
                        hintText: "0",
                        fillColor: Colors.grey.shade50,
                        filled: true,
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
  }
}