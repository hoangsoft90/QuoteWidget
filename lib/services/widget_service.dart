import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/item_model.dart';
import '../models/widget_config_model.dart';
import 'storage_service.dart';
import 'widget_data_bridge.dart';

class WidgetService {
  final StorageService _storageService;

  WidgetService(this._storageService);

  /// Sync widget data from Hive to SharedPreferences.
  /// Uses WidgetDataBridge (shared prefs) so Kotlin can read it directly.
  /// The [appWidgetId] is the Android system widget instance ID.
  /// If not provided, looks up via the appWidgetId↔config mapping.
  ///
  /// Phase 2A — Favorites-only: when [WidgetConfig.contentFilter] is
  /// [ContentFilter.favoritesOnly], the rotation pool is the collection's
  /// favorite items only. The ordered TEXT POOL is written as a JSON list
  /// (`widget_<id>_items`) so Kotlin's tap-to-cycle picks `pool[index]` and
  /// actually changes the displayed text (fixes the single-`_text` bug where
  /// tap only advanced the counter).
  Future<void> syncWidgetData(WidgetConfig config, {int? appWidgetId}) async {
    // Resolve appWidgetId from mapping if not provided
    final resolvedId = appWidgetId ?? await WidgetDataBridge.getAppWidgetIdForConfig(config.id) ?? 0;

    final allItems = _storageService.getItemsForCollection(config.collectionId);
    final items = config.contentFilter == ContentFilter.favoritesOnly
        ? allItems.where((i) => i.favorite).toList()
        : allItems;

    String? text;
    if (items.isNotEmpty && config.currentIndex < items.length) {
      text = items[config.currentIndex].text;
    }

    final prefix = 'widget_$resolvedId';
    await HomeWidget.saveWidgetData('${prefix}_currentIndex', config.currentIndex.toString());
    await HomeWidget.saveWidgetData('${prefix}_collectionId', config.collectionId);
    await HomeWidget.saveWidgetData('${prefix}_rotationMode', config.rotationMode.name);
    await HomeWidget.saveWidgetData('${prefix}_totalItems', items.length.toString());
    await HomeWidget.saveWidgetData('${prefix}_text', text ?? '');
    // Phase 2A: ordered text pool for index-based native rotation. Flattened
    // primitives (JSON list of strings) — allowed by plan 2B native-keys rule.
    await HomeWidget.saveWidgetData(
      '${prefix}_items',
      jsonEncode(items.map((Item i) => i.text).toList()),
    );
    await HomeWidget.saveWidgetData('${prefix}_contentFilter', config.contentFilter.name);
    await HomeWidget.saveWidgetData('${prefix}_theme', config.appearance.theme);
    await HomeWidget.saveWidgetData('${prefix}_fontSize', config.appearance.fontSize.toString());
    await HomeWidget.saveWidgetData('${prefix}_textColor', config.appearance.textColor.toString());
    await HomeWidget.saveWidgetData('${prefix}_backgroundColor', config.appearance.background.toString());
    await HomeWidget.saveWidgetData('${prefix}_alignment', config.appearance.alignment.name);
    await HomeWidget.saveWidgetData('${prefix}_sizeCategory', config.sizeCategory.name);
    await HomeWidget.saveWidgetData('${prefix}_showProgress', config.showProgress.toString());

    // Update all widget instances
    await HomeWidget.updateWidget(
      name: 'QuoteWidgetProvider',
      androidName: 'QuoteWidgetProvider',
    );
  }

  /// Update widget after data change
  Future<void> updateWidget(String widgetId) async {
    final config = _storageService.getWidgetConfig(widgetId);
    if (config != null) {
      await syncWidgetData(config);
    }
  }

  /// Update all widgets for a collection
  Future<void> updateWidgetsForCollection(String collectionId) async {
    final configs = _storageService.getAllWidgetConfigs()
        .where((c) => c.collectionId == collectionId)
        .toList();

    for (final config in configs) {
      await syncWidgetData(config);
    }
  }

  /// Mark widgets pointing to a deleted collection.
  /// Uses a dedicated _status key instead of a sentinel in the text field,
  /// so user content can never collide with internal state markers.
  Future<void> markCollectionRemoved(String collectionId) async {
    final configs = _storageService.getAllWidgetConfigs()
        .where((c) => c.collectionId == collectionId)
        .toList();

    for (final config in configs) {
      // Look up the real appWidgetId from the mapping
      final appWidgetId = await WidgetDataBridge.getAppWidgetIdForConfig(config.id);
      if (appWidgetId != null) {
        await HomeWidget.saveWidgetData('widget_${appWidgetId}_status', 'removed');
      }
      await HomeWidget.updateWidget(
        name: 'QuoteWidgetProvider',
        androidName: 'QuoteWidgetProvider',
      );
    }
  }

  /// Sync Pro status + expiry to SharedPreferences so Kotlin can read it.
  /// [proUnlockedUntil] null = not unlocked; DateTime(9999) = permanent.
  ///
  /// Called once at app startup with the freshly-loaded status. Also pushes a
  /// widget update so Kotlin re-renders — plan5 Sprint 0 §1.6: without this, a
  /// widget whose 24h pass expired while the app was closed would keep showing
  /// stale content forever (updatePeriodMillis=0 → no system refresh; the
  /// lock only applies on a render). The push makes expiry self-apply at next
  /// app open. Best-effort: never break app startup on a missing widget host.
  Future<void> syncProStatus(bool isPro, {DateTime? proUnlockedUntil}) async {
    await HomeWidget.saveWidgetData('is_pro', isPro.toString());
    final millis = proUnlockedUntil?.millisecondsSinceEpoch ?? 0;
    await HomeWidget.saveWidgetData('is_pro_expires_at', millis.toString());
    await WidgetDataBridge.setProExpiry(proUnlockedUntil);
    try {
      await HomeWidget.updateWidget(
        name: 'QuoteWidgetProvider',
        androidName: 'QuoteWidgetProvider',
      );
    } catch (_) {
      // No widget host (unit tests / non-Android) — ignore.
    }
  }

  /// Get device manufacturer for OEM-specific guides
  Future<String> getDeviceManufacturer() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.manufacturer.toLowerCase();
    } catch (e) {
      return 'unknown';
    }
  }

  /// Try to pin widget using Android API (Android 8.0+)
  Future<bool> requestPinWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        androidName: 'QuoteWidgetProvider',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get OEM-specific widget guide instructions
  WidgetGuide getGuideForDevice(String manufacturer) {
    switch (manufacturer) {
      case 'samsung':
        return WidgetGuide(
          manufacturer: 'Samsung',
          title: 'Samsung One UI',
          steps: [
            'Long press on home screen',
            'Tap "Widgets"',
            'Find "Your Words"',
            'Tap "Add" or drag to home screen',
          ],
          imageUrl: 'assets/guides/samsung_guide.png',
        );
      case 'xiaomi':
        return WidgetGuide(
          manufacturer: 'Xiaomi',
          title: 'Xiaomi MIUI',
          steps: [
            'Long press on home screen',
            'Tap "Add widgets"',
            'Find "Your Words"',
            'Tap to add',
          ],
          imageUrl: 'assets/guides/xiaomi_guide.png',
        );
      default:
        return WidgetGuide(
          manufacturer: 'Android',
          title: 'Stock Android',
          steps: [
            'Long press on home screen',
            'Tap "Widgets"',
            'Find "Your Words"',
            'Drag to home screen',
          ],
          imageUrl: 'assets/guides/stock_guide.png',
        );
    }
  }
}

class WidgetGuide {
  final String manufacturer;
  final String title;
  final List<String> steps;
  final String imageUrl;

  WidgetGuide({
    required this.manufacturer,
    required this.title,
    required this.steps,
    required this.imageUrl,
  });
}
