/// <<FILE: lib/screens/inventory/stock_adjustment_dialog.dart>>
import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/numeric_pad.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/services/inventory_log_service.dart';

class StockAdjustmentDialog extends StatefulWidget {
  final IngredientModel ingredient;

  const StockAdjustmentDialog({super.key, required this.ingredient});

  @override
  State<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<StockAdjustmentDialog> {
  String _inputStr = "";
  
  // ✅ NEW: Toggle State
  // false = Use Main Unit (L), true = Use Base Unit (mL)
  bool _useBaseUnit = false; 

  // ──────────────── LOGIC ────────────────
  void _onKeypadInput(String value) {
    setState(() {
      if (value == "." && _inputStr.contains(".")) return;
      if (_inputStr.length > 8) return; 
      _inputStr += value;
    });
  }

  void _clear() {
    setState(() => _inputStr = "");
  }

  void _backspace() {
    if (_inputStr.isNotEmpty) {
      setState(() => _inputStr = _inputStr.substring(0, _inputStr.length - 1));
    }
  }

  void _addPreset(double multiplier) {
    setState(() {
      // Logic: Multiplier x Purchase Size
      // Presets ALWAYS refer to the Purchase Size (Bottles/Packs), 
      // regardless of the toggle. It's physical counting.
      double amountToAdd = multiplier * widget.ingredient.purchaseSize;
      
      // However, if we are in Base Unit mode, we need to display it as mL
      if (_useBaseUnit) {
         amountToAdd = amountToAdd * widget.ingredient.conversionFactor;
      }

      // Add to current input
      double current = double.tryParse(_inputStr) ?? 0;
      current += amountToAdd;
      
      if (current % 1 == 0) {
        _inputStr = current.toInt().toString();
      } else {
        _inputStr = current.toStringAsFixed(2);
      }
    });
  }

  // ──────────────── MATH HELPERS ────────────────
  
  /// Converts the user input string into the Database Value (Base Unit)
  double _calculateFinalQuantity() {
    double rawInput = double.tryParse(_inputStr) ?? 0;
    
    if (_useBaseUnit) {
      // User typed in mL. No conversion needed.
      return rawInput;
    } else {
      // User typed in L. Convert L -> mL.
      return rawInput * widget.ingredient.conversionFactor;
    }
  }

  // ──────────────── ACTIONS ────────────────
  
  void _processRestock() async {
    final qtyToAdd = _calculateFinalQuantity();
    if (qtyToAdd <= 0) return;

    // Update Hive (quantity is always stored in Base Units)
    widget.ingredient.quantity += qtyToAdd;
    widget.ingredient.updatedAt = DateTime.now();
    await widget.ingredient.save();

    SupabaseSyncService.addToQueue(
      table: 'ingredients',
      action: 'UPSERT',
      data: {
        'id': widget.ingredient.id,
        'name': widget.ingredient.name,
        'category': widget.ingredient.category,
        'unit': widget.ingredient.unit,
        'quantity': widget.ingredient.quantity,

        // ✅ MANUAL MAPPING TO SNAKE_CASE
        'reorder_level': widget.ingredient.reorderLevel,
        'unit_cost': widget.ingredient.unitCost,
        'purchase_size': widget.ingredient.purchaseSize,
        'base_unit': widget.ingredient.baseUnit,
        'conversion_factor': widget.ingredient.conversionFactor,
        'is_custom_conversion': widget.ingredient.isCustomConversion,
        'updated_at': widget.ingredient.updatedAt.toIso8601String(),
      },
    );

    // 2. ✅ Log Transaction
    await InventoryLogService.log(
      ingredientName: widget.ingredient.name,
      action: "Restock",
      quantity: qtyToAdd, // Positive
      unit: widget.ingredient.baseUnit, // Always log in base unit for consistency
      reason: "Manual Add",
    );

    if (mounted) {
      DialogUtils.showToast(context, "Stock updated successfully");
      Navigator.pop(context);
    }
  }

  void _initiateReduce() async {
    final qtyToReduce = _calculateFinalQuantity();
    if (qtyToReduce <= 0) return;

    // 1. Ask for Reason
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Select Reason for Waste/Loss"),
        children: [
          _reasonOption(ctx, "Spoilage / Expired"),
          _reasonOption(ctx, "Spilled / Waste"),
          _reasonOption(ctx, "Inventory Correction"), // This triggers "Correction" action
          _reasonOption(ctx, "Theft / Lost"),
        ],
      )
    );

    if (reason == null) return; 

    // 2. Process Reduction
    if (widget.ingredient.quantity < qtyToReduce) {
       if(mounted) DialogUtils.showToast(context, "Cannot reduce below zero!", icon: Icons.warning, accentColor: Colors.orange);
       return;
    }

    widget.ingredient.quantity -= qtyToReduce;
    widget.ingredient.updatedAt = DateTime.now();
    await widget.ingredient.save();

    // ✅ FIX: Determine Action Category dynamically
    // If the reason is a count correction, label it "Correction".
    // Otherwise (Spoilage, Theft, Spills), label it "Waste".
    String actionCategory = "Waste";
    if (reason.contains("Correction")) {
      actionCategory = "Correction";
    }

    // 3. Log Transaction
    await InventoryLogService.log(
      ingredientName: widget.ingredient.name,
      action: actionCategory, // ✅ Dynamic Action
      quantity: -qtyToReduce, // Negative
      unit: widget.ingredient.baseUnit, // Always base unit for logs
      reason: reason,
    );

    if (mounted) {
      DialogUtils.showToast(context, "Reduced stock ($reason)", accentColor: Colors.redAccent);
      Navigator.pop(context);
    }
  }

  Widget _reasonOption(BuildContext ctx, String text) {
    return SimpleDialogOption(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      onPressed: () => Navigator.pop(ctx, text),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  // ──────────────── UI ────────────────
  @override
  Widget build(BuildContext context) {
    final hasInput = _inputStr.isNotEmpty && (double.tryParse(_inputStr) ?? 0) > 0;
    
    // If unit and baseUnit are same (e.g. "pcs"), don't show toggle
    final bool showToggle = widget.ingredient.unit != widget.ingredient.baseUnit;

    return DialogBoxTitled(
      title: "Adjust Stock: ${widget.ingredient.name}",
      width: 750,
      actions: [
        IconButton(
          icon: const Icon(Icons.close, color: ThemeConfig.primaryGreen),
          onPressed: () => Navigator.pop(context),
        )
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── SPLIT VIEW ───
          SizedBox(
            height: 320, 
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // LEFT: INFO
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Stock
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeConfig.lightGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Current:", style: FontConfig.body(context)),
                            // Always show current in logical display format
                            Text(
                              "${FormatUtils.formatQuantity(widget.ingredient.displayQuantity)} ${widget.ingredient.unit}",
                              style: FontConfig.h3(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // ──────────────── TOGGLE ROW ────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("ENTER QUANTITY", style: FontConfig.caption(context)),
                          
                          if (showToggle)
                            Container(
                              height: 30,
                              decoration: BoxDecoration(
                                color: ThemeConfig.lightGray,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: ThemeConfig.midGray)
                              ),
                              child: Row(
                                children: [
                                  _buildToggleOption(widget.ingredient.unit, false), // e.g. "L"
                                  _buildToggleOption(widget.ingredient.baseUnit, true), // e.g. "mL"
                                ],
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // ──────────────── DISPLAY ────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        alignment: Alignment.centerRight,
                        decoration: BoxDecoration(
                          border: Border.all(color: ThemeConfig.primaryGreen, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                             Text(
                              _inputStr.isEmpty ? "0" : _inputStr,
                              style: const TextStyle(
                                fontSize: 36, 
                                fontWeight: FontWeight.bold, 
                                color: ThemeConfig.primaryGreen
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Dynamic Suffix
                            Text(
                              _useBaseUnit ? widget.ingredient.baseUnit : widget.ingredient.unit,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: ThemeConfig.secondaryGreen
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      Text("Quick Add (x Purchase Size):", style: FontConfig.caption(context)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [1, 2, 5, 10].map((val) {
                           bool isBulk = widget.ingredient.purchaseSize > 1;
                           String label = "+$val${isBulk ? 'x' : ''}"; 
                          return ActionChip(
                            label: Text(label),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: ThemeConfig.midGray),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onPressed: () => _addPreset(val.toDouble()),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                const VerticalDivider(width: 1),
                const SizedBox(width: 20),
                // RIGHT: KEYPAD
                Expanded(
                  flex: 4,
                  child: NumericPad(
                    onInput: _onKeypadInput,
                    onClear: _clear,
                    onBackspace: _backspace,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),

          // ─── ACTION BUTTONS ───
          Row(
            children: [
              Expanded(
                child: BasicButton(
                  label: "WASTE / REDUCE (-)",
                  type: AppButtonType.danger,
                  onPressed: hasInput ? _initiateReduce : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BasicButton(
                  label: "ADD STOCK (+)",
                  type: AppButtonType.primary,
                  onPressed: hasInput ? _processRestock : null,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, bool isBase) {
    final isSelected = _useBaseUnit == isBase;
    return GestureDetector(
      onTap: () {
        setState(() {
          _useBaseUnit = isBase;
          _inputStr = ""; // Clear input on switch to avoid math confusion
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? ThemeConfig.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : ThemeConfig.midGray,
            fontWeight: FontWeight.w600,
            fontSize: 13
          ),
        ),
      ),
    );
  }
}
/// <<END FILE>>