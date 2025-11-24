import 'package:uuid/uuid.dart';
import 'hive_service.dart';
import 'session_user.dart';
import '../models/inventory_log_model.dart';
import 'supabase_sync_service.dart';

class InventoryLogService {
  static final _uuid = const Uuid();

  /// Records an inventory transaction
  static Future<void> log({
    required String ingredientName,
    required String action,     // "Restock", "Waste", "Correction"
    required double quantity,   // The amount changed (can be + or -)
    required String unit,
    String? reason,
  }) async {
    final user = SessionUser.current;
    final userName = user?.username ?? "Unknown";

    final logEntry = InventoryLogModel(
      id: _uuid.v4(),
      dateTime: DateTime.now(),
      ingredientName: ingredientName,
      action: action,
      changeAmount: quantity,
      unit: unit,
      userName: userName,
      reason: reason ?? "-",
    );

    await HiveService.logsBox.add(logEntry);

    SupabaseSyncService.addToQueue(
      table: 'inventory_logs',
      action: 'UPSERT',
      data: {
        'id': logEntry.id,
        'date_time': logEntry.dateTime.toIso8601String(),
        'ingredient_name': logEntry.ingredientName,
        'action': logEntry.action,
        'change_amount': logEntry.changeAmount,
        'unit': logEntry.unit,
        'reason': logEntry.reason,
        'user_name': logEntry.userName,
      }
    );
  }
}
