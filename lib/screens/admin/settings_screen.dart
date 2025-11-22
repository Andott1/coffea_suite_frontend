import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/bloc/connectivity/connectivity_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/sync_queue_model.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/container_card_titled.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRestoring = false;
  bool _isPushing = false;

  Future<void> _handleForcePush() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🚀 Upload Local Data?"),
        content: const Text(
          "This will take ALL data currently on this device (Seeded Data, Transactions, Logs) "
          "and upload it to Supabase.\n\n"
          "Use this if your cloud database is empty or out of sync.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: ThemeConfig.primaryGreen),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Start Upload", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPushing = true);

    try {
      await SupabaseSyncService.forceLocalToCloud();
      if (mounted) {
        DialogUtils.showToast(context, "Upload started! Check the queue indicator.");
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showToast(context, "Upload Failed: ${e.toString()}", icon: Icons.error, accentColor: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isPushing = false);
    }
  }

  Future<void> _handleRestore() async {
    // 1. Confirm Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Overwrite Local Data?"),
        content: const Text(
          "This will DELETE all local data (Users, Products, Stock, Logs) "
          "and replace it with the latest data from Supabase Cloud.\n\n"
          "This cannot be undone. Are you sure?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Yes, Overwrite", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);

    try {
      await SupabaseSyncService.restoreFromCloud();
      if (mounted) {
        DialogUtils.showToast(context, "Data successfully restored from Cloud!");
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showToast(context, "Restore Failed: ${e.toString()}", icon: Icons.error, accentColor: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── HEADER ───
            Text("System Settings", style: FontConfig.h2(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            // ─── CLOUD SYNC PANEL ───
            ContainerCardTitled(
              title: "Cloud Synchronization",
              subtitle: "Manage connection between this device and Supabase Cloud",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STATUS INDICATORS
                  Row(
                    children: [
                      _ConnectionStatusBadge(),
                      const SizedBox(width: 12),
                      _QueueStatusBadge(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // ACTIONS
                  const Text(
                    "Data Synchronization", 
                    style: TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.secondaryGreen)
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Manage the flow of data between this device and the cloud.",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      // PUSH BUTTON
                      _isPushing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                        : BasicButton(
                            label: "Push Local to Cloud",
                            icon: Icons.cloud_upload_outlined,
                            type: AppButtonType.primary,
                            onPressed: _handleForcePush,
                            fullWidth: false,
                          ),
                          
                      const SizedBox(width: 16),

                      // RESTORE BUTTON
                      _isRestoring 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator())
                        : BasicButton(
                            label: "Restore from Cloud",
                            icon: Icons.cloud_download_outlined,
                            type: AppButtonType.danger,
                            onPressed: _handleRestore,
                            fullWidth: false,
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────── HELPER WIDGETS ────────────────

class _ConnectionStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, bool>(
      builder: (context, isOnline) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isOnline ? Colors.green : Colors.red),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 16, color: isOnline ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(
                isOnline ? "ONLINE" : "OFFLINE",
                style: TextStyle(fontWeight: FontWeight.bold, color: isOnline ? Colors.green : Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QueueStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<SyncQueueModel>('sync_queue').listenable(),
      builder: (context, Box<SyncQueueModel> box, _) {
        final count = box.length;
        final isSyncing = count > 0;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSyncing ? Colors.orange.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSyncing ? Colors.orange : Colors.blue),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncing) 
                const SizedBox(
                  width: 12, height: 12, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                )
              else 
                const Icon(Icons.check_circle, size: 16, color: Colors.blue),
              
              const SizedBox(width: 8),
              
              Text(
                isSyncing ? "$count Pending Uploads..." : "All Synced",
                style: TextStyle(fontWeight: FontWeight.bold, color: isSyncing ? Colors.orange : Colors.blue),
              ),
            ],
          ),
        );
      }
    );
  }
}