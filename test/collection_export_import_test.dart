import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/services/backup_service.dart';
import 'package:quotewidget/services/snapshot_manager.dart';
import 'package:quotewidget/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B2: single-collection export → import round trip. Author (B1 field) must
/// survive the trip; import-as-new never touches the source collection;
/// append mode adds items AFTER the existing ones with fresh ids.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // exportCollection writes into the app temp dir — mock the plugin.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => (await Directory.systemTemp.createTemp('b2_tmp_')).path,
    );
  });

  late Directory tempDir;
  late StorageService storage;
  late BackupService backup;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('b2_export_test_');
    storage = StorageService();
    await storage.init(testPath: tempDir.path);
    backup = BackupService(storage, SnapshotManager());
  });

  tearDown(() async {
    await storage.clearAll();
    await tempDir.delete(recursive: true);
  });

  test('export writes a file with the collection + items (author included)',
      () async {
    final col = await storage.createCollection('Poems');
    await storage.createItem(collectionId: col.id, text: 'Row row row',
        order: 0, author: 'Unknown');
    await storage.createItem(collectionId: col.id, text: 'Your boat', order: 1);

    final path = await backup.exportCollection(col.id);
    final file = File(path);
    expect(await file.exists(), isTrue, reason: 'export must write a file');
    expect(path.endsWith('.json'), isTrue);

    final preview = await BackupService.previewCollectionImport(path);
    expect(preview.collection.name, 'Poems');
    expect(preview.items.map((i) => i.text), ['Row row row', 'Your boat']);
    expect(preview.items.first.author, 'Unknown',
        reason: 'B1 author must survive the export');
  });

  test('import as NEW collection: fresh id, name suffixed, items recreated',
      () async {
    final col = await storage.createCollection('Poems');
    await storage.createItem(collectionId: col.id, text: 'A', order: 0,
        author: 'Xu');
    final path = await backup.exportCollection(col.id);

    final result = await backup.importCollection(filePath: path);

    expect(result.success, isTrue, reason: result.message);
    expect(result.collectionsImported, 1);
    expect(result.itemsImported, 1);

    // Source untouched.
    expect(storage.getAllCollections().where((c) => c.name == 'Poems'),
        hasLength(1));

    final imported = storage.getAllCollections()
        .singleWhere((c) => c.name == 'Poems (imported)');
    final items = storage.getItemsForCollection(imported.id);
    expect(items, hasLength(1));
    expect(items.single.text, 'A');
    expect(items.single.author, 'Xu',
        reason: 'author must survive the import');
    expect(items.single.id, isNot(equals('')),
        reason: 'fresh item ids — no collision with the source file');
  });

  test('append mode adds items into the target collection, order continues',
      () async {
    final col = await storage.createCollection('Poems');
    await storage.createItem(collectionId: col.id, text: 'existing', order: 0);
    final other = await storage.createCollection('Source');
    await storage.createItem(collectionId: other.id, text: 'imported-1',
        order: 0);
    await storage.createItem(collectionId: other.id, text: 'imported-2',
        order: 1);
    final path = await backup.exportCollection(other.id);

    final result = await backup.importCollection(
      filePath: path,
      targetCollectionId: col.id,
    );

    expect(result.success, isTrue, reason: result.message);
    final items = storage.getItemsForCollection(col.id);
    expect(items.map((i) => i.text), ['existing', 'imported-1', 'imported-2'],
        reason: 'appended AFTER existing items, order preserved');
  });

  test('import rejects a non-collection JSON file', () async {
    final bad = File('${tempDir.path}/bad.json');
    await bad.writeAsString('{"backupFormat": "quote-widget-backup"}');

    final result = await backup.importCollection(filePath: bad.path);

    expect(result.success, isFalse);
    expect(result.message, contains('Import failed'));
  });
}
