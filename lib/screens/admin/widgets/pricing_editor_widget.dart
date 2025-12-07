import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../core/widgets/basic_input_field.dart';
import '../../../core/widgets/searchable_picker_dialog.dart'; // ✅ Import

class PricingEditorWidget extends StatefulWidget {
  final String pricingType; // "size" or "variant"
  final Map<String, TextEditingController> priceControllers;
  final Function(String) onAddSize;
  final Function(String) onRemoveSize;
  final List<String> existingVariants; // ✅ NEW: Dynamic Data

  const PricingEditorWidget({
    super.key,
    required this.pricingType,
    required this.priceControllers,
    required this.onAddSize,
    required this.onRemoveSize,
    required this.existingVariants, // ✅ Required
  });

  @override
  State<PricingEditorWidget> createState() => _PricingEditorWidgetState();
}

class _PricingEditorWidgetState extends State<PricingEditorWidget> {
  
  void _showAddDialog() async {
    // 1. Determine Suggestions
    // In a real app, you might sort these by usage frequency.
    // For now, we take the top 5 distinct items from the existing list that fit the type.
    final List<String> suggestions = widget.pricingType == "size"
        ? ["12oz", "16oz", "22oz", "Hot"]
        : ["Piece", "Regular", "Slice"];

    // Merge with DB suggestions if available
    final dbSuggestions = widget.existingVariants.take(5).toList();
    if (dbSuggestions.isNotEmpty) {
      // Simple logic: Use DB suggestions if available, else defaults
      // In advanced logic, you'd filter DB items by "looking like a size" vs "looking like a variant"
    }

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => SearchablePickerDialog(
        title: "Add ${widget.pricingType == 'size' ? 'Sizes' : 'Variants'}",
        items: widget.existingVariants,
        suggestions: suggestions,
        multiSelect: true, // ✅ Enable Multi
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      for (final item in selected) {
        widget.onAddSize(item);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "${widget.pricingType == 'size' ? 'Sizes' : 'Variants'} & Prices",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add"),
              onPressed: _showAddDialog,
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        if (widget.priceControllers.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: ThemeConfig.midGray),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[50],
            ),
            child: const Text("No variants defined. Click 'Add' to start.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.priceControllers.length,
            itemBuilder: (context, index) {
              final key = widget.priceControllers.keys.elementAt(index);
              final ctrl = widget.priceControllers[key]!;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    // VARIANT NAME (Read-onlyish container)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: ThemeConfig.primaryGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ThemeConfig.primaryGreen.withOpacity(0.2))
                        ),
                        child: Text(key, style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // PRICE INPUT
                    Expanded(
                      flex: 3,
                      child: BasicInputField(
                        label: "Price", 
                        controller: ctrl, 
                        inputType: TextInputType.number, 
                        isCurrency: true
                      ),
                    ),
                    const SizedBox(width: 8),
                    // DELETE
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => widget.onRemoveSize(key),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}