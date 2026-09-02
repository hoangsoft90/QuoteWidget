import 'package:shared_preferences/shared_preferences.dart';

/// Bridge between Flutter and Kotlin for widget SharedPreferences data.
///
/// Both sides MUST use the same file and key format:
///   File: "quotewidget_widget_data"
///   Keys: "widget_${appWidgetId}_${fieldName}"
///
/// This replaces the home_widget plugin's data storage for widget state,
/// because home_widget writes to its own SharedPreferences file which
/// Kotlin cannot reliably read.
class WidgetDataBridge {
  static const String _proStatusKey = 'is_pro';

  /// Write a widget field to SharedPreferences.
  static Future<void> setWidgetData({
    required int appWidgetId,
    required String field,
    required String value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_${appWidgetId}_$field', value);
  }

  /// Read a widget field from SharedPreferences.
  static Future<String?> getWidgetData({
    required int appWidgetId,
    required String field,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('widget_${appWidgetId}_$field');
  }

  /// Write an integer widget field.
  static Future<void> setWidgetInt({
    required int appWidgetId,
    required String field,
    required int value,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('widget_${appWidgetId}_$field', value);
  }

  /// Read an integer widget field (with default).
  static Future<int> getWidgetInt({
    required int appWidgetId,
    required String field,
    int defaultValue = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('widget_${appWidgetId}_$field') ?? defaultValue;
  }

  /// Check if a widget has been configured (has a collectionId).
  static Future<bool> isWidgetConfigured(int appWidgetId) async {
    final collectionId = await getWidgetData(
      appWidgetId: appWidgetId,
      field: 'collectionId',
    );
    return collectionId != null && collectionId.isNotEmpty;
  }

  /// Get all configured widget appWidgetIds.
  static Future<List<int>> getConfiguredWidgetIds() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final widgetIds = <int>{};
    for (final key in keys) {
      if (key.startsWith('widget_') && key.endsWith('_collectionId')) {
        final idStr = key.substring(7, key.length - 13); // Extract appWidgetId
        final id = int.tryParse(idStr);
        if (id != null) {
          final collectionId = prefs.getString(key);
          if (collectionId != null && collectionId.isNotEmpty) {
            widgetIds.add(id);
          }
        }
      }
    }
    return widgetIds.toList()..sort();
  }

  /// Set Pro status (synced from Flutter).
  static Future<void> setProStatus(bool isPro) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proStatusKey, isPro);
  }

  /// Get Pro status (read by Kotlin).
  static Future<bool> getProStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_proStatusKey) ?? false;
  }

  /// Update all widget fields for a given appWidgetId from a data map.
  static Future<void> syncAllWidgetData({
    required int appWidgetId,
    required Map<String, String> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in data.entries) {
      await prefs.setString('widget_${appWidgetId}_${entry.key}', entry.value);
    }
  }

  // ==================== appWidgetId ↔ WidgetConfig mapping ====================
  // When Android creates a widget via system picker, it assigns an appWidgetId.
  // Flutter's WidgetConfig has its own Hive UUID. We need a mapping so Flutter
  // can find the appWidgetId for a given WidgetConfig, and vice versa.

  static const String _mappingPrefix = 'wcfg_';

  /// Register a mapping: appWidgetId → configId (called when Kotlin configures).
  static Future<void> registerWidgetMapping({
    required int appWidgetId,
    required String configId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_mappingPrefix${appWidgetId}_configId', configId);
    await prefs.setString('$_mappingPrefix${configId}_appWidgetId', appWidgetId.toString());
  }

  /// Get appWidgetId for a WidgetConfig (returns null if not mapped).
  static Future<int?> getAppWidgetIdForConfig(String configId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('$_mappingPrefix${configId}_appWidgetId');
    return str != null ? int.tryParse(str) : null;
  }

  /// Get configId for an appWidgetId (returns null if not mapped).
  static Future<String?> getConfigIdForWidget(int appWidgetId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_mappingPrefix${appWidgetId}_configId');
  }

  /// Remove a widget mapping (called on widget delete).
  static Future<void> removeWidgetMapping(int appWidgetId) async {
    final prefs = await SharedPreferences.getInstance();
    final configId = prefs.getString('$_mappingPrefix${appWidgetId}_configId');
    if (configId != null) {
      await prefs.remove('$_mappingPrefix${appWidgetId}_configId');
      await prefs.remove('$_mappingPrefix${configId}_appWidgetId');
    }
  }
}
