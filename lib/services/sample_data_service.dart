import '../models/collection_model.dart';
import 'storage_service.dart';

class SampleDataService {
  final StorageService _storageService;

  SampleDataService(this._storageService);

  /// Create sample collections with pre-written content
  Future<List<Collection>> createSampleCollections() async {
    final collections = <Collection>[];

    // Collection 1: Daily Affirmations
    final affirmations = await _createCollection(
      name: 'Daily Affirmations',
      items: [
        'I am capable of achieving great things.',
        'Today is full of possibilities.',
        'I choose to focus on what I can control.',
        'Every challenge is an opportunity to grow.',
        'I am worthy of success and happiness.',
        'My potential is limitless.',
        'I attract positive energy into my life.',
        'I am grateful for this moment.',
      ],
    );
    collections.add(affirmations);

    // Collection 2: Productivity Prompts (all original — no celebrity quotes)
    final productivity = await _createCollection(
      name: 'Productivity Prompts',
      items: [
        'Start before you feel ready — momentum builds clarity.',
        'One focused hour beats eight scattered ones.',
        'Break the big thing into small things, then do the smallest one.',
        'Progress quietly, let results make the noise.',
        'Protect your morning for the work that matters most.',
        'Done imperfectly today beats perfect tomorrow.',
      ],
    );
    collections.add(productivity);

    // Collection 3: Mindfulness Reminders
    final mindfulness = await _createCollection(
      name: 'Mindfulness Reminders',
      items: [
        'Be here now.',
        'Breathe in calm, breathe out tension.',
        'This moment is enough.',
        "Let go of what you can't control.",
        'Peace begins with a single breath.',
        'You are not your thoughts.',
        'Observe without judgment.',
        'Return to your breath.',
      ],
    );
    collections.add(mindfulness);

    // Create a widget config for the first collection
    if (collections.isNotEmpty) {
      await _storageService.createWidgetConfig(
        collectionId: collections.first.id,
      );
    }

    return collections;
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
