import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'ingredient_model.g.dart';

@HiveType(typeId: 1)
class IngredientModel extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String name;
  @HiveField(2) String category;
  @HiveField(3) String unit;
  @HiveField(4) double quantity;
  @HiveField(5) double reorderLevel;
  @HiveField(6) DateTime updatedAt;
  @HiveField(7) String baseUnit;
  @HiveField(8) double conversionFactor;
  @HiveField(9) bool isCustomConversion;
  @HiveField(10) double unitCost;
  @HiveField(11) double purchaseSize;

  // ──────────────── AUTO-CONVERSION PRESETS ────────────────
  static const Map<String, Map<String, dynamic>> _autoConversionPresets = {
    'kg': {'base': 'g', 'factor': 1000.0},
    'g': {'base': 'g', 'factor': 1.0},
    'L': {'base': 'mL', 'factor': 1000.0},
    'mL': {'base': 'mL', 'factor': 1.0},
    'pcs': {'base': 'pcs', 'factor': 1.0},
  };

  // ✅ NEW: Public Helper to get factor
  static double getFactor(String unit) {
    return _autoConversionPresets[unit]?['factor']?.toDouble() ?? 1.0;
  }

  IngredientModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    this.reorderLevel = 0,
    required this.updatedAt,
    String? baseUnit,
    double? conversionFactor,
    this.isCustomConversion = false,
    this.unitCost = 0.0,
    this.purchaseSize = 1.0,
  })  : baseUnit = baseUnit ?? _autoConversionPresets[unit]?['base'] ?? unit,
        conversionFactor = conversionFactor ?? _autoConversionPresets[unit]?['factor'] ?? 1.0;

  double get displayQuantity => quantity / conversionFactor;
  String get displayString => "${displayQuantity.toStringAsFixed(2)} $unit";

  double get costPerBaseUnit {
    double sizeInBaseUnits = purchaseSize * conversionFactor;
    if (sizeInBaseUnits == 0) return 0;
    return unitCost / sizeInBaseUnits;
  }

  double get totalValue {
    if (purchaseSize == 0) return 0;
    return (displayQuantity / purchaseSize) * unitCost;
  }

  // ✅ NEW: Factory that handles ID and Reorder Logic internally
  factory IngredientModel.create({
    required String name,
    required String category,
    required String unit,
    required double quantity,    // Raw input (e.g. 5 kg)
    required double reorderRaw,  // Raw input (e.g. 1 kg)
    required double unitCost,
    required double purchaseSize,
  }) {
    final factor = getFactor(unit);
    final preset = _autoConversionPresets[unit];

    return IngredientModel(
      id: const Uuid().v4(), // ✅ Generates Safe UUID
      name: name,
      category: category,
      unit: unit,
      quantity: quantity * factor,        // ✅ Auto-converts to base
      reorderLevel: reorderRaw * factor,  // ✅ Auto-converts to base
      updatedAt: DateTime.now(),
      baseUnit: preset?['base'] ?? unit,
      conversionFactor: factor,
      unitCost: unitCost,
      purchaseSize: purchaseSize,
    );
  }

  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    final unit = (json['unit'] ?? 'pcs') as String;
    final preset = _autoConversionPresets[unit];

    return IngredientModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] ?? 'Uncategorized',
      unit: unit,
      quantity: (json['quantity'] ?? 0).toDouble(),
      reorderLevel: (json['reorderLevel'] ?? 0).toDouble(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      baseUnit: json['baseUnit'] ?? preset?['base'] ?? unit,
      conversionFactor: (json['conversionFactor'] ?? preset?['factor'] ?? 1).toDouble(),
      isCustomConversion: json['isCustomConversion'] ?? false,
      unitCost: (json['unitCost'] ?? 0).toDouble(),
      purchaseSize: (json['purchaseSize'] ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'unit': unit,
        'quantity': quantity,
        'reorder_level': reorderLevel,
        'updated_at': updatedAt.toIso8601String(),
        'base_unit': baseUnit,                // Was 'baseUnit'
        'conversion_factor': conversionFactor, // Was 'conversionFactor'
        'is_custom_conversion': isCustomConversion, // Was 'isCustomConversion'
        'unit_cost': unitCost,                // Was 'unitCost'
        'purchase_size': purchaseSize,        // Was 'purchaseSize'
      };

  static bool isKnownUnit(String unit) => _autoConversionPresets.containsKey(unit);

  // Legacy auto factory (kept for compatibility if needed)
  factory IngredientModel.auto({
    required String id,
    required String name,
    required String category,
    required String unit,
    required double quantity,
    double reorderLevel = 0,
    double unitCost = 0.0,
    double purchaseSize = 1.0,
  }) {
    final preset = _autoConversionPresets[unit];
    return IngredientModel(
      id: id,
      name: name,
      category: category,
      unit: unit,
      quantity: quantity * (preset?['factor'] ?? 1.0),
      reorderLevel: reorderLevel,
      updatedAt: DateTime.now(),
      baseUnit: preset?['base'] ?? unit,
      conversionFactor: preset?['factor'] ?? 1.0,
      unitCost: unitCost,
      purchaseSize: purchaseSize,
    );
  }
}