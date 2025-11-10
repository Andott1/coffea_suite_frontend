import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/utils/responsive.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  // Temporary data for visualization
  final List<Map<String, dynamic>> _products = List.generate(
    12,
    (index) => {
      'name': 'Product ${index + 1}',
      'price': 100 + index * 5,
      'image': 'assets/logo/coffea.png',
    },
  );

  final List<Map<String, dynamic>> _cart = [];

  void _addToCart(Map<String, dynamic> product) {
    setState(() {
      _cart.add(product);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: ThemeConfig.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(r.wp(2)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LEFT SIDE: Product Grid
              Expanded(
                flex: 3,
                child: _ProductGrid(
                  products: _products,
                  onTap: _addToCart,
                ),
              ),

              SizedBox(width: r.wp(2)),

              // RIGHT SIDE: Order Summary
              Expanded(
                flex: 2,
                child: _OrderSummary(cart: _cart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onTap;

  const _ProductGrid({required this.products, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    // Number of columns adjusts based on screen width
    final int crossAxisCount =
        (r.screenWidth > 1500) ? 5 : (r.screenWidth > 1100) ? 4 : 3;

    return Container(
      decoration: BoxDecoration(
        color: ThemeConfig.lightGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(r.scale(10)),
      ),
      padding: EdgeInsets.all(r.wp(1.5)),
      child: GridView.builder(
        itemCount: products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: r.wp(1),
          mainAxisSpacing: r.hp(1.5),
          childAspectRatio: 0.85,
        ),
        itemBuilder: (context, index) {
          final product = products[index];
          return GestureDetector(
            onTap: () => onTap(product),
            child: Container(
              decoration: BoxDecoration(
                color: ThemeConfig.white,
                borderRadius: BorderRadius.circular(r.scale(12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: r.scale(6),
                    offset: Offset(0, r.scale(3)),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    product['image'],
                    height: r.hp(10),
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: r.hp(1)),
                  Text(
                    product['name'],
                    style: FontConfig.body(context),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: r.hp(0.5)),
                  Text(
                    "₱${product['price']}",
                    style: FontConfig.body(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final List<Map<String, dynamic>> cart;

  const _OrderSummary({required this.cart});

  double get _total =>
      cart.fold(0, (sum, item) => sum + (item['price'] as num));

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Container(
      decoration: BoxDecoration(
        color: ThemeConfig.white,
        borderRadius: BorderRadius.circular(r.scale(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: r.scale(6),
            offset: Offset(0, r.scale(2)),
          ),
        ],
      ),
      padding: EdgeInsets.all(r.wp(2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order Summary', style: FontConfig.h2(context)),
          SizedBox(height: r.hp(2)),

          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, index) {
                final item = cart[index];
                return Container(
                  margin: EdgeInsets.only(bottom: r.hp(1)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item['name'],
                          style: FontConfig.body(context),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        "₱${item['price']}",
                        style: FontConfig.body(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(thickness: 1),
          SizedBox(height: r.hp(1)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: FontConfig.h2(context),
              ),
              Text(
                "₱${_total.toStringAsFixed(2)}",
                style: FontConfig.h2(context).copyWith(
                  color: ThemeConfig.primaryGreen,
                ),
              ),
            ],
          ),

          SizedBox(height: r.hp(2)),

          SizedBox(
            width: double.infinity,
            height: r.hp(7),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeConfig.primaryGreen,
              ),
              child: Text(
                'Complete Payment',
                style: FontConfig.button(context)
                    .copyWith(fontSize: r.font(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
