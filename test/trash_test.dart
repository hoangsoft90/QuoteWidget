import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quotewidget/services/storage_service.dart';

/// Task 7 (P1) — Trash / Recently Deleted.
void main() {
  late StorageService service;
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('quotewidget_trash_test_');
    Hive.init(tempDir.path);
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

  group('Item soft-delete', () {
    test('deleteItem flags item, hides from active views, keeps in Hive', () async {
      final col = await service.createCollection('Test');
      final item = await service.createItem(collectionId: col.id, text: 'A', order: 0);

      await service.deleteItem(item.id);

      // Hidden from active accessors.
      expect(service.getItem(item.id), isNull);
      expect(service.getItemsForCollection(col.id), isEmpty);
      expect(service.getItemCountForCollection(col.id), 0);
      // Present in trash.
      final trashed = service.getTrashedItems();
      expect(trashed.length, 1);
      expect(trashed.first.id, item.id);
      expect(trashed.first.isDeleted, true);
      expect(trashed.first.deletedAt, isNotNull);
    });

    test('restoreItem brings item back to active view', () async {
      final col = await service.createCollection('Test');
      final item = await service.createItem(collectionId: col.id, text: 'A', order: 0);

      await service.deleteItem(item.id);
      await service.restoreItem(item.id);

      expect(service.getTrashedItems(), isEmpty);
      expect(service.getItem(item.id), isNotNull);
      expect(service.getItemsForCollection(col.id).length, 1);
    });

    test('permanentlyDeleteItem removes from Hive entirely', () async {
      final col = await service.createCollection('Test');
      final item = await service.createItem(collectionId: col.id, text: 'A', order: 0);

      await service.deleteItem(item.id);
      await service.permanentlyDeleteItem(item.id);

      expect(service.getTrashedItems(), isEmpty);
      expect(service.getItemsForCollection(col.id), isEmpty);
    });
  });

  group('Collection soft-delete + cascade', () {
    test('deleteCollection flags collection AND its items, hides collection', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'A', order: 0);
      await service.createItem(collectionId: col.id, text: 'B', order: 1);

      await service.deleteCollection(col.id);

      // Collection hidden from active views.
      expect(service.getCollection(col.id), isNull);
      expect(service.getAllCollections(), isEmpty);
      // In trash with items flagged too.
      final trashedCols = service.getTrashedCollections();
      expect(trashedCols.length, 1);
      expect(trashedCols.first.isDeleted, true);
      final trashedItems = service.getTrashedItems();
      expect(trashedItems.length, 2, reason: 'All items cascade into trash');
    });

    test('restoreCollection restores collection and all its items', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'A', order: 0);
      await service.createItem(collectionId: col.id, text: 'B', order: 1);

      await service.deleteCollection(col.id);
      expect(service.getAllCollections(), isEmpty);

      await service.restoreCollection(col.id);

      expect(service.getAllCollections().length, 1);
      expect(service.getCollection(col.id), isNotNull);
      expect(service.getItemCountForCollection(col.id), 2,
          reason: 'Items restored with the collection');
      expect(service.getTrashedCollections(), isEmpty);
      expect(service.getTrashedItems(), isEmpty);
    });

    test('permanentlyDeleteCollection removes everything from Hive', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'A', order: 0);

      await service.deleteCollection(col.id);
      await service.permanentlyDeleteCollection(col.id);

      expect(service.getTrashedCollections(), isEmpty);
      expect(service.getTrashedItems(), isEmpty);
    });
  });

  group('30-day purge', () {
    test('purgeTrash removes items older than retention window', () async {
      final col = await service.createCollection('Test');
      final item = await service.createItem(collectionId: col.id, text: 'Old', order: 0);
      await service.deleteItem(item.id);

      // Verify the purge via the service contract: delete the collection, then
      // expire everything by calling purgeTrash with a zero-length window.
      await service.deleteCollection(col.id);

      // Zero-length retention → everything trashed is immediately purged.
      await service.purgeTrash(retention: Duration.zero);

      expect(service.getTrashedCollections(), isEmpty);
      expect(service.getTrashedItems(), isEmpty,
          reason: 'Items of an expired collection are purged too');
    });

    test('purgeTrash keeps items inside retention window', () async {
      final col = await service.createCollection('Test');
      await service.createItem(collectionId: col.id, text: 'Recent', order: 0);
      await service.deleteCollection(col.id);

      // Default 30-day window → nothing purged yet.
      await service.purgeTrash();

      expect(service.getTrashedCollections().length, 1);
      expect(service.getTrashedItems().length, 1);
    });
  });

  group('Active collections exclude trashed (regression)', () {
    test('getAllCollections / getItemsForCollection only return active', () async {
      final col = await service.createCollection('Keep');
      final trashCol = await service.createCollection('Trash');
      await service.createItem(collectionId: col.id, text: 'A', order: 0);
      await service.createItem(collectionId: trashCol.id, text: 'B', order: 0);

      await service.deleteCollection(trashCol.id);

      final active = service.getAllCollections();
      expect(active.length, 1);
      expect(active.first.id, col.id);
      expect(service.getItemCountForCollection(col.id), 1);
    });
  });
}