import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/models/widget_config_model.dart';
import 'package:quotewidget/screens/collection_detail_screen.dart';
import 'package:quotewidget/services/rotation_service.dart';
import 'package:quotewidget/services/storage_service.dart';
import 'package:quotewidget/services/widget_data_bridge.dart';
import 'package:quotewidget/services/widget_service.dart';

/// plan5 Sprint 0 §1.6: `syncProStatus` (called once at app startup with the
/// freshly-loaded Pro status) must push a widget update AFTER writing
/// is_pro / is_pro_expires_at. Without the push, a widget whose 24h pass
/// expired while the app was closed would keep showing stale content forever
/// (updatePeriodMillis=0 → no system refresh; Kotlin only re-renders on a
/// push/tap). The push makes the expiry self-apply at next app open.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  List<MethodCall> mockHomeWidgetChannel() {
    const channel = MethodChannel('home_widget');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    return calls;
  }

  /// A4 helper: STATEFUL mock — saveWidgetData stores into a map,
  /// getWidgetData reads it back. Lets a test seed the native display-data
  /// file exactly as Kotlin would (resize, tap progress) before a sync.
  List<MethodCall> mockStatefulHomeWidgetChannel() {
    const channel = MethodChannel('home_widget');
    final store = <String, Object?>{};
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = call.arguments as Map;
      switch (call.method) {
        case 'saveWidgetData':
          store[args['id'] as String] = args['data'];
          return true;
        case 'getWidgetData':
          return store[args['id'] as String];
        default:
          return null;
      }
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    return calls;
  }

  group('Phase 2A: favorites-only rotation pool', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('widget_svc_test_');
      storage = StorageService();
      await storage.init(testPath: tempDir.path);
    });

    tearDown(() async {
      await storage.clearAll();
      await tempDir.delete(recursive: true);
    });

    test('favoritesOnly writes ONLY favorite texts to the pool + totalItems',
        () async {
      final calls = mockHomeWidgetChannel();
      final col = await storage.createCollection('Vocab');
      final a = await storage.createItem(collectionId: col.id, text: 'A', order: 0);
      await storage.createItem(collectionId: col.id, text: 'B', order: 1);
      final c = await storage.createItem(collectionId: col.id, text: 'C', order: 2);
      await storage.setItemFavorite(a.id, true);
      await storage.setItemFavorite(c.id, true);

      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        contentFilter: ContentFilter.favoritesOnly,
      );
      final service = WidgetService(storage);
      await service.syncWidgetData(config, appWidgetId: 7);

      String? saved(String id) {
        for (final call in calls) {
          if (call.method == 'saveWidgetData' &&
              (call.arguments as Map)['id'] == id) {
            return (call.arguments as Map)['data'] as String?;
          }
        }
        return null;
      }

      expect(saved('widget_7_totalItems'), '2',
          reason: 'pool size = favorites count (2), not all items (3)');
      final pool = jsonDecode(saved('widget_7_items')!) as List;
      expect(pool, ['A', 'C'],
          reason: 'ordered favorite texts only, in item order');
      expect(saved('widget_7_contentFilter'), 'favoritesOnly');
      expect(saved('widget_7_text'), 'A', reason: 'currentIndex 0 → first favorite');
    });

    test('contentFilter all writes the full ordered pool', () async {
      final calls = mockHomeWidgetChannel();
      final col = await storage.createCollection('Vocab');
      await storage.createItem(collectionId: col.id, text: 'X', order: 0);
      await storage.createItem(collectionId: col.id, text: 'Y', order: 1);

      final config = await storage.createWidgetConfig(collectionId: col.id);
      final service = WidgetService(storage);
      await service.syncWidgetData(config, appWidgetId: 9);

      String? saved(String id) {
        for (final call in calls) {
          if (call.method == 'saveWidgetData' &&
              (call.arguments as Map)['id'] == id) {
            return (call.arguments as Map)['data'] as String?;
          }
        }
        return null;
      }

      expect(saved('widget_9_totalItems'), '2');
      final pool = jsonDecode(saved('widget_9_items')!) as List;
      expect(pool, ['X', 'Y']);
      expect(saved('widget_9_contentFilter'), 'all');
    });

    test('favoritesOnly with zero favorites → empty pool + empty text',
        () async {
      final calls = mockHomeWidgetChannel();
      final col = await storage.createCollection('Vocab');
      await storage.createItem(collectionId: col.id, text: 'unstarred', order: 0);

      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        contentFilter: ContentFilter.favoritesOnly,
      );
      final service = WidgetService(storage);
      await service.syncWidgetData(config, appWidgetId: 3);

      String? saved(String id) {
        for (final call in calls) {
          if (call.method == 'saveWidgetData' &&
              (call.arguments as Map)['id'] == id) {
            return (call.arguments as Map)['data'] as String?;
          }
        }
        return null;
      }

      expect(saved('widget_3_totalItems'), '0');
      final pool = jsonDecode(saved('widget_3_items')!) as List;
      expect(pool, isEmpty);
      expect(saved('widget_3_text'), '');
    });
  });

  group('Phase 2B: schedule + tap-action keys persisted', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('widget_svc_2b_');
      storage = StorageService();
      await storage.init(testPath: tempDir.path);
    });

    tearDown(() async {
      await storage.clearAll();
      await tempDir.delete(recursive: true);
    });

    test('sync writes schedule + tapAction for a configured widget', () async {
      final calls = mockHomeWidgetChannel();
      final col = await storage.createCollection('Vocab');
      await storage.createItem(collectionId: col.id, text: 'X', order: 0);
      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        schedule: ScheduleMode.every3h,
        tapAction: TapAction.openCollection,
      );
      final service = WidgetService(storage);
      await service.syncWidgetData(config, appWidgetId: 5);

      String? saved(String id) {
        for (final call in calls) {
          if (call.method == 'saveWidgetData' &&
              (call.arguments as Map)['id'] == id) {
            return (call.arguments as Map)['data'] as String?;
          }
        }
        return null;
      }

      expect(saved('widget_5_schedule'), 'every3h');
      expect(saved('widget_5_tapAction'), 'openCollection');
      // Auto-rotate seeds next_rotation_at on first sync.
      expect(saved('widget_5_next_rotation_at'), isNotNull);
      expect(int.tryParse(saved('widget_5_next_rotation_at')!),
          greaterThan(DateTime.now().millisecondsSinceEpoch));
    });

    test('daily schedule pins today + daily index + ITEM ID on first sync',
        () async {
      final calls = mockHomeWidgetChannel();
      final col = await storage.createCollection('Vocab');
      final x =
          await storage.createItem(collectionId: col.id, text: 'X', order: 0);
      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        schedule: ScheduleMode.daily,
      );
      final service = WidgetService(storage);
      await service.syncWidgetData(config, appWidgetId: 6);

      String? saved(String id) {
        for (final call in calls) {
          if (call.method == 'saveWidgetData' &&
              (call.arguments as Map)['id'] == id) {
            return (call.arguments as Map)['data'] as String?;
          }
        }
        return null;
      }

      final today = RotationService().localDateKey(DateTime.now());
      expect(saved('widget_6_daily_date'), today);
      expect(saved('widget_6_daily_index'), '0');
      expect(saved('widget_6_daily_item_id'), x.id,
          reason: 'P1-2: the daily pin must be tracked by ITEM ID, not only by '
              'an index (index alone drifts after a mid-day delete/reorder)');
    });
  });

  group('P1-2: daily pin stays stable when the pool changes mid-day', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('p12_daily_');
      storage = StorageService();
      await storage.init(testPath: tempDir.path);
    });

    tearDown(() async {
      await storage.clearAll();
      await tempDir.delete(recursive: true);
    });

    /// Seed "today's pin = [pinned]" exactly as an earlier sync/Kotlin would
    /// have persisted it, then re-sync to exercise the SAME-DAY logic.
    Future<void> seedPin({
      required int appWidgetId,
      required String dailyDate,
      required String pinnedId,
      required int pinnedIndex,
    }) async {
      final p = 'widget_${appWidgetId}_';
      await HomeWidget.saveWidgetData('${p}daily_date', dailyDate);
      await HomeWidget.saveWidgetData('${p}daily_item_id', pinnedId);
      await HomeWidget.saveWidgetData('${p}daily_index', pinnedIndex.toString());
    }

    test('deleting ANOTHER item keeps today\'s pinned quote (id stable, index '
        're-derived)', () async {
      mockStatefulHomeWidgetChannel();
      final col = await storage.createCollection('Col');
      final a =
          await storage.createItem(collectionId: col.id, text: 'A', order: 0);
      await storage.createItem(collectionId: col.id, text: 'B', order: 1);
      final c =
          await storage.createItem(collectionId: col.id, text: 'C', order: 2);
      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        schedule: ScheduleMode.daily,
      );
      final service = WidgetService(storage);
      final today = RotationService().localDateKey(DateTime.now());

      await seedPin(
        appWidgetId: 8,
        dailyDate: today,
        pinnedId: c.id,
        pinnedIndex: 2,
      );

      // Mid-day: user deletes item A (NOT the pinned C).
      await storage.deleteItem(a.id);
      await service.syncWidgetData(config, appWidgetId: 8);

      expect(await HomeWidget.getWidgetData<String>('widget_8_daily_date'),
          today,
          reason: 'same day — daily_date unchanged');
      expect(await HomeWidget.getWidgetData<String>('widget_8_daily_item_id'),
          c.id,
          reason: 'C still exists → stays today\'s pinned quote');
      expect(await HomeWidget.getWidgetData<String>('widget_8_daily_index'),
          '1',
          reason: 'pool is now [B, C] → C\'s index re-derived from 2 to 1');
    });

    test('deleting today\'s pinned item re-pins a replacement (same date)',
        () async {
      mockStatefulHomeWidgetChannel();
      final col = await storage.createCollection('Col');
      await storage.createItem(collectionId: col.id, text: 'A', order: 0);
      await storage.createItem(collectionId: col.id, text: 'B', order: 1);
      final c =
          await storage.createItem(collectionId: col.id, text: 'C', order: 2);
      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        schedule: ScheduleMode.daily,
      );
      final service = WidgetService(storage);
      final today = RotationService().localDateKey(DateTime.now());

      await seedPin(
        appWidgetId: 9,
        dailyDate: today,
        pinnedId: c.id,
        pinnedIndex: 2,
      );

      // Mid-day: the pinned item C itself is deleted.
      await storage.deleteItem(c.id);
      await service.syncWidgetData(config, appWidgetId: 9);

      expect(await HomeWidget.getWidgetData<String>('widget_9_daily_date'),
          today,
          reason: 'a replacement is chosen for TODAY — daily_date must not '
              'advance');
      final newId =
          await HomeWidget.getWidgetData<String>('widget_9_daily_item_id');
      final newIndex =
          await HomeWidget.getWidgetData<String>('widget_9_daily_index');
      expect(newId, isNotEmpty,
          reason: 'a replacement item must be pinned');
      expect(newId, isNot(c.id),
          reason: 'the deleted item cannot stay pinned');
      final pool = storage.getItemsForCollection(col.id); // [A, B]
      expect(pool[int.parse(newIndex!)].id, newId,
          reason: 'daily_index must point at the newly pinned item');
      expect(
          await HomeWidget.getWidgetData<String>('widget_9_currentIndex'),
          newIndex,
          reason: 'the replacement shows immediately');
    });

    test('deleting the LAST item never pins a negative daily_index; adding '
        'items back re-pins the same day', () async {
      mockStatefulHomeWidgetChannel();
      final col = await storage.createCollection('Col');
      final a =
          await storage.createItem(collectionId: col.id, text: 'A', order: 0);
      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        schedule: ScheduleMode.daily,
      );
      final service = WidgetService(storage);
      final today = RotationService().localDateKey(DateTime.now());

      await seedPin(
        appWidgetId: 12,
        dailyDate: today,
        pinnedId: a.id,
        pinnedIndex: 0,
      );

      // Mid-day: delete the ONLY (pinned) item → pool becomes empty.
      await storage.deleteItem(a.id);
      await service.syncWidgetData(config, appWidgetId: 12);
      expect(
          await HomeWidget.getWidgetData<String>('widget_12_daily_index'),
          isNot('-1'),
          reason: 'review guard: a negative daily_index must never be persisted '
              '(Kotlin same-day snap would render items[-1] and crash once '
              'items exist again)');

      // User adds two fresh items later the SAME day → the stale id triggers a
      // proper same-day re-pin (no crash, valid index).
      await storage.createItem(collectionId: col.id, text: 'B', order: 0);
      await storage.createItem(collectionId: col.id, text: 'C', order: 1);
      await service.syncWidgetData(config, appWidgetId: 12);

      final newId =
          await HomeWidget.getWidgetData<String>('widget_12_daily_item_id');
      final newIndex = int.tryParse(
              await HomeWidget.getWidgetData<String>(
                      'widget_12_daily_index') ??
                  '') ??
          -1;
      expect(newId, isNotEmpty);
      expect(newId, isNot(a.id), reason: 'deleted item cannot stay pinned');
      expect(newIndex, isNot(-1));
      final pool = storage.getItemsForCollection(col.id); // [B, C]
      expect(pool[newIndex].id, newId,
          reason: 'same-day re-pin must point at a real item');
    });

    test('daily configured on an EMPTY collection records the day but never '
        'a negative index', () async {
      mockStatefulHomeWidgetChannel();
      final col = await storage.createCollection('Col');
      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        schedule: ScheduleMode.daily,
      );
      final service = WidgetService(storage);
      final today = RotationService().localDateKey(DateTime.now());

      // First sync with an empty pool.
      await service.syncWidgetData(config, appWidgetId: 13);
      expect(await HomeWidget.getWidgetData<String>('widget_13_daily_date'),
          today,
          reason: 'day is still recorded so it is not treated as un-activated');
      expect(await HomeWidget.getWidgetData<String>('widget_13_daily_index'),
          isNull,
          reason: 'review guard: an empty pool must never produce a negative '
              'daily_index');
      expect(
          await HomeWidget.getWidgetData<String>('widget_13_daily_item_id'),
          isNull);

      // Items arrive later the same day → still no negative index anywhere.
      await storage.createItem(collectionId: col.id, text: 'X', order: 0);
      await service.syncWidgetData(config, appWidgetId: 13);
      expect(await HomeWidget.getWidgetData<String>('widget_13_daily_index'),
          isNull);
      expect(await HomeWidget.getWidgetData<String>('widget_13_currentIndex'),
          isNot('-1'));
    });

    test('a PAST daily_date is left to native rollover — yesterday\'s id is '
        'never resurrected as today\'s pin by a Flutter sync', () async {
      mockStatefulHomeWidgetChannel();
      final col = await storage.createCollection('Col');
      final c =
          await storage.createItem(collectionId: col.id, text: 'C', order: 0);
      final config = await storage.createWidgetConfig(
        collectionId: col.id,
        schedule: ScheduleMode.daily,
      );
      final service = WidgetService(storage);

      // Yesterday's pin (id = C) is stale: native advances the day and clears
      // daily_item_id when it renders — the Flutter sync must NOT claim C as
      // today's pin while daily_date is still in the past.
      await seedPin(
        appWidgetId: 10,
        dailyDate: '2000-01-01',
        pinnedId: c.id,
        pinnedIndex: 0,
      );
      await service.syncWidgetData(config, appWidgetId: 10);

      expect(await HomeWidget.getWidgetData<String>('widget_10_daily_date'),
          '2000-01-01',
          reason: 'day rollover is owned by the native render — sync leaves the '
              'stale date untouched instead of silently rewriting it');
      expect(await HomeWidget.getWidgetData<String>('widget_10_daily_item_id'),
          c.id,
          reason: 'untouched too — Kotlin clears it when IT advances the day');
    });
  });

  group('Forensic: native tap progress preserved on re-sync', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('widget_svc_fx_');
      storage = StorageService();
      await storage.init(testPath: tempDir.path);
    });

    tearDown(() async {
      await storage.clearAll();
      await tempDir.delete(recursive: true);
    });

    test('re-sync keeps the native currentIndex instead of resetting to 0',
        () async {
      final calls = mockHomeWidgetChannel();
      final col = await storage.createCollection('Vocab');
      await storage.createItem(collectionId: col.id, text: 'A', order: 0);
      await storage.createItem(collectionId: col.id, text: 'B', order: 1);
      await storage.createItem(collectionId: col.id, text: 'C', order: 2);
      final config = await storage.createWidgetConfig(collectionId: col.id);
      final service = WidgetService(storage);

      // First sync (config index 0).
      await service.syncWidgetData(config, appWidgetId: 11);
      // Simulate native taps: Kotlin advanced the prefs index to 2.
      // Kotlin writes via its own prefs, not the channel — emulate by
      // intercepting the channel: next sync reads getWidgetData → return 2.
      // Mock getWidgetData to return the advanced index.
      final getCalls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('home_widget'), (call) async {
        if (call.method == 'getWidgetData') {
          getCalls.add((call.arguments as Map)['id'] as String);
          if ((call.arguments as Map)['id'] == 'widget_11_currentIndex') {
            return '2'; // native taps advanced to index 2
          }
          return null;
        }
        calls.add(call);
        return null;
      });

      // Re-sync after an item edit (config.currentIndex still 0 in Hive).
      await service.syncWidgetData(config, appWidgetId: 11);

      // Take the LAST write for an id: the first sync wrote 0, the re-sync
      // must write the preserved native index (2).
      String? saved(String id) {
        String? value;
        for (final call in calls) {
          if (call.method == 'saveWidgetData' &&
              (call.arguments as Map)['id'] == id) {
            value = (call.arguments as Map)['data'] as String?;
          }
        }
        return value;
      }

      expect(saved('widget_11_currentIndex'), '2',
          reason: 'native tap progress must survive a Flutter re-sync');
      expect(saved('widget_11_text'), 'C',
          reason: 'displayed text follows the preserved native index');
    });
  });

  group('syncProStatus startup push (plan5 Sprint 0 §1.6)', () {
    test('expired Pro (isPro=false) writes state THEN pushes updateWidget',
        () async {
      final calls = mockHomeWidgetChannel();

      final service = WidgetService(StorageService());
      await service.syncProStatus(
        false,
        proUnlockedUntil:
            DateTime.now().subtract(const Duration(hours: 1)),
      );

      final methods = calls.map((c) => c.method).toList();
      // is_pro written first so Kotlin reads fresh state on the re-render.
      final isProCall = calls
          .where((c) => c.method == 'saveWidgetData')
          .firstWhere((c) => (c.arguments as Map)['id'] == 'is_pro');
      expect((isProCall.arguments as Map)['data'], 'false',
          reason: 'expired → is_pro=false must be persisted');
      expect(methods.last, 'updateWidget',
          reason: 'startup push must trigger Kotlin re-render (self-lock)');
      // Ordering: both saves happen before the push.
      expect(methods.indexOf('updateWidget'),
          greaterThan(methods.lastIndexOf('saveWidgetData')));
    });

    test('active Pro (isPro=true) also pushes a fresh render', () async {
      final calls = mockHomeWidgetChannel();

      final service = WidgetService(StorageService());
      await service.syncProStatus(true, proUnlockedUntil: DateTime(9999));

      final isProCall = calls
          .where((c) => c.method == 'saveWidgetData')
          .firstWhere((c) => (c.arguments as Map)['id'] == 'is_pro');
      expect((isProCall.arguments as Map)['data'], 'true');
      expect(calls.map((c) => c.method).toList().last, 'updateWidget',
          reason: 'active Pro still renders fresh content after startup');
    });
  });

  group('A4: sizeCategory — native resize value is never clobbered', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('a4_size_test_');
      storage = StorageService();
      await storage.init(testPath: tempDir.path);
    });

    tearDown(() async {
      await storage.clearAll();
      await tempDir.delete(recursive: true);
    });

    test('syncWidgetData does NOT overwrite an existing native sizeCategory',
        () async {
      // Kotlin onAppWidgetOptionsChanged persisted 'wide' (user resized the
      // widget to 4×2). Hive still holds the stale default 'small'.
      mockStatefulHomeWidgetChannel();
      await HomeWidget.saveWidgetData('widget_21_sizeCategory', 'wide');

      final col = await storage.createCollection('Col');
      final config = await storage.createWidgetConfig(collectionId: col.id);
      expect(config.sizeCategory, SizeCategory.small,
          reason: 'Hive default — the stale value that used to win');

      final service = WidgetService(storage);
      await service.syncWidgetData(config, appWidgetId: 21); // item-edit sync

      final stillWide =
          await HomeWidget.getWidgetData<String>('widget_21_sizeCategory');
      expect(stillWide, 'wide',
          reason:
              'A4: resize-derived native layout must survive a Flutter sync');
    });

    test('B1: author key follows the displayed item, empty when unset',
        () async {
      mockStatefulHomeWidgetChannel();

      final col = await storage.createCollection('Col');
      await storage.createItem(collectionId: col.id, text: 'A', order: 0,
          author: 'Thoreau');
      await storage.createItem(collectionId: col.id, text: 'B', order: 1);

      final config = await storage.createWidgetConfig(collectionId: col.id);
      final service = WidgetService(storage);

      // Item 0 has author 'Thoreau' → key carries it.
      await service.syncWidgetData(config, appWidgetId: 31);
      expect(await HomeWidget.getWidgetData<String>('widget_31_author'),
          'Thoreau');

      // Native tap advanced to item 1 (no author) → key must be EMPTY (not
      // stale 'Thoreau'), otherwise the widget would keep the old author.
      await HomeWidget.saveWidgetData('widget_31_currentIndex', '1');
      await service.syncWidgetData(config, appWidgetId: 31);
      expect(await HomeWidget.getWidgetData<String>('widget_31_author'), '',
          reason: 'author must follow the displayed item, never stay stale');
    });

    test('brand-new widget (no native value yet) gets the Hive default',
        () async {
      final calls = mockStatefulHomeWidgetChannel();

      final col = await storage.createCollection('Col');
      final config = await storage.createWidgetConfig(collectionId: col.id);

      final service = WidgetService(storage);
      await service.syncWidgetData(config, appWidgetId: 22);

      final writes = calls
          .where((c) =>
              c.method == 'saveWidgetData' &&
              (c.arguments as Map)['id'] == 'widget_22_sizeCategory')
          .toList();
      expect(writes, hasLength(1),
          reason: 'first sync of a new widget must seed the layout');
      expect((writes.single.arguments as Map)['data'], 'small');
    });
  });

  group('A5a: reorder immediately re-syncs the widget pool', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('a5_reorder_test_');
      storage = StorageService();
      await storage.init(testPath: tempDir.path);
    });

    tearDown(() async {
      await storage.clearAll();
      await tempDir.delete(recursive: true);
    });

    test('reorder flow persists order AND re-syncs the widget pool', () async {
      final calls = mockHomeWidgetChannel();

      final col = await storage.createCollection('Col');
      await storage.createItem(collectionId: col.id, text: 'A', order: 0);
      await storage.createItem(collectionId: col.id, text: 'B', order: 1);
      await storage.createItem(collectionId: col.id, text: 'C', order: 2);
      final config = await storage.createWidgetConfig(collectionId: col.id);
      await WidgetDataBridge.registerWidgetMapping(
        appWidgetId: 7,
        configId: config.id,
      );

      // The EXACT flow a drag fires (moved item 0 → index 1: A,B,C → B,A,C),
      // awaited end-to-end.
      await reorderAndSyncItems(
        storageService: storage,
        widgetService: WidgetService(storage),
        collectionId: col.id,
        items: storage.getItemsForCollection(col.id)..sort((a, b) => a.order.compareTo(b.order)),
        fromIndex: 0,
        toIndex: 1,
      );

      final pool = _lastSavedList(calls, 'widget_7_items');
      expect(pool, isNotNull,
          reason: 'reorder MUST re-sync the widget (A5a: no _syncWidget before)');
      final items = (jsonDecode(pool!) as List).cast<String>();
      expect(items, ['B', 'A', 'C'],
          reason: 'widget pool must reflect the new order immediately');
    });
  });
}

/// Last saveWidgetData payload for [id] across all calls (sync writes several
/// times — the last write is what Kotlin renders).
String? _lastSavedList(List<MethodCall> calls, String id) {
  String? value;
  for (final call in calls) {
    if (call.method == 'saveWidgetData' &&
        (call.arguments as Map)['id'] == id) {
      value = (call.arguments as Map)['data'] as String?;
    }
  }
  return value;
}
