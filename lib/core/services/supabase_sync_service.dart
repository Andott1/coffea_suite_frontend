import 'dart:async';
import 'dart:convert'; // ✅ IMPORTED for jsonEncode
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';

import '../models/attendance_log_model.dart';
import '../models/cart_item_model.dart';
import '../models/ingredient_model.dart';
import '../models/inventory_log_model.dart';
import '../models/product_model.dart';
import '../models/sync_queue_model.dart';
import '../models/transaction_model.dart';
import '../models/user_model.dart';
import 'logger_service.dart';

class SupabaseSyncService {
  static final SupabaseClient _client = Supabase.instance.client;
  static Box<SyncQueueModel>? _queueBox;
  static bool _isSyncing = false;
  
  static Timer? _debounceTimer;

  static Future<void> init() async {
    if (!Hive.isAdapterRegistered(100)) {
      Hive.registerAdapter(SyncQueueModelAdapter());
    }
    _queueBox = await Hive.openBox<SyncQueueModel>('sync_queue');

    Connectivity().onConnectivityChanged.listen((result) {
      if (!result.contains(ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  static Future<void> addToQueue({
    required String table,
    required String action,
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
    
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      processQueue();
    });
  }

  // ─── HELPER: FORMAT SIZE ───
  static String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    return "${(bytes / 1024).toStringAsFixed(2)} KB";
  }

  // ─── PROCESS QUEUE ───
  static Future<void> processQueue() async {
    if (_isSyncing || _queueBox == null || _queueBox!.isEmpty) return;

    _isSyncing = true;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) return;

      final allPending = _queueBox!.values.toList();
      if (allPending.isEmpty) return;

      // Group by TABLE
      final byTable = groupBy(allPending, (SyncQueueModel item) => item.table);

      for (final table in byTable.keys) {
        final tableItems = byTable[table]!;

        if (table == 'attendance_logs') {
           await _handleFileUploads(tableItems);
        }
        
        // 1. Deduplicate Logic
        final Map<String, Map<String, dynamic>> uniqueUpserts = {};
        final Set<String> uniqueDeletes = {};
        final Map<String, Map<String, dynamic>> uniqueUpdates = {}; 

        for (var item in tableItems) {
          final id = item.data['id'];
          if (id == null) continue;

          if (item.action == 'UPSERT') {
            uniqueUpserts[id] = item.data;
            uniqueDeletes.remove(id);
            uniqueUpdates.remove(id); 
          } 
          else if (item.action == 'DELETE') {
            uniqueDeletes.add(id);
            uniqueUpserts.remove(id);
            uniqueUpdates.remove(id);
          } 
          else if (item.action == 'UPDATE') {
            if (!uniqueUpserts.containsKey(id) && !uniqueDeletes.contains(id)) {
              final existing = uniqueUpdates[id] ?? {};
              uniqueUpdates[id] = {...existing, ...item.data};
            }
          }
        }

        final upserts = uniqueUpserts.values.toList();
        final deletes = uniqueDeletes.toList();
        final updates = uniqueUpdates.entries.toList();

        try {
          // 2. Execute Batch Upserts
          if (upserts.isNotEmpty) {
            // ✅ Calculate Size
            final jsonString = jsonEncode(upserts);
            final sizeStr = _formatSize(jsonString.length);

            await _client.from(table).upsert(upserts);
            LoggerService.info("✅ [Batch] Upserted ${upserts.length} rows to '$table' ($sizeStr)");
          }

          // 3. Execute Batch Deletes
          if (deletes.isNotEmpty) {
            // Size is roughly the list of IDs
            final sizeStr = _formatSize(jsonEncode(deletes).length);

            await _client.from(table).delete().inFilter('id', deletes);
            LoggerService.info("🗑️ [Batch] Deleted ${deletes.length} rows from '$table' ($sizeStr)");
          }

          // 4. Execute Partial Updates (Loop)
          if (updates.isNotEmpty) {
            int totalBytes = 0;
            
            for (var entry in updates) {
              final id = entry.key;
              final data = entry.value;
              
              // ✅ Accumulate Size
              totalBytes += jsonEncode(data).length;

              await _client.from(table).update(data).match({'id': id});
            }
            
            final sizeStr = _formatSize(totalBytes);
            LoggerService.info("✏️ [Batch] Updated ${updates.length} rows in '$table' (Total: $sizeStr)");
          }

          // 5. Clean up
          final keysToDelete = tableItems.map((e) => e.key).toList();
          await _queueBox!.deleteAll(keysToDelete);

        } catch (e) {
          LoggerService.error("❌ Batch Sync Failed for table '$table': $e");
        }
      }
    } catch (e) {
      LoggerService.error("❌ Critical Sync Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  // ... _handleFileUploads and other methods remain unchanged ...
  
  static Future<void> _handleFileUploads(List<SyncQueueModel> items) async {
    for (var item in items) {
      if (item.action != 'UPSERT') continue;
      final localPath = item.data['proof_image'];
      if (localPath != null && localPath is String && localPath.isNotEmpty && !localPath.startsWith('http')) {
        try {
          final file = File(localPath);
          if (!await file.exists()) continue;
          final fileName = "${item.data['user_id']}_${item.data['date']}_${const Uuid().v4()}.jpg";
          
          // ✅ Log Upload Size
          final fileSize = await file.length();
          LoggerService.info("📸 Uploading image (${_formatSize(fileSize)})...");

          await _client.storage.from('attendance_proofs').upload(fileName, file);
          final publicUrl = _client.storage.from('attendance_proofs').getPublicUrl(fileName);
          item.data['proof_image'] = publicUrl;
          await item.save(); 
        } catch (e) {
          LoggerService.error("❌ Proof Upload Failed: $e");
        }
      }
    }
  }

  static Future<void> forceLocalToCloud() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw Exception("No internet connection. Cannot sync.");
    }

    LoggerService.info("🚀 Starting Force Push to Cloud...");

    Future<void> queueSilent(String table, Map<String, dynamic> data) async {
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
      await queueSilent('users', {
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
      await queueSilent('ingredients', item.toJson());
    }

    // 3. Products
    final prodBox = Hive.box<ProductModel>('products');
    for (var item in prodBox.values) {
      await queueSilent('products', item.toJson());
    }

    // 4. Transactions
    final txnBox = Hive.box<TransactionModel>('transactions');
    for (var item in txnBox.values) {
       await queueSilent('transactions', {
        'id': item.id,
        'date_time': item.dateTime.toIso8601String(),
        'total_amount': item.totalAmount,
        'tendered_amount': item.tenderedAmount,
        'payment_method': item.paymentMethod,
        'cashier_name': item.cashierName,
        'status': item.status.name,
        'is_void': item.isVoid,
        'reference_no': item.referenceNo,
        'order_type': item.orderType,
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
      await queueSilent('attendance_logs', {
        'id': item.id,
        'user_id': item.userId,
        'date': item.date.toIso8601String(),
        'time_in': item.timeIn.toIso8601String(),
        'time_out': item.timeOut?.toIso8601String(),
        'break_start': item.breakStart?.toIso8601String(),
        'break_end': item.breakEnd?.toIso8601String(),
        'status': item.status.name,
        'hourly_rate_snapshot': item.hourlyRateSnapshot,
        'proof_image': item.proofImage,
        'is_verified': item.isVerified,
        'rejection_reason': item.rejectionReason,
      });
    }

    // 6. Inventory Logs
    final logBox = Hive.box<InventoryLogModel>('inventory_logs');
    for (var item in logBox.values) {
      await queueSilent('inventory_logs', {
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

    LoggerService.info("✅ All local data queued. Triggering batch sync...");
    
    processQueue();
  }

  static Future<void> restoreFromCloud() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      throw Exception("No internet connection. Cannot restore.");
    }

    if (_queueBox != null && _queueBox!.isNotEmpty) {
      throw Exception("Unsynced local changes detected. Please wait for auto-sync to finish before restoring.");
    }

    _isSyncing = true;
    LoggerService.info("☁️ Starting Cloud Restore...");

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

      // 3. PRODUCTS
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

      // 4. ATTENDANCE
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
          proofImage: map['proof_image'],
          isVerified: map['is_verified'] ?? false,
          rejectionReason: map['rejection_reason'],
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

      // 6. TRANSACTIONS
      final txnData = await _client.from('transactions').select();
      final txnBox = Hive.box<TransactionModel>('transactions');
      final productBox = Hive.box<ProductModel>('products'); 
      
      await txnBox.clear();

      for (final map in txnData) {
        final statusEnum = OrderStatus.values.firstWhere(
          (e) => e.name == map['status'], orElse: () => OrderStatus.served
        );

        List<CartItemModel> cartItems = [];
        if (map['items'] != null) {
          final rawItems = List<dynamic>.from(map['items']);
          for (final itemMap in rawItems) {
            ProductModel? product;
            try {
              product = productBox.values.firstWhere((p) => p.name == itemMap['product_name']);
            } catch (_) {
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
          orderType: map['order_type'] ?? 'dineIn', 
        );
        await txnBox.put(txn.id, txn);
      }
      LoggerService.info("✅ Restored ${txnData.length} transactions.");

      LoggerService.info("🎉 FULL CLOUD RESTORE COMPLETE!");
      
    } catch (e) {
      LoggerService.error("❌ Restore Failed: $e");
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }
}