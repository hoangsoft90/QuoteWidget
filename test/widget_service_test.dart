import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/models/widget_config_model.dart';
import 'package:quotewidget/services/rotation_service.dart';
import 'package:quotewidget/services/storage_service.dart';
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

    test('daily schedule pins today + daily index on first sync', () async {
      final calls = mockHomeWidgetChannel();
      final col = await storage.createCollection('Vocab');
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
}