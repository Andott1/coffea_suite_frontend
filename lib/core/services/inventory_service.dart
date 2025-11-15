// lib/core/services/inventory_service.dart
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../models/product_model.dart';
import '../models/ingredient_model.dart';

class InventoryService {
  final Dio dio = Dio();
  final String baseUrl = "https://financify-app-backend.onrender.com/api";

  Future<void> syncProducts() async {
    final productBox = Hive.box<ProductModel>('products');

    // Push local data
    for (final product in productBox.values) {
      await dio.post('$baseUrl/products/', data: product.toJson());
    }

    // Pull latest data
    final response = await dio.get('$baseUrl/products/');
    if (response.statusCode == 200) {
      productBox.clear();
      for (final jsonItem in response.data) {
        productBox.put(jsonItem['id'], ProductModel.fromJson(jsonItem));
      }
    }
  }

  Future<void> syncIngredients() async {
    final ingredientBox = Hive.box<IngredientModel>('ingredients');

    // Push local data
    for (final ingredient in ingredientBox.values) {
      await dio.post('$baseUrl/ingredients/', data: ingredient.toJson());
    }

    // Pull latest data
    final response = await dio.get('$baseUrl/ingredients/');
    if (response.statusCode == 200) {
      ingredientBox.clear();
      for (final jsonItem in response.data) {
        ingredientBox.put(jsonItem['id'], IngredientModel.fromJson(jsonItem));
      }
    }
  }
}
