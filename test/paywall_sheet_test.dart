import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/services/iap_service.dart';
import 'package:quotewidget/services/rewarded_ad_service.dart';
import 'package:quotewidget/widgets/paywall_sheet.dart';

/// plan4 Sprint A-5: the shared paywall bottom sheet used by both the
/// WidgetSetupScreen widget-limit path and the native "Upgrade to Pro"
/// deep link (route=paywall). Verify the three actions resolve correctly
/// without hitting any platform channel (ads/IAP are unavailable in tests —
/// RewardedAdService.loadRewardedAd short-circuits on AdConfig.supported,
/// IapService.buyPro returns false when not available).
void main() {
  late IapService iapService;
  late RewardedAdService rewardedAdService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    iapService = IapService();
    rewardedAdService = RewardedAdService(iapService);
  });

  Future<PaywallResult> pumpAndPick(WidgetTester tester, String choice) async {
    PaywallResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showPaywallSheet(
                    context,
                    iapService: iapService,
                    rewardedAdService: rewardedAdService,
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(choice));
    await tester.pumpAndSettle();
    return result!;
  }

  testWidgets('A5: sheet opens with 3 options', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPaywallSheet(
                context,
                iapService: iapService,
                rewardedAdService: rewardedAdService,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock Pro'), findsOneWidget);
    expect(find.text('Watch Ad — Unlock 24h'), findsOneWidget);
    expect(find.text('Remove Ads Forever'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('A5: Cancel → PaywallResult.cancelled, no Pro', (tester) async {
    final result = await pumpAndPick(tester, 'Cancel');
    expect(result, PaywallResult.cancelled);
    expect(iapService.isPro, isFalse);
  });

  testWidgets('A5: Watch Ad with no ad ready → cancelled + retry snackbar',
      (tester) async {
    final result = await pumpAndPick(tester, 'Watch Ad — Unlock 24h');
    expect(result, PaywallResult.cancelled,
        reason: 'No ad loaded in test → must not claim Pro was granted');
    expect(iapService.isPro, isFalse);
    expect(find.text('Ad not finished. Please try again.'), findsOneWidget);
  });

  testWidgets('A5: Buy Pro when store unavailable → cancelled + snackbar',
      (tester) async {
    final result = await pumpAndPick(tester, 'Remove Ads Forever');
    expect(result, PaywallResult.cancelled);
    expect(iapService.isPro, isFalse);
    expect(find.text('Purchase unavailable right now.'), findsOneWidget);
  });
}