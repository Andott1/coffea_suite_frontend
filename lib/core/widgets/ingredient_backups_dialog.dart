import 'package:flutter/material.dart';
import '../services/backup_service.dart';

/// =============================================================
/// IngredientBackupsDialog
/// -------------------------------------------------------------
/// - Lists all saved backups.
/// - Allows restore of one backup at a time.
/// - Optional “Delete Mode” for removing old backups.
/// =============================================================
class IngredientBackupsDialog extends StatefulWidget {
  final BackupService backupService;

  const IngredientBackupsDialog({
    required this.backupService,
    Key? key,
  }) : super(key: key);

  @override
  State<IngredientBackupsDialog> createState() =>
      _IngredientBackupsDialogState();
}

class _IngredientBackupsDialogState extends State<IngredientBackupsDialog> {
  List<BackupEntry> _entries = [];
  String? _selectedFilename;
  bool _loading = true;
  bool _deleteMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await widget.backupService.listBackups();
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasBackups = _entries.isNotEmpty;
    final canRestore = hasBackups && _selectedFilename != null && !_deleteMode;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SizedBox(
        width: 720,
        height: 520,
        child: Column(
          children: [
            // ─────────────────────────── Header ───────────────────────────
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Restore from Backup',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _deleteMode ? 'Exit delete mode' : 'Manage backups',
                    icon: Icon(
                      _deleteMode ? Icons.close : Icons.edit,
                      color: _deleteMode ? Colors.redAccent : Colors.black87,
                    ),
                    onPressed: () => setState(() => _deleteMode = !_deleteMode),
                  ),
                  IconButton(
                    tooltip: 'Refresh list',
                    icon: const Icon(Icons.refresh),
                    onPressed: _load,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ─────────────────────────── Content ───────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !hasBackups
                      ? const Center(child: Text('No backups found'))
                      : Scrollbar(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _entries.length,
                            itemBuilder: (context, i) {
                              final e = _entries[i];
                              final selected = e.filename == _selectedFilename;

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (_deleteMode)
                                    IconButton(
                                      tooltip: 'Delete this backup',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        final confirm =
                                            await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Delete Backup'),
                                            content: Text(
                                              'Are you sure you want to delete "${e.filename}"?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.redAccent),
                                                onPressed: () =>
                                                    Navigator.pop(context, true),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await widget.backupService
                                              .deleteBackup(e.filename);
                                          await _load();
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Backup "${e.filename}" deleted'),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  // Backup card
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        if (!_deleteMode) {
                                          setState(() =>
                                              _selectedFilename = e.filename);
                                        }
                                      },
                                      child: Card(
                                        elevation: selected ? 5 : 1,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          side: BorderSide(
                                            color: selected
                                                ? Colors.green
                                                : Colors.transparent,
                                            width: selected ? 2 : 1,
                                          ),
                                        ),
                                        child: ListTile(
                                          title: Text(e.filename),
                                          subtitle: Text(
                                            'Created: ${e.createdAt.toLocal()}  •  ${e.count} items',
                                          ),
                                          trailing: _deleteMode
                                              ? null
                                              : selected
                                                  ? const Icon(
                                                      Icons.check_circle,
                                                      color: Colors.green,
                                                    )
                                                  : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
            ),

            // ─────────────────────────── Footer ───────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: canRestore
                        ? () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Confirm Restore'),
                                content: const Text(
                                  'Restoring will overwrite all current ingredients. Proceed?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: const Text('Restore'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await widget.backupService
                                  .restoreBackup(_selectedFilename!);
                              if (mounted) Navigator.of(context).pop(true);
                            }
                          }
                        : null,
                    child: const Text('Restore'),
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
