/// <<FILE: lib/core/models/inventory_log_model.dart>>
import 'package:hive/hive.dart';

part 'inventory_log_model.g.dart';

@HiveType(typeId: 3)
class InventoryLogModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime dateTime;

  @HiveField(2)
  String ingredientName; // Store name snapshot in case ingredient is deleted later

  @HiveField(3)
  String action; // "Restock", "Waste", "Correction", "Audit"

  @HiveField(4)
  double changeAmount; // e.g. +500 or -20

  @HiveField(5)
  String unit; // e.g. "mL"

  @HiveField(6)
  String userName; // Who did it

  @HiveField(7)
  String reason; // "Spilled", "Delivery", etc.

  InventoryLogModel({
    required this.id,
    required this.dateTime,
    required this.ingredientName,
    required this.action,
    required this.changeAmount,
    required this.unit,
    required this.userName,
    required this.reason,
  });
}
/// <<END FILE>>