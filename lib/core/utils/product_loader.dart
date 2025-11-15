/// <<FILE: lib/core/utils/product_loader.dart>>
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/product_model.dart';

class ProductLoader {
  /// Load product list from JSON asset
  static Future<List<ProductModel>> loadProducts() async {
    final jsonString =
        await rootBundle.loadString('assets/data/products_list.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}