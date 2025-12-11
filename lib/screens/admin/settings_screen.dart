import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/sync_queue_model.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/services/backup_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/bloc/connectivity/connectivity_cubit.dart';

// Widgets
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/backups_list_dialog.dart';
import 'database_viewer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRestoring = false;
  bool _isPushing = false;

  // ──────────────── CLOUD ACTIONS ────────────────
  
  Future<void> _handleForcePush() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🚀 Upload Local Data?"),
        content: const Text(
          "This will FORCE UPLOAD all local data to the cloud.\n"
          "Use this if the cloud database is empty or out of sync.",
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
      if (mounted) DialogUtils.showToast(context, "Upload started! Check queue.");
    } catch (e) {
      if (mounted) DialogUtils.showToast(context, "Error: $e", icon: Icons.error, accentColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isPushing = false);
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("⚠️ Overwrite Local Data?"),
        content: const Text(
          "This will DELETE all local data and replace it with Cloud data.\n"
          "This cannot be undone. Are you sure?",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Overwrite", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRestoring = true);
    try {
      await SupabaseSyncService.restoreFromCloud();
      if (mounted) DialogUtils.showToast(context, "Data restored from Cloud!");
    } catch (e) {
      if (mounted) DialogUtils.showToast(context, "Error: $e", icon: Icons.error, accentColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // ──────────────── LOCAL BACKUP ACTIONS ────────────────

  Future<void> _createLocalBackup(String type) async {
    final service = BackupService();
    final filename = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text('Create $type Backup'),
          content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Filename (Optional)')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
          ],
        );
      },
    );

    if (filename != null) {
      try {
        final entry = await service.createBackup(fileName: filename, type: type.toLowerCase());
        if (mounted) DialogUtils.showToast(context, 'Saved: ${entry.filename}');
      } catch (e) {
        if (mounted) DialogUtils.showToast(context, 'Failed: $e', icon: Icons.error);
      }
    }
  }

  Future<void> _restoreLocalBackup(String type) async {
    await showDialog(
      context: context,
      builder: (_) => BackupsListDialog(backupService: BackupService(), type: type.toLowerCase()),
    );
  }

  // ──────────────── UI BUILD ────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TITLE
            Row(
              children: [
                const Icon(Icons.settings, size: 32, color: Colors.black87),
                const SizedBox(width: 12),
                Text("System Settings", style: FontConfig.h2(context).copyWith(fontSize: 28, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 24),

            // MAIN GRID (2 Columns)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── LEFT COL: CLOUD & SYNC ───
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      _buildCloudSection(),
                      const SizedBox(height: 24),
                      _buildDiagnosticsSection(),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // ─── RIGHT COL: DATA MANAGEMENT ───
                Expanded(
                  flex: 4,
                  child: _buildLocalDataSection(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── SECTION WIDGETS ────────────────

  Widget _buildCloudSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _flatDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Cloud Synchronization", style: FontConfig.h3(context)),
              const _ConnectionStatusBadge(),
            ],
          ),
          const SizedBox(height: 8),
          const Text("Manage data flow between this device and the central server.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),

          // SYNC QUEUE STATUS
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_queue, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: Hive.box<SyncQueueModel>('sync_queue').listenable(),
                    builder: (context, Box<SyncQueueModel> box, _) {
                      final count = box.length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count == 0 ? "All changes synced" : "$count pending changes",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                          Text(
                            count == 0 ? "Your data is up to date." : "Syncing in background...",
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_isPushing || _isRestoring)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ACTIONS
          Row(
            children: [
              Expanded(
                child: BasicButton(
                  label: "Push to Cloud",
                  icon: Icons.cloud_upload_outlined,
                  type: AppButtonType.primary,
                  onPressed: _isPushing || _isRestoring ? null : _handleForcePush,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: BasicButton(
                  label: "Restore",
                  icon: Icons.cloud_download_outlined,
                  type: AppButtonType.secondary,
                  onPressed: _isPushing || _isRestoring ? null : _handleRestore,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLocalDataSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _flatDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Local Backups", style: FontConfig.h3(context)),
          const SizedBox(height: 8),
          const Text("Create offline snapshots of your data.", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),

          _buildBackupTile(
            title: "Ingredients & Stock",
            subtitle: "Inventory levels and item details",
            icon: Icons.science_outlined,
            color: Colors.orange,
            onBackup: () => _createLocalBackup("Ingredients"),
            onRestore: () => _restoreLocalBackup("Ingredients"),
          ),
          const SizedBox(height: 20),
          _buildBackupTile(
            title: "Operation Logs",
            subtitle: "Inventory movement history",
            icon: Icons.history_edu,
            color: Colors.purple,
            onBackup: () => _createLocalBackup("Logs"),
            onRestore: () => _restoreLocalBackup("Logs"),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticsSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _flatDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("System Diagnostics", style: FontConfig.h3(context)),
          const SizedBox(height: 20),
          
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storage, color: Colors.black87),
            ),
            title: const Text("Database Inspector", style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("View raw data in local Hive boxes"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DatabaseViewerScreen()));
            },
          ),
        ],
      ),
    );
  }

  // ──────────────── HELPER WIDGETS ────────────────

  Widget _buildBackupTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onBackup,
    required VoidCallback onRestore,
  }) {
    return Container(
      padding: const EdgeInsets.all(20), // Increased inner padding
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12), // Larger Icon Background
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28), // Larger Icon
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), // Bigger Font
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              BasicButton(
                label: "Backup", 
                icon: Icons.save, 
                type: AppButtonType.secondary, // Secondary style is clearer
                onPressed: onBackup,
                fullWidth: false,
                height: 42, // Tablet-friendly height
                fontSize: 14,
              ),
              const SizedBox(height: 8),
              BasicButton(
                label: "Restore", 
                icon: Icons.restore, 
                type: AppButtonType.danger, 
                onPressed: onRestore,
                fullWidth: false,
                height: 42, // Tablet-friendly height
                fontSize: 14,
              ),
            ],
          )
        ],
      ),
    );
  }

  BoxDecoration _flatDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 4,
          offset: const Offset(0, 2),
        )
      ],
    );
  }
}

// ──────────────── STATUS BADGES ────────────────

class _ConnectionStatusBadge extends StatelessWidget {
  const _ConnectionStatusBadge();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, bool>(
      builder: (context, isOnline) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isOnline ? Colors.green.shade200 : Colors.red.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 14, color: isOnline ? Colors.green : Colors.red),
              const SizedBox(width: 6),
              Text(
                isOnline ? "ONLINE" : "OFFLINE",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isOnline ? Colors.green : Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }
}