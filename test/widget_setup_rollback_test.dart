import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/screens/widget_setup_screen.dart';
import 'package:quotewidget/services/backup_service.dart';
import 'package:quotewidget/services/iap_service.dart';
import 'package:quotewidget/services/interstitial_ad_service.dart';
import 'package:quotewidget/services/rewarded_ad_service.dart';
import 'package:quotewidget/services/snapshot_manager.dart';
import 'package:quotewidget/services/storage_service.dart';
import 'package:quotewidget/services/widget_service.dart';

/// Final Hardening P1-3: the setup chain
/// (createWidgetConfig → registerWidgetMapping → syncWidgetData → updateWidget)
/// must ROLL BACK when a step AFTER createWidgetConfig fails. The home_widget
/// method channel is intentionally NOT mocked here, so syncWidgetData throws
/// (MissingPluginException) right after the config + mapping were written —
/// exactly the "mid-chain failure" the fix targets. The freshly created config
/// must be removed from Hive and the user must get honest error feedback.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;
  late WidgetService widgetService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('setup_rollback_');
    storage = StorageService();
    await storage.init(testPath: tempDir.path);
    widgetService = WidgetService(storage);
    await storage.createCollection('Col');
  });

  tearDown(() async {
    await storage.clearAll();
    await tempDir.delete(recursive: true);
  });

  testWidgets('sync failure after createWidgetConfig rolls the config back',
      (tester) async {
    final iap = IapService();
    await tester.pumpWidget(MaterialApp(
      home: WidgetSetupScreen(
        appWidgetId: 42,
        storageService: storage,
        widgetService: widgetService,
        iapService: iap,
        rewardedAdService: RewardedAdService(iap),
        interstitialAdController: InterstitialAdController(),
        backupService: BackupService(storage, SnapshotManager()),
        snapshotManager: SnapshotManager(),
      ),
    ));
    await tester.pumpAndSettle();

    // Pick the collection, then press "Set Up Widget". The whole setup chain
    // does real Hive/IO work, so it runs inside tester.runAsync.
    await tester.runAsync(() async {
      await tester.tap(find.text('Col'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Set Up Widget'));
      // Let the async chain (config create → mapping → sync throw → rollback)
      // complete on the real event loop.
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    // 1. No config survives the failed setup (rollback ran).
    expect(storage.getAllWidgetConfigs(), isEmpty,
        reason: 'P1-3: a half-configured widget must not leave a phantom '
            'WidgetConfig in Hive after the setup failed');

    // 2. No half-written wcfg_* mapping survives either.
    final prefs = await SharedPreferences.getInstance();
    final leftover = prefs
        .getKeys()
        .where((k) => k.startsWith('wcfg_'))
        .toList();
    expect(leftover, isEmpty,
        reason: 'P1-3: rollback must also clean the partial mapping');

    // 3. The user sees honest failure feedback — no fake success.
    expect(find.text('Không thể thiết lập widget, vui lòng thử lại'),
        findsOneWidget,
        reason: 'P1-3: never report success when the setup actually failed');
  });
}
