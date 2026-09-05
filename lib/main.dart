import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/item_model.dart';
import 'services/storage_service.dart';
import 'services/widget_service.dart';
import 'services/widget_data_bridge.dart';
import 'services/backup_service.dart';
import 'services/share_service.dart';
import 'services/snapshot_manager.dart';
import 'services/ad_config.dart';
import 'services/iap_service.dart';
import 'services/interstitial_ad_service.dart';
import 'services/rewarded_ad_service.dart';
import 'services/toast_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/collection_picker_dialog.dart';
import 'screens/widget_setup_screen.dart';
import 'widgets/paywall_sheet.dart';
import 'widgets/share_target_dialog.dart';
import 'widgets/share_undo_snackbar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sentry crash/error reporting (Flutter + native Android via manifest DSN).
  // init is awaited FIRST so errors in the service setup below are captured.
  await SentryFlutter.init(
    (options) {
      options.dsn =
          'https://a387c41f7f60045b744b5d112f3adbef@o4505474077753344.ingest.us.sentry.io/4512011826364416';
      // Errors are always reported; tracing (performance) is off for now.
      options.tracesSampleRate = 0.0;
    },
  );

  // Initialize storage service
  final storageService = StorageService();
  await storageService.init();

  // plan4 Sprint A-1: free-limit gate reads the NATIVE configured-widget count
  // (configured_widget_ids) instead of trusting the Hive box alone — the two
  // can diverge and leave a Free user with a widget stuck on "Upgrade to Pro".
  storageService.setWidgetCountProvider(
    WidgetDataBridge.getNativeConfiguredWidgetCount,
  );
  // plan4 Sprint A-2: hybrid reconciliation — compare Hive configs with the
  // native registry at startup and clean orphaned configs whose physical
  // widget no longer exists (fast path: counts match → no full scan).
  storageService.setWidgetIdsProvider(
    WidgetDataBridge.getNativeConfiguredWidgetIds,
  );
  await storageService.reconcileWidgetConfigs();

  // Purge trash items/collections past the 30-day retention (Task 7).
  await storageService.purgeTrash();

  // Initialize other services
  final widgetService = WidgetService(storageService);
  final snapshotManager = SnapshotManager();
  storageService.setSnapshotManager(snapshotManager);
  final backupService = BackupService(storageService, snapshotManager);
  final iapService = IapService();
  await iapService.init();
  // Live time-bound Pro provider: re-evaluates on every widget-limit check,
  // so a 24h unlock re-locks automatically when it expires.
  storageService.setProStatusProvider(() => iapService.isPro);
  await widgetService.syncProStatus(
    iapService.isPro,
    proUnlockedUntil: iapService.proUnlockedUntil,
  );

  // Init rewarded ads (primary monetization path)
  final rewardedAdService = RewardedAdService(iapService);
  final interstitialAdController = InterstitialAdController();
  if (AdConfig.supported) {
    try {
      await RewardedAdService.initMobileAds();
      await rewardedAdService.loadRewardedAd();
    } catch (_) {
      // Ads unavailable (no Play Services / no network) — non-fatal.
    }
  }

  // Check if first launch
  final prefs = await SharedPreferences.getInstance();
  final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

  // Check for pending share text
  final pendingShareText = prefs.getString('pending_share_text');
  if (pendingShareText != null && pendingShareText.isNotEmpty) {
    // Clear the pending share
    await prefs.remove('pending_share_text');
    await prefs.remove('share_timestamp');
  }

  // Check if opened from widget tap (deep link for unconfigured widget)
  final tappedWidgetIdStr = prefs.getString('tapped_widget_id');
  final tappedWidgetId = tappedWidgetIdStr != null ? int.tryParse(tappedWidgetIdStr) : null;
  final tappedCollectionId = prefs.getString('tapped_collection_id');
  if (tappedWidgetId != null) {
    await prefs.remove('tapped_widget_id');
    await prefs.remove('tapped_collection_id');
  }

  // plan4 Sprint A-5: native "Upgrade to Pro" widget tap → open the paywall
  // bottom sheet on cold start. MainActivity persists pending_route (both
  // prefs files); read + clear it here, then hand the flag to the app.
  final pendingRoute = prefs.getString('pending_route');
  final showPaywallOnStart = pendingRoute == 'paywall';
  if (pendingRoute != null) {
    await prefs.remove('pending_route');
  }

  // plan6 C1: reconcile native configured-widget ids against Hive configs.
  // The OLD code compared int appWidgetIds against String config UUIDs
  // (always false) and silenced the dead result with an `// ignore:
  // unused_local_variable` — the reconciliation never actually ran. Correct
  // version: for each native id, resolve its `wcfg_<id>_configId` mapping;
  // if the referenced config no longer exists in Hive, the mapping is stale
  // → clean it (both directions). Runs in a microtask so a large widget
  // list never blocks the first frame.
  Future<void> reconcileNativeWidgetMappings() async {
    final configuredIdsStr = prefs.getString('configured_widget_ids') ?? '';
    final configuredIds = configuredIdsStr
        .split(',')
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s) ?? -1)
        .where((id) => id >= 0)
        .toList();
    if (configuredIds.isEmpty) return;
    await storageService.cleanupOrphanWidgetMappings(configuredIds);
  }

  Future.microtask(reconcileNativeWidgetMappings);

  runApp(QuoteWidgetApp(
    storageService: storageService,
    widgetService: widgetService,
    backupService: backupService,
    snapshotManager: snapshotManager,
    iapService: iapService,
    rewardedAdService: rewardedAdService,
    interstitialAdController: interstitialAdController,
    onboardingComplete: onboardingComplete,
    pendingShareText: pendingShareText,
    tappedWidgetId: tappedWidgetId,
    tappedCollectionId: tappedCollectionId,
    showPaywallOnStart: showPaywallOnStart,
  ));
}

class QuoteWidgetApp extends StatefulWidget {
  final StorageService storageService;
  final WidgetService widgetService;
  final BackupService backupService;
  final SnapshotManager snapshotManager;
  final IapService iapService;
  final RewardedAdService rewardedAdService;
  final InterstitialAdController interstitialAdController;
  final bool onboardingComplete;
  final String? pendingShareText;
  final int? tappedWidgetId;
  final String? tappedCollectionId;
  final bool showPaywallOnStart;

  const QuoteWidgetApp({
    super.key,
    required this.storageService,
    required this.widgetService,
    required this.backupService,
    required this.snapshotManager,
    required this.iapService,
    required this.rewardedAdService,
    required this.interstitialAdController,
    required this.onboardingComplete,
    this.pendingShareText,
    this.tappedWidgetId,
    this.tappedCollectionId,
    this.showPaywallOnStart = false,
  });

  @override
  State<QuoteWidgetApp> createState() => _QuoteWidgetAppState();
}

class _QuoteWidgetAppState extends State<QuoteWidgetApp> with WidgetsBindingObserver {
  // plan4 Sprint A-5: the app widget sits ABOVE MaterialApp's Navigator, so
  // Navigator.of(this.context) would fail — use the navigator key instead.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingShare();
      if (widget.showPaywallOnStart) {
        _openPaywall();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingWidgetTap();
      // plan4 Sprint A-2: reconcile Hive ↔ native on resume (a widget may
      // have been added/removed on the Home Screen while the app was away).
      widget.storageService.reconcileWidgetConfigs();
      // plan4 Sprint A-5: warm-start paywall deep link (tapped "Upgrade to
      // Pro" on the widget while the app was backgrounded).
      _checkPendingPaywallRoute();
    }
  }

  /// Open the shared paywall sheet (plan4 Sprint A-5). Uses the navigator
  /// key so it works regardless of which route is on top.
  Future<void> _openPaywall() async {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null || !mounted) return;
    await showPaywallSheet(
      navigatorContext,
      iapService: widget.iapService,
      rewardedAdService: widget.rewardedAdService,
    );
  }

  /// Warm-start variant: check pending_route in prefs (written by
  /// MainActivity.onNewIntent) and clear it.
  Future<void> _checkPendingPaywallRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final route = prefs.getString('pending_route');
    if (route != 'paywall') return;
    await prefs.remove('pending_route');
    if (!mounted) return;
    await _openPaywall();
  }

  /// Fallback for warm-start: when app resumes, check if a new widget tap
  /// pending in SharedPreferences (written by MainActivity.onNewIntent).
  Future<void> _checkPendingWidgetTap() async {
    final prefs = await SharedPreferences.getInstance();
    final tappedWidgetIdStr = prefs.getString('tapped_widget_id');
    if (tappedWidgetIdStr == null) return;

    final tappedWidgetId = int.tryParse(tappedWidgetIdStr);
    final tappedCollectionId = prefs.getString('tapped_collection_id');
    await prefs.remove('tapped_widget_id');
    await prefs.remove('tapped_collection_id');

    if (tappedWidgetId == null || !mounted) return;

    // Navigate to WidgetSetupScreen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WidgetSetupScreen(
          appWidgetId: tappedWidgetId,
          collectionId: tappedCollectionId,
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

  Future<void> _handlePendingShare() async {
    if (widget.pendingShareText != null && widget.pendingShareText!.isNotEmpty) {
      final shareService = ShareService(widget.storageService);
      final collections = widget.storageService.getAllCollections();

      if (collections.isEmpty) {
        // Toast (system-level) — no app screen is guaranteed to be visible.
        ToastService.show('Create a collection first to save shared content');
        return;
      }

      // The save runs post-frame while the app UI is on screen, so the
      // confirmation is a SnackBar with an Undo action (plan5 Sprint 0 §1.7):
      // visible, tappable, auto-expires after 10s. This state sits ABOVE
      // MaterialApp's Navigator/ScaffoldMessenger, so use the navigator-key
      // context — the app-level context would crash showDialog/ScaffoldMessenger.
      final navigatorContext = _navigatorKey.currentContext;

      // After a successful save, show "Saved to X" + Undo (soft-delete the
      // just-created item + refresh affected widgets). Failures keep the
      // system Toast — there is nothing to undo.
      void confirmSaved(
          Item savedItem, String collectionName, String collectionId) {
        if (navigatorContext == null || !navigatorContext.mounted) return;
        final messenger = ScaffoldMessenger.of(navigatorContext);
        showShareUndoSnackBar(
          messenger,
          collectionName: collectionName,
          onUndo: () async {
            // Undo = soft-delete (app's Trash model, recoverable) of the
            // exact item just saved + refresh any widget showing this
            // collection so the new content disappears.
            await widget.storageService.deleteItem(savedItem.id);
            await widget.widgetService.updateWidgetsForCollection(collectionId);
          },
        );
      }

      // plan6 H5: explicit share-target dialog instead of silent auto-save.
      // Phase 2B: default = last-used collection (remembered per share),
      // falling back to the most recent collection (newest-first).
      // No 5s auto-save timer — the user decides on every share.
      final prefs = await SharedPreferences.getInstance();
      final lastCollectionId = prefs.getString('last_share_collection_id');

      Future<void> saveAndConfirm(String collectionId, String collectionName) async {
        final saved = await shareService.saveToCollection(
          text: widget.pendingShareText!,
          collectionId: collectionId,
        );
        if (saved == null) {
          await ToastService.show('Failed to save');
          return;
        }
        // Phase 2B: remember the chosen collection for the next share.
        await prefs.setString('last_share_collection_id', collectionId);
        // Refresh any widget showing this collection so new content shows.
        await widget.widgetService.updateWidgetsForCollection(collectionId);
        confirmSaved(saved, collectionName, collectionId);
      }

      final defaultCollection = collections.firstWhere(
        (c) => c.id == lastCollectionId,
        orElse: () => collections.first,
      );
      if (navigatorContext == null || !navigatorContext.mounted) return;
      showShareTargetDialog(
        navigatorContext,
        defaultCollection: defaultCollection,
      ).then((action) {
        if (action == ShareTargetAction.saveDefault) {
          saveAndConfirm(defaultCollection.id, defaultCollection.name);
        } else if (action == ShareTargetAction.changeCollection &&
            navigatorContext.mounted) {
          showDialog(
            context: navigatorContext,
            builder: (context) => CollectionPickerDialog(
              storageService: widget.storageService,
              onSelected: (collection) {
                saveAndConfirm(collection.id, collection.name);
              },
            ),
          );
        }
        // cancel → abort, nothing saved.
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Quote Widget - Your Words',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: widget.tappedWidgetId != null
          ? WidgetSetupScreen(
              appWidgetId: widget.tappedWidgetId!,
              collectionId: widget.tappedCollectionId,
              storageService: widget.storageService,
              widgetService: widget.widgetService,
              iapService: widget.iapService,
              rewardedAdService: widget.rewardedAdService,
              interstitialAdController: widget.interstitialAdController,
              backupService: widget.backupService,
              snapshotManager: widget.snapshotManager,
            )
          : widget.onboardingComplete
              ? HomeScreen(
                  storageService: widget.storageService,
                  widgetService: widget.widgetService,
                  iapService: widget.iapService,
                  rewardedAdService: widget.rewardedAdService,
                  interstitialAdController: widget.interstitialAdController,
                  backupService: widget.backupService,
                  snapshotManager: widget.snapshotManager,
                )
              : OnboardingScreen(
                  storageService: widget.storageService,
                  widgetService: widget.widgetService,
                  iapService: widget.iapService,
                  rewardedAdService: widget.rewardedAdService,
                  interstitialAdController: widget.interstitialAdController,
                  backupService: widget.backupService,
                  snapshotManager: widget.snapshotManager,
                ),
    );
  }
}
