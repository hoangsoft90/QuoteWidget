import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quotewidget/models/collection_model.dart';
import 'package:quotewidget/models/item_model.dart';
import 'package:quotewidget/models/widget_config_model.dart';
import 'package:quotewidget/services/storage_service.dart';
import 'package:quotewidget/services/widget_data_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('Widget config + time-bound Pro limit', () {
    test('createWidgetConfig creates with correct defaults', () async {
      final col = await service.createCollection('Test');
      final config = await service.createWidgetConfig(collectionId: col.id);

      expect(config.collectionId, col.id);
      expect(config.currentIndex, 0);
      expect(config.rotationMode, RotationMode.sequential);
      expect(config.sizeCategory, SizeCategory.small);
      expect(config.showProgress, true);
    });

    test('Free 2nd widget blocked, but unblocked while 24h Pro active', () async {
      final col = await service.createCollection('Test');
      await service.createWidgetConfig(collectionId: col.id);

      // Free: second widget must be blocked.
      expect(
        () => service.createWidgetConfig(collectionId: col.id),
        throwsA(isA<WidgetLimitReachedException>()),
      );

      // Simulate a live rewarded-ad unlock still inside its 24h window.
      var unlockedUntil = DateTime.now().add(const Duration(hours: 12));
      service.setProStatusProvider(() =>
          DateTime.now().isBefore(unlockedUntil));

      final second = await service.createWidgetConfig(collectionId: col.id);
      expect(second, isNotNull, reason: 'Pro within 24h window → 2nd widget OK');
    });

    test('widget limit auto-relocks when the 24h window expires', () async {
      final col = await service.createCollection('Test');
      await service.createWidgetConfig(collectionId: col.id);

      // Provider starts "active", then the window expires mid-session.
      var unlockedUntil = DateTime.now().add(const Duration(hours: 24));
      service.setProStatusProvider(() =>
          DateTime.now().isBefore(unlockedUntil));
      final second = await service.createWidgetConfig(collectionId: col.id);
      expect(second, isNotNull);

      // Expire the window (as if 24h elapsed without a new ad).
      unlockedUntil = DateTime.now().subtract(const Duration(seconds: 1));
      await service.deleteWidgetConfig(second.id); // back to 1 widget
      expect(
        () => service.createWidgetConfig(collectionId: col.id),
        throwsA(isA<WidgetLimitReachedException>()),
        reason: 'Expired unlock must re-engage the 1-widget Free limit',
      );
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

    test('A1: native count blocks Free 2nd widget even when Hive box is empty', () async {
      // plan4 Sprint A-1 dead-end trap: the Hive box is empty (the only
      // WidgetConfig was deleted with its collection) but a physical widget
      // still exists natively (configured_widget_ids = [1]). The gate must
      // read the NATIVE count, not the Hive box.
      final service = StorageService();
      await service.init(testPath: tempDir.path);
      service.setWidgetCountProvider(() async => 1);

      final col = await service.createCollection('Test');
      expect(service.getAllWidgetConfigs(), isEmpty,
          reason: 'Hive box empty — pre-fix this would NOT block');

      await expectLater(
        service.createWidgetConfig(collectionId: col.id),
        throwsA(isA<WidgetLimitReachedException>()),
        reason: 'Native count 1 ≥ Free limit 1 → must block even with empty Hive',
      );
    });

    test('A1: null native count falls back to Hive box length', () async {
      final service = StorageService();
      await service.init(testPath: tempDir.path);
      // Provider returns null (channel unavailable / tests) → Hive fallback.
      service.setWidgetCountProvider(() async => null);

      final col = await service.createCollection('Test');
      await service.createWidgetConfig(collectionId: col.id);

      await expectLater(
        service.createWidgetConfig(collectionId: col.id),
        throwsA(isA<WidgetLimitReachedException>()),
        reason: 'Native unavailable → Hive box (1 config) must still block',
      );
    });

    test('A1: Pro (24h window) bypasses native-count gate', () async {
      final service = StorageService();
      await service.init(testPath: tempDir.path);
      service.setWidgetCountProvider(() async => 1);

      final col = await service.createCollection('Test');
      final unlockedUntil = DateTime.now().add(const Duration(hours: 12));
      service.setProStatusProvider(
          () => DateTime.now().isBefore(unlockedUntil));

      final second = await service.createWidgetConfig(collectionId: col.id);
      expect(second, isNotNull,
          reason: 'Pro within 24h window → native count must not block');
    });
  });

  group('A2: Hybrid reconciliation (Hive ↔ native registry)', () {
    test('orphaned config (mapped id not in native set) is deleted + mapping cleaned',
        () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.init(testPath: tempDir.path);

      final col = await service.createCollection('Test');
      final config = await service.createWidgetConfig(collectionId: col.id);
      // Simulate a real mapping: config ↔ appWidgetId 1001.
      await WidgetDataBridge.registerWidgetMapping(
        appWidgetId: 1001,
        configId: config.id,
      );
      expect(service.getAllWidgetConfigs().length, 1);

      // Native registry no longer has 1001 (physical widget deleted while
      // the app was closed) and has 2 unrelated widgets → counts differ
      // (Hive 1 vs native 2) so the full scan runs.
      service.setWidgetIdsProvider(() async => [2002, 3003]);

      await service.reconcileWidgetConfigs();

      expect(service.getAllWidgetConfigs(), isEmpty,
          reason: 'Config mapped to a dead appWidgetId must be removed');
      // Both directions of the mapping must be gone.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('wcfg_1001_configId'), isNull,
          reason: 'appWidgetId→config mapping must be cleaned');
      expect(prefs.getString('wcfg_${config.id}_appWidgetId'), isNull,
          reason: 'config→appWidgetId mapping must be cleaned');
    });

    test('fast path: counts match → no cleanup even with different ids', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.init(testPath: tempDir.path);

      final col = await service.createCollection('Test');
      final config = await service.createWidgetConfig(collectionId: col.id);
      await WidgetDataBridge.registerWidgetMapping(
        appWidgetId: 1001,
        configId: config.id,
      );

      // Native count (1) == Hive count (1) → fast path, no full scan.
      service.setWidgetIdsProvider(() async => [2002]);

      await service.reconcileWidgetConfigs();

      expect(service.getAllWidgetConfigs().length, 1,
          reason: 'Counts equal → fast path must not scan/delete');
    });

    test('reverse: native ids without Hive config are left alone', () async {
      SharedPreferences.setMockInitialValues({});
      final service = StorageService();
      await service.init(testPath: tempDir.path);

      // Hive empty, native has 1 widget → counts differ (0 vs 1), full scan
      // runs, but there is no Hive config to delete (unconfigured widget).
      service.setWidgetIdsProvider(() async => [1001]);

      await service.reconcileWidgetConfigs();

      expect(service.getAllWidgetConfigs(), isEmpty,
          reason: 'Unconfigured native widgets are the "Tap to set up" state — kept');
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
