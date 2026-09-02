import 'dart:math';
import '../models/widget_config_model.dart';

class RotationService {
  static final RotationService _instance = RotationService._internal();
  factory RotationService() => _instance;
  RotationService._internal();

  final Random _random = Random();

  /// Calculate the next item index based on rotation mode
  /// Returns -1 for empty/invalid state
  int getNextIndex({
    required int currentIndex,
    required int totalItems,
    required RotationMode mode,
  }) {
    if (totalItems <= 0) {
      return -1; // Empty collection
    }

    if (totalItems == 1) {
      return 0; // Only one item, no change
    }

    switch (mode) {
      case RotationMode.sequential:
        return _getSequentialNext(currentIndex, totalItems);
      case RotationMode.random:
        return _getRandomNext(currentIndex, totalItems);
    }
  }

  int _getSequentialNext(int currentIndex, int totalItems) {
    return (currentIndex + 1) % totalItems;
  }

  int _getRandomNext(int currentIndex, int totalItems) {
    if (totalItems <= 1) {
      return 0;
    }

    // Generate random index excluding current
    int nextIndex;
    do {
      nextIndex = _random.nextInt(totalItems);
    } while (nextIndex == currentIndex);

    return nextIndex;
  }

  /// Find a valid index when the current item has been deleted
  /// Returns the next valid index, or -1 if no items remain
  int findValidIndexAfterDeletion({
    required int currentIndex,
    required int totalItems,
    required RotationMode mode,
  }) {
    if (totalItems <= 0) {
      return -1;
    }

    // If current index is still valid, use it
    if (currentIndex < totalItems) {
      return currentIndex;
    }

    // Otherwise, wrap around to the last valid index
    return totalItems - 1;
  }
}
