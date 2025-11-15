// lib/core/widgets/product_customization_dialog.dart
import 'package:flutter/material.dart';
import 'package:coffea_suite_frontend/core/models/product_model.dart';
import 'package:coffea_suite_frontend/core/models/order_item_model.dart';

class ProductCustomizationDialog extends StatefulWidget {
  final ProductModel product;
  final int initialQuantity;
  final String? initialSize;
  final bool? initialIsIced;

  const ProductCustomizationDialog({
    Key? key,
    required this.product,
    this.initialQuantity = 1,
    this.initialSize,
    this.initialIsIced,
  }) : super(key: key);

  @override
  State<ProductCustomizationDialog> createState() =>
      _ProductCustomizationDialogState();
}

class _ProductCustomizationDialogState
    extends State<ProductCustomizationDialog> {
  late bool isIced;
  late String selectedSize;
  late int quantity;

  @override
  void initState() {
    super.initState();

    final prices = widget.product.prices;

    isIced = widget.initialIsIced ?? true;
    quantity = widget.initialQuantity;

    // Handle initial size selection OR default to first cold size
    if (widget.initialSize != null && prices.containsKey(widget.initialSize)) {
      selectedSize = widget.initialSize!;
      if (selectedSize.toLowerCase() == 'hot') isIced = false;
    } else {
      final coldSizes = prices.keys
          .where((k) => k.toLowerCase() != 'hot')
          .toList();

      if (coldSizes.isNotEmpty) {
        selectedSize = coldSizes.first;
        isIced = true;
      } else if (prices.containsKey("HOT")) {
        selectedSize = "HOT";
        isIced = false;
      } else {
        selectedSize = prices.keys.first;
      }
    }
  }

  // -------------------------------
  // PRICE LOGIC (NEW SYSTEM)
  // -------------------------------
  double get selectedPrice {
    final prices = widget.product.prices;

    // If drink with size-based pricing:
    if (widget.product.pricingType == "size") {
      return prices[selectedSize] ?? prices.values.first;
    }

    // If meal/dessert: return first price
    return widget.product.prices.values.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDrink = widget.product.category.toLowerCase() == "drinks";
    final prices = widget.product.prices;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 360,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFEFAE0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start, // left-align product name
          children: [
            // Product name
            Text(
              widget.product.name,
              style: const TextStyle(
                fontFamily:
                    'BerlowSemiCondensed', // Mulish Berlow Semi-Condensed
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // ---------------------------------
            // ICED / HOT TOGGLE FOR DRINKS
            // ---------------------------------
            if (isDrink)
              Row(
                mainAxisAlignment: MainAxisAlignment.center, // center buttons
                children: [
                  Container(
                    width: 86, // fixed width
                    height: 33, // fixed height
                    alignment: Alignment.center, // center the text
                    child: _toggleButton('Iced', isIced, () {
                      setState(() {
                        isIced = true;
                        final coldSizes = prices.keys
                            .where((s) => s.toLowerCase() != 'hot')
                            .toList();
                        if (coldSizes.isNotEmpty)
                          selectedSize = coldSizes.first;
                      });
                    }),
                  ),
                  const SizedBox(width: 7),
                  if (prices.containsKey("HOT"))
                    Container(
                      width: 86, // fixed width
                      height: 33, // fixed height
                      alignment: Alignment.center, // center the text
                      child: _toggleButton('Hot', !isIced, () {
                        setState(() {
                          isIced = false;
                          selectedSize = "HOT";
                        });
                      }),
                    ),
                ],
              ),

            const SizedBox(height: 12),

            /// -------------------------------
            // SIZE BUTTONS (ONLY FOR ICED)
            // -------------------------------
            if (isDrink && isIced)
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // keeps text left-aligned
                children: [
                  // Size text (left-aligned)
                  const Text(
                    'Size',
                    style: TextStyle(
                      fontFamily: 'Mulish',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Buttons centered
                  Center(
                    child: Wrap(
                      spacing: 8,
                      children: prices.keys
                          .where((k) => k.toLowerCase() != 'hot')
                          .map((size) {
                            final selected = selectedSize == size && isIced;
                            return GestureDetector(
                              onTap: () => setState(() => selectedSize = size),
                              child: Container(
                                width: 86,
                                height: 33,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF5D2C02)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF5D2C02),
                                  ),
                                ),
                                child: Text(
                                  size,
                                  style: TextStyle(
                                    fontFamily: 'Mulish',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF5D2C02),
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // -------------------------------
            // QUANTITY
            // -------------------------------
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(
                    fontFamily: 'Mulish',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _qtyCircle(Icons.remove, () {
                      if (quantity > 1) setState(() => quantity--);
                    }),
                    const SizedBox(width: 12),
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        fontFamily: 'Mulish',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _qtyCircle(Icons.add, () {
                      setState(() => quantity++);
                    }),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // -------------------------------
            // PRICE
            // -------------------------------
            Center(
              child: Text(
                'Price: ₱${selectedPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // -------------------------------
            // BUTTONS
            // -------------------------------
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Cancel button
                SizedBox(
                  width: 130,
                  height: 30,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Mulish',
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Add to Order button
                SizedBox(
                  width: 140,
                  height: 30,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () {
                      final id =
                          'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}';

                      final orderItem = OrderItem(
                        id: id,
                        product: widget.product,
                        quantity: quantity,
                        size: isDrink ? selectedSize : null,
                        isIced: isDrink ? isIced : null,
                      );

                      Navigator.pop(context, orderItem);
                    },
                    child: const Text(
                      'Add to Order',
                      style: TextStyle(fontFamily: 'Mulish', fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggleButton(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 86, // fixed width
        height: 33, // fixed height
        alignment: Alignment.center, // center the text
        decoration: BoxDecoration(
          color: active ? const Color(0xFF004D26) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF004D26)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Mulish', // Mulish font
            fontSize: 16, // size 16
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : const Color(0xFF004D26),
          ),
        ),
      ),
    );
  }

  Widget _qtyCircle(IconData icon, VoidCallback onTap) {
    return Material(
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20)),
      ),
    );
  }
}
