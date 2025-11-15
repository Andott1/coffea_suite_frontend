// lib/screens/cashier_screen.dart
import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../core/utils/responsive.dart';
import '../../core/models/product_model.dart';
import '../../core/widgets/item_grid_view.dart';
import '../../core/utils/product_loader.dart';
import '../../core/widgets/order_panel.dart';
import '../../core/widgets/customization_dialog.dart';
import '../../core/models/order_item_model.dart';
import '../../core/widgets/item_card.dart';
import 'package:google_fonts/google_fonts.dart';


class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  List<ProductModel> _products = [];
  bool _loading = true;

  String? _selectedCategory;
  String? _selectedSubCategory;

  final List<OrderItem> _cart = [];
  bool _isDineIn = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = 'Drinks';
    _selectedSubCategory = 'Coffee';
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final loaded = await ProductLoader.loadProducts();
    setState(() {
      _products = loaded;
      _loading = false;
    });
  }

  // categories like before (you can keep your original categories)
  final Map<String, Map<String, dynamic>> categories = {
    'Drinks': {
      'sub': ['Coffee', 'Non-Coffee', 'Carbonated', 'Frappe'],
    },
    'Meals': {
      'sub': ['Rice Meals', 'Snacks'],
    },
    'Desserts': {
      'sub': ['Desserts'],
    },
  };

  void onProductTapped(ProductModel p) async {
    final result = await showDialog<OrderItem>(
      context: context,
      builder: (ctx) => ProductCustomizationDialog(product: p),
    );

    if (result != null) {
      setState(() {
        // If same product+size exists, increment the qty instead of adding duplicate
        final sameIndex = _cart.indexWhere(
          (it) =>
              it.product.name == result.product.name &&
              (it.size ?? '') == (result.size ?? '') &&
              (it.isIced ?? false) == (result.isIced ?? false),
        );
        if (sameIndex >= 0) {
          _cart[sameIndex].quantity += result.quantity;
        } else {
          _cart.add(result);
        }
      });
    }
  }

  void _editItem(OrderItem item) async {
    // open dialog again pre-filled
    final result = await showDialog<OrderItem>(
      context: context,
      builder: (ctx) => ProductCustomizationDialog(
        product: item.product,
        initialQuantity: item.quantity,
        initialSize: item.size,
        initialIsIced: item.isIced,
      ),
    );

    if (result != null) {
      setState(() {
        final idx = _cart.indexWhere((it) => it.id == item.id);
        if (idx >= 0) _cart[idx] = result;
      });
    }
  }

  void _deleteItem(OrderItem item) {
    setState(() {
      _cart.removeWhere((it) => it.id == item.id);
    });
  }

  void _changeQty(OrderItem item, int newQty) {
    setState(() {
      final idx = _cart.indexWhere((it) => it.id == item.id);
      if (idx >= 0) {
        _cart[idx].quantity = newQty;
        if (_cart[idx].quantity <= 0) _cart.removeAt(idx);
      }
    });
  }

  double get _subtotal => _cart.fold(0.0, (s, i) => s + i.totalPrice);
  double get _vat => _subtotal * 0.12;
  double get _total => _subtotal + _vat;

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    final filteredProducts = _products.where((p) {
      if (_selectedCategory == null) return true;
      if (_selectedCategory != p.category) return false;
      if (_selectedSubCategory == null) return true;
      return _selectedSubCategory == p.subCategory;
    }).toList();

    return Scaffold(
      backgroundColor: ThemeConfig.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(r.wp(2)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT PANEL (product grid)
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    // category tabs
                    Container(
                      height: 100,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: Colors.white,
                      child: Row(
                        children: categories.keys.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat;
                                  _selectedSubCategory =
                                      categories[cat]!['sub']?.first as String?;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  gradient: isSelected
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF000000),
                                            Color(0xFF00401B),
                                          ],
                                        )
                                      : const LinearGradient(
                                          colors: [
                                            Color(0xFF3D1C00),
                                            Color(0xFF9C5921),
                                          ],
                                        ),
                                ),
                                child: Center(
                                  child: Text(
                                    cat,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  
                  //Subcategory-button
                    if (_selectedCategory != null)
                      SizedBox(
                        height: 40, // enough for the buttons
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children:
                              (categories[_selectedCategory]!['sub']
                                      as List<String>)
                                  .map((subName) {
                                    final isSelected =
                                        _selectedSubCategory == subName;

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedSubCategory = subName;
                                          });
                                        },
                                        child: Container(
                                          width: 149, // fixed width
                                          height: 40, // fixed height
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? null
                                                : const Color(
                                                    0xFFF0F0F0,
                                                  ), // grey when not selected
                                            gradient: isSelected
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF000000),
                                                      Color(0xFF00401B),
                                                    ],
                                                  )
                                                : null,
                                            border: Border.all(
                                              color: const Color(
                                                0xFF013617,
                                              ), // dark green border
                                              width: 1.0,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              25,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              subName,
                                              style: GoogleFonts.mulish(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  })
                                  .toList(),
                        ),
                      ),

                    // product grid
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 20),
                        color: Colors.white,
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : ItemGridView<ProductModel>(
                                items: filteredProducts,
                                itemBuilder: (context, product) {
                                  return ItemCard(
                                    product: product,
                                    onTap: () async {
                                      // Show the customization dialog
                                      final orderItem =
                                          await showDialog<OrderItem>(
                                            context: context,
                                            builder: (context) =>
                                                ProductCustomizationDialog(
                                                  product: product,
                                                ),
                                          );

                                      // If user pressed "Add to Order", add to the order panel
                                      if (orderItem != null) {
                                        setState(() {
                                          // Add to _cart, not orderPanelItems
                                          // If same product+size exists, increment the quantity
                                          final sameIndex = _cart.indexWhere(
                                            (it) =>
                                                it.product.name ==
                                                    orderItem.product.name &&
                                                (it.size ?? '') ==
                                                    (orderItem.size ?? '') &&
                                                (it.isIced ?? false) ==
                                                    (orderItem.isIced ?? false),
                                          );
                                          if (sameIndex >= 0) {
                                            _cart[sameIndex].quantity +=
                                                orderItem.quantity;
                                          } else {
                                            _cart.add(orderItem);
                                          }
                                        });
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(width: r.wp(2)),

              // RIGHT PANEL: new order panel
              Expanded(
                flex: 1,
                child: NewOrderPanel(
                  orderItems: _cart,
                  isDineIn: _isDineIn,
                  subtotal: _subtotal,
                  vat: _vat,
                  total: _total,
                  onDineInChanged: (val) => setState(() => _isDineIn = val),
                  onEditItem: (item) => _editItem(item),
                  onDeleteItem: (item) => _deleteItem(item),
                  onQuantityChanged: (item, newQty) => _changeQty(item, newQty),
                  onProceedToPayment: () {
                    // optional extra action
                  },
                  onOrderPlaced: () {
                    setState(() {
                      _cart.clear();
                    });
                  },
                  orderType: _isDineIn ? 'Dine In' : 'Take-out',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
