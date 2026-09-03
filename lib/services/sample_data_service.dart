import '../models/collection_model.dart';
import 'storage_service.dart';

/// The five onboarding use cases (Task 5). Each maps to ONE starter
/// collection with self-written content (no celebrity quotes, per policy).
enum SampleUseCase {
  vocabulary,
  motivation,
  workFocus,
  gym,
  personalQuotes,
}

extension SampleUseCaseInfo on SampleUseCase {
  String get title {
    switch (this) {
      case SampleUseCase.vocabulary:
        return 'Vocabulary';
      case SampleUseCase.motivation:
        return 'Motivation & Affirmation';
      case SampleUseCase.workFocus:
        return 'Work & Focus';
      case SampleUseCase.gym:
        return 'Gym & Workout';
      case SampleUseCase.personalQuotes:
        return 'Personal Quotes';
    }
  }

  String get description {
    switch (this) {
      case SampleUseCase.vocabulary:
        return 'Words and phrases you are learning';
      case SampleUseCase.motivation:
        return 'Daily reminders to keep you going';
      case SampleUseCase.workFocus:
        return 'Goals and prompts for deep work';
      case SampleUseCase.gym:
        return 'Reps, cues, and workout notes';
      case SampleUseCase.personalQuotes:
        return 'Your own lines to see every day';
    }
  }
}

class SampleDataService {
  final StorageService _storageService;

  SampleDataService(this._storageService);

  /// Create the starter collection for a chosen use case.
  ///
  /// Returns the single created collection (empty if creation failed).
  /// All content is original — no quotes attributed to real people.
  Future<List<Collection>> createSampleCollections(
      SampleUseCase useCase) async {
    final collections = <Collection>[];

    final (name, items) = _contentFor(useCase);
    final collection = await _createCollection(name: name, items: items);
    collections.add(collection);

    return collections;
  }

  /// Original, self-written content per use case.
  (String, List<String>) _contentFor(SampleUseCase useCase) {
    switch (useCase) {
      case SampleUseCase.vocabulary:
        return (
          'Vocabulary',
          [
            'serendipity — finding something good without looking for it',
            'ephemeral — lasting for a very short time',
            'resilient — able to recover quickly from difficulty',
            'elucidate — to make something clear and easy to understand',
            'meticulous — showing great attention to detail',
            'to thrive — to grow, develop, or be successful',
            'ambiguous — open to more than one interpretation',
            'to embrace — to accept something willingly',
          ],
        );
      case SampleUseCase.motivation:
        return (
          'Daily Motivation',
          [
            'Start with one small step — motion creates momentum.',
            'You are allowed to be a beginner at first.',
            'Focus on the progress, not the perfection.',
            'Today is a fresh chance to try again.',
            'Your effort today builds tomorrow\'s confidence.',
            'Keep going — consistency beats intensity.',
            'One good decision at a time adds up.',
            'You have handled hard days before. This one too.',
          ],
        );
      case SampleUseCase.workFocus:
        return (
          'Work & Focus',
          [
            'What is the ONE task that matters most right now?',
            'Work in 25-minute sprints, then take a real break.',
            'Close the tabs you do not need. Protect your attention.',
            'Clarify the next action before stopping.',
            'A finished small task beats a half-done big one.',
            'Block distractions before they block you.',
            'Review the day: what moved the needle?',
            'Do the deep work first, email later.',
          ],
        );
      case SampleUseCase.gym:
        return (
          'Gym Notes',
          [
            'Warm up 5 minutes before lifting heavy.',
            'Squat — brace your core, drive through the whole foot.',
            'Push day: bench, shoulder press, triceps.',
            'Pull day: rows, pull-ups, curls.',
            'Leg day: squats, deadlifts, lunges.',
            'Breathe out on the effort, in on the return.',
            'Log your sets — what gets measured gets improved.',
            'Rest 48h before training the same muscle group.',
          ],
        );
      case SampleUseCase.personalQuotes:
        return (
          'My Quotes',
          [
            'I write the reminders I need to hear.',
            'Small steps, taken daily, change everything.',
            'I choose what deserves my attention today.',
            'Calm is a skill I practice on purpose.',
            'I am building something worth showing up for.',
            'Keep it simple, keep it honest.',
            'Today I focus on what I can control.',
          ],
        );
    }
  }

  Future<Collection> _createCollection({
    required String name,
    required List<String> items,
  }) async {
    final collection = await _storageService.createCollection(name);

    for (int i = 0; i < items.length; i++) {
      await _storageService.createItem(
        collectionId: collection.id,
        text: items[i],
        order: i,
      );
    }

    return collection;
  }
}