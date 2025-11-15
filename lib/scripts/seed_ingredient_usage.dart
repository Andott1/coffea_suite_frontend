/// <<FILE: lib/scripts/seed_ingredients_usage.dart>>
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/models/ingredient_usage_model.dart';

/// Seeds the IngredientUsage Hive box from assets/data/ingredients_usage.json
Future<void> seedIngredientUsage() async {
  final box = Hive.box<IngredientUsageModel>('ingredient_usages');
  if (box.isNotEmpty) {
    print('ℹ️ Ingredient usage already seeded, skipping.');
    return;
  }

  try {
    final jsonString = await rootBundle.loadString('assets/data/ingredients_usage.json');
    final List<dynamic> data = jsonDecode(jsonString);
    final uuid = const Uuid();

    int count = 0;
    for (final item in data) {
      // ✅ Safely cast quantities to double
      final quantities = <String, double>{};
      (item['quantities'] as Map<String, dynamic>).forEach((key, value) {
        if (value != null) quantities[key] = (value as num).toDouble();
      });

      final usage = IngredientUsageModel(
        id: uuid.v4(),
        productId: item['productId'],
        ingredientId: item['ingredientId'],
        category: item['category'],
        subCategory: item['subCategory'],
        unit: item['unit'],
        quantities: quantities,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await box.put(usage.id, usage);
      count++;
    }

    print('✅ Ingredient usage seeded successfully ($count records).');
  } catch (e) {
    print('❌ Failed to seed ingredient usage: $e');
  }
}
/// <<END FILE>>