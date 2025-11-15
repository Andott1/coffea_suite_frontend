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
  String category; // e.g., Drinks, Meals, Desserts

  @HiveField(3)
  String subCategory; // e.g., Coffee, Non-Coffee, Ricemeal, Pastry

  /// NEW: pricing type (size-based or variant-based)
  /// - "size" → multi-size drinks (12oz, 16oz, 22oz, HOT)
  /// - "variant" → fixed price items (Regular, Piece, Single)
  @HiveField(4)
  String pricingType;

  /// Dynamic price table (key = size/variant, value = price)
  /// e.g., {'12oz': 75.0, '16oz': 115.0, 'HOT': 105.0}
  @HiveField(5)
  Map<String, double> prices;

  /// Optional map of ingredient usage per size/variant
  /// e.g. {'Coffee Beans': {'12oz': 30, '16oz': 45}}
  @HiveField(6)
  Map<String, Map<String, double>> ingredientUsage;

  @HiveField(7)
  bool available;

  @HiveField(8)
  DateTime updatedAt;

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
  });

  // ──────────────── FACTORY FROM JSON ────────────────
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Clean pricing map: ignore nulls and non-numeric values
    final Map<String, double> priceMap = {};
    final knownKeys = [
      '12oz', '16oz', '22oz', 'HOT',
      'Regular', 'Piece', 'Cup', 'Single'
    ];

    for (final key in knownKeys) {
      final value = json[key];
      if (value != null) {
        final parsed = double.tryParse(value.toString());
        if (parsed != null) priceMap[key] = parsed;
      }
    }

    return ProductModel(
      id: json['id'] ?? json['product_id'],
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      subCategory: json['subCategory'] ?? json['subcategory'] ?? '',
      pricingType: json['pricingType'] ?? json['pricing_type'] ?? 'size',
      prices: priceMap,
      ingredientUsage: (json['ingredientUsage'] as Map?)?.map(
            (k, v) => MapEntry(
              k,
              Map<String, double>.from(v as Map),
            ),
          ) ??
          {},
      available: json['available'] ?? true,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
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
    };
  }

  // ──────────────── HELPERS ────────────────
  double? getPrice(String key) => prices[key];

  bool get isDrink => category.toLowerCase() == 'drinks';
  bool get isMeal => category.toLowerCase() == 'meals';
  bool get isDessert => category.toLowerCase() == 'desserts';
}
/// <<END FILE>>
