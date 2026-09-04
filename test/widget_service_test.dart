import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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