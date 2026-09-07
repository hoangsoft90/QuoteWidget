import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/services/widget_data_bridge.dart';

/// f54623f follow-up: prefs hygiene for the Pro-expiry bridge keys.
///
/// The Dart shared_preferences plugin maps the logical key
/// `is_pro_expires_at` to the physical `flutter.is_pro_expires_at` entry in
/// its real platform store — exactly the key Kotlin's getLong() fallback
/// reads (FlutterSharedPreferences). An explicit second write of a
/// 'flutter.'-prefixed key used to create a double-prefixed rubbish key
/// flutter.flutter.is_pro_expires_at that nothing could read.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WidgetDataBridge pro-expiry prefs hygiene', () {
    test('setProExpiry writes the plain key, no double-prefixed rubbish',
        () async {
      final expiry = DateTime.now().add(const Duration(hours: 24));

      await WidgetDataBridge.setProExpiry(expiry);

      final prefs = await SharedPreferences.getInstance();
      final expected = expiry.millisecondsSinceEpoch.toString();

      // In the test mock the store holds the key exactly as written — the
      // flutter. prefix is applied by the plugin's real platform store, not
      // by the mock backend. So assert the logical key here; on device the
      // plugin persists it physically as flutter.is_pro_expires_at, which is
      // the key Kotlin reads back.
      expect(prefs.getString('is_pro_expires_at'), expected);

      // No double-prefixed rubbish key may exist under any backend (mock or
      // device): this is what an explicit 'flutter.'-prefixed write creates.
      expect(
        prefs.getKeys().where((k) => k.startsWith('flutter.flutter.')),
        isEmpty,
        reason: 'explicit flutter.-prefixed writes get auto-prefixed again '
            'into an unreadable flutter.flutter.* key — must not be written',
      );
    });

    test('setProExpiry(null) persists 0 (= never unlocked)', () async {
      await WidgetDataBridge.setProExpiry(null);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('is_pro_expires_at'), '0');
      expect(await WidgetDataBridge.getProExpiry(), 0);
    });

    test('getProExpiry reads back the persisted window', () async {
      final expiry = DateTime.now().add(const Duration(hours: 24));
      await WidgetDataBridge.setProExpiry(expiry);

      expect(await WidgetDataBridge.getProExpiry(),
          expiry.millisecondsSinceEpoch);
    });

    test('getProExpiry returns 0 when nothing was ever written', () async {
      expect(await WidgetDataBridge.getProExpiry(), 0);
    });
  });
}
