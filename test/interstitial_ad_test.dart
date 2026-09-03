import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/services/interstitial_ad_service.dart';

void main() {
  final now = DateTime(2026, 9, 3, 12, 0, 0);
  const cooldown = Duration(minutes: 5);
  const frequency = 5;

  group('shouldShowInterstitial', () {
    test('returns false when action count is below the frequency', () {
      expect(
        shouldShowInterstitial(
          actionCount: 4,
          frequency: frequency,
          now: now,
          lastShownAt: null,
          cooldown: cooldown,
        ),
        isFalse,
      );
    });

    test('returns true at the frequency milestone with no prior show', () {
      expect(
        shouldShowInterstitial(
          actionCount: 5,
          frequency: frequency,
          now: now,
          lastShownAt: null,
          cooldown: cooldown,
        ),
        isTrue,
      );
    });

    test('returns false if the cooldown has not elapsed since the last show',
        () {
      expect(
        shouldShowInterstitial(
          actionCount: 10,
          frequency: frequency,
          now: now,
          lastShownAt: now.subtract(const Duration(minutes: 2)),
          cooldown: cooldown,
        ),
        isFalse,
      );
    });

    test('returns true at the milestone once the cooldown has elapsed', () {
      expect(
        shouldShowInterstitial(
          actionCount: 10,
          frequency: frequency,
          now: now,
          lastShownAt: now.subtract(const Duration(minutes: 6)),
          cooldown: cooldown,
        ),
        isTrue,
      );
    });

    test('returns true exactly at the cooldown boundary', () {
      expect(
        shouldShowInterstitial(
          actionCount: 15,
          frequency: frequency,
          now: now,
          lastShownAt: now.subtract(cooldown),
          cooldown: cooldown,
        ),
        isTrue,
      );
    });

    test('guards against non-positive counters', () {
      expect(
        shouldShowInterstitial(
          actionCount: 0,
          frequency: frequency,
          now: now,
          lastShownAt: null,
          cooldown: cooldown,
        ),
        isFalse,
      );
      expect(
        shouldShowInterstitial(
          actionCount: 5,
          frequency: 0,
          now: now,
          lastShownAt: null,
          cooldown: cooldown,
        ),
        isFalse,
      );
    });
  });
}