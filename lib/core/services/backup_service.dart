import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../../core/models/ingredient_model.dart';

/// =============================================================
/// BackupService
/// -------------------------------------------------------------
/// Handles creation, listing, deletion, and restoration of
/// ingredient backups. All data stored under ApplicationDocumentsDirectory.
/// =============================================================
class BackupEntry {
  final String filename;
  final DateTime createdAt;
  final int count;

  BackupEntry({
    required this.filename,
    required this.createdAt,
    required this.count,
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'createdAt': createdAt.toIso8601String(),
        'count': count,
      };

  factory BackupEntry.fromJson(Map<String, dynamic> j) => BackupEntry(
        filename: j['filename'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        count: (j['count'] as num).toInt(),
      );
}

class BackupService {
  static const String _backupDirName = 'coffea_backups';
  static const String _metadataFileName = 'metadata.json';

  // Ensures the backup directory exists
  Future<Directory> _ensureBackupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/$_backupDirName');
    if (!(await backupDir.exists())) await backupDir.create(recursive: true);
    return backupDir;
  }

  // Metadata file path
  Future<File> _metadataFile() async {
    final d = await _ensureBackupDir();
    return File('${d.path}/$_metadataFileName');
  }

  // Read all backup entries
  Future<List<BackupEntry>> listBackups() async {
    try {
      final mf = await _metadataFile();
      if (!await mf.exists()) return [];
      final text = await mf.readAsString();
      final List<dynamic> arr = jsonDecode(text);
      return arr.map((e) => BackupEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // Write metadata to file
  Future<void> _writeMetadata(List<BackupEntry> entries) async {
    final mf = await _metadataFile();
    final jsonText = jsonEncode(entries.map((e) => e.toJson()).toList());
    await mf.writeAsString(jsonText);
  }

  // Generate default backup filename
  String _defaultFileNameForNow() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    return 'backup-$y$m$d$hh$mm$ss.json';
  }

  // Create a backup file
  Future<BackupEntry> createBackup({String? fileName}) async {
    final backupDir = await _ensureBackupDir();
    final box = Hive.box<IngredientModel>('ingredients');
    final List<Map<String, dynamic>> dump = box.values.map((v) => v.toJson()).toList();

    final name = (fileName == null || fileName.trim().isEmpty)
        ? _defaultFileNameForNow()
        : (fileName.endsWith('.json') ? fileName : '$fileName.json');

    final file = File('${backupDir.path}/$name');
    await file.writeAsString(jsonEncode(dump));

    final entries = await listBackups();
    final entry = BackupEntry(
      filename: name,
      createdAt: DateTime.now(),
      count: dump.length,
    );

    entries.insert(0, entry);
    await _writeMetadata(entries);

    return entry;
  }

  // Restore a selected backup
  Future<void> restoreBackup(String filename) async {
    final backupDir = await _ensureBackupDir();
    final file = File('${backupDir.path}/$filename');
    if (!await file.exists()) throw Exception('Backup not found');

    final jsonString = await file.readAsString();
    final List<dynamic> data = jsonDecode(jsonString);

    final box = Hive.box<IngredientModel>('ingredients');
    await box.clear();

    for (final item in data) {
      final ingredient = IngredientModel.fromJson(Map<String, dynamic>.from(item));
      await box.put(ingredient.id, ingredient);
    }
  }

  // ✅ NEW: Delete backup and remove from metadata
  Future<void> deleteBackup(String filename) async {
    final backupDir = await _ensureBackupDir();
    final file = File('${backupDir.path}/$filename');

    // Delete backup file if it exists
    if (await file.exists()) {
      await file.delete();
    }

    // Remove from metadata
    final entries = await listBackups();
    entries.removeWhere((entry) => entry.filename == filename);
    await _writeMetadata(entries);
  }
}
