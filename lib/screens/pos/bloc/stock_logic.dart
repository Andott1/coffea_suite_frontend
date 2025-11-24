import '../../../core/models/cart_item_model.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/inventory_log_service.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/supabase_sync_service.dart';

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
}
