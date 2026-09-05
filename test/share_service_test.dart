import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/services/share_service.dart';
import 'package:quotewidget/services/storage_service.dart';

void main() {
  late StorageService storage;
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('share_service_test_');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init(testPath: tempDir.path);
  });

  tearDown(() async {
    await storage.clearAll();
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  group('Quick Share Undo support (plan5 Sprint 0 §1.7)', () {
    test('saveToCollection returns the created Item (exact Undo target)',
        () async {
      final col = await storage.createCollection('Vocab');
      final item = await ShareService(storage).saveToCollection(
        text: 'hello world',
        collectionId: col.id,
      );

      expect(item, isNotNull, reason: 'successful save must return the Item');
      expect(item!.text, 'hello world');
      expect(item.collectionId, col.id);
      expect(storage.getItemCountForCollection(col.id), 1);
    });

    test('saveToCollection appends order after existing items', () async {
      final col = await storage.createCollection('Vocab');
      await storage.createItem(collectionId: col.id, text: 'old', order: 0);

      final item = await ShareService(storage).saveToCollection(
        text: 'new share',
        collectionId: col.id,
      );

      expect(item, isNotNull);
      final items = storage.getItemsForCollection(col.id);
      expect(items.length, 2);
      expect(items[1].id, item!.id, reason: 'new share appended last');
      expect(items[1].order, greaterThan(items[0].order));
    });

    test('undo target: deleteItem removes exactly the saved item', () async {
      // Undo target is exactly the item saved — verify deleteItem removes it.
      // (saveToCollection itself must not throw on normal input.)
      final col = await storage.createCollection('Vocab');
      final item = await ShareService(storage).saveToCollection(
        text: 'x',
        collectionId: col.id,
      );
      expect(item, isNotNull);

      await storage.deleteItem(item!.id);
      expect(storage.getItem(item.id), isNull,
          reason: 'Undo uses deleteItem → item goes to Trash (recoverable)');
      expect(storage.getItemCountForCollection(col.id), 0);
    });
  });
}