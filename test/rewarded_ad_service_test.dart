import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/services/iap_service.dart';
import 'package:quotewidget/services/rewarded_ad_service.dart';

/// Fake IapService that records unlock attempts and can simulate persistence
/// failures — lets us test the reward-outcome gate without a platform ad.
class _FakeIapService extends IapService {
  int unlockCalls = 0;
  bool failUnlock = false;

  @override
  Future<void> unlockProFor24h() async {
    unlockCalls++;
    if (failUnlock) {
      throw Exception('persist failed');
    }
  }
}

void main() {
  group('resolveRewardOutcome (plan3 Fix A — grant only after persist)', () {
    test('no reward → false and unlock is never attempted', () async {
      final iap = _FakeIapService();
      final service = RewardedAdService(iap);

      expect(await service.resolveRewardOutcome(false), isFalse);
      expect(iap.unlockCalls, 0,
          reason: 'No unlock attempt when the ad was not watched to the end');
    });

    test('reward + successful persist → true (unlock awaited)', () async {
      final iap = _FakeIapService();
      final service = RewardedAdService(iap);

      expect(await service.resolveRewardOutcome(true), isTrue);
      expect(iap.unlockCalls, 1,
          reason: 'Unlock must be attempted exactly once for a completed ad');
    });

    test('reward + persistence failure → false (no fake grant)', () async {
      final iap = _FakeIapService()..failUnlock = true;
      final service = RewardedAdService(iap);

      expect(await service.resolveRewardOutcome(true), isFalse,
          reason: 'A failed persist must never report a successful grant');
      expect(iap.unlockCalls, 1);
    });
  });
}
