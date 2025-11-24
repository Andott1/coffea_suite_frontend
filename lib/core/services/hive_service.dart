import 'package:hive_flutter/hive_flutter.dart';

import '../models/ingredient_model.dart';
import '../models/product_model.dart';
import '../models/ingredient_usage_model.dart';
import '../models/user_model.dart';
import '../models/inventory_log_model.dart';
import '../models/cart_item_model.dart'; 
import '../models/transaction_model.dart'; 
import '../models/attendance_log_model.dart'; 
import '../models/sync_queue_model.dart'; // Don't forget SyncQueue adapter

import 'logger_service.dart';

class HiveService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register adapters safely
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(IngredientModelAdapter());
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductModelAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(IngredientUsageModelAdapter());
    if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(UserRoleLevelAdapter());
    if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(UserModelAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(InventoryLogModelAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(CartItemModelAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(TransactionModelAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(OrderStatusAdapter());
    if (!Hive.isAdapterRegistered(30)) Hive.registerAdapter(AttendanceStatusAdapter());
    if (!Hive.isAdapterRegistered(31)) Hive.registerAdapter(AttendanceLogModelAdapter());
    if (!Hive.isAdapterRegistered(100)) Hive.registerAdapter(SyncQueueModelAdapter());

    // Open boxes
    await Hive.openBox<IngredientModel>('ingredients');
    await Hive.openBox<ProductModel>('products');
    await Hive.openBox<IngredientUsageModel>('ingredient_usages');
    await Hive.openBox<UserModel>('users');
    await Hive.openBox<InventoryLogModel>('inventory_logs');
    await Hive.openBox<TransactionModel>('transactions');
    await Hive.openBox<AttendanceLogModel>('attendance_logs');
    
    // NOTE: SyncQueue is opened by SupabaseSyncService, but safe to open here too if needed.

    // ❌ REMOVED: await _smartSeed(...); 
    // Data seeding is now handled by InitialSetupScreen.

    _initialized = true;
    LoggerService.info('[HiveService] ✅ Hive initialized. Boxes ready.');
  }

  // Accessors
  static Box<ProductModel> get productBox => Hive.box<ProductModel>('products');
  static Box<IngredientModel> get ingredientBox => Hive.box<IngredientModel>('ingredients');
  static Box<IngredientUsageModel> get usageBox => Hive.box<IngredientUsageModel>('ingredient_usages');
  static Box<UserModel> get userBox => Hive.box<UserModel>('users');
  static Box<InventoryLogModel> get logsBox => Hive.box<InventoryLogModel>('inventory_logs');
  static Box<TransactionModel> get transactionBox => Hive.box<TransactionModel>('transactions');
  static Box<AttendanceLogModel> get attendanceBox => Hive.box<AttendanceLogModel>('attendance_logs');

  static Future<void> close() async {
    await Hive.close();
    _initialized = false;
    LoggerService.info('[HiveService] 🔒 Hive closed');
  }
}