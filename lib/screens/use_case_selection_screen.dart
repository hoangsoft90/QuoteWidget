import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/collection_model.dart';
import '../models/widget_config_model.dart';
import '../services/backup_service.dart';
import '../services/interstitial_ad_service.dart';
import '../services/snapshot_manager.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../services/iap_service.dart';
import '../services/rewarded_ad_service.dart';
import '../services/sample_data_service.dart';
import '../widgets/quote_card.dart';
import 'add_widget_guide_screen.dart';

/// Onboarding use-case picker (Task 5 — P0.5).
///
/// Flow: pick a use case → the matching single sample collection is created
/// (content is self-written, no celebrity quotes) → a live widget preview is
/// shown → user continues to [AddWidgetGuideScreen].
class UseCaseSelectionScreen extends StatefulWidget {
  final StorageService storageService;
  final WidgetService widgetService;
  final IapService iapService;
  final RewardedAdService rewardedAdService;
  final InterstitialAdController interstitialAdController;
  final BackupService backupService;
  final SnapshotManager snapshotManager;

  const UseCaseSelectionScreen({
    super.key,
    required this.storageService,
    required this.widgetService,
    required this.iapService,
    required this.rewardedAdService,
    required this.interstitialAdController,
    required this.backupService,
    required this.snapshotManager,
  });

  @override
  State<UseCaseSelectionScreen> createState() => _UseCaseSelectionScreenState();
}

class _UseCaseSelectionScreenState extends State<UseCaseSelectionScreen> {
  bool _isCreating = false;
  Collection? _createdCollection;
  List<String> _previewItems = [];
  int _previewIndex = 0;

  Future<void> _selectUseCase(SampleUseCase useCase) async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    try {
      final sampleService = SampleDataService(widget.storageService);
      final collections = await sampleService.createSampleCollections(useCase);

      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      if (!mounted) return;
      setState(() {
        _createdCollection = collections.isNotEmpty ? collections.first : null;
        _previewItems = _createdCollection != null
            ? widget.storageService
                .getItemsForCollection(_createdCollection!.id)
                .map((e) => e.text)
                .toList()
            : [];
        _previewIndex = 0;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create sample content: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _previewTap() {
    if (_previewItems.isEmpty) return;
    setState(() {
      _previewIndex = (_previewIndex + 1) % _previewItems.length;
    });
  }

  void _continueToGuide() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AddWidgetGuideScreen(
          widgetService: widget.widgetService,
          storageService: widget.storageService,
          iapService: widget.iapService,
          rewardedAdService: widget.rewardedAdService,
          interstitialAdController: widget.interstitialAdController,
          backupService: widget.backupService,
          snapshotManager: widget.snapshotManager,
        ),
      ),
    );
  }

  IconData _iconFor(SampleUseCase useCase) {
    switch (useCase) {
      case SampleUseCase.vocabulary:
        return Icons.translate;
      case SampleUseCase.motivation:
        return Icons.auto_awesome;
      case SampleUseCase.workFocus:
        return Icons.work_outline;
      case SampleUseCase.gym:
        return Icons.fitness_center;
      case SampleUseCase.personalQuotes:
        return Icons.edit_note;
    }
  }

  @override
  Widget build(BuildContext context) {
    // After a collection is created → show live preview step.
    if (_createdCollection != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Your Words')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Here is your widget preview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the preview to cycle through “${_createdCollection!.name}”.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Center(
                child: GestureDetector(
                  onTap: _previewTap,
                  child: QuoteCard(
                    text: _previewItems.isEmpty
                        ? 'Add some content to this collection.'
                        : _previewItems[_previewIndex],
                    appearance: AppearanceConfig(
                      theme: 'light',
                      fontSize: 16,
                      textColor: 0xFF1A1A1A,
                      background: 0xFFFFFFFF,
                      alignment: TextAlignment.center,
                    ),
                    sizeCategory: SizeCategory.medium,
                    index: _previewItems.isEmpty ? null : _previewIndex,
                    total: _previewItems.isEmpty ? null : _previewItems.length,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _previewItems.isEmpty
                    ? '0/0'
                    : '${_previewIndex + 1}/${_previewItems.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _continueToGuide,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Continue', style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _continueToGuide,
                child: const Text('Skip preview'),
              ),
            ],
          ),
        ),
      );
    }

    // Otherwise → show the use-case picker.
    return Scaffold(
      appBar: AppBar(title: const Text('Your Words')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What will you use this for?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick a starter pack — you can edit everything later.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 24),
              if (_isCreating)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: ListView(
                    children: SampleUseCase.values.map((useCase) {
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: Icon(
                            _iconFor(useCase),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          title: Text(useCase.title),
                          subtitle: Text(useCase.description),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _selectUseCase(useCase),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}