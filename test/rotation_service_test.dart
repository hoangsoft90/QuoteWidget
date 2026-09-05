import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/services/rotation_service.dart';
import 'package:quotewidget/models/widget_config_model.dart';

void main() {
  final service = RotationService();

  group('Sequential rotation', () {
    test('wraps around: [A,B,C] at index 0 → 1 → 2 → 0', () {
      expect(service.getNextIndex(currentIndex: 0, totalItems: 3, mode: RotationMode.sequential), 1);
      expect(service.getNextIndex(currentIndex: 1, totalItems: 3, mode: RotationMode.sequential), 2);
      expect(service.getNextIndex(currentIndex: 2, totalItems: 3, mode: RotationMode.sequential), 0);
    });

    test('single item stays at 0', () {
      expect(service.getNextIndex(currentIndex: 0, totalItems: 1, mode: RotationMode.sequential), 0);
    });

    test('two items alternates', () {
      expect(service.getNextIndex(currentIndex: 0, totalItems: 2, mode: RotationMode.sequential), 1);
      expect(service.getNextIndex(currentIndex: 1, totalItems: 2, mode: RotationMode.sequential), 0);
    });
  });

  group('Random rotation', () {
    test('never returns current index (100 iterations)', () {
      for (var i = 0; i < 100; i++) {
        final next = service.getNextIndex(currentIndex: 0, totalItems: 5, mode: RotationMode.random);
        expect(next, isNot(0), reason: 'Iteration $i: random returned current index 0');
        expect(next, greaterThanOrEqualTo(0));
        expect(next, lessThan(5));
      }
    });

    test('single item returns 0', () {
      expect(service.getNextIndex(currentIndex: 0, totalItems: 1, mode: RotationMode.random), 0);
    });

    test('returns different values over multiple calls (probabilistic)', () {
      final results = <int>{};
      for (var i = 0; i < 50; i++) {
        results.add(service.getNextIndex(currentIndex: 2, totalItems: 10, mode: RotationMode.random));
      }
      // With 50 calls and 9 possible outcomes, we should see at least 2 different values
      expect(results.length, greaterThanOrEqualTo(2));
    });
  });

  group('Edge cases', () {
    test('empty collection returns -1', () {
      expect(service.getNextIndex(currentIndex: 0, totalItems: 0, mode: RotationMode.sequential), -1);
      expect(service.getNextIndex(currentIndex: 0, totalItems: 0, mode: RotationMode.random), -1);
    });
  });

  group('Phase 2B: Shuffle Bag (features_final §2)', () {
    test('bag contains every id exactly once (no repeats until exhausted)',
        () {
      final ids = ['a', 'b', 'c', 'd', 'e'];
      final bag = service.buildShuffleBag(ids);
      expect(bag.toSet(), ids.toSet(), reason: 'bag is a permutation of source');
      expect(bag.length, ids.length);
    });

    test('new bag never starts with the avoided id (when len > 1)', () {
      for (var i = 0; i < 50; i++) {
        final bag = service.buildShuffleBag(['a', 'b', 'c'], avoidFirst: 'b');
        expect(bag.first, isNot('b'),
            reason: 'iteration $i: new bag must not start with the just-shown item');
      }
    });

    test('nextShuffleStep advances through the whole bag before rebuilding',
        () {
      final ids = ['a', 'b', 'c'];
      var state = service.nextShuffleStep(
          sourceIds: ids, current: null, currentId: 'a');
      final firstBag = List.of(state.bag);
      expect(state.index, 0);
      // Spec: a fresh bag must NOT start with the item just shown (when >1).
      expect(state.bag.first, isNot('a'));

      // Walk to the end: each step advances index by one within the SAME bag.
      state = service.nextShuffleStep(
          sourceIds: ids, current: state, currentId: state.bag[state.index]);
      expect(state.bag, firstBag, reason: 'same bag while not exhausted');
      expect(state.index, 1);

      state = service.nextShuffleStep(
          sourceIds: ids, current: state, currentId: state.bag[state.index]);
      expect(state.bag, firstBag);
      expect(state.index, 2);

      // Exhausted → new bag, fresh index, and NOT starting with the last shown.
      final lastShown = state.bag[state.index];
      state = service.nextShuffleStep(
          sourceIds: ids, current: state, currentId: lastShown);
      expect(state.index, 0);
      expect(state.bag.first, isNot(lastShown));
    });

    test('source change (fp) invalidates the bag', () {
      final ids1 = ['a', 'b', 'c'];
      var state = service.nextShuffleStep(
          sourceIds: ids1, current: null, currentId: 'a');
      expect(state.index, 0);

      // Add an item → fingerprint changes → rebuild.
      final ids2 = ['a', 'b', 'c', 'd'];
      state = service.nextShuffleStep(
          sourceIds: ids2, current: state, currentId: state.bag[state.index]);
      expect(state.index, 0, reason: 'source changed → bag rebuilt from index 0');
      expect(state.bag.toSet(), ids2.toSet());
    });

    test('empty source → empty bag', () {
      final state = service.nextShuffleStep(
          sourceIds: const [], current: null, currentId: 'x');
      expect(state.bag, isEmpty);
    });

    test('single item bag stays stable', () {
      final state = service.nextShuffleStep(
          sourceIds: const ['only'], current: null, currentId: 'only');
      expect(state.bag, ['only']);
      expect(state.index, 0);
    });
  });

  group('Phase 2B: Daily rotation (features_final §3)', () {
    test('localDateKey formats yyyy-MM-dd', () {
      expect(service.localDateKey(DateTime(2026, 9, 5)), '2026-09-05');
      expect(service.localDateKey(DateTime(2026, 1, 1)), '2026-01-01');
    });

    test('dailyIndexForToday never repeats yesterday (when len > 1)', () {
      for (var i = 0; i < 50; i++) {
        final idx = service.dailyIndexForToday(
          itemIds: ['a', 'b', 'c', 'd'],
          previousDailyId: 'c',
        );
        expect(['a', 'b', 'c', 'd'][idx], isNot('c'),
            reason: 'new day item must differ from yesterday');
      }
    });

    test('dailyIndexForToday: single item → 0; empty → -1; null prev → any', () {
      expect(service.dailyIndexForToday(itemIds: const ['a'], previousDailyId: 'a'), 0);
      expect(service.dailyIndexForToday(itemIds: const [], previousDailyId: null), -1);
      final idx = service.dailyIndexForToday(
          itemIds: ['a', 'b'], previousDailyId: null);
      expect(idx, anyOf(0, 1));
    });

    test('isRotationDue: manual never; daily only on date change; every_Nh by time',
        () {
      final now = DateTime(2026, 9, 5, 12);
      expect(service.isRotationDue(
          schedule: ScheduleMode.manual,
          now: now,
          dailyDate: '2026-09-05',
          nextRotationAt: 0), isFalse);
      expect(service.isRotationDue(
          schedule: ScheduleMode.daily,
          now: now,
          dailyDate: '2026-09-05',
          nextRotationAt: 0), isFalse, reason: 'same day → not due');
      expect(service.isRotationDue(
          schedule: ScheduleMode.daily,
          now: now,
          dailyDate: '2026-09-04',
          nextRotationAt: 0), isTrue, reason: 'date changed → due');
      expect(service.isRotationDue(
          schedule: ScheduleMode.every1h,
          now: now,
          dailyDate: null,
          nextRotationAt: now.millisecondsSinceEpoch - 1000), isTrue);
      expect(service.isRotationDue(
          schedule: ScheduleMode.every1h,
          now: now,
          dailyDate: null,
          nextRotationAt: now.millisecondsSinceEpoch + 10000), isFalse);
    });

    test('nextRotationAt: 1h/3h/6h set; manual/daily null', () {
      final now = DateTime(2026, 9, 5, 12);
      expect(service.nextRotationAt(schedule: ScheduleMode.every1h, now: now),
          now.add(const Duration(hours: 1)).millisecondsSinceEpoch);
      expect(service.nextRotationAt(schedule: ScheduleMode.every3h, now: now),
          now.add(const Duration(hours: 3)).millisecondsSinceEpoch);
      expect(service.nextRotationAt(schedule: ScheduleMode.every6h, now: now),
          now.add(const Duration(hours: 6)).millisecondsSinceEpoch);
      expect(service.nextRotationAt(schedule: ScheduleMode.manual, now: now), isNull);
      expect(service.nextRotationAt(schedule: ScheduleMode.daily, now: now), isNull);
    });
  });

  group('findValidIndexAfterDeletion', () {
    test('returns currentIndex if still valid', () {
      expect(service.findValidIndexAfterDeletion(currentIndex: 1, totalItems: 5, mode: RotationMode.sequential), 1);
    });

    test('wraps to last valid index if currentIndex out of bounds', () {
      expect(service.findValidIndexAfterDeletion(currentIndex: 5, totalItems: 3, mode: RotationMode.sequential), 2);
    });

    test('returns -1 for empty collection', () {
      expect(service.findValidIndexAfterDeletion(currentIndex: 0, totalItems: 0, mode: RotationMode.sequential), -1);
    });

    test('returns 0 for single remaining item', () {
      expect(service.findValidIndexAfterDeletion(currentIndex: 2, totalItems: 1, mode: RotationMode.sequential), 0);
    });
  });
}
