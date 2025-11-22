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

import 'package:connectivity_plus/connectivity_plus.dart'; // ✅ Check internet
import 'supabase_sync_service.dart'; // ✅ Perform restore

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

    await _smartSeed(userBox, ingredientBox, productBox, usageBox);

    _initialized = true;

    print('[HiveService] ✅ Hive initialized, adapters registered, and boxes ready.');
  }

  // ──────────────── SMART SEEDING STRATEGY ────────────────
  static Future<void> _smartSeed(
    Box<UserModel> userBox,
    Box<IngredientModel> ingredientBox,
    Box<ProductModel> productBox,
    Box<IngredientUsageModel> usageBox,
  ) async {
    // 1. Only run if critical data (Users) is missing.
    if (userBox.isNotEmpty) return;

    print('[HiveService] 🆕 Fresh Install Detected.');

    // 2. Check Connectivity
    final connectivity = await Connectivity().checkConnectivity();
    final isOnline = !connectivity.contains(ConnectivityResult.none);

    bool restoreSuccess = false;

    // 3. Try Cloud Restore if Online
    if (isOnline) {
      print('[HiveService] ☁️ Online detected. Attempting Cloud Restore...');
      try {
        await SupabaseSyncService.restoreFromCloud();
        
        // Verify if data actually came in. 
        // If Supabase is empty (new project), userBox will still be empty.
        if (userBox.isNotEmpty) {
          restoreSuccess = true;
          print('[HiveService] ✅ Cloud Restore Successful.');
        } else {
          print('[HiveService] ⚠️ Cloud DB is empty.');
        }
      } catch (e) {
        print('[HiveService] ❌ Cloud Restore Failed: $e');
        // Fallthrough to local seed
      }
    } else {
      print('[HiveService] 🔌 Offline detected. Skipping Cloud Restore.');
    }

    // 4. Fallback: Local Seeding
    // Run this if we are Offline OR if Cloud Restore failed/returned empty
    if (!restoreSuccess && userBox.isEmpty) {
      print('[HiveService] 🌱 Executing Local Fallback Seeding...');
      if (ingredientBox.isEmpty) await seedIngredients();
      if (productBox.isEmpty) await seedProducts();
      if (usageBox.isEmpty) await seedIngredientUsage();
      if (userBox.isEmpty) await seedUsers();
    }
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