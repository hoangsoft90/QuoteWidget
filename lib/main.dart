import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'services/storage_service.dart';
import 'services/widget_service.dart';
import 'services/backup_service.dart';
import 'services/share_service.dart';
import 'services/snapshot_manager.dart';
import 'services/iap_service.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/collection_picker_dialog.dart';
import 'screens/widget_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage service
  final storageService = StorageService();
  await storageService.init();

  // Initialize other services
  final widgetService = WidgetService(storageService);
  final snapshotManager = SnapshotManager();
  storageService.setSnapshotManager(snapshotManager);
  final backupService = BackupService(storageService, snapshotManager);
  final iapService = IapService();
  await iapService.init();
  storageService.setProStatus(iapService.isPro);
  await HomeWidget.saveWidgetData('is_pro', iapService.isPro.toString());

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

  // Detect unconfigured widgets from Android system picker
  // Kotlin writes 'configured_widget_ids' to SharedPreferences when widgets are placed.
  // On app open, we check for widgets that exist but aren't in our Hive store.
  final configuredIdsStr = prefs.getString('configured_widget_ids') ?? '';
  final configuredIds = configuredIdsStr
      .split(',')
      .where((s) => s.isNotEmpty)
      .map((s) => int.tryParse(s) ?? -1)
      .where((id) => id >= 0)
      .toList();
  // Find widgets that Kotlin knows about but Flutter doesn't have WidgetConfigs for
  final existingConfigs = storageService.getAllWidgetConfigs();
  final existingConfigIds = existingConfigs.map((c) => c.id).toSet();
  // ignore: unused_local_variable
  final unconfiguredWidgetIds = configuredIds
      .where((id) => !existingConfigIds.contains(id.toString()))
      .toList();

  runApp(QuoteWidgetApp(
    storageService: storageService,
    widgetService: widgetService,
    backupService: backupService,
    snapshotManager: snapshotManager,
    iapService: iapService,
    onboardingComplete: onboardingComplete,
    pendingShareText: pendingShareText,
    tappedWidgetId: tappedWidgetId,
    tappedCollectionId: tappedCollectionId,
  ));
}

class QuoteWidgetApp extends StatefulWidget {
  final StorageService storageService;
  final WidgetService widgetService;
  final BackupService backupService;
  final SnapshotManager snapshotManager;
  final IapService iapService;
  final bool onboardingComplete;
  final String? pendingShareText;
  final int? tappedWidgetId;
  final String? tappedCollectionId;

  const QuoteWidgetApp({
    super.key,
    required this.storageService,
    required this.widgetService,
    required this.backupService,
    required this.snapshotManager,
    required this.iapService,
    required this.onboardingComplete,
    this.pendingShareText,
    this.tappedWidgetId,
    this.tappedCollectionId,
  });

  @override
  State<QuoteWidgetApp> createState() => _QuoteWidgetAppState();
}

class _QuoteWidgetAppState extends State<QuoteWidgetApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingShare();
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
    }
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
        ),
      ),
    );
  }

  void _handlePendingShare() {
    if (widget.pendingShareText != null && widget.pendingShareText!.isNotEmpty) {
      final shareService = ShareService(widget.storageService);
      final collections = widget.storageService.getAllCollections();

      if (collections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create a collection first to save shared content')),
        );
        return;
      }

      if (collections.length == 1) {
        // Auto-select the only collection
        shareService.saveToCollection(
          text: widget.pendingShareText!,
          collectionId: collections.first.id,
        ).then((success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(success ? 'Added to ${collections.first.name}' : 'Failed to save')),
            );
          }
        });
      } else {
        // Show collection picker
        showDialog(
          context: context,
          builder: (context) => CollectionPickerDialog(
            storageService: widget.storageService,
            onSelected: (collection) {
              shareService.saveToCollection(
                text: widget.pendingShareText!,
                collectionId: collection.id,
              ).then((success) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(success ? 'Added to ${collection.name}' : 'Failed to save')),
                  );
                }
              });
            },
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
            )
          : widget.onboardingComplete
              ? HomeScreen(
                  storageService: widget.storageService,
                  widgetService: widget.widgetService,
                  iapService: widget.iapService,
                )
              : OnboardingScreen(
                  storageService: widget.storageService,
                  widgetService: widget.widgetService,
                  iapService: widget.iapService,
                ),
    );
  }
}
