import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/product_model.dart';
import '../../core/utils/format_utils.dart';
import '../../core/widgets/dialog_box_titled.dart';
import '../../core/widgets/basic_button.dart';
import 'bloc/pos_bloc.dart';
import 'bloc/pos_event.dart';

class ProductBuilderDialog extends StatefulWidget {
  final ProductModel product;

  const ProductBuilderDialog({super.key, required this.product});

  @override
  State<ProductBuilderDialog> createState() => _ProductBuilderDialogState();
}

class _ProductBuilderDialogState extends State<ProductBuilderDialog> {
  // State
  late String _selectedVariant;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Default to the first available price key (e.g., "12oz")
    if (widget.product.prices.isNotEmpty) {
      // Optional: Try to sort keys to make "12oz" appear before "16oz" if possible
      // For now, just taking the first one from the map
      _selectedVariant = widget.product.prices.keys.first;
    } else {
      _selectedVariant = "";
    }
  }

  double get _unitPrice => widget.product.prices[_selectedVariant] ?? 0.0;
  double get _totalPrice => _unitPrice * _quantity;

  void _addToOrder() {
    if (_selectedVariant.isEmpty) return;

    context.read<PosBloc>().add(
      PosAddToCart(
        product: widget.product,
        variant: _selectedVariant, // ✅ Clean variant name
        price: _unitPrice,
        quantity: _quantity, 
      )
    );
    
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Sort keys alphabetically (usually works for 12oz, 16oz) 
    // or custom logic can be added later.
    final sortedVariants = widget.product.prices.keys.toList()..sort();
    
    return DialogBoxTitled(
      title: widget.product.name,
      subtitle: widget.product.subCategory,
      width: 450,
      actions: [
        IconButton(
          icon: const Icon(Icons.close, color: ThemeConfig.primaryGreen),
          onPressed: () => Navigator.pop(context),
        )
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ──────────────── SIZE / VARIANT SELECTOR ────────────────
          Text("Select Size / Variant", style: FontConfig.caption(context)),
          const SizedBox(height: 10),
          
          if (sortedVariants.isEmpty)
            const Text("No prices defined.", style: TextStyle(color: Colors.red))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: sortedVariants.map((variant) {
                final isSelected = _selectedVariant == variant;
                final price = widget.product.prices[variant]!;
                
                return GestureDetector(
                  onTap: () => setState(() => _selectedVariant = variant),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? ThemeConfig.primaryGreen : Colors.white,
                      border: Border.all(
                        color: isSelected ? ThemeConfig.primaryGreen : ThemeConfig.midGray,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          variant,
                          style: TextStyle(
                            color: isSelected ? Colors.white : ThemeConfig.primaryGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          FormatUtils.formatCurrency(price), // e.g. ₱75
                          style: TextStyle(
                            color: isSelected ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // ──────────────── QUANTITY ────────────────
          Text("Quantity", style: FontConfig.caption(context)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _qtyButton(Icons.remove, () {
                if (_quantity > 1) setState(() => _quantity--);
              }),
              Container(
                width: 80,
                alignment: Alignment.center,
                child: Text(
                  "$_quantity",
                  style: const TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.bold, 
                    color: ThemeConfig.primaryGreen
                  ),
                ),
              ),
              _qtyButton(Icons.add, () {
                 setState(() => _quantity++);
              }),
            ],
          ),

          const SizedBox(height: 30),
          const Divider(),
          const SizedBox(height: 10),

          // ──────────────── TOTAL & ACTION ────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Total Price", style: TextStyle(color: Colors.grey)),
                  Text(
                    FormatUtils.formatCurrency(_totalPrice),
                    style: FontConfig.h2(context).copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: BasicButton(
                  label: "Add to Order",
                  type: AppButtonType.primary,
                  onPressed: _addToOrder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 45, height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ThemeConfig.midGray),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: IconButton(
        icon: Icon(icon, color: ThemeConfig.primaryGreen),
        onPressed: onTap,
        splashRadius: 24,
      ),
    );
  }
}
/// <<END FILE>>