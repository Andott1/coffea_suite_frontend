import 'package:hive/hive.dart';
part 'ingredient_usage_model.g.dart';

@HiveType(typeId: 2)
class IngredientUsageModel extends HiveObject {
  // ──────────────── CORE REFERENCES ────────────────
  @HiveField(0)
  String id; // unique ID for this usage record

  @HiveField(1)
  String productId; // e.g., "coffee_latte"

  @HiveField(2)
  String ingredientId; // e.g., "milk"

  @HiveField(3)
  String category; // e.g., "Drinks"

  @HiveField(4)
  String subCategory; // e.g., "Coffee"

  @HiveField(5)
  String unit; // e.g., "g", "mL", "pcs"

  // ──────────────── SIZE / VARIANT QUANTITIES ────────────────
  @HiveField(6)
  Map<String, double> quantities; // e.g. {'12oz': 30, '16oz': 60, 'HOT': 45}

  // ──────────────── TIMESTAMP + VERSIONING ────────────────
  @HiveField(7)
  DateTime createdAt; // when the record was created (usage defined)
  
  @HiveField(8)
  DateTime updatedAt; // when last modified

  /// Optional — track which admin made changes (future feature)
  @HiveField(9)
  String? modifiedBy;

  // ──────────────── CONSTRUCTOR ────────────────
  IngredientUsageModel({
    required this.id,
    required this.productId,
    required this.ingredientId,
    required this.category,
    required this.subCategory,
    required this.unit,
    required this.quantities,
    required this.createdAt,
    required this.updatedAt,
    this.modifiedBy,
  });

  // ──────────────── SERIALIZATION ────────────────
  factory IngredientUsageModel.fromJson(Map<String, dynamic> json) {
    return IngredientUsageModel(
      id: json['id'] ?? '',
      productId: json['productId'] ?? json['product_id'] ?? '',
      ingredientId: json['ingredientId'] ?? json['ingredient'] ?? '',
      category: json['category'] ?? '',
      subCategory: json['subCategory'] ?? json['subcategory'] ?? '',
      unit: json['unit'] ?? 'pcs',
      quantities: {
        for (var key in ['12oz', '16oz', '22oz', 'HOT'])
          if (json[key] != null)
            key: double.tryParse(json[key].toString()) ?? 0,
      },
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      modifiedBy: json['modifiedBy'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'ingredientId': ingredientId,
        'category': category,
        'subCategory': subCategory,
        'unit': unit,
        'quantities': quantities,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'modifiedBy': modifiedBy,
      };

  // ──────────────── UTILITY GETTERS ────────────────
  double get totalUsage =>
      quantities.values.fold(0.0, (sum, val) => sum + (val ?? 0));

  bool get isEmpty =>
      quantities.values.every((v) => v == 0 || v.isNaN || v.isInfinite);
}

