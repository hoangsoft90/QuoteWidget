import 'dart:math';
import '../models/widget_config_model.dart';

class RotationService {
  static final RotationService _instance = RotationService._internal();
  factory RotationService() => _instance;
  RotationService._internal();

  final Random _random = Random();

  /// Calculate the next item index based on rotation mode.
  /// Returns -1 for empty/invalid state.
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
      case RotationMode.shuffleBag:
        // Shuffle-bag is index-stateful: the caller must pass the CURRENT
        // position within the bag, not the collection index. This mode is
        // handled by the bag-aware API below; here we return a valid index
        // within the bag when it is fresh, else sequential fallback.
        return _getSequentialNext(currentIndex, totalItems);
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

  /// Find a valid index when the current item has been deleted.
  /// Returns the next valid index, or -1 if no items remain.
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

  // ==================== Shuffle Bag (features_final §2) ====================

  /// Build a fresh shuffled bag from [itemIds]. A single shuffle so every
  /// item appears exactly once per cycle. When [avoidFirst] is provided and
  /// the bag has >1 items, the bag is re-arranged so it does NOT start with
  /// that id ("new bag never starts with the item just shown").
  List<String> buildShuffleBag(List<String> itemIds, {String? avoidFirst}) {
    if (itemIds.length <= 1) return List.of(itemIds);
    var bag = List.of(itemIds)..shuffle(_random);
    if (avoidFirst != null && bag.isNotEmpty && bag.first == avoidFirst) {
      // Move the forbidden id somewhere else (always possible when len > 1).
      final swapIndex = 1 + _random.nextInt(bag.length - 1);
      final tmp = bag[0];
      bag[0] = bag[swapIndex];
      bag[swapIndex] = tmp;
    }
    return bag;
  }

  /// Compute the next shuffle-bag step. Returns the updated bag/index.
  ///
  /// [currentId] is the item id currently displayed. When the bag is stale
  /// (source fingerprint changed), empty, or exhausted, a fresh bag is built
  /// (avoiding a repeat of [currentId] at the start).
  ShuffleBagState nextShuffleStep({
    required List<String> sourceIds,
    required ShuffleBagState? current,
    required String currentId,
  }) {
    final fp = _fingerprint(sourceIds);

    // 0 items → empty bag, nothing to show.
    if (sourceIds.isEmpty) {
      return ShuffleBagState(
        bag: const [],
        index: 0,
        sourceFingerprint: fp,
      );
    }

    // Rebuild when source changed or no bag yet.
    if (current == null ||
        current.sourceFingerprint != fp ||
        current.bag.isEmpty) {
      final bag = buildShuffleBag(sourceIds, avoidFirst: currentId);
      return ShuffleBagState(bag: bag, index: 0, sourceFingerprint: fp);
    }

    // Advance within the bag.
    var index = current.index + 1;
    if (index >= current.bag.length) {
      // Exhausted → new bag, avoid starting with the item just shown
      // (the last item of the exhausted bag).
      final lastShown = current.bag.last;
      final bag = buildShuffleBag(sourceIds, avoidFirst: lastShown);
      return ShuffleBagState(bag: bag, index: 0, sourceFingerprint: fp);
    }

    return ShuffleBagState(
      bag: current.bag,
      index: index,
      sourceFingerprint: fp,
    );
  }

  /// Fingerprint of the source id set — detects content changes so the bag
  /// invalidates (features_final §2.4).
  String _fingerprint(List<String> ids) {
    final sorted = List.of(ids)..sort();
    return sorted.join('|');
  }

  // ==================== Daily rotation (features_final §3) ====================

  /// Local calendar date as `yyyy-MM-dd` (the daily key format).
  String localDateKey(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  /// Choose the item for a new day.
  /// - [previousDailyId]: the id shown yesterday (avoid immediate repeat when
  ///   more than one item exists).
  int dailyIndexForToday({
    required List<String> itemIds,
    required String? previousDailyId,
  }) {
    if (itemIds.isEmpty) return -1;
    if (itemIds.length == 1) return 0;
    if (previousDailyId == null) return _random.nextInt(itemIds.length);
    final prev = itemIds.indexOf(previousDailyId);
    if (prev == -1) return _random.nextInt(itemIds.length);
    // Pick any index except yesterday's.
    var idx = _random.nextInt(itemIds.length - 1);
    if (idx >= prev) idx += 1;
    return idx;
  }

  /// Whether a scheduled rotation is due (features_final §3 auto-rotate).
  /// [schedule] manual → never auto; daily → due after local midnight;
  /// every_Nh → due when now >= nextRotationAt.
  bool isRotationDue({
    required ScheduleMode schedule,
    required DateTime now,
    required String? dailyDate,
    required int? nextRotationAt,
  }) {
    switch (schedule) {
      case ScheduleMode.manual:
        return false;
      case ScheduleMode.daily:
        return dailyDate != localDateKey(now);
      case ScheduleMode.every1h:
      case ScheduleMode.every3h:
      case ScheduleMode.every6h:
        if (nextRotationAt == null) return true;
        return now.millisecondsSinceEpoch >= nextRotationAt;
    }
  }

  /// Next auto-rotation timestamp for a schedule (epoch millis). Manual and
  /// daily return null (daily is date-keyed, not timestamp-keyed).
  int? nextRotationAt({
    required ScheduleMode schedule,
    required DateTime now,
  }) {
    final Duration interval = switch (schedule) {
      ScheduleMode.every1h => const Duration(hours: 1),
      ScheduleMode.every3h => const Duration(hours: 3),
      ScheduleMode.every6h => const Duration(hours: 6),
      _ => Duration.zero,
    };
    if (interval == Duration.zero) return null;
    return now.add(interval).millisecondsSinceEpoch;
  }
}