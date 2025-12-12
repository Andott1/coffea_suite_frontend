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
          try {
            final ingredient = ingredientBox.values.firstWhere(
              (i) => i.name == ingredientName
            );

            // 5. Perform Deduction Locally
            ingredient.quantity -= totalDeduction;
            ingredient.updatedAt = DateTime.now();
            await ingredient.save();

            // ✅ 6. Sync ONLY Quantity (Efficient Partial Update)
            SupabaseSyncService.addToQueue(
              table: 'ingredients',
              action: 'UPDATE', 
              data: {
                'id': ingredient.id,
                'quantity': ingredient.quantity, // Only sending the new value
                'updated_at': ingredient.updatedAt.toIso8601String(),
              },
            );

            // 7. Log it
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

  /// ✅ FIXED: Robust check for availability.
  /// Returns TRUE if at least ONE variant of the product can be made with current stock.
  /// Returns FALSE only if ALL variants are impossible to make.
  static bool isProductAvailable(ProductModel product) {
    // If no ingredients are tracked, it's always available (e.g. Service fee, Water)
    if (product.ingredientUsage.isEmpty) return true;

    final ingredientBox = HiveService.ingredientBox;
    final availableVariants = product.prices.keys.toList();

    // If no variants defined but ingredients exist, we assume it's one generic item.
    // We check if we can make at least 1 unit of the "default" or any defined usage.
    if (availableVariants.isEmpty) return true;

    // We check availability for EACH variant. 
    // If we find AT LEAST ONE makeable variant, the product is "Available".
    for (String variant in availableVariants) {
      bool canMakeThisVariant = true;

      // Check all ingredients required for THIS variant
      for (var entry in product.ingredientUsage.entries) {
        final ingredientName = entry.key;
        final usageMap = entry.value;

        // Does this variant use this ingredient?
        if (usageMap.containsKey(variant)) {
          final requiredAmount = usageMap[variant]!;

          // Find the ingredient in DB
          final ingredient = ingredientBox.values.firstWhere(
            (i) => i.name == ingredientName,
            orElse: () => IngredientModel(id: 'missing', name: '', category: '', unit: '', quantity: -1, updatedAt: DateTime.now(), reorderLevel: 0),
          );

          // If ingredient missing or insufficient stock for THIS variant
          if (ingredient.quantity < requiredAmount) {
            canMakeThisVariant = false;
            break; // Stop checking ingredients for this variant, it's dead
          }
        }
      }

      if (canMakeThisVariant) {
        return true; // Found a valid variant, so Product is Available!
      }
    }

    // If we finished the loop and found NO makeable variants, it is Sold Out.
    return false;
  }

  static Future<void> restoreStock(List<CartItemModel> cart, String orderId) async {
    final ingredientBox = HiveService.ingredientBox;
    
    // 1. AGGREGATION PHASE
    final Map<String, double> restorationMap = {}; 

    for (final item in cart) {
      if (item.product.ingredientUsage.isEmpty) continue;

      for (final entry in item.product.ingredientUsage.entries) {
        final ingredientName = entry.key;
        final usageMap = entry.value;

        if (usageMap.containsKey(item.variant)) {
          final amountPerUnit = usageMap[item.variant]!;
          final totalToRestore = amountPerUnit * item.quantity;
          
          restorationMap[ingredientName] = (restorationMap[ingredientName] ?? 0) + totalToRestore;
        }
      }
    }

    // 2. EXECUTION PHASE
    for (final entry in restorationMap.entries) {
      final ingredientName = entry.key;
      final amount = entry.value;

      try {
        final ingredient = ingredientBox.values.firstWhere(
          (i) => i.name == ingredientName
        );

        ingredient.quantity += amount;
        ingredient.updatedAt = DateTime.now();
        await ingredient.save();

        SupabaseSyncService.addToQueue(
          table: 'ingredients',
          action: 'UPDATE',
          data: {
            'id': ingredient.id,
            'quantity': ingredient.quantity,
            'updated_at': ingredient.updatedAt.toIso8601String(),
          },
        );

        await InventoryLogService.log(
          ingredientName: ingredient.name,
          action: "Void",
          quantity: amount, 
          unit: ingredient.baseUnit,
          reason: "Void Order #$orderId",
        );

      } catch (e) {
        LoggerService.warning("⚠️ Restore Stock Error: Ingredient '$ingredientName' not found, skipping restore.");
      }
    }
  }

  static int calculateMaxStock({
    required ProductModel product,
    required String variant,
    required List<CartItemModel> currentCart,
  }) {
    final ingredientBox = HiveService.ingredientBox;
    
    // 1. Calculate "Committed" Stock (Usage by items ALREADY in cart)
    final Map<String, double> committedStock = {};

    for (final item in currentCart) {
      if (item.product.ingredientUsage.isEmpty) continue;

      for (final entry in item.product.ingredientUsage.entries) {
        final ingName = entry.key;
        final usageMap = entry.value;

        if (usageMap.containsKey(item.variant)) {
          final usagePerUnit = usageMap[item.variant]!;
          final totalUsed = usagePerUnit * item.quantity;
          committedStock[ingName] = (committedStock[ingName] ?? 0) + totalUsed;
        }
      }
    }

    // 2. Determine Bottleneck
    double minYield = double.infinity;
    bool hasTrackedIngredients = false;

    for (var entry in product.ingredientUsage.entries) {
      final ingredientName = entry.key;
      final usageMap = entry.value;

      if (usageMap.containsKey(variant)) {
        hasTrackedIngredients = true;
        final requiredPerUnit = usageMap[variant]!;
        
        final ingredient = ingredientBox.values.firstWhere(
          (i) => i.name == ingredientName,
          orElse: () => IngredientModel(id: 'missing', name: '', category: '', unit: '', quantity: 0, updatedAt: DateTime.now(), reorderLevel: 0),
        );

        final usedAmount = committedStock[ingredientName] ?? 0;
        final freeStock = ingredient.quantity - usedAmount;

        final possible = freeStock <= 0 ? 0.0 : (freeStock / requiredPerUnit).floorToDouble();
        
        if (possible < minYield) {
          minYield = possible;
        }
      }
    }

    if (!hasTrackedIngredients) return 999;
    if (minYield == double.infinity) return 999;
    
    return minYield.toInt(); 
  }
}