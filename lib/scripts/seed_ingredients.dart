import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import '../core/models/ingredient_model.dart';
import '../core/services/logger_service.dart';

/// Seeds the Ingredient Hive box from assets/data/ingredients_list.json
Future<void> seedIngredients() async {
  final box = Hive.box<IngredientModel>('ingredients');
  if (box.isNotEmpty) {
    LoggerService.info('ℹ️ Ingredients already seeded, skipping.');
    return;
  }

  try {
    final jsonString = await rootBundle.loadString('assets/data/ingredients_list.json');
    final List<dynamic> data = jsonDecode(jsonString);

    int count = 0;
    for (final item in data) {
      final ingredient = IngredientModel(
        id: item['id'],
        name: item['name'],
        category: item['category'],
        unit: item['unit'],
        quantity: (item['quantity'] ?? 0).toDouble() *
            ((item['conversionFactor'] ?? 1).toDouble()),
        reorderLevel: 0,
        updatedAt: DateTime.now(),
        baseUnit: item['baseUnit'],
        conversionFactor: (item['conversionFactor'] ?? 1).toDouble(),
      );
      await box.put(ingredient.id, ingredient);
      count++;
    }

    LoggerService.info('✅ Ingredients seeded successfully ($count records).');
  } catch (e) {
    LoggerService.error('❌ Failed to seed ingredients: $e');
  }
}
