import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/services/widget_data_bridge.dart';

/// Tests simulating the REAL Android widget creation flow.
///
/// In the real flow:
/// 1. User drags widget from Android picker → Android creates appWidgetId
/// 2. QuoteWidgetProvider.onUpdate() is called with the new appWidgetId
/// 3. Kotlin checks SharedPreferences: is Pro? How many configured widgets?
/// 4. If Free + ≥1 configured → show upgrade prompt
/// 5. If Pro or first widget → show normal content
///
/// These tests verify the SharedPreferences state transitions that
/// Kotlin reads, without needing to mock Android framework classes.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Widget limit enforcement (simulates Kotlin onUpdate logic)', () {
    test('Free tier: first widget passes limit check', () async {
      // Simulate: no configured widgets yet
      await WidgetDataBridge.setProStatus(false);
      final configured = await WidgetDataBridge.getConfiguredWidgetIds();
      final isPro = await WidgetDataBridge.getProStatus();

      // Kotlin logic: !isPro && configured.size >= 1 → block
      final shouldBlock = !isPro && configured.length >= 1;
      expect(shouldBlock, false, reason: 'First widget should not be blocked');
    });

    test('Free tier: second widget is blocked', () async {
      // Simulate: one widget already configured
      await WidgetDataBridge.setProStatus(false);
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 1001,
        field: 'collectionId',
        value: 'collection-abc',
      );

      final configured = await WidgetDataBridge.getConfiguredWidgetIds();
      final isPro = await WidgetDataBridge.getProStatus();

      // Kotlin logic: !isPro && configured.size >= 1 → block
      final shouldBlock = !isPro && configured.length >= 1;
      expect(shouldBlock, true, reason: 'Second widget should be blocked on Free tier');
      expect(configured.length, 1, reason: 'One widget already configured');
    });

    test('Pro tier: unlimited widgets pass limit check', () async {
      // Simulate: Pro user with 3 configured widgets
      await WidgetDataBridge.setProStatus(true);
      for (var i = 1001; i <= 1003; i++) {
        await WidgetDataBridge.setWidgetData(
          appWidgetId: i,
          field: 'collectionId',
          value: 'collection-$i',
        );
      }

      final configured = await WidgetDataBridge.getConfiguredWidgetIds();
      final isPro = await WidgetDataBridge.getProStatus();

      // Kotlin logic: isPro → never block
      final shouldBlock = !isPro && configured.length >= 1;
      expect(shouldBlock, false, reason: 'Pro user should never be blocked');
      expect(configured.length, 3, reason: 'All 3 widgets configured');
    });

    test('Pro upgrade unlocks existing blocked widgets', () async {
      // Simulate: user had 1 configured widget, then upgraded to Pro
      await WidgetDataBridge.setProStatus(false);
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 1001,
        field: 'collectionId',
        value: 'collection-abc',
      );

      // Check: blocked before upgrade
      var configured = await WidgetDataBridge.getConfiguredWidgetIds();
      var isPro = await WidgetDataBridge.getProStatus();
      expect(!isPro && configured.length >= 1, true, reason: 'Blocked before upgrade');

      // Upgrade to Pro
      await WidgetDataBridge.setProStatus(true);

      // Check: unblocked after upgrade
      configured = await WidgetDataBridge.getConfiguredWidgetIds();
      isPro = await WidgetDataBridge.getProStatus();
      expect(!isPro && configured.length >= 1, false, reason: 'Unblocked after Pro upgrade');
    });
  });

  group('Widget data bridge (SharedPreferences consistency)', () {
    test('write and read widget data with same appWidgetId', () async {
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 42,
        field: 'collectionId',
        value: 'test-collection',
      );
      await WidgetDataBridge.setWidgetInt(
        appWidgetId: 42,
        field: 'currentIndex',
        value: 3,
      );

      final collectionId = await WidgetDataBridge.getWidgetData(
        appWidgetId: 42,
        field: 'collectionId',
      );
      final currentIndex = await WidgetDataBridge.getWidgetInt(
        appWidgetId: 42,
        field: 'currentIndex',
      );

      expect(collectionId, 'test-collection');
      expect(currentIndex, 3);
    });

    test('isWidgetConfigured returns false for new widget', () async {
      final configured = await WidgetDataBridge.isWidgetConfigured(999);
      expect(configured, false);
    });

    test('isWidgetConfigured returns true after setting collectionId', () async {
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 999,
        field: 'collectionId',
        value: 'some-collection',
      );
      final configured = await WidgetDataBridge.isWidgetConfigured(999);
      expect(configured, true);
    });

    test('isWidgetConfigured returns false for empty collectionId', () async {
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 999,
        field: 'collectionId',
        value: '',
      );
      final configured = await WidgetDataBridge.isWidgetConfigured(999);
      expect(configured, false);
    });

    test('multiple widgets have independent data', () async {
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 100,
        field: 'text',
        value: 'Widget A text',
      );
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 200,
        field: 'text',
        value: 'Widget B text',
      );

      final textA = await WidgetDataBridge.getWidgetData(appWidgetId: 100, field: 'text');
      final textB = await WidgetDataBridge.getWidgetData(appWidgetId: 200, field: 'text');

      expect(textA, 'Widget A text');
      expect(textB, 'Widget B text');
    });

    test('Pro status persists across reads', () async {
      await WidgetDataBridge.setProStatus(true);
      expect(await WidgetDataBridge.getProStatus(), true);

      await WidgetDataBridge.setProStatus(false);
      expect(await WidgetDataBridge.getProStatus(), false);
    });
  });

  group('Real flow simulation: Free user places 2 widgets', () {
    test('full flow: widget 1 configured, widget 2 shows upgrade', () async {
      // Step 1: User places first widget from Android picker
      // Kotlin: onUpdate(appWidgetIds=[1001])
      // → No data for widget 1001 → show "Tap to set up"
      var configured = await WidgetDataBridge.getConfiguredWidgetIds();
      expect(configured, isEmpty, reason: 'No widgets configured yet');

      // Step 2: User opens app, configures widget 1001
      // Flutter: creates WidgetConfig, writes data via bridge
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 1001,
        field: 'collectionId',
        value: 'my-collection',
      );
      await WidgetDataBridge.setWidgetData(
        appWidgetId: 1001,
        field: 'text',
        value: 'Hello from widget 1',
      );

      configured = await WidgetDataBridge.getConfiguredWidgetIds();
      expect(configured.length, 1);
      expect(configured.contains(1001), true);

      // Step 3: User places second widget from Android picker
      // Kotlin: onUpdate(appWidgetIds=[1001, 1002])
      // → Widget 1002 is new, not configured
      // → Free tier, already has 1 configured → BLOCK
      final isPro = await WidgetDataBridge.getProStatus();
      final shouldBlock = !isPro && configured.length >= 1;
      expect(shouldBlock, true, reason: 'Second widget blocked on Free tier');

      // Step 4: Kotlin shows "Upgrade to Pro" on widget 1002
      // (verified by shouldBlock == true above)

      // Step 5: User purchases Pro
      await WidgetDataBridge.setProStatus(true);

      // Step 6: Widget 1002 should now be accessible
      final shouldBlockAfterUpgrade = !await WidgetDataBridge.getProStatus() && configured.length >= 1;
      expect(shouldBlockAfterUpgrade, false, reason: 'After Pro upgrade, widget 1002 accessible');
    });
  });
}
