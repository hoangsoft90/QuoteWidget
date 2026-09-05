import 'package:hive_flutter/hive_flutter.dart';
import '../models/collection_model.dart';
import '../models/item_model.dart';
import '../models/widget_config_model.dart';
import 'snapshot_manager.dart';
import 'widget_data_bridge.dart';

class StorageService {
  static const String collectionsBoxName = 'collections';
  static const String itemsBoxName = 'items';
  static const String widgetConfigsBoxName = 'widget_configs';

  late Box<Collection> _collectionsBox;
  late Box<Item> _itemsBox;
  late Box<WidgetConfig> _widgetConfigsBox;
  SnapshotManager? _snapshotManager;
  bool Function()? _isProProvider;
  bool _isPro = false;

  /// Injectable provider for the NATIVE configured-widget count
  /// (configured_widget_ids in SharedPreferences). When null (unit tests,
  /// non-Android, channel unavailable) the free-limit gate falls back to the
  /// Hive box length so behavior never silently loosens.
  Future<int?> Function()? _widgetCountProvider;

  /// Injectable provider for the NATIVE configured-widget appWidgetIds.
  /// Used by [reconcileWidgetConfigs] to detect orphaned Hive configs.
  Future<List<int>?> Function()? _widgetIdsProvider;

  /// Guards [reconcileWidgetConfigs] against re-entrant runs (resume firing
  /// while the start-up reconciliation is still scanning).
  bool _reconciling = false;

  static bool _adaptersRegistered = false;

  /// Inject SnapshotManager for safety snapshots before destructive operations.
  /// Called once at startup after both services are created.
  void setSnapshotManager(SnapshotManager manager) {
    _snapshotManager = manager;
  }

  /// Set a live Pro-status provider for widget limit enforcement.
  /// The provider is re-evaluated on every check, so when a 24h unlock
  /// expires the limit re-engages automatically without restart.
  void setProStatusProvider(bool Function() isProProvider) {
    _isProProvider = isProProvider;
  }

  /// Set Pro status for widget limit enforcement (static fallback).
  /// Called once at startup after IapService initializes.
  void setProStatus(bool isPro) {
    _isPro = isPro;
  }

  /// Inject the native configured-widget count provider (plan4 Sprint A-1).
  /// Production wires it to [WidgetDataBridge.getNativeConfiguredWidgetCount];
  /// tests inject a fake so the gate is verified without platform channels.
  void setWidgetCountProvider(Future<int?> Function() provider) {
    _widgetCountProvider = provider;
  }

  /// Inject the native configured-widget appWidgetIds provider (plan4 A-2).
  /// Production wires it to [WidgetDataBridge.getNativeConfiguredWidgetIds].
  void setWidgetIdsProvider(Future<List<int>?> Function() provider) {
    _widgetIdsProvider = provider;
  }

  /// Effective widget count for the free-limit gate: native count when
  /// available, Hive box length otherwise (same behavior as before the fix).
  Future<int> _effectiveWidgetCount() async {
    final provider = _widgetCountProvider;
    if (provider != null) {
      final nativeCount = await provider();
      if (nativeCount != null) return nativeCount;
    }
    return _widgetConfigsBox.length;
  }

  /// Current Pro status — prefers the live provider, falls back to the
  /// static value (used in tests / when no provider is injected).
  bool get _isProActive => _isProProvider?.call() ?? _isPro;

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
      Hive.registerAdapter(ContentFilterAdapter());
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

  /// Duplicate a collection with all its items (Phase 2A — features_final
  /// §1.4). New IDs everywhere; name becomes `name (Copy)` (or `name (Copy 2)`
  /// if the plain copy name exists). Items are inserted in ONE batch putAll —
  /// no per-item awaits, no jank on large collections.
  Future<Collection> duplicateCollection(String sourceId) async {
    final source = _collectionsBox.get(sourceId);
    if (source == null || source.isDeleted) {
      throw StateError('Source collection not found');
    }

    var copyName = '${source.name} (Copy)';
    var suffix = 2;
    final existingNames = _collectionsBox.values
        .where((c) => !c.isDeleted)
        .map((c) => c.name)
        .toSet();
    while (existingNames.contains(copyName)) {
      copyName = '${source.name} (Copy ${suffix++})';
    }

    final copy = Collection.create(name: copyName);
    final sourceItems = getItemsForCollection(sourceId);
    // Item.create generates fresh ids; then carry over the favorite flag.
    final copiedItems = sourceItems.map((item) {
      final copyItem = Item.create(
        collectionId: copy.id,
        text: item.text,
        order: item.order,
      );
      copyItem.favorite = item.favorite;
      return copyItem;
    }).toList();

    // Batch insert both boxes in one map each — avoids N sequential awaits.
    await _collectionsBox.put(copy.id, copy);
    if (copiedItems.isNotEmpty) {
      await _itemsBox.putAll({for (final i in copiedItems) i.id: i});
    }
    return copy;
  }

  /// Active (non-trashed) collections, newest first.
  List<Collection> getAllCollections() {
    return _collectionsBox.values
        .where((c) => !c.isDeleted)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Collection? getCollection(String id) {
    final collection = _collectionsBox.get(id);
    if (collection == null || collection.isDeleted) return null;
    return collection;
  }

  Future<void> updateCollection(String id, String name) async {
    final collection = _collectionsBox.get(id);
    if (collection != null && !collection.isDeleted) {
      collection.name = name;
      await collection.save();
    }
  }

  /// Soft-delete a collection (Trash): flag collection + its items; widget
  /// configs tied to it are removed (the widget shows "Collection removed"
  /// until reconfigured). Data stays in Hive for restore / 30-day purge.
  Future<void> deleteCollection(String id) async {
    // Safety snapshot before destructive operation (plan §2) — captured while
    // the collection is still active so it can be restored from the snapshot.
    if (_snapshotManager != null) {
      await _snapshotManager!.createSnapshot(
        collections: getAllCollections(),
        items: getAllItems(),
        widgetConfigs: getAllWidgetConfigs(),
      );
    }

    final now = DateTime.now();
    final collection = _collectionsBox.get(id);
    if (collection == null) return;

    // Flag the collection itself.
    collection.isDeleted = true;
    collection.deletedAt = now;
    await collection.save();

    // Flag all its items so restore can bring the whole set back.
    final items = _itemsBox.values
        .where((item) => item.collectionId == id && !item.isDeleted)
        .toList();
    for (final item in items) {
      item.isDeleted = true;
      item.deletedAt = now;
      await item.save();
    }

    // Remove widget configs pointing at this collection (no orphan widgets).
    final widgetConfigs = _widgetConfigsBox.values
        .where((config) => config.collectionId == id)
        .toList();
    for (final config in widgetConfigs) {
      await config.delete();
    }
  }

  /// Restore a trashed collection + its trashed items.
  Future<void> restoreCollection(String id) async {
    final collection = _collectionsBox.get(id);
    if (collection == null || !collection.isDeleted) return;
    collection.isDeleted = false;
    collection.deletedAt = null;
    await collection.save();

    final items = _itemsBox.values
        .where((item) => item.collectionId == id && item.isDeleted)
        .toList();
    for (final item in items) {
      item.isDeleted = false;
      item.deletedAt = null;
      await item.save();
    }
  }

  /// Permanently delete a trashed collection + its remaining items.
  Future<void> permanentlyDeleteCollection(String id) async {
    final items = _itemsBox.values
        .where((item) => item.collectionId == id)
        .toList();
    for (final item in items) {
      await item.delete();
    }
    await _collectionsBox.delete(id);
  }

  /// Trashed collections (Recently Deleted screen).
  List<Collection> getTrashedCollections() {
    return _collectionsBox.values.where((c) => c.isDeleted).toList()
      ..sort((a, b) => (b.deletedAt ?? b.createdAt)
          .compareTo(a.deletedAt ?? a.createdAt));
  }

  /// Trashed items (Recently Deleted screen).
  List<Item> getTrashedItems() {
    return _itemsBox.values.where((i) => i.isDeleted).toList()
      ..sort((a, b) => (b.deletedAt ?? b.createdAt)
          .compareTo(a.deletedAt ?? a.createdAt));
  }

  /// Purge items/collections trashed more than [retention] ago.
  /// Called at app start; defaults to 30 days (Task 7).
  Future<void> purgeTrash({Duration retention = const Duration(days: 30)}) async {
    final cutoff = DateTime.now().subtract(retention);

    final expiredCollections = _collectionsBox.values
        .where((c) => c.isDeleted && (c.deletedAt ?? c.createdAt).isBefore(cutoff))
        .toList();
    for (final collection in expiredCollections) {
      await permanentlyDeleteCollection(collection.id);
    }

    final expiredItems = _itemsBox.values
        .where((i) => i.isDeleted && (i.deletedAt ?? i.createdAt).isBefore(cutoff))
        .toList();
    for (final item in expiredItems) {
      await item.delete();
    }
  }

  int getItemCountForCollection(String collectionId) {
    return _itemsBox.values
        .where((item) => item.collectionId == collectionId && !item.isDeleted)
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

  /// Active (non-trashed) items of a collection, by order.
  List<Item> getItemsForCollection(String collectionId) {
    return _itemsBox.values
        .where((item) => item.collectionId == collectionId && !item.isDeleted)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Active (non-trashed) items across all collections.
  List<Item> getAllItems() {
    return _itemsBox.values.where((item) => !item.isDeleted).toList();
  }

  Item? getItem(String id) {
    final item = _itemsBox.get(id);
    if (item == null || item.isDeleted) return null;
    return item;
  }

  Future<void> updateItem(String id, String text) async {
    final item = _itemsBox.get(id);
    if (item != null && !item.isDeleted) {
      item.text = text;
      await item.save();
    }
  }

  /// Set/unset the favorite flag on an item (Phase 2A — Favorites).
  Future<void> setItemFavorite(String id, bool favorite) async {
    final item = _itemsBox.get(id);
    if (item == null || item.isDeleted) return;
    item.favorite = favorite;
    await item.save();
  }

  /// Toggle the favorite flag, returns the new value.
  Future<bool> toggleItemFavorite(String id) async {
    final item = _itemsBox.get(id);
    if (item == null || item.isDeleted) return false;
    item.favorite = !item.favorite;
    await item.save();
    return item.favorite;
  }

  /// Favorite (non-trashed) items of a collection, by order.
  /// Used by the Favorites-only filter in Collection Detail and by the
  /// favorites-only widget content filter (features_final §1.4).
  List<Item> getFavoriteItemsForCollection(String collectionId) {
    return _itemsBox.values
        .where((item) =>
            item.collectionId == collectionId && !item.isDeleted && item.favorite)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Soft-delete an item (Trash). Data stays in Hive for restore / purge.
  Future<void> deleteItem(String id) async {
    final item = _itemsBox.get(id);
    if (item == null || item.isDeleted) return;
    item.isDeleted = true;
    item.deletedAt = DateTime.now();
    await item.save();
  }

  /// Restore a single trashed item.
  Future<void> restoreItem(String id) async {
    final item = _itemsBox.get(id);
    if (item == null || !item.isDeleted) return;
    item.isDeleted = false;
    item.deletedAt = null;
    await item.save();
  }

  /// Permanently delete a single trashed item.
  Future<void> permanentlyDeleteItem(String id) async {
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
  ///
  /// plan4 Sprint A-1: the gate reads the NATIVE configured-widget count
  /// (configured_widget_ids — the physical source of truth), NOT the Hive box
  /// alone. Without this, deleting the collection of the only configured
  /// widget empties the Hive box and lets Free users configure a 2nd widget
  /// that then shows "Upgrade to Pro" forever natively (dead-end trap).
  Future<WidgetConfig> createWidgetConfig({
    required String collectionId,
    SizeCategory sizeCategory = SizeCategory.small,
    ContentFilter contentFilter = ContentFilter.all,
  }) async {
    // Free tier: max 1 widget. Pro: unlimited.
    if (!_isProActive && await _effectiveWidgetCount() >= 1) {
      throw WidgetLimitReachedException();
    }

    final config = WidgetConfig.create(
      collectionId: collectionId,
      sizeCategory: sizeCategory,
      contentFilter: contentFilter,
    );
    await _widgetConfigsBox.put(config.id, config);
    return config;
  }

  /// Hybrid reconciliation (plan4 Sprint A-2, hardened Phase 1 P0-2).
  ///
  /// ALWAYS runs the full 2-way scan whenever the native widget-id list is
  /// available — the old "count == count → fast path" skip was a P1 bug: an
  /// equal count can still hide a broken/absent mapping ("count bằng nhau nhưng
  /// mapping gãy").
  ///
  /// Direction 1 — every Hive config must be backed by a live physical widget:
  ///   - `appWidgetId == null` (no wcfg_* mapping at all) → unbound/phantom
  ///     config → delete.
  ///   - mapped `appWidgetId` not in the native set → physical widget is gone
  ///     (deleted off the Home Screen while the app was closed) → delete the
  ///     config AND its wcfg_* mapping (both directions).
  /// Direction 2 — every native widget must not hold a stale mapping:
  ///   - `wcfg_<id>_configId` points at a config missing from Hive (its
  ///     collection was deleted) → remove the stale mapping (both directions).
  ///   - no mapping → unconfigured widget → left alone ("Tap to set up").
  ///
  /// Never destroys data when the native channel is unavailable (provider
  /// returns null). Guarded against re-entrant runs (resume while scanning).
  Future<void> reconcileWidgetConfigs() async {
    final provider = _widgetIdsProvider;
    if (provider == null || _reconciling) return;

    final nativeIds = await provider();
    if (nativeIds == null) return; // channel unavailable → don't destroy data
    final nativeIdSet = nativeIds.toSet();

    _reconciling = true;
    try {
      final hiveConfigs = _widgetConfigsBox.values.toList();
      // Direction 1: Hive config → mapping → live native widget.
      for (final config in hiveConfigs) {
        final appWidgetId =
            await WidgetDataBridge.getAppWidgetIdForConfig(config.id);
        if (appWidgetId == null) {
          // Unbound / phantom config — no physical widget ever claimed it.
          await _widgetConfigsBox.delete(config.id);
        } else if (!nativeIdSet.contains(appWidgetId)) {
          // Physical widget gone → clean config + mapping (both directions).
          await WidgetDataBridge.removeWidgetMapping(appWidgetId);
          await _widgetConfigsBox.delete(config.id);
        }
      }
      // Direction 2: native widget → mapping → live Hive config.
      final liveConfigIds = _widgetConfigsBox.keys.toSet();
      for (final nativeId in nativeIds) {
        final configId =
            await WidgetDataBridge.getConfigIdForWidget(nativeId);
        if (configId != null && !liveConfigIds.contains(configId)) {
          // Stale mapping (config deleted, e.g. its collection was removed).
          await WidgetDataBridge.removeWidgetMapping(nativeId);
        }
        // configId == null → unconfigured widget → keep ("Tap to set up").
      }
    } finally {
      _reconciling = false;
    }
  }

  List<WidgetConfig> getAllWidgetConfigs() {
    return _widgetConfigsBox.values.toList();
  }

  /// plan6 C1: clean orphan `wcfg_*` mappings at startup.
  ///
  /// A native widget whose Hive config no longer exists (e.g. its collection
  /// was deleted) leaves a stale `wcfg_<appWidgetId>_configId` +
  /// `wcfg_<configId>_appWidgetId` pair behind. Android may later reuse the
  /// appWidgetId, so a stale mapping must not survive. Widgets WITHOUT a
  /// mapping are unconfigured — left alone (the native "Tap to set up"
  /// state). Never throws on malformed input.
  Future<void> cleanupOrphanWidgetMappings(List<int> configuredIds) async {
    if (configuredIds.isEmpty) return;
    final existingConfigIds = _widgetConfigsBox.keys.toSet();
    for (final appWidgetId in configuredIds) {
      final configId =
          await WidgetDataBridge.getConfigIdForWidget(appWidgetId);
      if (configId == null) continue; // no mapping → unconfigured, keep
      if (!existingConfigIds.contains(configId)) {
        await WidgetDataBridge.removeWidgetMapping(appWidgetId);
      }
    }
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
