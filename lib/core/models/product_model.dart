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
      // Support both 'id' (local) and 'product_id' (legacy/db) if needed
      id: json['id'] ?? json['product_id'], 
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      
      // ✅ MAP SNAKE_CASE (DB) -> CAMELCASE (DART)
      subCategory: json['sub_category'] ?? json['subCategory'] ?? '',
      pricingType: json['pricing_type'] ?? json['pricingType'] ?? 'size',
      
      prices: priceMap,
      
      // ✅ MAP SNAKE_CASE (DB) -> CAMELCASE (DART)
      ingredientUsage: (json['ingredient_usage'] ?? json['ingredientUsage'] as Map?)?.map(
            (k, v) => MapEntry(
              k,
              Map<String, double>.from(v as Map),
            ),
          ) ??
          {},
          
      available: json['available'] ?? true,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now()),
    );
  }

  // ──────────────── TO JSON ────────────────
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      
      // ✅ CONVERT CAMELCASE (DART) -> SNAKE_CASE (DB)
      'sub_category': subCategory,
      'pricing_type': pricingType,
      'prices': prices, // JSONB map inside is fine
      'ingredient_usage': ingredientUsage,
      'available': available,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ──────────────── HELPERS ────────────────
  double? getPrice(String key) => prices[key];

  bool get isDrink => category.toLowerCase() == 'drinks';
  bool get isMeal => category.toLowerCase() == 'meals';
  bool get isDessert => category.toLowerCase() == 'desserts';
}

