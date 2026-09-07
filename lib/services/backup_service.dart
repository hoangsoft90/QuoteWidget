import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/backup_data.dart';
import '../models/collection_model.dart';
import '../models/item_model.dart';
import 'storage_service.dart';
import 'snapshot_manager.dart';

class BackupService {
  final StorageService _storageService;
  final SnapshotManager _snapshotManager;

  BackupService(this._storageService, this._snapshotManager);

  /// Export all data to JSON file.
  ///
  /// V1 semantics (Phase 1 P0-3): backups carry Collections + Items ONLY.
  /// Active WidgetConfigs are never serialized (the schema field stays as an
  /// empty list) — a physical Home Screen widget cannot travel in a JSON file,
  /// and restoring configs with no matching appWidgetId creates phantom configs
  /// that block the Free limit / show stale content.
  Future<String> exportBackup() async {
    final collections = _storageService.getAllCollections();
    final items = _storageService.getAllItems();

    final backup = BackupData.create(
      collections: collections,
      items: items,
      // Intentionally empty: widget configs are device-bound, not backup data.
      widgetConfigs: const [],
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

      // Validate required fields. `widgetConfigs` is OPTIONAL (V1 semantics,
      // Phase 1 P0-3): new exports write it as an empty list, old files may
      // carry configs — either way the content is IGNORED on restore.
      if (data['schemaVersion'] == null) {
        return ImportResult(
          success: false,
          message: 'Missing schema version',
        );
      }

      if (data['collections'] == null || data['items'] == null) {
        return ImportResult(
          success: false,
          message: 'Missing required fields',
        );
      }

      // Parse data. widgetConfigs in the file are intentionally DROPPED —
      // restoring them would create phantom Hive configs with no physical
      // widget (V1 semantics, Phase 1 P0-3).
      List<Collection> collections;
      List<Item> items;

      try {
        collections = (data['collections'] as List)
            .map((c) => Collection.fromJson(c as Map<String, dynamic>))
            .toList();
        items = (data['items'] as List)
            .map((i) => Item.fromJson(i as Map<String, dynamic>))
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

      collections = collections.where((c) => seenCollectionIds.add(c.id)).toList();
      items = items.where((i) => seenItemIds.add(i.id)).toList();

      // Validate item references
      final validCollectionIds = collections.map((c) => c.id).toSet();
      items = items.where((i) => validCollectionIds.contains(i.collectionId)).toList();

      // Overwrite mode: create safety snapshot first
      if (overwrite) {
        await _snapshotManager.createSnapshot(
          collections: _storageService.getAllCollections(),
          items: _storageService.getAllItems(),
        );

        try {
          await _storageService.restoreFromBackup(
            collections: collections,
            items: items,
            // Never restore widget configs from a backup file (no phantom).
            widgetConfigs: const [],
          );
          // A6: reconcile + refresh widgets immediately — every surviving
          // native widget's mapping just went orphaned (Hive was wiped).
          await _storageService.reconcileAfterRestore();
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
          // Never restore widget configs from a backup file (no phantom).
          widgetConfigs: const [],
        );
        // A6: widgets may show stale content after new data lands — refresh.
        await _storageService.reconcileAfterRestore();
      }

      return ImportResult(
        success: true,
        message: 'Import successful',
        collectionsImported: collections.length,
        itemsImported: items.length,
        // V1 semantics (Phase 1 P0-3): widget configs are never restored.
        widgetConfigsImported: 0,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: 'Import failed: $e',
      );
    }
  }

  // ==================== B2: single-collection export/import ====================

  /// B2: export ONE collection + its items to a `.json` file (no
  /// WidgetConfig — device-bound, same rule as full backups).
  /// Returns the written file path.
  Future<String> exportCollection(String collectionId) async {
    final collection = _storageService.getCollection(collectionId);
    if (collection == null) {
      throw StateError('Collection not found');
    }
    final items = _storageService.getItemsForCollection(collectionId);

    final payload = {
      'backupFormat': 'quote-widget-collection',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'collection': collection.toJson(),
      'items': items.map((i) => i.toJson()).toList(),
    };

    final directory = await getTemporaryDirectory();
    final timestamp =
        DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final safeName = collection.name.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    final file = File(
        '${directory.path}/quotewidget-$safeName-$timestamp.json');
    await file.writeAsString(jsonEncode(payload));
    return file.path;
  }

  /// Parsed preview of a collection-export file (for the confirm step).
  static Future<CollectionImportPreview> previewCollectionImport(
      String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('File not found');
    }
    final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (data['backupFormat'] != 'quote-widget-collection') {
      throw FormatException('Not a collection export file');
    }
    final collection =
        Collection.fromJson(data['collection'] as Map<String, dynamic>);
    final items = (data['items'] as List)
        .map((i) => Item.fromJson(i as Map<String, dynamic>))
        .toList();
    return CollectionImportPreview(collection: collection, items: items);
  }

  /// B2: import a collection-export file. Either create a NEW collection
  /// from the file ([targetCollectionId] null — always gets a fresh id so a
  /// same-named collection never collides), or append the items into an
  /// EXISTING collection (new item ids — no overwrite of current content).
  Future<ImportResult> importCollection({
    required String filePath,
    String? targetCollectionId,
  }) async {
    try {
      final preview = await previewCollectionImport(filePath);

      if (targetCollectionId == null) {
        final created = await _storageService
            .createCollection('${preview.collection.name} (imported)');
        var order = 0;
        for (final item in preview.items) {
          await _storageService.createItem(
            collectionId: created.id,
            text: item.text,
            order: order++,
            author: item.author,
          );
        }
        return ImportResult(
          success: true,
          message:
              'Created "${created.name}" with ${preview.items.length} items',
          collectionsImported: 1,
          itemsImported: preview.items.length,
        );
      }

      final target = _storageService.getCollection(targetCollectionId);
      if (target == null) {
        return ImportResult(
            success: false, message: 'Target collection not found');
      }
      var order = _storageService.getItemCountForCollection(target.id);
      for (final item in preview.items) {
        await _storageService.createItem(
          collectionId: target.id,
          text: item.text,
          order: order++,
          author: item.author,
        );
      }
      return ImportResult(
        success: true,
        message: 'Added ${preview.items.length} items to "${target.name}"',
        itemsImported: preview.items.length,
      );
    } catch (e) {
      return ImportResult(success: false, message: 'Import failed: $e');
    }
  }
}

/// B2: in-memory preview used by the confirm dialog before writing anything.
class CollectionImportPreview {
  final Collection collection;
  final List<Item> items;
  const CollectionImportPreview({required this.collection, required this.items});
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
