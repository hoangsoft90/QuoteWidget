import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/screens/add_widget_guide_screen.dart';
import 'package:quotewidget/services/backup_service.dart';
import 'package:quotewidget/services/iap_service.dart';
import 'package:quotewidget/services/interstitial_ad_service.dart';
import 'package:quotewidget/services/rewarded_ad_service.dart';
import 'package:quotewidget/services/snapshot_manager.dart';
import 'package:quotewidget/services/storage_service.dart';
import 'package:quotewidget/services/widget_service.dart';

/// Final Hardening P2-3: opening AddWidgetGuideScreen must NOT pop up the
/// system pin-widget dialog on its own. The pin (requestPinWidget) may only be
/// requested when the user taps the "Add Widget to Home Screen" button.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storage;

  /// Mock the home_widget channel: record every call; the device supports
  /// pinning (so the quick-add button is shown and the tap can be exercised).
  List<String> mockHomeWidgetChannel() {
    const channel = MethodChannel('home_widget');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (call.method == 'isRequestPinWidgetSupported') return true;
      if (call.method == 'requestPinWidget') return true;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    return calls;
  }

  /// The guide loads an OEM guide via device_info_plus — make that platform
  /// call fail fast (falls back to the default guide) instead of hanging the
  /// test's fake-async zone.
  void mockDeviceInfoUnavailable() {
    const channel = MethodChannel('dev.fluttercommunity.plus/device_info');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'unavailable');
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('guide_pin_test_');
    storage = StorageService();
    await storage.init(testPath: tempDir.path);
  });

  tearDown(() async {
    await storage.clearAll();
    await tempDir.delete(recursive: true);
  });

  Widget buildScreen(WidgetService widgetService) {
    final iap = IapService();
    return MaterialApp(
      home: AddWidgetGuideScreen(
        widgetService: widgetService,
        storageService: storage,
        iapService: iap,
        rewardedAdService: RewardedAdService(iap),
        interstitialAdController: InterstitialAdController(),
        backupService: BackupService(storage, SnapshotManager()),
        snapshotManager: SnapshotManager(),
      ),
    );
  }

  testWidgets('opening the guide requests NO pin; pressing the button does',
      (tester) async {
    final calls = mockHomeWidgetChannel();
    mockDeviceInfoUnavailable();
    final widgetService = WidgetService(storage);

    await tester.pumpWidget(buildScreen(widgetService));
    await tester.pumpAndSettle();

    // Support probe is a pure query — allowed. A pin REQUEST is not.
    expect(calls, isNot(contains('requestPinWidget')),
        reason: 'P2-3: opening AddWidgetGuideScreen must not auto-trigger the '
            'system pin dialog');
    expect(calls, contains('isRequestPinWidgetSupported'),
        reason: 'support probe on open is fine (no dialog)');

    // Device supports pinning → the quick-add button is available.
    final button = find.widgetWithText(
        ElevatedButton, 'Add Widget to Home Screen');
    expect(button, findsOneWidget);

    // Only the user's press may request the pin.
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
        calls.where((m) => m == 'requestPinWidget').length, 1,
        reason: 'P2-3: requestPinWidget fires exactly once — on the button tap');
  });
}
