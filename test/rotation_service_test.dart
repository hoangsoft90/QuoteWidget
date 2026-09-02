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
