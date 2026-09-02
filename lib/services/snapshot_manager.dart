import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/collection_model.dart';
import '../models/item_model.dart';
import '../models/widget_config_model.dart';
import '../models/backup_data.dart';
import 'storage_service.dart';

class SnapshotManager {
  static const int _maxSnapshots = 3;
  static const String _snapshotDirName = 'safety_snapshots';

  /// Create a safety snapshot of current data
  Future<String> createSnapshot({
    required List<Collection> collections,
    required List<Item> items,
    required List<WidgetConfig> widgetConfigs,
  }) async {
    final directory = await _getApplicationDocumentsDirectory();
    final snapshotDir = Directory('${directory.path}/$_snapshotDirName');

    if (!await snapshotDir.exists()) {
      await snapshotDir.create(recursive: true);
    }

    // Create backup data
    final backup = BackupData.create(
      collections: collections,
      items: items,
      widgetConfigs: widgetConfigs,
    );

    final json = jsonEncode(backup.toJson());

    // Create snapshot file with timestamp
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${snapshotDir.path}/snapshot-$timestamp.json');
    await file.writeAsString(json);

    // Cleanup old snapshots if we exceed max
    await _cleanupOldSnapshots(snapshotDir);

    return file.path;
  }

  /// List available snapshots
  Future<List<SnapshotInfo>> listSnapshots() async {
    final directory = await _getApplicationDocumentsDirectory();
    final snapshotDir = Directory('${directory.path}/$_snapshotDirName');

    if (!await snapshotDir.exists()) {
      return [];
    }

    final files = await snapshotDir.list().where((entity) => entity is File).toList();
    final snapshots = <SnapshotInfo>[];

    for (final file in files) {
      if (file is File && file.path.endsWith('.json')) {
        final stat = await file.stat();
        snapshots.add(SnapshotInfo(
          path: file.path,
          timestamp: stat.modified,
          size: stat.size,
        ));
      }
    }

    // Sort by timestamp, newest first
    snapshots.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return snapshots;
  }

  /// Restore from a specific snapshot
  Future<void> restoreFromSnapshot(String snapshotPath, StorageService storageService) async {
    final file = File(snapshotPath);
    if (!await file.exists()) {
      throw Exception('Snapshot file not found');
    }

    final json = await file.readAsString();
    final data = jsonDecode(json) as Map<String, dynamic>;

    final backup = BackupData.fromJson(data);

    await storageService.restoreFromBackup(
      collections: backup.collections,
      items: backup.items,
      widgetConfigs: backup.widgetConfigs,
    );
  }

  /// Restore from the latest snapshot
  Future<void> restoreLatestSnapshot(StorageService storageService) async {
    final snapshots = await listSnapshots();
    if (snapshots.isEmpty) {
      throw Exception('No snapshots available');
    }

    await restoreFromSnapshot(snapshots.first.path, storageService);
  }

  /// Delete a specific snapshot
  Future<void> deleteSnapshot(String snapshotPath) async {
    final file = File(snapshotPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Cleanup old snapshots, keeping only maxSnapshots
  Future<void> _cleanupOldSnapshots(Directory snapshotDir) async {
    final snapshots = await listSnapshots();
    if (snapshots.length > _maxSnapshots) {
      for (int i = _maxSnapshots; i < snapshots.length; i++) {
        await deleteSnapshot(snapshots[i].path);
      }
    }
  }

  Future<Directory> _getApplicationDocumentsDirectory() async {
    return await getApplicationDocumentsDirectory();
  }
}

class SnapshotInfo {
  final String path;
  final DateTime timestamp;
  final int size;

  SnapshotInfo({
    required this.path,
    required this.timestamp,
    required this.size,
  });

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
