import 'dart:math' as math;
import '../../../core/models/cart_item_model.dart';
import '../../../core/models/ingredient_model.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/inventory_log_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/supabase_sync_service.dart';
import '../../../core/models/product_model.dart';

class StockLogic {
  /// Iterates through the cart and deducts ingredients from Hive
  static Future<void> deductStock(List<CartItemModel> cart, String orderId) async {
    final ingredientBox = HiveService.ingredientBox;

    for (final item in cart) {
      final product = item.product;
      final variant = item.variant; // e.g. "12oz"
      final quantitySold = item.quantity;

      // 1. Check if Product has ingredient usage
      if (product.ingredientUsage.isEmpty) continue;

      // 2. Iterate through ingredients for this product
      for (final entry in product.ingredientUsage.entries) {
        final ingredientName = entry.key; // e.g. "Coffee Beans"
        final usageMap = entry.value;     // e.g. {"12oz": 30, "16oz": 60}

        // 3. Check if there is usage defined for this specific variant
        if (usageMap.containsKey(variant)) {
          final amountPerUnit = usageMap[variant]!;
          final totalDeduction = amountPerUnit * quantitySold;

          // 4. Find the actual Ingredient Model
          // Note: This matches by NAME. ID matching is safer but your Usage Model uses names currently.
          // We fallback to safe searching.
          try {
            final ingredient = ingredientBox.values.firstWhere(
              (i) => i.name == ingredientName
            );

            // 5. Perform Deduction
            ingredient.quantity -= totalDeduction;
            ingredient.updatedAt = DateTime.now();
            await ingredient.save();

            SupabaseSyncService.addToQueue(
              table: 'ingredients',
              action: 'UPSERT',
              data: {
                'id': ingredient.id,
                'name': ingredient.name,
                'category': ingredient.category,
                'unit': ingredient.unit,
                'quantity': ingredient.quantity,

                // ✅ MANUAL MAPPING TO SNAKE_CASE
                'reorder_level': ingredient.reorderLevel,
                'unit_cost': ingredient.unitCost,
                'purchase_size': ingredient.purchaseSize,
                'base_unit': ingredient.baseUnit,
                'conversion_factor': ingredient.conversionFactor,
                'is_custom_conversion': ingredient.isCustomConversion,
                'updated_at': ingredient.updatedAt.toIso8601String(),
              },
            );

            // 6. Log it (Silent log, or maybe grouped log later)
            // Logging every single bean deduction might spam the logs. 
            // Ideally, we log 1 entry per order, but for detailed tracking:
            await InventoryLogService.log(
              ingredientName: ingredient.name,
              action: "Sale",
              quantity: -totalDeduction,
              unit: ingredient.baseUnit,
              reason: "Order #$orderId (${product.name})",
            );
            
          } catch (e) {
            LoggerService.warning("⚠️ Stock Deduction Error: Ingredient '$ingredientName' not found in Inventory.");
          }
        }
      }
    }
  }

  static bool isProductAvailable(ProductModel product) {
    // If no ingredients, it's always available (e.g. plain water)
    if (product.ingredientUsage.isEmpty) return true;

    final ingredientBox = HiveService.ingredientBox;

    // Iterate through all ingredients used by this product
    for (var entry in product.ingredientUsage.entries) {
      final ingredientName = entry.key;
      final variantMap = entry.value;

      // 1. Find the ingredient
      // Note: This naive lookup by name matches your current architecture. 
      // Ideally we'd use ID in future.
      final ingredient = ingredientBox.values.firstWhere(
        (i) => i.name == ingredientName,
        orElse: () => IngredientModel(id: 'missing', name: '', category: '', unit: '', quantity: -1, updatedAt: DateTime.now(), reorderLevel: 0),
      );

      // 2. If ingredient doesn't exist (was deleted) OR quantity is 0/negative
      if (ingredient.quantity <= 0) {
        return false; // Sold Out
      }
    }

    return true; // All ingredients have > 0 stock
  }

  static int calculateMaxStock({
    required ProductModel product,
    required String variant,
    required List<CartItemModel> currentCart,
  }) {
    final ingredientBox = HiveService.ingredientBox;
    
    // 1. Calculate "Committed" Stock (Usage by items ALREADY in cart)
    // Map<IngredientName, TotalUsedAmount>
    final Map<String, double> committedStock = {};

    for (final item in currentCart) {
      // Skip if product has no recipe
      if (item.product.ingredientUsage.isEmpty) continue;

      // Loop through the recipe of the CART ITEM
      for (final entry in item.product.ingredientUsage.entries) {
        final ingName = entry.key;
        final usageMap = entry.value;

        // If this cart item uses this ingredient for its variant
        if (usageMap.containsKey(item.variant)) {
          final usagePerUnit = usageMap[item.variant]!;
          final totalUsed = usagePerUnit * item.quantity;

          // Add to accumulator
          committedStock[ingName] = (committedStock[ingName] ?? 0) + totalUsed;
        }
      }
    }

    // 2. Determine Bottleneck for the NEW item
    double minYield = double.infinity;
    bool hasTrackedIngredients = false;

    // Loop through the recipe of the TARGET item (the one we want to add)
    for (var entry in product.ingredientUsage.entries) {
      final ingredientName = entry.key;
      final usageMap = entry.value;

      if (usageMap.containsKey(variant)) {
        hasTrackedIngredients = true;
        final requiredPerUnit = usageMap[variant]!;
        
        // Get Real Stock from DB
        final ingredient = ingredientBox.values.firstWhere(
          (i) => i.name == ingredientName,
          orElse: () => IngredientModel(id: 'missing', name: '', category: '', unit: '', quantity: 0, updatedAt: DateTime.now(), reorderLevel: 0),
        );

        // Get Committed Stock from Cart
        final usedAmount = committedStock[ingredientName] ?? 0;

        // Calculate "Free" Stock
        final freeStock = ingredient.quantity - usedAmount;

        // How many can we make with the FREE stock?
        // If free stock is negative (error state), yield is 0
        final possible = freeStock <= 0 ? 0.0 : (freeStock / requiredPerUnit).floorToDouble();
        
        if (possible < minYield) {
          minYield = possible;
        }
      }
    }

    // If no recipe, return unlimited
    if (!hasTrackedIngredients) return 999;
    if (minYield == double.infinity) return 999;

    // 3. Return Absolute Limit
    // We don't subtract 'alreadyInCart' here because we already subtracted
    // the usage of the items in the cart from the 'freeStock' calculation above.
    // The result 'minYield' IS the remaining capacity.
    
    return minYield.toInt(); 
  }
}
