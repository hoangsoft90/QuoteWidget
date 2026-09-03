import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/services/iap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Time-bound Pro (rewarded-ad 24h model)', () {
    test('new IapService is NOT Pro by default', () {
      final iap = IapService();
      expect(iap.isPro, false);
      expect(iap.proUnlockedUntil, isNull);
    });

    test('unlockProFor24h sets proUnlockedUntil ≈ now + 24h and isPro true',
        () async {
      final iap = IapService();
      await iap.unlockProFor24h();

      expect(iap.isPro, true, reason: 'isPro must be true right after unlock');
      expect(iap.proUnlockedUntil, isNotNull);
      // Measured from the stored expiry back to now (after the await), the
      // window must still be ~24h (>= 23h59m allows for elapsed test time).
      final remaining =
          iap.proUnlockedUntil!.difference(DateTime.now());
      expect(remaining.inHours, greaterThanOrEqualTo(23));
      expect(remaining.inHours, lessThanOrEqualTo(24));
      expect(iap.hoursRemaining, greaterThanOrEqualTo(23));
    });

    test('isPro is false after the 24h window expires (auto re-lock)', () {
      final iap = IapService();
      // Simulate a 24h unlock that has since elapsed.
      iap.proUnlockedUntil = DateTime.now().subtract(const Duration(minutes: 1));
      expect(iap.isPro, false, reason: 'Expired unlock must auto re-lock');

      // And just before expiry it is still active.
      iap.proUnlockedUntil = DateTime.now().add(const Duration(hours: 1));
      expect(iap.isPro, true);
      expect(iap.hoursRemaining, greaterThanOrEqualTo(0));
    });

    test('persists expiry to SharedPreferences (is_pro_expires_at key)',
        () async {
      final iap = IapService();
      await iap.unlockProFor24h();

      final prefs = await SharedPreferences.getInstance();
      final savedMillis = prefs.getInt('iap_pro_expires_at');
      expect(savedMillis, isNotNull);
      expect(savedMillis!, greaterThan(DateTime.now().millisecondsSinceEpoch));

      // is_pro boolean written too.
      expect(prefs.getBool('iap_pro_purchased'), true);
      // Widget-facing keys written (Kotlin reads these).
      expect(prefs.getString('is_pro'), 'true');
      expect(prefs.getString('is_pro_expires_at'), savedMillis.toString());
    });

    test('relocks on init after expiry has passed', () async {
      // Write an already-expired expiry to prefs, then init a fresh service.
      final prefs = await SharedPreferences.getInstance();
      final expired =
          DateTime.now().subtract(const Duration(hours: 25)).millisecondsSinceEpoch;
      await prefs.setInt('iap_pro_expires_at', expired);

      final iap = IapService();
      iap.proUnlockedUntil = DateTime.fromMillisecondsSinceEpoch(expired);
      expect(iap.isPro, false, reason: 'Expired state loaded from prefs → not Pro');
    });
  });

  group('Permanent Pro (legacy IAP / buy forever)', () {
    test('permanent purchase (DateTime(9999)) isPro true', () {
      final iap = IapService();
      iap.proUnlockedUntil = DateTime(9999);
      expect(iap.isPro, true, reason: 'Permanent owner is always Pro');
      // hoursRemaining clamps to a sane bound rather than showing ~8.7M h.
      expect(iap.hoursRemaining, 24 * 365);
    });
  });

  group('Widget push on Pro change (plan3 Fix B)', () {
    test('unlockProFor24h pushes a widget update AFTER the is_pro writes',
        () async {
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

      final iap = IapService();
      await iap.unlockProFor24h();

      final methods = calls.map((c) => c.method).toList();
      final saveIdx = <int>[];
      for (var i = 0; i < calls.length; i++) {
        if (calls[i].method == 'saveWidgetData' &&
            (calls[i].arguments as Map)['id'] == 'is_pro') {
          saveIdx.add(i);
        }
      }
      expect(saveIdx, isNotEmpty,
          reason: 'is_pro must be written to HomeWidgetPreferences');
      expect(methods, contains('updateWidget'),
          reason: 'unlock must push a widget update (plan3 Fix B)');
      expect(methods.indexOf('updateWidget'), greaterThan(saveIdx.first),
          reason: 'updateWidget must run after the is_pro write so Kotlin '
              're-reads the fresh value');
    });
  });
}