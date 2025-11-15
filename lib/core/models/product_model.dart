/// <<FILE: lib/core/models/product_model.dart>>
import 'package:hive/hive.dart';
part 'product_model.g.dart';

@HiveType(typeId: 0)
class ProductModel extends HiveObject {
  // ──────────────── CORE FIELDS ────────────────
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String category;

  @HiveField(3)
  String subCategory;

  @HiveField(4)
  String pricingType;

  @HiveField(5)
  Map<String, double> prices;

  @HiveField(6)
  Map<String, Map<String, double>> ingredientUsage;

  @HiveField(7)
  bool available;

  @HiveField(8)
  DateTime updatedAt;

  /// NEW FIELD: image URL or asset path
  @HiveField(9)
  String imageUrl;

  // ──────────────── CONSTRUCTOR ────────────────
  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.subCategory,
    required this.pricingType,
    required this.prices,
    this.ingredientUsage = const {},
    this.available = true,
    required this.updatedAt,
    required this.imageUrl, // new required field
  });

  // ──────────────── FACTORY FROM JSON ────────────────
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final rawPrices = json['prices'] ?? {};
    final Map<String, double> priceMap = {};
    rawPrices.forEach((key, value) {
      final parsed = double.tryParse(value.toString());
      if (parsed != null) priceMap[key] = parsed;
    });

    return ProductModel(
      id: json['id'] ?? json['product_id'],
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      subCategory: json['subCategory'] ?? json['subcategory'] ?? '',
      pricingType: json['pricingType'] ?? json['pricing_type'] ?? 'size',
      prices: priceMap,
      ingredientUsage: {}, // optional for later
      available: json['available'] ?? true,
      updatedAt: DateTime.now(),
      imageUrl: json['imageUrl'] ?? '', // read from JSON
    );
  }

  // ──────────────── TO JSON ────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'subCategory': subCategory,
      'pricingType': pricingType,
      'prices': prices,
      'ingredientUsage': ingredientUsage,
      'available': available,
      'updatedAt': updatedAt.toIso8601String(),
      'imageUrl': imageUrl, // save image URL
    };
  }

  // ──────────────── HELPERS ────────────────
  double? getPrice(String key) => prices[key];
  bool get isDrink => category.toLowerCase() == 'drinks';
  bool get isMeal => category.toLowerCase() == 'meals';
  bool get isDessert => category.toLowerCase() == 'desserts';
}
