import 'package:hive_flutter/hive_flutter.dart';
import '../models/collection_model.dart';
import '../models/item_model.dart';
import '../models/widget_config_model.dart';
import 'snapshot_manager.dart';

class StorageService {
  static const String collectionsBoxName = 'collections';
  static const String itemsBoxName = 'items';
  static const String widgetConfigsBoxName = 'widget_configs';

  late Box<Collection> _collectionsBox;
  late Box<Item> _itemsBox;
  late Box<WidgetConfig> _widgetConfigsBox;
  SnapshotManager? _snapshotManager;
  bool _isPro = false;
  static bool _adaptersRegistered = false;

  /// Inject SnapshotManager for safety snapshots before destructive operations.
  /// Called once at startup after both services are created.
  void setSnapshotManager(SnapshotManager manager) {
    _snapshotManager = manager;
  }

  /// Set Pro status for widget limit enforcement.
  /// Called once at startup after IapService initializes.
  void setProStatus(bool isPro) {
    _isPro = isPro;
  }

  // Initialize Hive and open boxes.
  // If [testPath] is provided, use Hive.init() instead of initFlutter() (for unit tests).
  Future<void> init({String? testPath}) async {
    if (testPath != null) {
      Hive.init(testPath);
    } else {
      await Hive.initFlutter();
    }

    // Register adapters (only once, even if init() is called multiple times)
    if (!_adaptersRegistered) {
      Hive.registerAdapter(CollectionAdapter());
      Hive.registerAdapter(ItemAdapter());
      Hive.registerAdapter(WidgetConfigAdapter());
      Hive.registerAdapter(AppearanceConfigAdapter());
      Hive.registerAdapter(RotationModeAdapter());
      Hive.registerAdapter(SizeCategoryAdapter());
      Hive.registerAdapter(TextAlignmentAdapter());
      _adaptersRegistered = true;
    }

    // Open boxes
    _collectionsBox = await Hive.openBox<Collection>(collectionsBoxName);
    _itemsBox = await Hive.openBox<Item>(itemsBoxName);
    _widgetConfigsBox = await Hive.openBox<WidgetConfig>(widgetConfigsBoxName);
  }

  // Close boxes
  Future<void> close() async {
    await Hive.close();
  }

  // ==================== Collections ====================

  Future<Collection> createCollection(String name) async {
    final collection = Collection.create(name: name);
    await _collectionsBox.put(collection.id, collection);
    return collection;
  }

  List<Collection> getAllCollections() {
    return _collectionsBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Collection? getCollection(String id) {
    return _collectionsBox.get(id);
  }

  Future<void> updateCollection(String id, String name) async {
    final collection = _collectionsBox.get(id);
    if (collection != null) {
      collection.name = name;
      await collection.save();
    }
  }

  Future<void> deleteCollection(String id) async {
    // Safety snapshot before destructive operation (plan §2)
    if (_snapshotManager != null) {
      await _snapshotManager!.createSnapshot(
        collections: getAllCollections(),
        items: getAllItems(),
        widgetConfigs: getAllWidgetConfigs(),
      );
    }

    // Cascade delete: delete all items in this collection
    final items = _itemsBox.values
        .where((item) => item.collectionId == id)
        .toList();
    for (final item in items) {
      await item.delete();
    }

    // Cascade delete: delete all widget configs for this collection
    final widgetConfigs = _widgetConfigsBox.values
        .where((config) => config.collectionId == id)
        .toList();
    for (final config in widgetConfigs) {
      await config.delete();
    }

    // Delete the collection itself
    await _collectionsBox.delete(id);
  }

  int getItemCountForCollection(String collectionId) {
    return _itemsBox.values
        .where((item) => item.collectionId == collectionId)
        .length;
  }

  // ==================== Items ====================

  Future<Item> createItem({
    required String collectionId,
    required String text,
    required int order,
  }) async {
    final item = Item.create(
      collectionId: collectionId,
      text: text,
      order: order,
    );
    await _itemsBox.put(item.id, item);
    return item;
  }

  List<Item> getItemsForCollection(String collectionId) {
    return _itemsBox.values
        .where((item) => item.collectionId == collectionId)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  List<Item> getAllItems() {
    return _itemsBox.values.toList();
  }

  Item? getItem(String id) {
    return _itemsBox.get(id);
  }

  Future<void> updateItem(String id, String text) async {
    final item = _itemsBox.get(id);
    if (item != null) {
      item.text = text;
      await item.save();
    }
  }

  Future<void> deleteItem(String id) async {
    await _itemsBox.delete(id);
  }

  Future<void> reorderItems(String collectionId, List<String> itemIds) async {
    for (int i = 0; i < itemIds.length; i++) {
      final item = _itemsBox.get(itemIds[i]);
      if (item != null && item.collectionId == collectionId) {
        item.order = i;
        await item.save();
      }
    }
  }

  Future<List<Item>> bulkAddItems({
    required String collectionId,
    required List<String> texts,
  }) async {
    final existingItems = getItemsForCollection(collectionId);
    final nextOrder = existingItems.isEmpty
        ? 0
        : existingItems.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;

    final items = <Item>[];
    for (int i = 0; i < texts.length; i++) {
      final item = Item.create(
        collectionId: collectionId,
        text: texts[i],
        order: nextOrder + i,
      );
      await _itemsBox.put(item.id, item);
      items.add(item);
    }
    return items;
  }

  // ==================== WidgetConfigs ====================

  /// Creates a new WidgetConfig.
  /// Throws [WidgetLimitReachedException] if Free user already has ≥1 widget.
  Future<WidgetConfig> createWidgetConfig({
    required String collectionId,
    SizeCategory sizeCategory = SizeCategory.small,
  }) async {
    // Free tier: max 1 widget. Pro: unlimited.
    if (!_isPro && _widgetConfigsBox.isNotEmpty) {
      throw WidgetLimitReachedException();
    }

    final config = WidgetConfig.create(
      collectionId: collectionId,
      sizeCategory: sizeCategory,
    );
    await _widgetConfigsBox.put(config.id, config);
    return config;
  }

  List<WidgetConfig> getAllWidgetConfigs() {
    return _widgetConfigsBox.values.toList();
  }

  WidgetConfig? getWidgetConfig(String id) {
    return _widgetConfigsBox.get(id);
  }

  Future<void> updateWidgetConfig(WidgetConfig config) async {
    await _widgetConfigsBox.put(config.id, config);
  }

  Future<void> deleteWidgetConfig(String id) async {
    await _widgetConfigsBox.delete(id);
  }

  // ==================== Backup/Restore ====================

  Future<void> clearAll() async {
    await _collectionsBox.clear();
    await _itemsBox.clear();
    await _widgetConfigsBox.clear();
  }

  Future<void> restoreFromBackup({
    required List<Collection> collections,
    required List<Item> items,
    required List<WidgetConfig> widgetConfigs,
  }) async {
    await clearAll();

    for (final collection in collections) {
      await _collectionsBox.put(collection.id, collection);
    }

    for (final item in items) {
      await _itemsBox.put(item.id, item);
    }

    for (final config in widgetConfigs) {
      await _widgetConfigsBox.put(config.id, config);
    }
  }

  Future<void> appendFromBackup({
    required List<Collection> collections,
    required List<Item> items,
    required List<WidgetConfig> widgetConfigs,
  }) async {
    // Append collections (skip if ID exists)
    for (final collection in collections) {
      if (_collectionsBox.get(collection.id) == null) {
        await _collectionsBox.put(collection.id, collection);
      }
    }

    // Append items (skip if ID exists)
    for (final item in items) {
      if (_itemsBox.get(item.id) == null) {
        await _itemsBox.put(item.id, item);
      }
    }

    // Append widget configs (skip if ID exists)
    for (final config in widgetConfigs) {
      if (_widgetConfigsBox.get(config.id) == null) {
        await _widgetConfigsBox.put(config.id, config);
      }
    }
  }
}

/// Thrown when a Free-tier user tries to create more than 1 widget.
class WidgetLimitReachedException implements Exception {
  final String message;
  WidgetLimitReachedException({this.message = 'Free tier allows 1 widget. Upgrade to Pro for unlimited widgets.'});
  @override
  String toString() => message;
}
