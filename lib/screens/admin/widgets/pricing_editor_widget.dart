import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/basic_button.dart';
import '../../../core/widgets/basic_input_field.dart';
import '../../../core/widgets/searchable_picker_dialog.dart';

class PricingEditorWidget extends StatefulWidget {
  final String pricingType; // "size" or "variant"
  final Map<String, TextEditingController> priceControllers;
  final Function(String) onAddSize;
  final Function(String) onRemoveSize;
  final List<String> existingVariants;
  
  // ✅ NEW: Import Feature Props
  final List<String> importSuggestions; // ["12oz, 16oz", "Single, Box"]
  final List<String> importOptions;     // ["Latte", "Cappuccino"]
  final Function(String) onImport;      // Callback when user picks one

  const PricingEditorWidget({
    super.key,
    required this.pricingType,
    required this.priceControllers,
    required this.onAddSize,
    required this.onRemoveSize,
    required this.existingVariants,
    required this.importSuggestions, // ✅ Required
    required this.importOptions,     // ✅ Required
    required this.onImport,          // ✅ Required
  });

  @override
  State<PricingEditorWidget> createState() => _PricingEditorWidgetState();
}

class _PricingEditorWidgetState extends State<PricingEditorWidget> {
  
  void _showAddDialog() async {
    final List<String> suggestions = widget.pricingType == "size"
        ? ["12oz", "16oz", "22oz", "Hot", "Iced"] 
        : ["Regular", "Large", "Single", "Box", "Slice"];

    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => SearchablePickerDialog(
        title: "Add ${widget.pricingType == 'size' ? 'Sizes' : 'Variants'}",
        items: widget.existingVariants,
        suggestions: suggestions,
        multiSelect: true,
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      for (final item in selected) {
        widget.onAddSize(item);
      }
    }
  }

  // ✅ NEW: Import Dialog Logic
  void _showImportDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SearchablePickerDialog(
        title: "Import Prices from...",
        items: widget.importOptions,       // Product Names
        suggestions: widget.importSuggestions, // Common Structures
        multiSelect: false,
      ),
    );

    if (selected != null && selected.isNotEmpty) {
      widget.onImport(selected);
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen),
            ),
            
            // ✅ ACTION BUTTONS ROW
            Row(
              children: [
                // Import Button
                TextButton.icon(
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: const Text("Import/Preset"),
                  onPressed: _showImportDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(width: 8),
                // Add Button
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Add"),
                  onPressed: _showAddDialog,
                  style: TextButton.styleFrom(
                    foregroundColor: ThemeConfig.primaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
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
            child: const Text("No variants defined. Click 'Add' or 'Import' to start.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
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
                    // VARIANT NAME
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: ThemeConfig.primaryGreen.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ThemeConfig.primaryGreen.withValues(alpha: 0.2))
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