import 'collection_model.dart';
import 'item_model.dart';
import 'widget_config_model.dart';

class BackupData {
  final String backupFormat;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final String platform;
  final List<Collection> collections;
  final List<Item> items;
  final List<WidgetConfig> widgetConfigs;

  BackupData({
    required this.backupFormat,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.platform,
    required this.collections,
    required this.items,
    required this.widgetConfigs,
  });

  factory BackupData.create({
    required List<Collection> collections,
    required List<Item> items,
    required List<WidgetConfig> widgetConfigs,
  }) {
    return BackupData(
      backupFormat: 'quote-widget-backup',
      schemaVersion: 1,
      appVersion: '1.0.0',
      createdAt: DateTime.now(),
      platform: 'android',
      collections: collections,
      items: items,
      widgetConfigs: widgetConfigs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'backupFormat': backupFormat,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toIso8601String(),
      'platform': platform,
      'collections': collections.map((c) => c.toJson()).toList(),
      'items': items.map((i) => i.toJson()).toList(),
      'widgetConfigs': widgetConfigs.map((w) => w.toJson()).toList(),
    };
  }

  factory BackupData.fromJson(Map<String, dynamic> json) {
    return BackupData(
      backupFormat: json['backupFormat'] as String,
      schemaVersion: json['schemaVersion'] as int,
      appVersion: json['appVersion'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      platform: json['platform'] as String,
      collections: (json['collections'] as List)
          .map((c) => Collection.fromJson(c as Map<String, dynamic>))
          .toList(),
      items: (json['items'] as List)
          .map((i) => Item.fromJson(i as Map<String, dynamic>))
          .toList(),
      widgetConfigs: (json['widgetConfigs'] as List)
          .map((w) => WidgetConfig.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }

  // Validate backup data
  static ValidationResult validate(Map<String, dynamic> json) {
    final errors = <String>[];

    if (json['backupFormat'] != 'quote-widget-backup') {
      errors.add('Invalid backup format');
    }

    if (json['schemaVersion'] == null) {
      errors.add('Missing schema version');
    }

    if (json['collections'] == null || json['items'] == null || json['widgetConfigs'] == null) {
      errors.add('Missing required fields');
    }

    // Validate items have required fields
    if (json['items'] is List) {
      for (var i = 0; i < (json['items'] as List).length; i++) {
        final item = json['items'][i];
        if (item['id'] == null || item['collectionId'] == null || item['text'] == null) {
          errors.add('Item at index $i missing required fields');
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;

  ValidationResult({
    required this.isValid,
    required this.errors,
  });
}
