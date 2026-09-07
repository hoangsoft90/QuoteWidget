import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/collection_model.dart';
import '../models/widget_config_model.dart';
import '../services/backup_service.dart';
import '../services/interstitial_ad_service.dart';
import '../services/snapshot_manager.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../services/widget_data_bridge.dart';
import '../services/iap_service.dart';
import '../services/rewarded_ad_service.dart';
import 'collection_detail_screen.dart';
import 'home_screen.dart';
import 'package:home_widget/home_widget.dart';
import '../widgets/paywall_sheet.dart';

/// Screen shown when user taps an unconfigured/empty widget on Home Screen.
/// If [collectionId] is null → shows collection picker (first-time setup).
/// If [collectionId] is provided → opens collection detail to add items.
///
/// This is the in-app widget-limit block point: a Free user trying to add a
/// 2nd widget hits [WidgetLimitReachedException] here and sees a rewarded-ad
/// unlock dialog instead of a dead-end (Task 1 acceptance).
class WidgetSetupScreen extends StatefulWidget {
  final int appWidgetId;
  final String? collectionId;
  final StorageService storageService;
  final WidgetService widgetService;
  final IapService iapService;
  final RewardedAdService rewardedAdService;
  final InterstitialAdController interstitialAdController;
  final BackupService backupService;
  final SnapshotManager snapshotManager;

  const WidgetSetupScreen({
    super.key,
    required this.appWidgetId,
    this.collectionId,
    required this.storageService,
    required this.widgetService,
    required this.iapService,
    required this.rewardedAdService,
    required this.interstitialAdController,
    required this.backupService,
    required this.snapshotManager,
  });

  @override
  State<WidgetSetupScreen> createState() => _WidgetSetupScreenState();
}

class _WidgetSetupScreenState extends State<WidgetSetupScreen> {
  List<Collection> _collections = [];
  Collection? _selectedCollection;
  bool _saving = false;

  /// Phase 2A — Favorites-only widget (features_final §1.4). When enabled,
  /// the widget's rotation pool is the collection's favorite items only.
  bool _favoritesOnly = false;

  /// Phase 2B — rotation order / schedule / tap action (features_final §3).
  RotationMode _rotationMode = RotationMode.sequential;
  ScheduleMode _schedule = ScheduleMode.manual;
  TapAction _tapAction = TapAction.next;

  @override
  void initState() {
    super.initState();
    _collections = widget.storageService.getAllCollections();

    // If collectionId is provided, auto-select it and save immediately
    if (widget.collectionId != null) {
      final col = widget.storageService.getCollection(widget.collectionId!);
      if (col != null) {
        _selectedCollection = col;
        // Auto-save and navigate to collection detail
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _saveAndNavigateToDetail();
        });
      }
    }
  }

  /// P1-3: run the post-create chain — registerWidgetMapping →
  /// syncWidgetData → updateWidget. If ANY step after [createWidgetConfig]
  /// fails, roll the freshly-created config back ([unbindWidgetConfig]:
  /// Hive config + partial wcfg_* mapping + native registry/display data)
  /// so a half-configured setup never leaves a phantom config behind.
  /// Returns false when the setup failed (config already rolled back).
  Future<bool> _bindWidget(WidgetConfig config) async {
    try {
      // Register mapping: appWidgetId ↔ configId
      await WidgetDataBridge.registerWidgetMapping(
        appWidgetId: widget.appWidgetId,
        configId: config.id,
      );

      // Sync data to HomeWidgetPreferences so Kotlin can read it
      await widget.widgetService.syncWidgetData(
        config,
        appWidgetId: widget.appWidgetId,
      );

      // Trigger widget refresh
      await HomeWidget.updateWidget(
        name: 'QuoteWidgetProvider',
        androidName: 'QuoteWidgetProvider',
      );
      return true;
    } catch (_) {
      // Rollback: reuse the existing full unbind (never writes new delete
      // logic) — safe both when the mapping already ran and when it didn't.
      await widget.storageService.unbindWidgetConfig(config.id);
      return false;
    }
  }

  /// P1-3: honest failure feedback — never leave the screen hanging or claim
  /// success when the widget could not be set up.
  void _showSetupError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Không thể thiết lập widget, vui lòng thử lại')),
    );
  }

  /// Shared setup head: create the WidgetConfig (honoring the Free-limit
  /// gate). Returns null when the limit blocked the creation (caller shows
  /// the unlock dialog). Throws for any other create failure.
  Future<WidgetConfig?> _createConfig() async {
    try {
      return await widget.storageService.createWidgetConfig(
        collectionId: _selectedCollection!.id,
        contentFilter:
            _favoritesOnly ? ContentFilter.favoritesOnly : ContentFilter.all,
        rotationMode: _rotationMode,
        schedule: _schedule,
        tapAction: _tapAction,
      );
    } on WidgetLimitReachedException {
      return null;
    }
  }

  Future<void> _saveAndNavigateToDetail() async {
    if (_selectedCollection == null || _saving) return;
    setState(() => _saving = true);

    // Create WidgetConfig (throws WidgetLimitReachedException for Free 2nd)
    final config = await _createConfig();
    if (config == null) {
      if (mounted) setState(() => _saving = false);
      await _showUnlockDialog();
      return;
    }

    // P1-3: bind + sync with rollback on any post-create failure.
    final bound = await _bindWidget(config);
    if (!bound) {
      if (mounted) setState(() => _saving = false);
      _showSetupError();
      return;
    }

    // Clear tapped ids
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tapped_widget_id');
    await prefs.remove('tapped_collection_id');

    if (mounted) {
      // Navigate to collection detail screen to add items
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CollectionDetailScreen(
            collection: _selectedCollection!,
            storageService: widget.storageService,
            widgetService: widget.widgetService,
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_selectedCollection == null || _saving) return;
    setState(() => _saving = true);

    // Create WidgetConfig (throws WidgetLimitReachedException for Free 2nd)
    final config = await _createConfig();
    if (config == null) {
      if (mounted) setState(() => _saving = false);
      await _showUnlockDialog();
      return;
    }

    // P1-3: bind + sync with rollback on any post-create failure.
    final bound = await _bindWidget(config);
    if (!bound) {
      if (mounted) setState(() => _saving = false);
      _showSetupError();
      return;
    }

    // Clear the tapped_widget_id
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tapped_widget_id');

    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        // Cold-start deep link: this screen IS the root route. Popping it
        // would leave an empty Navigator (black screen) — replace with Home
        // instead so the user always has a screen to return to.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              storageService: widget.storageService,
              widgetService: widget.widgetService,
              iapService: widget.iapService,
              rewardedAdService: widget.rewardedAdService,
              interstitialAdController: widget.interstitialAdController,
              backupService: widget.backupService,
              snapshotManager: widget.snapshotManager,
            ),
          ),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Widget configured!')),
      );
    }
  }

  /// Show the paywall when the Free widget limit blocks a 2nd widget (plan4
  /// Sprint A-5: shared with the native upgrade-prompt deep link). On a
  /// successful unlock, retries the save so the setup completes in one flow.
  Future<void> _showUnlockDialog() async {
    if (!mounted) return;
    final result = await showPaywallSheet(
      context,
      iapService: widget.iapService,
      rewardedAdService: widget.rewardedAdService,
    );
    if (mounted && result == PaywallResult.adGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Now add your widget.')),
      );
      await _save();
    }
  }

  String _rotationLabel(RotationMode mode) => switch (mode) {
        RotationMode.sequential => 'Sequential (in order)',
        RotationMode.random => 'Random (no immediate repeat)',
        RotationMode.shuffleBag => 'Shuffle (no repeats until done)',
      };

  String _scheduleLabel(ScheduleMode s) => switch (s) {
        ScheduleMode.manual => 'Manual (tap to change)',
        ScheduleMode.daily => 'Daily (one item per day)',
        ScheduleMode.every1h => 'Auto — every hour',
        ScheduleMode.every3h => 'Auto — every 3 hours',
        ScheduleMode.every6h => 'Auto — every 6 hours',
      };

  String _tapActionLabel(TapAction a) => switch (a) {
        TapAction.next => 'Next item',
        TapAction.openCollection => 'Open collection',
        TapAction.openApp => 'Open app',
        TapAction.copy => 'Copy text',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Widget'),
      ),
      body: _collections.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No collections yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create a collection first, then come back to set up your widget.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _collections.length,
              itemBuilder: (context, index) {
                final col = _collections[index];
                final isSelected = _selectedCollection?.id == col.id;
                final itemCount = widget.storageService
                    .getItemCountForCollection(col.id);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        col.name.isNotEmpty ? col.name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(col.name),
                    subtitle: Text('$itemCount items'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() => _selectedCollection = col);
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: _collections.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phase 2A — Favorites-only toggle.
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Favorites only'),
                      subtitle: const Text(
                        'Widget shows only starred items',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _favoritesOnly,
                      onChanged: (value) =>
                          setState(() => _favoritesOnly = value),
                    ),
                    // Phase 2B — rotation order.
                    DropdownButtonFormField<RotationMode>(
                      initialValue: _rotationMode,
                      decoration: const InputDecoration(
                        labelText: 'Rotation',
                        isDense: true,
                      ),
                      items: [
                        for (final mode in RotationMode.values)
                          DropdownMenuItem(
                            value: mode,
                            child: Text(_rotationLabel(mode)),
                          ),
                      ],
                      onChanged: (value) => setState(
                          () => _rotationMode = value ?? RotationMode.sequential),
                    ),
                    const SizedBox(height: 8),
                    // Phase 2B — schedule.
                    DropdownButtonFormField<ScheduleMode>(
                      initialValue: _schedule,
                      decoration: const InputDecoration(
                        labelText: 'Schedule',
                        isDense: true,
                      ),
                      items: [
                        for (final s in ScheduleMode.values)
                          DropdownMenuItem(
                            value: s,
                            child: Text(_scheduleLabel(s)),
                          ),
                      ],
                      onChanged: (value) => setState(
                          () => _schedule = value ?? ScheduleMode.manual),
                    ),
                    const SizedBox(height: 8),
                    // Phase 2B — tap action.
                    DropdownButtonFormField<TapAction>(
                      initialValue: _tapAction,
                      decoration: const InputDecoration(
                        labelText: 'Tap action',
                        isDense: true,
                      ),
                      items: [
                        for (final a in TapAction.values)
                          DropdownMenuItem(
                            value: a,
                            child: Text(_tapActionLabel(a)),
                          ),
                      ],
                      onChanged: (value) => setState(
                          () => _tapAction = value ?? TapAction.next),
                    ),
                    if (_schedule != ScheduleMode.manual) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Auto-rotate may be delayed on some devices to save battery.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                    ElevatedButton(
                  onPressed: _selectedCollection != null && !_saving
                      ? _save
                      : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Set Up Widget'),
                ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
