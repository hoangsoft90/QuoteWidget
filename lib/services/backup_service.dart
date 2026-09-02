import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/backup_data.dart';
import '../models/collection_model.dart';
import '../models/item_model.dart';
import '../models/widget_config_model.dart';
import 'storage_service.dart';
import 'snapshot_manager.dart';

class BackupService {
  final StorageService _storageService;
  final SnapshotManager _snapshotManager;

  BackupService(this._storageService, this._snapshotManager);

  /// Export all data to JSON file
  Future<String> exportBackup() async {
    final collections = _storageService.getAllCollections();
    final items = _storageService.getAllItems();
    final widgetConfigs = _storageService.getAllWidgetConfigs();

    final backup = BackupData.create(
      collections: collections,
      items: items,
      widgetConfigs: widgetConfigs,
    );

    final json = jsonEncode(backup.toJson());

    // Write to temporary file
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final file = File('${directory.path}/quotewidget-backup-$timestamp.json');
    await file.writeAsString(json);

    return file.path;
  }

  /// Share the backup file
  Future<void> shareBackup(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Quote Widget Backup',
    );
  }

  /// Import backup from file
  Future<ImportResult> importBackup({
    required String filePath,
    required bool overwrite,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(
          success: false,
          message: 'File not found',
        );
      }

      // Check file size (20MB limit)
      final fileSize = await file.length();
      if (fileSize > 20 * 1024 * 1024) {
        return ImportResult(
          success: false,
          message: 'File too large (max 20MB)',
        );
      }

      // Read and parse JSON
      final json = await file.readAsString();
      Map<String, dynamic> data;
      try {
        data = jsonDecode(json) as Map<String, dynamic>;
      } catch (e) {
        return ImportResult(
          success: false,
          message: 'Invalid JSON file',
        );
      }

      // Validate backup format
      if (data['backupFormat'] != 'quote-widget-backup') {
        return ImportResult(
          success: false,
          message: 'Invalid backup file format',
        );
      }

      // Validate required fields
      if (data['schemaVersion'] == null) {
        return ImportResult(
          success: false,
          message: 'Missing schema version',
        );
      }

      if (data['collections'] == null || data['items'] == null || data['widgetConfigs'] == null) {
        return ImportResult(
          success: false,
          message: 'Missing required fields',
        );
      }

      // Parse data
      List<Collection> collections;
      List<Item> items;
      List<WidgetConfig> widgetConfigs;

      try {
        collections = (data['collections'] as List)
            .map((c) => Collection.fromJson(c as Map<String, dynamic>))
            .toList();
        items = (data['items'] as List)
            .map((i) => Item.fromJson(i as Map<String, dynamic>))
            .toList();
        widgetConfigs = (data['widgetConfigs'] as List)
            .map((w) => WidgetConfig.fromJson(w as Map<String, dynamic>))
            .toList();
      } catch (e) {
        return ImportResult(
          success: false,
          message: 'Invalid data format: $e',
        );
      }

      // Deduplicate within backup file
      final seenCollectionIds = <String>{};
      final seenItemIds = <String>{};
      final seenConfigIds = <String>{};

      collections = collections.where((c) => seenCollectionIds.add(c.id)).toList();
      items = items.where((i) => seenItemIds.add(i.id)).toList();
      widgetConfigs = widgetConfigs.where((w) => seenConfigIds.add(w.id)).toList();

      // Validate item references
      final validCollectionIds = collections.map((c) => c.id).toSet();
      items = items.where((i) => validCollectionIds.contains(i.collectionId)).toList();

      // Overwrite mode: create safety snapshot first
      if (overwrite) {
        await _snapshotManager.createSnapshot(
          collections: _storageService.getAllCollections(),
          items: _storageService.getAllItems(),
          widgetConfigs: _storageService.getAllWidgetConfigs(),
        );

        try {
          await _storageService.restoreFromBackup(
            collections: collections,
            items: items,
            widgetConfigs: widgetConfigs,
          );
        } catch (e) {
          // Rollback on failure
          await _snapshotManager.restoreLatestSnapshot(_storageService);
          return ImportResult(
            success: false,
            message: 'Import failed. Previous data restored from safety snapshot.',
          );
        }
      } else {
        // Append mode
        await _storageService.appendFromBackup(
          collections: collections,
          items: items,
          widgetConfigs: widgetConfigs,
        );
      }

      return ImportResult(
        success: true,
        message: 'Import successful',
        collectionsImported: collections.length,
        itemsImported: items.length,
        widgetConfigsImported: widgetConfigs.length,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }
}

class ImportResult {
  final bool success;
  final String message;
  final int collectionsImported;
  final int itemsImported;
  final int widgetConfigsImported;

  ImportResult({
    required this.success,
    required this.message,
    this.collectionsImported = 0,
    this.itemsImported = 0,
    this.widgetConfigsImported = 0,
  });
}
