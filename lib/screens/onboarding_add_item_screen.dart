import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../services/storage_service.dart';
import '../widgets/onboarding_progress.dart';

/// Onboarding step 2 for "Add Your Own": add the first item.
/// Always ends by calling onNext (never pops to HomeScreen directly).
class OnboardingAddItemScreen extends StatefulWidget {
  final StorageService storageService;
  final Collection? collection;
  final VoidCallback onNext;

  const OnboardingAddItemScreen({
    super.key,
    required this.storageService,
    this.collection,
    required this.onNext,
  });

  @override
  State<OnboardingAddItemScreen> createState() =>
      _OnboardingAddItemScreenState();
}

class _OnboardingAddItemScreenState extends State<OnboardingAddItemScreen> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndNext() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.collection == null) {
      widget.onNext();
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.storageService.createItem(
        collectionId: widget.collection!.id,
        text: text,
        order: 0,
      );
      if (mounted) widget.onNext();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _skip() {
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
            const OnboardingProgress(currentStep: 2),
            const SizedBox(height: 32),
            Icon(
              Icons.note_add_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Add Your First Item',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.collection != null
                  ? 'Add something to "${widget.collection!.name}".\nYou can add more later.'
                  : 'Add some content that you want to see on your home screen.',
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
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. You are capable of amazing things.',
                border: OutlineInputBorder(),
                labelText: 'Your content',
              ),
              onSubmitted: (_) => _saveAndNext(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAndNext,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save & Continue',
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
