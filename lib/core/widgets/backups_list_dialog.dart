import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';
import '../utils/dialog_utils.dart';
import 'basic_button.dart';

class BackupsListDialog extends StatefulWidget {
  final BackupService backupService;
  final String type; // 'ingredients' or 'logs'

  const BackupsListDialog({
    super.key,
    required this.backupService,
    required this.type,
  });

  @override
  State<BackupsListDialog> createState() => _BackupsListDialogState();
}

class _BackupsListDialogState extends State<BackupsListDialog> {
  List<BackupEntry> _entries = [];
  String? _selectedFilename;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.backupService.listBackups(type: widget.type);
    if (mounted) {
      setState(() {
        _entries = list;
        _loading = false;
        _selectedFilename = null;
      });
    }
  }

  Future<void> _handleRestore() async {
    if (_selectedFilename == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Restore"),
        content: Text("This will OVERWRITE all current ${widget.type}. This cannot be undone.\n\nAre you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Restore", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.backupService.restoreBackup(_selectedFilename!, widget.type);
        if (mounted) {
          DialogUtils.showToast(context, "Restore successful!");
          Navigator.pop(context, true); // Return true to trigger refresh
        }
      } catch (e) {
        if (mounted) DialogUtils.showToast(context, "Restore failed: $e", icon: Icons.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Restore ${widget.type[0].toUpperCase()}${widget.type.substring(1)}",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 4),
            const Text("Select a backup file to restore.", style: TextStyle(color: Colors.grey)),
            const Divider(height: 30),

            // List
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty 
                    ? const Center(child: Text("No backups found."))
                    : ListView.builder(
                        itemCount: _entries.length,
                        itemBuilder: (context, index) {
                          final entry = _entries[index];
                          final isSelected = entry.filename == _selectedFilename;
                          final dateStr = DateFormat('MMM dd, yyyy - hh:mm a').format(entry.createdAt);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green.shade50 : Colors.white,
                              border: Border.all(color: isSelected ? Colors.green : Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              onTap: () => setState(() => _selectedFilename = entry.filename),
                              leading: Icon(Icons.history, color: isSelected ? Colors.green : Colors.grey),
                              title: Text(entry.filename, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text("$dateStr • ${entry.count} items"),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () async {
                                  await widget.backupService.deleteBackup(entry.filename);
                                  _load();
                                },
                              ),
                            ),
                          );
                        },
                      ),
            ),

            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                BasicButton(
                  label: "Cancel",
                  type: AppButtonType.secondary,
                  onPressed: () => Navigator.pop(context),
                  fullWidth: false,
                ),
                const SizedBox(width: 12),
                BasicButton(
                  label: "Restore Selected",
                  type: AppButtonType.danger,
                  onPressed: _selectedFilename != null ? _handleRestore : null,
                  fullWidth: false,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
