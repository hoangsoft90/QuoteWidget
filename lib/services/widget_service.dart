import 'dart:convert';
import 'dart:math';

import 'package:home_widget/home_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/item_model.dart';
import '../models/widget_config_model.dart';
import 'rotation_service.dart';
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

    // Forensic review fix: preserve NATIVE tap progress on re-sync. The user
    // cycles the widget on the Home Screen (Kotlin advances the prefs index,
    // Hive config.currentIndex stays 0). Re-syncing after an item edit used
    // to reset the displayed item to 0 — read the native index back and keep
    // it when it is still valid for the current pool.
    var displayIndex = config.currentIndex;
    if (resolvedId > 0) {
      final nativeIndex =
          await HomeWidget.getWidgetData<String>('widget_${resolvedId}_currentIndex');
      final parsed = int.tryParse(nativeIndex ?? '');
      if (parsed != null && parsed >= 0 && parsed < items.length) {
        displayIndex = parsed;
      }
    }

    String? text;
    if (items.isNotEmpty && displayIndex < items.length) {
      text = items[displayIndex].text;
    }

    final prefix = 'widget_$resolvedId';
    await HomeWidget.saveWidgetData('${prefix}_currentIndex', displayIndex.toString());
    await HomeWidget.saveWidgetData('${prefix}_collectionId', config.collectionId);
    await HomeWidget.saveWidgetData('${prefix}_rotationMode', config.rotationMode.name);
    await HomeWidget.saveWidgetData('${prefix}_totalItems', items.length.toString());
    await HomeWidget.saveWidgetData('${prefix}_text', text ?? '');
    // B1: optional author line — taken from the DISPLAYED item (index may
    // differ from config.currentIndex after a native tap), empty when unset.
    final displayedAuthor =
        (items.isNotEmpty && displayIndex >= 0 && displayIndex < items.length)
            ? items[displayIndex].author
            : null;
    await HomeWidget.saveWidgetData('${prefix}_author', displayedAuthor ?? '');
    // Phase 2A: ordered text pool for index-based native rotation. Flattened
    // primitives (JSON list of strings) — allowed by plan 2B native-keys rule.
    await HomeWidget.saveWidgetData(
      '${prefix}_items',
      jsonEncode(items.map((Item i) => i.text).toList()),
    );
    await HomeWidget.saveWidgetData('${prefix}_contentFilter', config.contentFilter.name);
    // Phase 2B: schedule + tap action (features_final §3).
    await HomeWidget.saveWidgetData('${prefix}_schedule', config.schedule.name);
    await HomeWidget.saveWidgetData('${prefix}_tapAction', config.tapAction.name);
    // Phase 2B: shuffle-bag + schedule state (features_final §2/§3). Native
    // keys are flat primitives; the bag is the one allowed JSON list.
    // Pass the preserved native index (not config.currentIndex, which Hive
    // keeps at 0) so a fresh bag never repeats the item currently shown.
    if (config.rotationMode == RotationMode.shuffleBag) {
      await _syncShuffleBag(prefix, items, displayIndex);
    }
    if (config.schedule == ScheduleMode.every1h ||
        config.schedule == ScheduleMode.every3h ||
        config.schedule == ScheduleMode.every6h) {
      final existing = await HomeWidget.getWidgetData<String>('${prefix}_next_rotation_at');
      if (existing == null || existing.isEmpty) {
        final next = RotationService()
            .nextRotationAt(schedule: config.schedule, now: DateTime.now());
        if (next != null) {
          await HomeWidget.saveWidgetData('${prefix}_next_rotation_at', next.toString());
        }
      }
    }
    if (config.schedule == ScheduleMode.daily) {
      final today = RotationService().localDateKey(DateTime.now());
      final dailyDate =
          await HomeWidget.getWidgetData<String>('${prefix}_daily_date');
      if (dailyDate == null || dailyDate.isEmpty) {
        // First daily activation (features_final §3.1): pin today's item.
        final itemIds = items.map((Item i) => i.id).toList();
        final idx = RotationService().dailyIndexForToday(
          itemIds: itemIds,
          previousDailyId: null,
        );
        await HomeWidget.saveWidgetData('${prefix}_daily_date', today);
        await _pinDailyItem(prefix, items, idx);
      } else if (dailyDate == today) {
        // P1-2: SAME day — today's quote must stay stable even when the pool
        // changed (an item deleted or reordered mid-day must not silently
        // shift the pinned quote to a different one). The pin is tracked by
        // ITEM ID (`daily_item_id`), not just an index.
        final pinnedId =
            await HomeWidget.getWidgetData<String>('${prefix}_daily_item_id');
        // Empty/absent id = the pin was chosen natively (Kotlin advanced the
        // day without a Flutter round-trip, or a legacy pre-P1-2 install) —
        // native has no id mapping, so leave its index pin untouched.
        if (pinnedId != null && pinnedId.isNotEmpty) {
          final currentIdx = items.indexWhere((i) => i.id == pinnedId);
          final storedIdx = int.tryParse(
                  await HomeWidget.getWidgetData<String>(
                          '${prefix}_daily_index') ??
                  '') ??
              -1;
          if (currentIdx >= 0) {
            // Pinned item still exists → keep it. Only refresh the INDEX if
            // a reorder shifted it (Kotlin snaps to daily_index on refresh).
            if (storedIdx != currentIdx) {
              await HomeWidget.saveWidgetData(
                  '${prefix}_daily_index', currentIdx.toString());
            }
          } else {
            // Pinned item deleted → pick a replacement for TODAY. Keep the
            // same daily_date (this is not a new day).
            final itemIds = items.map((Item i) => i.id).toList();
            final idx = RotationService().dailyIndexForToday(
              itemIds: itemIds,
              previousDailyId: pinnedId,
            );
            await _pinDailyItem(prefix, items, idx);
          }
        }
      }
      // dailyDate in the past → native advances the day on the next render
      // (resolveScheduleIndex), unchanged.
    }
    await HomeWidget.saveWidgetData('${prefix}_theme', config.appearance.theme);
    await HomeWidget.saveWidgetData('${prefix}_fontSize', config.appearance.fontSize.toString());
    await HomeWidget.saveWidgetData('${prefix}_textColor', config.appearance.textColor.toString());
    await HomeWidget.saveWidgetData('${prefix}_backgroundColor', config.appearance.background.toString());
    await HomeWidget.saveWidgetData('${prefix}_alignment', config.appearance.alignment.name);
    // A4: sizeCategory — NATIVE is source of truth. Kotlin persists the
    // resize-derived layout (onAppWidgetOptionsChanged writes
    // widget_<id>_sizeCategory into HomeWidgetPreferences). This sync must
    // NOT clobber it (a resized 4×2 wide widget used to shrink back to the
    // stale Hive value on the next item edit). Write Hive's value ONLY when
    // no native value exists yet (first sync of a brand-new widget).
    final nativeSize = await HomeWidget.getWidgetData<String>('${prefix}_sizeCategory');
    if (nativeSize == null || nativeSize.isEmpty) {
      await HomeWidget.saveWidgetData('${prefix}_sizeCategory', config.sizeCategory.name);
    }
    await HomeWidget.saveWidgetData('${prefix}_showProgress', config.showProgress.toString());

    // Update all widget instances
    await HomeWidget.updateWidget(
      name: 'QuoteWidgetProvider',
      androidName: 'QuoteWidgetProvider',
    );
  }

  /// P1-2: persist today's daily pin — index AND item id. The id is what
  /// keeps today's quote stable when the pool changes mid-day (index alone
  /// can silently point at a different item after a delete/reorder).
  Future<void> _pinDailyItem(String prefix, List<Item> items, int idx) async {
    await HomeWidget.saveWidgetData('${prefix}_daily_index', idx.toString());
    final id = (idx >= 0 && idx < items.length) ? items[idx].id : '';
    await HomeWidget.saveWidgetData('${prefix}_daily_item_id', id);
    if (idx >= 0 && idx < items.length) {
      // Show the freshly pinned item immediately (also overrides a stale
      // index when the previous pin was deleted).
      await HomeWidget.saveWidgetData('${prefix}_currentIndex', idx.toString());
    }
  }

  /// Phase 2B: (re)build the persisted shuffle bag when the source changed
  /// (features_final §2.4 invalidate-on-source-change) or no bag exists yet.
  /// The bag stores POOL INDICES (not item ids) because Kotlin only has the
  /// text pool — the fp below detects source changes so a stale index bag is
  /// always rebuilt before native rotation uses it.
  Future<void> _syncShuffleBag(String prefix, List<Item> items, int currentIndex) async {
    final fp = _sourceFingerprint(items);
    final previousFp = await HomeWidget.getWidgetData<String>('${prefix}_shuffle_source_fp');
    final existingBag = await HomeWidget.getWidgetData<String>('${prefix}_shuffle_bag');
    if (previousFp == fp && existingBag != null && existingBag.isNotEmpty) {
      return; // Source unchanged — keep native progress (force-stop safe).
    }

    // Build a fresh index bag; avoid starting with the current item
    // (features_final §2.3: new bag never starts with the item just shown).
    final count = items.length;
    var bag = List.generate(count, (i) => i)..shuffle(Random());
    if (count > 1 && bag.isNotEmpty && bag.first == currentIndex) {
      final swapIdx = 1 + Random().nextInt(count - 1);
      final tmp = bag[0];
      bag[0] = bag[swapIdx];
      bag[swapIdx] = tmp;
    }

    await HomeWidget.saveWidgetData('${prefix}_shuffle_bag', jsonEncode(bag));
    await HomeWidget.saveWidgetData('${prefix}_shuffle_index', '0');
    await HomeWidget.saveWidgetData('${prefix}_shuffle_source_fp', fp);
  }

  /// Deterministic fingerprint of the source item ids — detects add/remove
  /// so the bag invalidates (features_final §2.4).
  String _sourceFingerprint(List<Item> items) {
    final ids = items.map((i) => i.id).toList()..sort();
    return ids.join('|');
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
      try {
        // Look up the real appWidgetId from the mapping
        final appWidgetId = await WidgetDataBridge.getAppWidgetIdForConfig(config.id);
        if (appWidgetId != null) {
          await HomeWidget.saveWidgetData('widget_${appWidgetId}_status', 'removed');
        }
        await HomeWidget.updateWidget(
          name: 'QuoteWidgetProvider',
          androidName: 'QuoteWidgetProvider',
        );
      } catch (_) {
        // A3 defensive: widget host unavailable (tests / no home screen) —
        // the unbind in deleteCollection must still run after this.
      }
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

  /// P2-3: pure platform query — whether THIS device/launcher supports
  /// programmatic widget pinning. No dialog is shown (unlike
  /// [requestPinWidget]); used to show/hide the quick-add button.
  Future<bool> isRequestPinSupported() async {
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
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
