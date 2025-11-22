import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/attendance_log_model.dart';
import '../models/cart_item_model.dart';
import '../models/ingredient_model.dart';
import '../models/inventory_log_model.dart';
import '../models/product_model.dart';
import '../models/sync_queue_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';

class SupabaseSyncService {
  static final SupabaseClient _client = Supabase.instance.client;
  static Box<SyncQueueModel>? _queueBox;
  static bool _isSyncing = false;

  static Future<void> init() async {
    // 1. Open Queue Box
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(SyncQueueModelAdapter());
    }
    _queueBox = await Hive.openBox<SyncQueueModel>('sync_queue');

    // 2. Listen to Connectivity Changes
    Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  // ─── 1. ADD TO QUEUE ───
  static Future<void> addToQueue({
    required String table,
    required String action, // 'UPSERT', 'DELETE'
    required Map<String, dynamic> data,
  }) async {
    final item = SyncQueueModel(
      id: const Uuid().v4(),
      table: table,
      action: action,
      data: data,
      timestamp: DateTime.now(),
    );
    
    await _queueBox?.add(item);
    
    // Try to sync immediately
    processQueue();
  }

  // ─── 2. PROCESS QUEUE (Robust) ───
  static Future<void> processQueue() async {
    // Prevent concurrent syncs
    if (_isSyncing || _queueBox == null || _queueBox!.isEmpty) return;

    // Check internet
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    _isSyncing = true;
    print("🔄 Syncing ${_queueBox!.length} items to Supabase...");

    try {
      // Loop until queue is empty (handles items added *during* the sync)
      while (_queueBox!.isNotEmpty) {
        
        // Take a snapshot of current items
        final itemsToSync = _queueBox!.values.toList();
        if (itemsToSync.isEmpty) break;

        for (var item in itemsToSync) {
          // SAFETY CHECK: If item was already deleted by another process, skip it
          if (!item.isInBox) continue;

          try {
            if (item.action == 'UPSERT') {
              await _client.from(item.table).upsert(item.data);
            } else if (item.action == 'DELETE') {
              await _client.from(item.table).delete().eq('id', item.data['id']);
            }

            // ✅ SAFE DELETE: Check again before deleting
            if (item.isInBox) {
              await item.delete();
            }
            
          } catch (e) {
            print("❌ Sync Error on item ${item.id}: $e");
            // We leave the item in the box to retry later
            // Optional: You could add a 'retryCount' field to SyncQueueModel to delete after X fails
          }
        }
        
        // Re-check connectivity between batches
        final check = await Connectivity().checkConnectivity();
        if (check.contains(ConnectivityResult.none)) break;
      }
    } finally {
      _isSyncing = false;
    }
  }

  // ─── 3. RESTORE FROM CLOUD (Cloud -> Local) ───
  static Future<void> restoreFromCloud() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw Exception("No internet connection. Cannot restore.");
    }

    // Safety Check: Don't restore if we have pending uploads!
    if (_queueBox != null && _queueBox!.isNotEmpty) {
      throw Exception("Unsynced local changes detected. Please wait for auto-sync to finish before restoring.");
    }

    _isSyncing = true;
    print("☁️ Starting Cloud Restore...");

    try {
      // 1. USERS
      final usersData = await _client.from('users').select();
      final userBox = Hive.box<UserModel>('users');
      await userBox.clear(); 
      for (final map in usersData) {
        final roleEnum = UserRoleLevel.values.firstWhere(
          (e) => e.name == map['role'], orElse: () => UserRoleLevel.employee
        );
        final user = UserModel(
          id: map['id'],
          fullName: map['full_name'],
          username: map['username'],
          passwordHash: map['password_hash'],
          pinHash: map['pin_hash'],
          role: roleEnum,
          isActive: map['is_active'] ?? true,
          hourlyRate: (map['hourly_rate'] as num?)?.toDouble() ?? 0.0,
          createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
          updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
        );
        await userBox.put(user.id, user);
      }

      // 2. INGREDIENTS
      final ingData = await _client.from('ingredients').select();
      final ingBox = Hive.box<IngredientModel>('ingredients');
      await ingBox.clear();
      for (final map in ingData) {
        final ing = IngredientModel(
          id: map['id'],
          name: map['name'],
          category: map['category'],
          unit: map['unit'],
          quantity: (map['quantity'] as num).toDouble(),
          reorderLevel: (map['reorder_level'] as num).toDouble(),
          unitCost: (map['unit_cost'] as num).toDouble(),
          purchaseSize: (map['purchase_size'] as num).toDouble(),
          baseUnit: map['base_unit'] ?? map['unit'],
          conversionFactor: (map['conversion_factor'] as num?)?.toDouble() ?? 1.0,
          isCustomConversion: map['is_custom_conversion'] ?? false,
          updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
        );
        await ingBox.put(ing.id, ing);
      }

      // 3. PRODUCTS (The Menu)
      final prodData = await _client.from('products').select();
      final prodBox = Hive.box<ProductModel>('products');
      await prodBox.clear();
      for (final map in prodData) {
        Map<String, double> prices = {};
        if (map['prices'] != null) {
          prices = Map<String, double>.from((map['prices'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())));
        }

        Map<String, Map<String, double>> usage = {};
        if (map['ingredient_usage'] != null) {
          usage = (map['ingredient_usage'] as Map).map((k, v) {
            return MapEntry(k as String, Map<String, double>.from((v as Map).map((k2, v2) => MapEntry(k2, (v2 as num).toDouble()))));
          });
        }

        final prod = ProductModel(
          id: map['id'],
          name: map['name'],
          category: map['category'],
          subCategory: map['sub_category'] ?? '',
          pricingType: map['pricing_type'] ?? 'size',
          prices: prices,
          ingredientUsage: usage,
          available: map['available'] ?? true,
          updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
        );
        await prodBox.put(prod.id, prod);
      }

      // 4. ATTENDANCE LOGS
      final attData = await _client.from('attendance_logs').select();
      final attBox = Hive.box<AttendanceLogModel>('attendance_logs');
      await attBox.clear();
      for (final map in attData) {
        final statusEnum = AttendanceStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => AttendanceStatus.incomplete
        );
        final log = AttendanceLogModel(
          id: map['id'],
          userId: map['user_id'],
          date: DateTime.parse(map['date']),
          timeIn: DateTime.parse(map['time_in']),
          timeOut: map['time_out'] != null ? DateTime.parse(map['time_out']) : null,
          breakStart: map['break_start'] != null ? DateTime.parse(map['break_start']) : null,
          breakEnd: map['break_end'] != null ? DateTime.parse(map['break_end']) : null,
          status: statusEnum,
          hourlyRateSnapshot: (map['hourly_rate_snapshot'] as num?)?.toDouble() ?? 0.0,
        );
        await attBox.put(log.id, log);
      }

      // 5. INVENTORY LOGS
      final logData = await _client.from('inventory_logs').select();
      final logBox = Hive.box<InventoryLogModel>('inventory_logs');
      await logBox.clear();
      for(final map in logData) {
        final log = InventoryLogModel(
          id: map['id'],
          dateTime: DateTime.parse(map['date_time']),
          ingredientName: map['ingredient_name'],
          action: map['action'],
          changeAmount: (map['change_amount'] as num).toDouble(),
          unit: map['unit'] ?? '',
          userName: map['user_name'] ?? 'Unknown',
          reason: map['reason'] ?? '-',
        );
        await logBox.add(log);
      }

      // ✅ 6. TRANSACTIONS (The Missing Part)
      final txnData = await _client.from('transactions').select();
      final txnBox = Hive.box<TransactionModel>('transactions');
      
      // We need to look up products to reconstruct items
      final productBox = Hive.box<ProductModel>('products'); 
      
      await txnBox.clear();

      for (final map in txnData) {
        // A. Map OrderStatus
        final statusEnum = OrderStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => OrderStatus.served
        );

        // B. Reconstruct Cart Items from JSONB
        List<CartItemModel> cartItems = [];
        if (map['items'] != null) {
          final rawItems = List<dynamic>.from(map['items']);
          for (final itemMap in rawItems) {
            // ⚠️ Crucial: Find the product object by Name
            // (Since we stored 'product_name' in the JSON)
            ProductModel? product;
            try {
              product = productBox.values.firstWhere((p) => p.name == itemMap['product_name']);
            } catch (_) {
              // If product was deleted from menu, create a placeholder so history isn't broken
              product = ProductModel(
                id: 'archived', 
                name: itemMap['product_name'], 
                category: 'Archived', 
                subCategory: '', 
                pricingType: 'size', 
                prices: {}, 
                updatedAt: DateTime.now()
              );
            }

            cartItems.add(CartItemModel(
              product: product,
              variant: itemMap['variant'] ?? '',
              price: (itemMap['price'] as num).toDouble(),
              quantity: (itemMap['qty'] as num).toInt(),
            ));
          }
        }

        final txn = TransactionModel(
          id: map['id'],
          dateTime: DateTime.parse(map['date_time']),
          items: cartItems,
          totalAmount: (map['total_amount'] as num).toDouble(),
          tenderedAmount: (map['tendered_amount'] as num?)?.toDouble() ?? 0.0,
          paymentMethod: map['payment_method'] ?? 'Cash',
          cashierName: map['cashier_name'] ?? 'Unknown',
          referenceNo: map['reference_no'],
          isVoid: map['is_void'] ?? false,
          status: statusEnum,
        );
        await txnBox.put(txn.id, txn);
      }
      print("✅ Restored ${txnData.length} transactions.");

      print("🎉 FULL CLOUD RESTORE COMPLETE!");
      
    } catch (e) {
      print("❌ Restore Failed: $e");
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  // ─── 4. FORCE PUSH (Local -> Cloud) ───
  static Future<void> forceLocalToCloud() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw Exception("No internet connection. Cannot sync.");
    }

    print("🚀 Starting Force Push to Cloud...");

    // Helper to queue without triggering sync immediately
    Future<void> queue(String table, Map<String, dynamic> data) async {
      final item = SyncQueueModel(
        id: const Uuid().v4(),
        table: table,
        action: 'UPSERT',
        data: data,
        timestamp: DateTime.now(),
      );
      await _queueBox?.add(item);
    }

    // 1. Users
    final userBox = Hive.box<UserModel>('users');
    for (var item in userBox.values) {
      await queue('users', {
        'id': item.id,
        'full_name': item.fullName,
        'username': item.username,
        'password_hash': item.passwordHash,
        'pin_hash': item.pinHash,
        'role': item.role.name,
        'is_active': item.isActive,
        'hourly_rate': item.hourlyRate,
        'updated_at': item.updatedAt.toIso8601String(),
        'created_at': item.createdAt.toIso8601String(),
      });
    }

    // 2. Ingredients
    final ingBox = Hive.box<IngredientModel>('ingredients');
    for (var item in ingBox.values) {
      await queue('ingredients', {
        'id': item.id,
        'name': item.name,
        'category': item.category,
        'unit': item.unit,
        'quantity': item.quantity,
        'reorder_level': item.reorderLevel,
        'unit_cost': item.unitCost,
        'purchase_size': item.purchaseSize,
        'base_unit': item.baseUnit,
        'conversion_factor': item.conversionFactor,
        'is_custom_conversion': item.isCustomConversion,
        'updated_at': item.updatedAt.toIso8601String(),
      });
    }

    // 3. Products
    final prodBox = Hive.box<ProductModel>('products');
    for (var item in prodBox.values) {
      await queue('products', {
        'id': item.id,
        'name': item.name,
        'category': item.category,
        'sub_category': item.subCategory,
        'pricing_type': item.pricingType,
        'prices': item.prices,
        'ingredient_usage': item.ingredientUsage,
        'available': item.available,
        'updated_at': item.updatedAt.toIso8601String(),
      });
    }

    // 4. Transactions
    final txnBox = Hive.box<TransactionModel>('transactions');
    for (var item in txnBox.values) {
       await queue('transactions', {
        'id': item.id,
        'date_time': item.dateTime.toIso8601String(),
        'total_amount': item.totalAmount,
        'tendered_amount': item.tenderedAmount,
        'payment_method': item.paymentMethod,
        'cashier_name': item.cashierName,
        'status': item.status.name,
        'is_void': item.isVoid,
        'reference_no': item.referenceNo,
        'items': item.items.map((i) => {
          'product_name': i.product.name,
          'variant': i.variant,
          'qty': i.quantity,
          'price': i.price,
          'total': i.total
        }).toList(),
      });
    }

    // 5. Attendance
    final attBox = Hive.box<AttendanceLogModel>('attendance_logs');
    for (var item in attBox.values) {
      await queue('attendance_logs', {
        'id': item.id,
        'user_id': item.userId,
        'date': item.date.toIso8601String(),
        'time_in': item.timeIn.toIso8601String(),
        'time_out': item.timeOut?.toIso8601String(),
        'break_start': item.breakStart?.toIso8601String(),
        'break_end': item.breakEnd?.toIso8601String(),
        'status': item.status.name,
        'hourly_rate_snapshot': item.hourlyRateSnapshot,
      });
    }

    // 6. Inventory Logs
    final logBox = Hive.box<InventoryLogModel>('inventory_logs');
    for (var item in logBox.values) {
      await queue('inventory_logs', {
        'id': item.id,
        'date_time': item.dateTime.toIso8601String(),
        'ingredient_name': item.ingredientName,
        'action': item.action,
        'change_amount': item.changeAmount,
        'unit': item.unit,
        'user_name': item.userName,
        'reason': item.reason,
      });
    }

    print("✅ All local data queued for sync.");
    
    // Trigger the background sync
    processQueue();
  }
  
}