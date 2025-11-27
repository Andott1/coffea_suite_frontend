import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../../config/theme_config.dart';
import '../../../core/models/ingredient_model.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/widgets/basic_button.dart';
import '../../../core/widgets/hybrid_dropdown_field.dart';

class RecipeMatrixWidget extends StatefulWidget {
  final List<String> sizes; // Columns
  final Map<String, Map<String, TextEditingController>> usageControllers; // Rows -> Cells
  final Function(String) onAddIngredient;
  final Function(String) onRemoveIngredient;

  const RecipeMatrixWidget({
    super.key,
    required this.sizes,
    required this.usageControllers,
    required this.onAddIngredient,
    required this.onRemoveIngredient,
  });

  @override
  State<RecipeMatrixWidget> createState() => _RecipeMatrixWidgetState();
}

class _RecipeMatrixWidgetState extends State<RecipeMatrixWidget> {
  
  void _showAddDialog() async {
    final ingredientBox = HiveService.ingredientBox;
    final allIngredients = ingredientBox.values.map((i) => i.name).toSet().toList();
    final controller = TextEditingController();

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Ingredient Row"),
        content: SizedBox(
          width: 300,
          child: HybridDropdownField(
            label: "Search Ingredient",
            controller: controller,
            options: allIngredients,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()), 
            child: const Text("Add")
          ),
        ],
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
        padding: const EdgeInsets.all(20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.orange.shade200),
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8)
        ),
        child: const Text("⚠️ Please add at least one Size/Variant above to configure the recipe.", style: TextStyle(color: Colors.orange)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Recipe Matrix",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen),
            ),
            TextButton.icon(
              icon: const Icon(Icons.playlist_add, size: 18),
              label: const Text("Add Ingredient"),
              onPressed: _showAddDialog,
            ),
          ],
        ),
        
        const SizedBox(height: 8),

        // SCROLLABLE TABLE
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.grey.shade300),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(ThemeConfig.lightGray),
              columnSpacing: 20,
              border: TableBorder.all(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(8)),
              columns: [
                const DataColumn(label: Text("INGREDIENT", style: TextStyle(fontWeight: FontWeight.bold))),
                ...widget.sizes.map((s) => DataColumn(label: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.secondaryGreen)))),
                const DataColumn(label: Text("")), // Action col
              ],
              rows: widget.usageControllers.entries.map((entry) {
                final ingredientName = entry.key;
                final sizeCtrls = entry.value;

                // Try to find unit
                String unit = "";
                try {
                  final ing = HiveService.ingredientBox.values.firstWhere((i) => i.name == ingredientName);
                  unit = "(${ing.baseUnit})";
                } catch (_) {}

                return DataRow(
                  cells: [
                    // Ingredient Name
                    DataCell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ingredientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      )
                    ),
                    // Inputs for each size
                    ...widget.sizes.map((size) {
                      return DataCell(
                        Container(
                          width: 60,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: TextField(
                            controller: sizeCtrls[size],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                      );
                    }),
                    // Delete Row
                    DataCell(
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                        onPressed: () => widget.onRemoveIngredient(ingredientName),
                      )
                    )
                  ]
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}