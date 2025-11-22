/// <<FILE: lib/core/services/hive_service.dart>>
import 'package:hive_flutter/hive_flutter.dart';

import '../../scripts/seed_ingredients.dart';
import '../../scripts/seed_products.dart';
import '../../scripts/seed_ingredient_usage.dart';
import '../../scripts/seed_users.dart';

import '../models/ingredient_model.dart';
import '../models/product_model.dart';
import '../models/ingredient_usage_model.dart';
import '../models/user_model.dart';
import '../models/inventory_log_model.dart';

import '../models/cart_item_model.dart'; // ✅ Import
import '../models/transaction_model.dart'; // ✅ Import
import '../models/attendance_log_model.dart'; // ✅ Import

class HiveService {
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register adapters safely
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(IngredientModelAdapter());
    }
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ProductModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(IngredientUsageModelAdapter());
    }
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(UserRoleLevelAdapter());
    }
    if (!Hive.isAdapterRegistered(21)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(InventoryLogModelAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(CartItemModelAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(TransactionModelAdapter());
    }
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(OrderStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(30)) {
      Hive.registerAdapter(AttendanceStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(31)) {
      Hive.registerAdapter(AttendanceLogModelAdapter());
    }

    // Open boxes
    final ingredientBox = await Hive.openBox<IngredientModel>('ingredients');
    final productBox = await Hive.openBox<ProductModel>('products');
    final usageBox = await Hive.openBox<IngredientUsageModel>('ingredient_usages');
    final userBox = await Hive.openBox<UserModel>('users');
    await Hive.openBox<InventoryLogModel>('inventory_logs');
    await Hive.openBox<TransactionModel>('transactions');
    await Hive.openBox<AttendanceLogModel>('attendance_logs');

    // ✅ Seed data if empty
    if (ingredientBox.isEmpty) {
      await seedIngredients();
    }
    if (productBox.isEmpty) {
      await seedProducts();
    }
    if (usageBox.isEmpty) {
      await seedIngredientUsage();
    }
    if (userBox.isEmpty) {
      await seedUsers();
    }

    _initialized = true;

    print('[HiveService] ✅ Hive initialized, adapters registered, and boxes ready.');
  }

  // Accessors
  static Box<ProductModel> get productBox => Hive.box<ProductModel>('products');
  static Box<IngredientModel> get ingredientBox => Hive.box<IngredientModel>('ingredients');
  static Box<IngredientUsageModel> get usageBox => Hive.box<IngredientUsageModel>('ingredient_usages');
  static Box<UserModel> get userBox => Hive.box<UserModel>('users');
  static Box<InventoryLogModel> get logsBox => Hive.box<InventoryLogModel>('inventory_logs');
  static Box<TransactionModel> get transactionBox => Hive.box<TransactionModel>('transactions');
  static Box<AttendanceLogModel> get attendanceBox => Hive.box<AttendanceLogModel>('attendance_logs');

  // Maintenance
  static Future<void> clearAll() async {
    await productBox.clear();
    await ingredientBox.clear();
    await usageBox.clear();
    await userBox.clear();
    await logsBox.clear();
    await transactionBox.clear();
    await attendanceBox.clear();
    print('[HiveService] 🧹 All Hive boxes cleared');
  }

  static Future<void> close() async {
    await Hive.close();
    _initialized = false;
    print('[HiveService] 🔒 Hive closed');
  }
}
/// <<END FILE>>