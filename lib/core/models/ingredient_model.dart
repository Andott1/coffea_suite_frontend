/// <<FILE: lib/core/models/ingredient_model.dart>>
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

  /// Display unit used by admin (e.g., kg, L, pcs)
  @HiveField(3)
  String unit;

  /// Quantity stored internally in base unit (e.g., g, mL, pcs)
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

  // ──────────────── PRESETS FOR AUTO-CONVERSION ────────────────
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
  })  : baseUnit = baseUnit ?? _autoConversionPresets[unit]?['base'] ?? unit,
        conversionFactor =
            conversionFactor ?? _autoConversionPresets[unit]?['factor'] ?? 1.0;

  // ──────────────── COMPUTED GETTERS ────────────────
  double get displayQuantity => quantity / conversionFactor;

  String get displayString => "${displayQuantity.toStringAsFixed(2)} $unit";

  // ──────────────── SERIALIZATION ────────────────
  factory IngredientModel.fromJson(Map<String, dynamic> json) {
    final unit = (json['unit'] ?? 'pcs') as String;
    final preset = _autoConversionPresets[unit];

    return IngredientModel(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ??
          'Uncategorized', // fallback for safety during imports
      unit: unit,
      quantity: (json['quantity'] ?? 0).toDouble(),
      reorderLevel: (json['reorderLevel'] ?? 0).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      baseUnit: json['baseUnit'] as String? ?? preset?['base'] as String?,
      conversionFactor:
          (json['conversionFactor'] ?? preset?['factor'] ?? 1.0).toDouble(),
      isCustomConversion: json['isCustomConversion'] ?? false,
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
      };

  // ──────────────── UTILITIES ────────────────
  static bool isKnownUnit(String unit) =>
      _autoConversionPresets.containsKey(unit);

  /// Factory shortcut for creating auto-converted ingredients
  factory IngredientModel.auto({
    required String id,
    required String name,
    required String category,
    required String unit,
    required double quantity,
    double reorderLevel = 0,
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
    );
  }
}
/// <<END FILE>>
