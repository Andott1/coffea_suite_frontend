// lib/core/models/order_item.dart
import 'package:coffea_suite_frontend/core/models/product_model.dart';

class OrderItem {
  final String id;
  final ProductModel product;
  int quantity;
  final String? size; // For drinks only
  final bool? isIced; // For iced/hot option
  final String? customization;

  OrderItem({
    required this.id,
    required this.product,
    this.quantity = 1,
    this.size,
    this.isIced,
    this.customization,
  });

  double get totalPrice {
  // If item has sizes (like drinks)
  if (product.pricingType == 'size') {
    final selectedSize = size ?? product.prices.keys.first;
    final price = product.prices[selectedSize] ?? 0.0;
    return price * quantity;
  }

  // For meals, desserts, pastries that have one price only
  if (product.pricingType == 'variant' || product.prices.length == 1) {
    final fixedPrice = product.prices.values.first;
    return fixedPrice * quantity;
  }

  // Fallback
  return 0.0;
}

}
