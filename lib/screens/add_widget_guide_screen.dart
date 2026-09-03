import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import '../services/interstitial_ad_service.dart';
import '../services/snapshot_manager.dart';
import '../services/widget_service.dart';
import '../services/storage_service.dart';
import '../services/iap_service.dart';
import '../services/rewarded_ad_service.dart';
import 'home_screen.dart';

class AddWidgetGuideScreen extends StatefulWidget {
  final WidgetService widgetService;
  final StorageService storageService;
  final IapService iapService;
  final RewardedAdService rewardedAdService;
  final InterstitialAdController interstitialAdController;
  final BackupService backupService;
  final SnapshotManager snapshotManager;

  const AddWidgetGuideScreen({
    super.key,
    required this.widgetService,
    required this.storageService,
    required this.iapService,
    required this.rewardedAdService,
    required this.interstitialAdController,
    required this.backupService,
    required this.snapshotManager,
  });

  @override
  State<AddWidgetGuideScreen> createState() => _AddWidgetGuideScreenState();
}

class _AddWidgetGuideScreenState extends State<AddWidgetGuideScreen> {
  WidgetGuide? _guide;
  bool _isLoading = true;
  bool _pinRequested = false;
  bool _pinSupported = false;

  @override
  void initState() {
    super.initState();
    _loadGuide();
    _tryPinWidget();
  }

  Future<void> _tryPinWidget() async {
    final supported = await widget.widgetService.requestPinWidget();
    setState(() {
      _pinRequested = true;
      _pinSupported = supported;
    });
  }

  Future<void> _loadGuide() async {
    try {
      final manufacturer = await widget.widgetService.getDeviceManufacturer();
      _guide = widget.widgetService.getGuideForDevice(manufacturer);
    } catch (e) {
      // Default guide
      _guide = WidgetGuide(
        manufacturer: 'Android',
        title: 'Android',
        steps: [
          'Long press on home screen',
          'Tap "Widgets"',
          'Find "Your Words"',
          'Drag to home screen',
        ],
        imageUrl: 'assets/guides/stock_guide.png',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onComplete() {
    Navigator.pushReplacement(
      context,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Widget'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Icon(
                    Icons.widgets,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add Widget to Home Screen',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Follow these steps to add the widget to your home screen.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Manual Steps
                  if (_guide != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _guide!.title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            ...(_guide!.steps.asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      child: Text(
                                        '${entry.key + 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        entry.value,
                                        style: Theme.of(context).textTheme.bodyLarge,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            })),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // Auto-add button (if supported)
                  if (_pinRequested && _pinSupported) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _tryPinWidget,
                        icon: const Icon(Icons.add_circle),
                        label: const Text(
                          'Add Widget to Home Screen',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Done Button
                  OutlinedButton(
                    onPressed: _onComplete,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      "I've added the widget",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _onComplete,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
