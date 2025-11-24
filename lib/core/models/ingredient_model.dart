import 'package:hive/hive.dart';
part 'ingredient_model.g.dart';

@HiveType(typeId: 1)
class IngredientModel extends HiveObject {
  // ──────────────── CORE FIELDS ────────────────
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  /// Ingredient category (e.g., "Core Ingredients", "Syrups", "Packaging Supplies")
  @HiveField(2)
  String category;

  /// Purchase/display unit (e.g., kg, L, pcs)
  @HiveField(3)
  String unit;

  /// Quantity stored internally in base units (e.g., g, mL, pcs)
  @HiveField(4)
  double quantity;

  /// Minimum allowed stock (in base units)
  @HiveField(5)
  double reorderLevel;

  @HiveField(6)
  DateTime updatedAt;

  /// Base unit (auto-determined from `unit`)
  @HiveField(7)
  String baseUnit;

  /// Conversion factor between `unit` → `baseUnit`
  @HiveField(8)
  double conversionFactor;

  /// Optional flag for custom overrides (future-use)
  @HiveField(9)
  bool isCustomConversion;

  // ──────────────── NEW COSTING FIELD ────────────────
  /// 💰 Cost per purchased unit (e.g., ₱250 per kg)
  @HiveField(10)
  double unitCost;

  @HiveField(11) 
  double purchaseSize;

  // ──────────────── AUTO-CONVERSION PRESETS ────────────────
  static const Map<String, Map<String, dynamic>> _autoConversionPresets = {
    'kg': {'base': 'g', 'factor': 1000.0},
    'g': {'base': 'g', 'factor': 1.0},
    'L': {'base': 'mL', 'factor': 1000.0},
    'mL': {'base': 'mL', 'factor': 1.0},
    'pcs': {'base': 'pcs', 'factor': 1.0},
  };

  // ──────────────── CONSTRUCTOR ────────────────
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
    this.unitCost = 0.0, // 💰 new default
    this.purchaseSize = 1.0,
  })  : baseUnit = baseUnit ?? _autoConversionPresets[unit]?['base'] ?? unit,
        conversionFactor =
            conversionFactor ?? _autoConversionPresets[unit]?['factor'] ?? 1.0;

  // ──────────────── COMPUTED GETTERS ────────────────
  double get displayQuantity => quantity / conversionFactor;
  String get displayString => "${displayQuantity.toStringAsFixed(2)} $unit";

  /// ✅ FIX 1: Cost per Base Unit (e.g., Cost per mL)
  /// Logic: (Cost per Bottle) / (Size of Bottle in Base Units)
  double get costPerBaseUnit {
    // Convert purchaseSize (which is in 'unit', e.g., L) to Base Unit (e.g., mL)
    double sizeInBaseUnits = purchaseSize * conversionFactor;
    
    if (sizeInBaseUnits == 0) return 0;
    return unitCost / sizeInBaseUnits;
  }

  /// ✅ FIX 2: Total Value
  /// Logic: (Total Quantity / Bottle Size) * Cost per Bottle
  double get totalValue {
    if (purchaseSize == 0) return 0;
    return (displayQuantity / purchaseSize) * unitCost;
  }

  // ──────────────── SERIALIZATION ────────────────
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
        'reorderLevel': reorderLevel,
        'updatedAt': updatedAt.toIso8601String(),
        'baseUnit': baseUnit,
        'conversionFactor': conversionFactor,
        'isCustomConversion': isCustomConversion,
        'unitCost': unitCost,
        'purchaseSize': purchaseSize,
      };

  // ──────────────── UTILITIES ────────────────
  static bool isKnownUnit(String unit) => _autoConversionPresets.containsKey(unit);

  /// Factory shortcut for creating auto-converted ingredients
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
/// <<END FILE>>