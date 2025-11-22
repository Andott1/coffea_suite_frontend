import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/sync_queue_model.dart';

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
}