import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../core/utils/format_utils.dart';
import '../../../core/widgets/basic_button.dart';
import '../../../core/widgets/basic_input_field.dart';
import '../../../core/widgets/dialog_box_titled.dart';

class PricingEditorWidget extends StatefulWidget {
  final String pricingType; // "size" or "variant"
  final Map<String, TextEditingController> priceControllers;
  final Function(String) onAddSize;
  final Function(String) onRemoveSize;

  const PricingEditorWidget({
    super.key,
    required this.pricingType,
    required this.priceControllers,
    required this.onAddSize,
    required this.onRemoveSize,
  });

  @override
  State<PricingEditorWidget> createState() => _PricingEditorWidgetState();
}

class _PricingEditorWidgetState extends State<PricingEditorWidget> {
  void _showAddDialog() {
    final controller = TextEditingController();
    final label = widget.pricingType == "size" ? "Size (e.g. 12oz)" : "Variant Name";
    
    // Common presets
    final presets = widget.pricingType == "size" 
        ? ["12oz", "16oz", "22oz", "HOT"] 
        : ["Regular", "Single", "Box", "Slice"];

    showDialog(
      context: context,
      builder: (ctx) => DialogBoxTitled(
        title: "Add ${widget.pricingType == "size" ? "Size" : "Variant"}",
        width: 400,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: ThemeConfig.primaryGreen),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
        child: Column(
          children: [
            BasicInputField(label: label, controller: controller),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: presets.map((p) => ActionChip(
                label: Text(p),
                onPressed: () => controller.text = p,
              )).toList(),
            ),
            const SizedBox(height: 24),
            BasicButton(
              label: "Add", 
              type: AppButtonType.primary,
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  widget.onAddSize(controller.text.trim());
                  Navigator.pop(ctx);
                }
              }
            )
          ],
        ),
      )
    );
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
            child: const Text("No variants defined.", style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
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