import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // ✅ Import BLoC
import '../../../../config/theme_config.dart';
import '../../../../core/models/cart_item_model.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/basic_button.dart';
import '../../../../core/widgets/basic_input_field.dart';
import '../../../../core/widgets/dialog_box_titled.dart';
import '../bloc/pos_bloc.dart'; // ✅ Import Bloc
import '../bloc/stock_logic.dart'; // ✅ Import Logic

class CartItemEditDialog extends StatefulWidget {
  final CartItemModel item;
  final Function(int qty, double discount, String note) onUpdate;
  final VoidCallback onRemove;

  const CartItemEditDialog({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<CartItemEditDialog> createState() => _CartItemEditDialogState();
}

class _CartItemEditDialogState extends State<CartItemEditDialog> {
  late int _quantity;
  late TextEditingController _noteCtrl;
  
  // Discount State
  late TextEditingController _discountCtrl;
  bool _showDiscountField = false;
  bool _isPercentage = false; // ✅ Toggle State

  // Stock State
  int _maxAvailable = 999;

  @override
  void initState() {
    super.initState();
    _quantity = widget.item.quantity;
    _noteCtrl = TextEditingController(text: widget.item.note);
    
    // Initialize discount
    // If it was already discounted, we show it as fixed amount by default
    _discountCtrl = TextEditingController(
      text: widget.item.discount > 0 
          ? widget.item.discount.toStringAsFixed(2) 
          : ""
    );
    _showDiscountField = widget.item.discount > 0;

    // ✅ Post-frame callback to calculate stock safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxStock();
    });
  }

  void _calculateMaxStock() {
    final currentCart = context.read<PosBloc>().state.cart;
    
    // How many *more* can we make beyond what's already in the cart?
    final additionalStock = StockLogic.calculateMaxStock(
      product: widget.item.product,
      variant: widget.item.variant,
      currentCart: currentCart,
    );

    // Total Allowed = Current Qty (already secured) + Additional Available
    setState(() {
      _maxAvailable = _quantity + additionalStock;
    });
  }

  // ✅ Helper to get the actual PHP value of the discount
  double get _calculatedDiscountAmount {
    double inputVal = double.tryParse(_discountCtrl.text.replaceAll(',', '')) ?? 0;
    
    if (_isPercentage) {
      // Calculate % of the TOTAL PRICE for this line item
      double lineTotal = widget.item.price * _quantity;
      return lineTotal * (inputVal / 100);
    }
    
    return inputVal; // Fixed amount
  }

  double get _currentTotal {
    double lineTotal = widget.item.price * _quantity;
    return lineTotal - _calculatedDiscountAmount;
  }

  void _submit() {
    // Pass the FINAL CALCULATED AMOUNT (database only stores money value)
    widget.onUpdate(_quantity, _calculatedDiscountAmount, _noteCtrl.text.trim());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we hit the ceiling
    final bool canIncrease = _quantity < _maxAvailable;

    return DialogBoxTitled(
      title: widget.item.product.name,
      subtitle: widget.item.variant.isNotEmpty ? widget.item.variant : "Standard",
      width: 450,
      actions: [
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        )
      ],
      child: Column(
        children: [
          // ─── 1. QUANTITY CONTROL (With Validation) ───
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: ThemeConfig.lightGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: canIncrease ? Colors.transparent : Colors.orange.withOpacity(0.5)
              )
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _circleBtn(Icons.remove, () {
                      if (_quantity > 1) setState(() => _quantity--);
                    }),
                    SizedBox(
                      width: 100,
                      child: Text(
                        "$_quantity",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32, 
                          fontWeight: FontWeight.bold, 
                          color: canIncrease ? ThemeConfig.primaryGreen : Colors.orange
                        ),
                      ),
                    ),
                    // ✅ Disable if max reached
                    _circleBtn(
                      Icons.add, 
                      canIncrease ? () => setState(() => _quantity++) : null
                    ),
                  ],
                ),
                if (!canIncrease)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Max stock available reached",
                      style: TextStyle(color: Colors.orange[800], fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  )
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ─── 2. NOTES ───
          BasicInputField(
            label: "Notes (Optional)",
            controller: _noteCtrl,
            onChanged: (_) {},
          ),
          
          const SizedBox(height: 12),

          // ─── 3. DISCOUNT (Toggleable) ───
          if (_showDiscountField)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isPercentage = !_isPercentage;
                      _discountCtrl.clear(); // Clear to avoid confusion
                    });
                  },
                  child: Container(
                    height: 56, // Match input height
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: ThemeConfig.primaryGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _isPercentage ? "%" : "₱",
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 24
                      ),
                    ),
                  ),
                ),
                
                // Input Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BasicInputField(
                        label: _isPercentage ? "Percentage Off" : "Amount Off",
                        controller: _discountCtrl,
                        inputType: TextInputType.number,
                        isCurrency: !_isPercentage, // Only show ₱ if not %
                        onChanged: (_) => setState(() {}), // Refresh total preview
                      ),
                      
                      // ✅ HELPER TEXT: Shows the calculated money value if using %
                      if (_isPercentage && _discountCtrl.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 4),
                          child: Text(
                            "Reduces total by ${FormatUtils.formatCurrency(_calculatedDiscountAmount)}",
                            style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            )
          else
            TextButton.icon(
              icon: const Icon(Icons.local_offer_outlined, size: 18),
              label: const Text("Add Discount"),
              onPressed: () => setState(() => _showDiscountField = true),
            ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ─── 4. TOTAL PREVIEW ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total:", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
              Text(
                FormatUtils.formatCurrency(_currentTotal),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ThemeConfig.primaryGreen),
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          // ─── 5. ACTIONS ───
          Row(
            children: [
              Expanded(
                child: BasicButton(
                  label: "Remove",
                  type: AppButtonType.danger,
                  icon: Icons.delete_outline,
                  onPressed: () {
                    widget.onRemove();
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BasicButton(
                  label: "Update",
                  type: AppButtonType.primary,
                  icon: Icons.check,
                  onPressed: _submit,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback? onTap) {
    final isDisabled = onTap == null;
    return Container(
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey[100] : Colors.white,
        shape: BoxShape.circle, 
        border: Border.all(color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade400)
      ),
      child: IconButton(
        icon: Icon(icon), 
        onPressed: onTap, 
        color: isDisabled ? Colors.grey : ThemeConfig.primaryGreen
      ),
    );
  }
}