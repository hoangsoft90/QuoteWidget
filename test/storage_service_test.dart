import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quotewidget/models/collection_model.dart';
import 'package:quotewidget/models/item_model.dart';
import 'package:quotewidget/models/widget_config_model.dart';
import 'package:quotewidget/services/storage_service.dart';

void main() {
  late StorageService service;
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('quotewidget_test_');
    Hive.init(tempDir.path);
    // Adapters are registered by StorageService.init() — do NOT register here.
  });

  setUp(() async {
    service = StorageService();
    await service.init(testPath: tempDir.path);
  });

  tearDown(() async {
    await service.clearAll();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('Collection CRUD', () {
    test('create and retrieve collection', () async {
      final col = await service.createCollection('Test');
      expect(col.name, 'Test');
      expect(col.id.isNotEmpty, true);

      final retrieved = service.getCollection(col.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.name, 'Test');
    });

    test('getAllCollections returns sorted by createdAt descending', () async {
      await service.createCollection('First');
      // Small delay to ensure different timestamps
      await Future.delayed(const Duration(milliseconds: 10));
      final col2 = await service.createCollection('Second');

      final all = service.getAllCollections();
      expect(all.length, 2);
      expect(all.first.id, col2.id); // Most recent first
    });

    test('updateCollection changes name', () async {
      final col = await service.createCollection('Old Name');
      await service.updateCollection(col.id, 'New Name');

      final updated = service.getCollection(col.id);
      expect(updated!.name, 'New Name');
    });
  });

  group('Item CRUD', () {
    test('create and retrieve items for collection', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'Item 1', order: 0);
      await service.createItem(collectionId: col.id, text: 'Item 2', order: 1);

      final items = service.getItemsForCollection(col.id);
      expect(items.length, 2);
      expect(items[0].text, 'Item 1');
      expect(items[1].text, 'Item 2');
    });

    test('items sorted by order', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'B', order: 1);
      await service.createItem(collectionId: col.id, text: 'A', order: 0);

      final items = service.getItemsForCollection(col.id);
      expect(items[0].text, 'A');
      expect(items[1].text, 'B');
    });

    test('updateItem changes text', () async {
      final col = await service.createCollection('Test');
      final item = await service.createItem(collectionId: col.id, text: 'Old', order: 0);
      await service.updateItem(item.id, 'New');

      final updated = service.getItem(item.id);
      expect(updated!.text, 'New');
    });

    test('deleteItem removes item', () async {
      final col = await service.createCollection('Test');
      final item = await service.createItem(collectionId: col.id, text: 'Delete me', order: 0);
      await service.deleteItem(item.id);

      expect(service.getItem(item.id), isNull);
    });

    test('getItemCountForCollection returns correct count', () async {
      final col = await service.createCollection('Test');
      expect(service.getItemCountForCollection(col.id), 0);

      await service.createItem(collectionId: col.id, text: 'A', order: 0);
      expect(service.getItemCountForCollection(col.id), 1);

      await service.createItem(collectionId: col.id, text: 'B', order: 1);
      expect(service.getItemCountForCollection(col.id), 2);
    });
  });

  group('Bulk add', () {
    test('bulkAddItems creates multiple items with correct order', () async {
      final col = await service.createCollection('Test');
      final items = await service.bulkAddItems(
        collectionId: col.id,
        texts: ['Alpha', 'Beta', 'Gamma'],
      );

      expect(items.length, 3);
      expect(items[0].text, 'Alpha');
      expect(items[0].order, 0);
      expect(items[1].text, 'Beta');
      expect(items[1].order, 1);
      expect(items[2].text, 'Gamma');
      expect(items[2].order, 2);
    });

    test('bulkAddItems appends after existing items', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'Existing', order: 0);

      final items = await service.bulkAddItems(
        collectionId: col.id,
        texts: ['New1', 'New2'],
      );

      expect(items[0].order, 1); // Starts after existing
      expect(items[1].order, 2);
    });
  });

  group('Cascade delete', () {
    test('deleteCollection removes all items in collection', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'A', order: 0);
      await service.createItem(collectionId: col.id, text: 'B', order: 1);
      await service.createItem(collectionId: col.id, text: 'C', order: 2);

      expect(service.getItemCountForCollection(col.id), 3);

      await service.deleteCollection(col.id);

      expect(service.getItemCountForCollection(col.id), 0);
      expect(service.getCollection(col.id), isNull);
    });

    test('deleteCollection removes widget configs for that collection', () async {
      final col = await service.createCollection('Test');
      final config = await service.createWidgetConfig(collectionId: col.id);

      expect(service.getWidgetConfig(config.id), isNotNull);

      await service.deleteCollection(col.id);

      expect(service.getWidgetConfig(config.id), isNull);
    });

    test('deleteCollection does NOT affect other collections', () async {
      final col1 = await service.createCollection('Keep');
      final col2 = await service.createCollection('Delete');
      await service.createItem(collectionId: col1.id, text: 'Keep this', order: 0);
      await service.createItem(collectionId: col2.id, text: 'Delete this', order: 0);

      await service.deleteCollection(col2.id);

      expect(service.getItemCountForCollection(col1.id), 1);
      expect(service.getCollection(col1.id), isNotNull);
    });

    test('cascade delete with snapshot manager (if set)', () async {
      // SnapshotManager is optional; without it, delete still works
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'A', order: 0);

      await service.deleteCollection(col.id);

      expect(service.getItemCountForCollection(col.id), 0);
    });
  });

  group('Reorder items', () {
    test('reorderItems updates order values', () async {
      final col = await service.createCollection('Test');
      final itemA = await service.createItem(collectionId: col.id, text: 'A', order: 0);
      final itemB = await service.createItem(collectionId: col.id, text: 'B', order: 1);
      final itemC = await service.createItem(collectionId: col.id, text: 'C', order: 2);

      // Swap A and C
      await service.reorderItems(col.id, [itemC.id, itemB.id, itemA.id]);

      final items = service.getItemsForCollection(col.id);
      expect(items[0].text, 'C');
      expect(items[1].text, 'B');
      expect(items[2].text, 'A');
    });
  });

  group('Widget config', () {
    test('createWidgetConfig creates with correct defaults', () async {
      final col = await service.createCollection('Test');
      final config = await service.createWidgetConfig(collectionId: col.id);

      expect(config.collectionId, col.id);
      expect(config.currentIndex, 0);
      expect(config.rotationMode, RotationMode.sequential);
      expect(config.sizeCategory, SizeCategory.small);
      expect(config.showProgress, true);
    });

    test('createWidgetConfig respects sizeCategory parameter', () async {
      final col = await service.createCollection('Test');
      final config = await service.createWidgetConfig(
        collectionId: col.id,
        sizeCategory: SizeCategory.medium,
      );

      expect(config.sizeCategory, SizeCategory.medium);
    });

    test('updateWidgetConfig persists changes', () async {
      final col = await service.createCollection('Test');
      final config = await service.createWidgetConfig(collectionId: col.id);

      config.currentIndex = 5;
      config.showProgress = false;
      await service.updateWidgetConfig(config);

      final retrieved = service.getWidgetConfig(config.id);
      expect(retrieved!.currentIndex, 5);
      expect(retrieved.showProgress, false);
    });
  });

  group('Backup/Restore', () {
    test('clearAll removes everything', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'A', order: 0);
      await service.createWidgetConfig(collectionId: col.id);

      await service.clearAll();

      expect(service.getAllCollections().length, 0);
      expect(service.getAllItems().length, 0);
      expect(service.getAllWidgetConfigs().length, 0);
    });

    test('restoreFromBackup replaces all data', () async {
      // Create initial data
      final oldCol = await service.createCollection('Old');
      await service.createItem(collectionId: oldCol.id, text: 'Old item', order: 0);

      // Prepare new data
      final newCol = Collection(id: 'new-1', name: 'New', createdAt: DateTime(2025));
      final newItem = Item(id: 'new-item-1', collectionId: 'new-1', text: 'New item', order: 0, createdAt: DateTime(2025));

      await service.restoreFromBackup(
        collections: [newCol],
        items: [newItem],
        widgetConfigs: [],
      );

      expect(service.getAllCollections().length, 1);
      expect(service.getAllCollections().first.name, 'New');
      expect(service.getAllItems().first.text, 'New item');
    });

    test('appendFromBackup skips duplicate IDs', () async {
      final col = await service.createCollection('Existing');
      await service.createItem(collectionId: col.id, text: 'Original', order: 0);

      // Append with same collection ID
      final duplicateCol = Collection(id: col.id, name: 'Duplicate', createdAt: DateTime(2025));
      final newItem = Item(id: 'new-item', collectionId: col.id, text: 'Added', order: 1, createdAt: DateTime(2025));

      await service.appendFromBackup(
        collections: [duplicateCol],
        items: [newItem],
        widgetConfigs: [],
      );

      expect(service.getAllCollections().length, 1);
      expect(service.getAllCollections().first.name, 'Existing'); // Not overwritten
      expect(service.getItemCountForCollection(col.id), 2); // New item added
    });
  });
}
