import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/onboarding_progress.dart';

/// Onboarding step 1 for "Add Your Own": create the first collection.
/// Always ends by calling onNext (never pops to HomeScreen directly).
class OnboardingCreateCollectionScreen extends StatefulWidget {
  final StorageService storageService;
  final VoidCallback onNext;

  const OnboardingCreateCollectionScreen({
    super.key,
    required this.storageService,
    required this.onNext,
  });

  @override
  State<OnboardingCreateCollectionScreen> createState() =>
      _OnboardingCreateCollectionScreenState();
}

class _OnboardingCreateCollectionScreenState
    extends State<OnboardingCreateCollectionScreen> {
  final _controller = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _createAndNext() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      await widget.storageService.createCollection(name);
      if (mounted) widget.onNext();
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _skip() {
    // Skip collection creation — just move to next step
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Words'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const OnboardingProgress(currentStep: 1),
            const SizedBox(height: 32),
            Icon(
              Icons.collections_bookmark_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Create Your First Collection',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'A collection groups related content together.\nYou can create more later.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Morning Motivation',
                border: OutlineInputBorder(),
                labelText: 'Collection name',
              ),
              onSubmitted: (_) => _createAndNext(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createAndNext,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create & Continue',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skip,
              child: Text(
                'Skip for now',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
