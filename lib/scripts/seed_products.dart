/// <<FILE: lib/scripts/seed_products.dart>>
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import '../core/models/product_model.dart';

/// Seeds the Product Hive box from assets/data/products_list.json
Future<void> seedProducts() async {
  final box = Hive.box<ProductModel>('products');
  if (box.isNotEmpty) {
    print('ℹ️ Products already seeded, skipping.');
    return;
  }

  try {
    final jsonString = await rootBundle.loadString('assets/data/products_list.json');
    final List<dynamic> data = jsonDecode(jsonString);

    int count = 0;
    for (final item in data) {
      // ✅ Safely cast prices to double
      final prices = <String, double>{};
      (item['prices'] as Map<String, dynamic>).forEach((key, value) {
        if (value != null) prices[key] = (value as num).toDouble();
      });

      final product = ProductModel(
        id: item['id'],
        name: item['name'],
        category: item['category'],
        subCategory: item['subCategory'],
        pricingType: item['pricingType'],
        prices: prices,
        ingredientUsage: const {},
        available: true,
        updatedAt: DateTime.now(),
      );
      await box.put(product.id, product);
      count++;
    }

    print('✅ Products seeded successfully ($count records).');
  } catch (e) {
    print('❌ Failed to seed products: $e');
  }
}
/// <<END FILE>>