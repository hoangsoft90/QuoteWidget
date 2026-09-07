import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/screens/settings_screen.dart';
import 'package:quotewidget/services/backup_service.dart';
import 'package:quotewidget/services/iap_service.dart';
import 'package:quotewidget/services/interstitial_ad_service.dart';
import 'package:quotewidget/services/rewarded_ad_service.dart';
import 'package:quotewidget/services/snapshot_manager.dart';
import 'package:quotewidget/services/storage_service.dart';
import 'package:quotewidget/services/widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// B5: the About row shows the version read live from PackageInfo (pubspec
/// version), not a hardcoded string that drifts on every release.
///
/// Services are constructed but NOT initialized (no Hive boxes opened) —
/// SettingsScreen.build never touches them, so the test stays hermetic and
/// the isolate exits cleanly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // PackageInfo platform channel — return a known version.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (call) async => <String, dynamic>{
        'appName': 'Quote Widget',
        'packageName': 'com.quotewidget.quotewidget',
        'version': '9.9.9',
        'buildNumber': '42',
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/package_info'),
            null);
  });

  testWidgets('About row shows the live PackageInfo version', (tester) async {
    // Uninitialized service stubs — safe: build() only reads iapService.
    final storage = StorageService();
    final screen = SettingsScreen(
      iapService: IapService(),
      rewardedAdService: RewardedAdService(IapService()),
      storageService: storage,
      widgetService: WidgetService(storage),
      backupService: BackupService(storage, SnapshotManager()),
      snapshotManager: SnapshotManager(),
      interstitialAdController: InterstitialAdController(),
    );

    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();

    expect(find.text('Quote Widget – Your Words v9.9.9'), findsOneWidget,
        reason: 'B5: version must come from PackageInfo, not a constant');
  });
}
