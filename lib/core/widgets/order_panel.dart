// lib/core/widgets/new_order_panel.dart
import 'package:flutter/material.dart';
import 'package:coffea_suite_frontend/core/models/order_item_model.dart';
import 'package:google_fonts/google_fonts.dart';

typedef OnEditItem = void Function(OrderItem item);
typedef OnDeleteItem = void Function(OrderItem item);
typedef OnQuantityChange = void Function(OrderItem item, int newQty);

class NewOrderPanel extends StatefulWidget {
  final List<OrderItem> orderItems;
  final bool isDineIn;
  final double subtotal;
  final double vat;
  final double total;
  final ValueChanged<bool> onDineInChanged;
  final OnEditItem onEditItem;
  final OnDeleteItem onDeleteItem;
  final OnQuantityChange? onQuantityChanged;
  final VoidCallback onProceedToPayment;
  final VoidCallback? onOrderPlaced;
  final String orderType;

  const NewOrderPanel({
    Key? key,
    required this.orderItems,
    required this.isDineIn,
    required this.subtotal,
    required this.vat,
    required this.total,
    required this.onDineInChanged,
    required this.onEditItem,
    required this.onDeleteItem,
    this.onQuantityChanged,
    required this.onProceedToPayment,
    this.onOrderPlaced,
    required this.orderType,
  }) : super(key: key);

  @override
  State<NewOrderPanel> createState() => _NewOrderPanelState();
}

class _NewOrderPanelState extends State<NewOrderPanel> {
  // Simple responsive sizing based on MediaQuery
  double _w(BuildContext c) => MediaQuery.of(c).size.width;
  double _h(BuildContext c) => MediaQuery.of(c).size.height;

  void _showPaymentModal(BuildContext context) {
    // For this example, keep payment flow simple.
    String selectedPaymentMethod = 'Cash';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: _w(context) * 0.30,
                maxHeight: _h(context) * 0.80,
              ),
              child: Dialog(
                insetPadding: const EdgeInsets.all(16),
                backgroundColor: const Color(0xFFFEFAE0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF003F1A), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Order Summary',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...widget.orderItems.map((item) {
                          final name = item.product.name;
                          final qty = item.quantity;
                          final size = item.size ?? '';
                          final price = item.totalPrice;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'x$qty  $name ${size.isNotEmpty ? "($size)" : ""}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₱${price.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        const Divider(
                          height: 1,
                          color: Color(0xFF838383), // updated color
                        ),
                        const SizedBox(height: 8),
                        _buildTotalRow('Subtotal:', widget.subtotal),
                        const SizedBox(height: 4),
                        _buildTotalRow('VAT (12%):', widget.vat),
                        const SizedBox(height: 8),
                        _buildTotalRow('Total:', widget.total, isBold: true),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedPaymentMethod,
                                items: ['Cash', 'Card', 'GCash', 'PayMaya']
                                    .map(
                                      (m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    selectedPaymentMethod = v ?? 'Cash';
                                  });
                                },
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  // Here you'd process payment & create receipt
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Order placed successfully via $selectedPaymentMethod',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  widget.onOrderPlaced?.call();
                                },
                                child: const Text('Place Order'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : null,
          ),
        ),
        Text(
          '₱${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF003F1A) : Colors.white,
          border: Border.all(color: const Color(0xFF003F1A)),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panelWidth = _w(context) < 900 ? _w(context) * 0.95 : 320.0;
    final panelHeight = _h(context) * 0.78;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          width: panelWidth,
          height: panelHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF838383), width: 1),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // header
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Text(
                      'COFFEA',
                      style: GoogleFonts.poppins(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order Details #${DateTime.now().millisecondsSinceEpoch % 10000}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildToggleButton(
                            'Dine In',
                            widget.isDineIn,
                            () {
                              widget.onDineInChanged(true);
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildToggleButton(
                            'Take-out',
                            !widget.isDineIn,
                            () {
                              widget.onDineInChanged(false);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(
                height: 1,
                color: Color(0xFF838383), // updated color
              ),

              // items
              Expanded(
                child: widget.orderItems.isEmpty
                    ? Center(
                        child: Text(
                          'No items in order',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 2,
                        ),
                        itemCount: widget.orderItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = widget.orderItems[idx];
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              border: Border.all(
                                color: const Color.fromARGB(143, 238, 238, 238),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style:
                                                GoogleFonts.barlowSemiCondensed(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(
                                                    0xFF013617,
                                                  ), // dark green
                                                ),
                                          ),
                                          if ((item.size ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4.0,
                                              ),
                                              child: Text(
                                                'Size: ${item.size}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Color.fromARGB(
                                                    255,
                                                    0,
                                                    0,
                                                    0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${item.totalPrice.toStringAsFixed(2)}',
                                      style: GoogleFonts.barlowSemiCondensed(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (item.quantity > 1) {
                                          widget.onQuantityChanged?.call(
                                            item,
                                            item.quantity - 1,
                                          );
                                        }
                                      },
                                      child: _qtyCircle('-'),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        widget.onQuantityChanged?.call(
                                          item,
                                          item.quantity + 1,
                                        );
                                      },
                                      child: _qtyCircle('+'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 25,
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              widget.onEditItem(item),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: Color(0xFF013617),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          child: Text(
                                            'Edit',
                                            style: GoogleFonts.mulish(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(
                                                0xFF013617,
                                              ), // match border
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 25,
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              widget.onDeleteItem(item),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: Colors.red,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          child: Text(
                                            'Delete',
                                            style: GoogleFonts.mulish(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.red, // match border
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // footer totals and proceed button
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFF838383))),
                ),
                child: Column(
                  children: [
                    _buildTotalRow('Subtotal:', widget.subtotal),
                    const SizedBox(height: 6),
                    _buildTotalRow('VAT (12%):', widget.vat),
                    const Divider(height: 12, color: Color(0xFF838383)),
                    _buildTotalRow('Total:', widget.total, isBold: true),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: widget.orderItems.isEmpty
                            ? null
                            : () => _showPaymentModal(context),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              25,
                            ), // set edge radius to 25
                          ),
                        ),
                        child: const Text('Proceed to Payment'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyCircle(String label) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
