import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart'; // Ensure this is added to pubspec if needed, or use basic string formatting
import '../../core/models/ingredient_model.dart';
import '../../core/models/inventory_log_model.dart'; // ✅ Import Log Model
import 'hive_service.dart'; // ✅ Import HiveService for box access

class BackupEntry {
  final String filename;
  final DateTime createdAt;
  final int count;
  final String type; // ✅ NEW: 'ingredients' or 'logs'

  BackupEntry({
    required this.filename,
    required this.createdAt,
    required this.count,
    this.type = 'ingredients', // Default for backward compatibility
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'createdAt': createdAt.toIso8601String(),
        'count': count,
        'type': type,
      };

  factory BackupEntry.fromJson(Map<String, dynamic> j) => BackupEntry(
        filename: j['filename'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        count: (j['count'] as num).toInt(),
        type: j['type'] ?? 'ingredients',
      );
}

class BackupService {
  static const String _backupDirName = 'coffea_backups';
  static const String _metadataFileName = 'metadata.json';

  Future<Directory> _ensureBackupDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${dir.path}/$_backupDirName');
    if (!(await backupDir.exists())) await backupDir.create(recursive: true);
    return backupDir;
  }

  Future<File> _metadataFile() async {
    final d = await _ensureBackupDir();
    return File('${d.path}/$_metadataFileName');
  }

  /// List backups, optionally filtered by type
  Future<List<BackupEntry>> listBackups({String? type}) async {
    try {
      final mf = await _metadataFile();
      if (!await mf.exists()) return [];
      final text = await mf.readAsString();
      final List<dynamic> arr = jsonDecode(text);
      
      var list = arr.map((e) => BackupEntry.fromJson(e as Map<String, dynamic>)).toList();
      
      if (type != null) {
        list = list.where((e) => e.type == type).toList();
      }
      
      // Sort newest first
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeMetadata(List<BackupEntry> entries) async {
    final mf = await _metadataFile();
    // We need to read existing ones first to ensure we don't lose other types if we were filtering? 
    // Actually, simpler strategy: define a master read/write. 
    // The listBackups() reads all. When we add one, we should prepend to the FULL list.
    
    // Re-read full list to be safe
    final fullList = await listBackups(); 
    
    // Merge logic is tricky if we just passed a partial list. 
    // Better architecture: _writeMetadata accepts the full new list.
    // For this implementation, let's assume we fetch all, insert new, and write all.
    final jsonText = jsonEncode(entries.map((e) => e.toJson()).toList());
    await mf.writeAsString(jsonText);
  }

  String _defaultFileNameForNow(String type) {
    final now = DateTime.now();
    final timestamp = "${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}${now.minute.toString().padLeft(2,'0')}";
    return '${type}_backup_$timestamp.json';
  }

  /// Create a backup (Ingredients or Logs)
  Future<BackupEntry> createBackup({String? fileName, String type = 'ingredients'}) async {
    final backupDir = await _ensureBackupDir();
    
    // 1. Select Data Source
    List<Map<String, dynamic>> dump = [];
    
    if (type == 'ingredients') {
      final box = HiveService.ingredientBox;
      dump = box.values.map((v) => v.toJson()).toList();
    } else if (type == 'logs') {
      final box = HiveService.logsBox;
      // HiveObject toJson might need manual handling if the model doesn't have it, 
      // but we should add toJson to InventoryLogModel.
      // Assuming we will add toJson to InventoryLogModel in next step.
       dump = box.values.map((v) {
         // Manual map if toJson missing, but let's assume we add it.
         return {
           'id': v.id,
           'dateTime': v.dateTime.toIso8601String(),
           'ingredientName': v.ingredientName,
           'action': v.action,
           'changeAmount': v.changeAmount,
           'unit': v.unit,
           'userName': v.userName,
           'reason': v.reason,
         };
       }).toList();
    }

    // 2. Write File
    final name = (fileName == null || fileName.trim().isEmpty)
        ? _defaultFileNameForNow(type)
        : (fileName.endsWith('.json') ? fileName : '$fileName.json');

    final file = File('${backupDir.path}/$name');
    await file.writeAsString(jsonEncode(dump));

    // 3. Update Metadata
    final allEntries = await listBackups(); // Get ALL types
    final newEntry = BackupEntry(
      filename: name,
      createdAt: DateTime.now(),
      count: dump.length,
      type: type,
    );
    allEntries.insert(0, newEntry); // Prepend
    await _writeMetadata(allEntries);

    return newEntry;
  }

  Future<void> restoreBackup(String filename, String type) async {
    final backupDir = await _ensureBackupDir();
    final file = File('${backupDir.path}/$filename');
    if (!await file.exists()) throw Exception('Backup file not found');

    final jsonString = await file.readAsString();
    final List<dynamic> data = jsonDecode(jsonString);

    if (type == 'ingredients') {
      final box = HiveService.ingredientBox;
      await box.clear();
      for (final item in data) {
        final ingredient = IngredientModel.fromJson(Map<String, dynamic>.from(item));
        await box.put(ingredient.id, ingredient);
      }
    } else if (type == 'logs') {
      final box = HiveService.logsBox;
      await box.clear();
      for (final item in data) {
        final map = Map<String, dynamic>.from(item);
        final log = InventoryLogModel(
          id: map['id'],
          dateTime: DateTime.parse(map['dateTime']),
          ingredientName: map['ingredientName'],
          action: map['action'],
          changeAmount: (map['changeAmount'] as num).toDouble(),
          unit: map['unit'],
          userName: map['userName'],
          reason: map['reason'],
        );
        await box.add(log);
      }
    }
  }

  Future<void> deleteBackup(String filename) async {
    final backupDir = await _ensureBackupDir();
    final file = File('${backupDir.path}/$filename');
    if (await file.exists()) await file.delete();

    final entries = await listBackups();
    entries.removeWhere((entry) => entry.filename == filename);
    await _writeMetadata(entries);
  }
  
  // ─────────────────────────────────────────
  // CSV EXPORT FEATURE (UPDATED)
  // ─────────────────────────────────────────
  Future<String> exportLogsToCSV() async {
    final box = HiveService.logsBox;
    final logs = box.values.toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime)); 

    // Header
    final buffer = StringBuffer();
    buffer.writeln("Date,Time,Item Name,Action,Quantity,Unit,User,Reason");

    // Rows
    for (final log in logs) {
      final date = "${log.dateTime.year}-${log.dateTime.month}-${log.dateTime.day}";
      final time = "${log.dateTime.hour}:${log.dateTime.minute}";
      
      final cleanName = log.ingredientName.replaceAll(',', ' ');
      final cleanReason = log.reason.replaceAll(',', ' ');
      final cleanUser = log.userName.replaceAll(',', ' ');

      buffer.writeln("$date,$time,$cleanName,${log.action},${log.changeAmount},${log.unit},$cleanUser,$cleanReason");
    }

    // ✅ FIX: Determine correct public path
    String path;
    if (Platform.isAndroid) {
      // Target public Downloads folder directly
      path = "/storage/emulated/0/Download";
    } else {
      // Fallback for iOS/Desktop
      final dir = await getApplicationDocumentsDirectory();
      path = dir.path;
    }

    // Ensure directory exists (rare case on Android where Download might be missing)
    final dir = Directory(path);
    if (!await dir.exists()) {
       // If standard Download folder fails, fallback to App Documents
       final fallback = await getApplicationDocumentsDirectory();
       path = fallback.path;
    }

    final filename = "coffea_logs_${DateTime.now().millisecondsSinceEpoch}.csv";
    final file = File('$path/$filename');
    
    await file.writeAsString(buffer.toString());
    
    return file.path;
  }
}
