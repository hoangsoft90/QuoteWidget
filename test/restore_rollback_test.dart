import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:quotewidget/models/backup_data.dart';
import 'package:quotewidget/models/collection_model.dart';
import 'package:quotewidget/models/item_model.dart';
import 'package:quotewidget/models/widget_config_model.dart';
import 'package:quotewidget/services/backup_service.dart';
import 'package:quotewidget/services/snapshot_manager.dart';
import 'package:quotewidget/services/storage_service.dart';

/// plan6 H6: restore rollback safety.
///
/// A restore that fails MID-WAY (after clearAll, before all inserts) must not
/// leave a partial mix of old+new data: BackupService.importBackup(overwrite)
/// snapshots BEFORE clearing, and on failure restores that snapshot.

class _FakePathProvider extends PathProviderPlatform {
  final String root;

  _FakePathProvider(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

/// StorageService whose restoreFromBackup throws after a partial write —
/// simulates a mid-restore failure (e.g. item 30/50 hits a corrupt field and
/// the Hive insert throws) to prove the rollback path.
class _FailingRestoreStorage extends StorageService {
  bool failOnce = true;

  @override
  Future<void> restoreFromBackup({
    required List<Collection> collections,
    required List<Item> items,
    required List<WidgetConfig> widgetConfigs,
  }) async {
    if (failOnce) {
      failOnce = false;
      // Simulate: clearAll ran, some data was inserted, then a mid-way insert
      // throws — leaving a partially-restored DB (old data wiped).
      await super.restoreFromBackup(
        collections: collections,
        items: const [],
        widgetConfigs: const [],
      );
      throw Exception('simulated mid-restore failure');
    }
    return super.restoreFromBackup(
      collections: collections,
      items: items,
      widgetConfigs: widgetConfigs,
    );
  }
}

void main() {
  late Directory tempDir;
  late Directory docsDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('quotewidget_h6_');
    docsDir = Directory('${tempDir.path}/docs');
    await docsDir.create(recursive: true);
    // Point SnapshotManager's app-documents dir at our temp dir.
    PathProviderPlatform.instance = _FakePathProvider(docsDir.path);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  test('failed restore rolls back to the PRE-restore state (no mixed data)',
      () async {
    final storage = _FailingRestoreStorage();
    await storage.init(testPath: '${tempDir.path}/hive');

    // Pre-restore state: 2 collections + 1 item.
    final oldCol1 = await storage.createCollection('Old One');
    await storage.createItem(collectionId: oldCol1.id, text: 'old item', order: 0);
    await storage.createCollection('Old Two');
    expect(storage.getAllCollections().length, 2);

    // A backup with NEW data (would wipe old state if it succeeded).
    final newCol = Collection(
      id: 'new-col-1',
      name: 'New Data',
      createdAt: DateTime(2026, 1, 1),
    );
    final newItem = Item(
      id: 'new-item-1',
      collectionId: 'new-col-1',
      text: 'brand new',
      order: 0,
      createdAt: DateTime(2026, 1, 1),
    );
    final backupFile = File('${tempDir.path}/backup.json');
    await backupFile.writeAsString(
      jsonEncode(BackupData.create(
        collections: [newCol],
        items: [newItem],
        widgetConfigs: const [],
      ).toJson()),
    );

    final snapshotManager = SnapshotManager();
    final backupService = BackupService(storage, snapshotManager);

    // Snapshot should be created BEFORE the restore begins. We can't hook
    // into BackupService internals directly, but we CAN assert the snapshot
    // that exists AFTER the failed restore contains the OLD (pre-restore)
    // data — proving it was captured before clearAll wiped it.
    final result =
        await backupService.importBackup(filePath: backupFile.path, overwrite: true);

    expect(result.success, isFalse);
    expect(result.message, contains('Previous data restored'));

    // DB == exactly the pre-restore state: old collections present, NEW data
    // must NOT be partially present, and old data must not be missing.
    expect(storage.getAllCollections().length, 2,
        reason: 'Rollback must restore both old collections');
    final names = storage.getAllCollections().map((c) => c.name).toSet();
    expect(names, {'Old One', 'Old Two'});
    expect(storage.getCollection('new-col-1'), isNull,
        reason: 'No partial NEW data may survive the rollback');
    final items = storage.getAllItems();
    expect(items.length, 1, reason: 'Old item restored');
    expect(items.first.text, 'old item');

    // The rollback source snapshot existed BEFORE the restore (it holds old
    // data — a snapshot taken after clearAll would hold the partial/new state).
    final snapshots = await snapshotManager.listSnapshots();
    expect(snapshots, isNotEmpty, reason: 'A safety snapshot must exist');
    final snapshotFile = File(snapshots.first.path);
    final snapshotJson =
        jsonDecode(await snapshotFile.readAsString()) as Map<String, dynamic>;
    final snapshotCols =
        (snapshotJson['collections'] as List).map((c) => (c as Map)['name']).toSet();
    expect(snapshotCols, {'Old One', 'Old Two'},
        reason: 'Snapshot captured the OLD state → taken BEFORE clearAll');
  });

  test('Phase1 P0-3: restore file WITH widgetConfigs creates NO phantom configs',
      () async {
    // V1 backup semantics: an old backup file may carry widgetConfigs, but
    // importing it must NOT re-insert them into Hive — a restored config has
    // no physical widget (phantom) and would block the Free limit.
    final storage = StorageService();
    await storage.init(testPath: '${tempDir.path}/hive3');

    final newCol = Collection(
      id: 'ph-col',
      name: 'Content Only',
      createdAt: DateTime(2026, 1, 1),
    );
    final newItem = Item(
      id: 'ph-item-1',
      collectionId: 'ph-col',
      text: 'backed up item',
      order: 0,
      createdAt: DateTime(2026, 1, 1),
    );
    final phantomConfig = WidgetConfig(
      id: 'phantom-config-1',
      collectionId: 'ph-col',
      appearance: AppearanceConfig.create(),
    );
    final backupFile = File('${tempDir.path}/backup-with-configs.json');
    await backupFile.writeAsString(
      jsonEncode(BackupData.create(
        collections: [newCol],
        items: [newItem],
        widgetConfigs: [phantomConfig],
      ).toJson()),
    );

    final snapshotManager = SnapshotManager();
    final backupService = BackupService(storage, snapshotManager);
    final result = await backupService.importBackup(
        filePath: backupFile.path, overwrite: true);

    expect(result.success, isTrue);
    expect(storage.getAllCollections().length, 1);
    expect(storage.getAllCollections().first.name, 'Content Only');
    expect(storage.getAllItems().length, 1);
    // The config from the file must NOT be re-inserted (no phantom).
    expect(storage.getAllWidgetConfigs(), isEmpty,
        reason: 'restore must never create phantom WidgetConfigs');
    expect(result.widgetConfigsImported, 0);
  });

  test('successful restore keeps no spurious snapshot data corruption',
      () async {
    final storage = _FailingRestoreStorage();
    await storage.init(testPath: '${tempDir.path}/hive2');

    // No old data: restore with 1 collection.
    final newCol = Collection(
      id: 'only-col',
      name: 'Solo',
      createdAt: DateTime(2026, 1, 1),
    );
    final backupFile = File('${tempDir.path}/backup2.json');
    await backupFile.writeAsString(
      jsonEncode(BackupData.create(
        collections: [newCol],
        items: const [],
        widgetConfigs: const [],
      ).toJson()),
    );

    final snapshotManager = SnapshotManager();
    final backupService = BackupService(storage, snapshotManager);
    // First import: simulate failure once (failOnce = true).
    final failed = await backupService.importBackup(
        filePath: backupFile.path, overwrite: true);
    expect(failed.success, isFalse);
    // Second import (failOnce now false): succeeds cleanly.
    final ok = await backupService.importBackup(
        filePath: backupFile.path, overwrite: true);
    expect(ok.success, isTrue);
    expect(storage.getAllCollections().length, 1);
    expect(storage.getAllCollections().first.name, 'Solo');
  });
}