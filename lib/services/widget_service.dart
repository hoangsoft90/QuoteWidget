import 'package:home_widget/home_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
  Future<void> syncWidgetData(WidgetConfig config, {int? appWidgetId}) async {
    // Resolve appWidgetId from mapping if not provided
    final resolvedId = appWidgetId ?? await WidgetDataBridge.getAppWidgetIdForConfig(config.id) ?? 0;

    final items = _storageService.getItemsForCollection(config.collectionId);

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

  /// Sync Pro status to SharedPreferences so Kotlin can read it.
  Future<void> syncProStatus(bool isPro) async {
    await HomeWidget.saveWidgetData('is_pro', isPro.toString());
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
