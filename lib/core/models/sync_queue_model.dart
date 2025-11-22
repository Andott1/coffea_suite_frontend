import 'package:hive/hive.dart';

part 'sync_queue_model.g.dart';

@HiveType(typeId: 100) // Use a high ID number
class SyncQueueModel extends HiveObject {
  @HiveField(0)
  final String id; // UUID

  @HiveField(1)
  final String table; // 'users', 'ingredients', 'transactions'

  @HiveField(2)
  final String action; // 'UPSERT', 'DELETE'

  @HiveField(3)
  final Map<String, dynamic> data; // The JSON payload

  @HiveField(4)
  final DateTime timestamp;

  SyncQueueModel({
    required this.id,
    required this.table,
    required this.action,
    required this.data,
    required this.timestamp,
  });
}