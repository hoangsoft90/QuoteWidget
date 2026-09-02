import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../services/sample_data_service.dart';
import '../services/widget_service.dart';
import '../services/iap_service.dart';
import 'home_screen.dart';
import 'add_widget_guide_screen.dart';
import 'onboarding_create_collection_screen.dart';
import 'onboarding_add_item_screen.dart';
import '../widgets/onboarding_progress.dart';

class OnboardingScreen extends StatefulWidget {
  final StorageService storageService;
  final WidgetService widgetService;
  final IapService iapService;

  const OnboardingScreen({
    super.key,
    required this.storageService,
    required this.widgetService,
    required this.iapService,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isCreatingSample = false;

  Future<void> _startWithSample() async {
    setState(() {
      _isCreatingSample = true;
    });

    try {
      final sampleService = SampleDataService(widget.storageService);
      await sampleService.createSampleCollections();

      // Mark onboarding as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_complete', true);

      if (mounted) {
        // Navigate to add widget guide
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AddWidgetGuideScreen(
              widgetService: widget.widgetService,
              storageService: widget.storageService,
              iapService: widget.iapService,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create sample content: $e')),
        );
      }
    } finally {
      setState(() {
        _isCreatingSample = false;
      });
    }
  }

  void _addYourOwn() async {
    // Mark onboarding as complete
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    // Guided flow: Create Collection → Add Item → Add Widget Guide → HomeScreen
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => OnboardingCreateCollectionScreen(
          storageService: widget.storageService,
          onNext: () {
            // Step 2: Get the collection we just created (or null if skipped)
            final collections = widget.storageService.getAllCollections();
            final latestCollection =
                collections.isNotEmpty ? collections.first : null;

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OnboardingAddItemScreen(
                  storageService: widget.storageService,
                  collection: latestCollection,
                  onNext: () {
                    // Step 3: Add Widget Guide → then HomeScreen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddWidgetGuideScreen(
                          widgetService: widget.widgetService,
                          storageService: widget.storageService,
                          iapService: widget.iapService,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            storageService: widget.storageService,
            widgetService: widget.widgetService,
            iapService: widget.iapService,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              // App Logo
              Icon(
                Icons.format_quote,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Words',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Personal content on your Home Screen',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const Spacer(),
              // Progress Indicator
              const OnboardingProgress(currentStep: 1),
              const SizedBox(height: 32),
              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreatingSample ? null : _startWithSample,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isCreatingSample
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Start with Sample',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _addYourOwn,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Add Your Own',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _skip,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
