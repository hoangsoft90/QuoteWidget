import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quotewidget/services/iap_service.dart';
import 'package:quotewidget/services/rewarded_ad_service.dart';
import 'package:quotewidget/widgets/paywall_sheet.dart';

/// plan4 Sprint A-5: the shared paywall bottom sheet used by both the
/// WidgetSetupScreen widget-limit path and the native "Upgrade to Pro"
/// deep link (route=paywall). Only Watch Ad (24h) + Cancel — no purchase
/// option (user decision 2026-09-03: all IAP removed, ads always shown).
void main() {
  late IapService iapService;
  late RewardedAdService rewardedAdService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    iapService = IapService();
    rewardedAdService = RewardedAdService(iapService);
  });

  testWidgets('sheet opens with Watch Ad + Cancel (2 options)', (tester) async {
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
    expect(find.text('Add unlimited widgets for 24 hours.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    // No purchase option
    expect(find.text('Remove Ads Forever'), findsNothing);
  });

  testWidgets('Cancel → PaywallResult.cancelled, no Pro', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await showPaywallSheet(
                  context,
                  iapService: iapService,
                  rewardedAdService: rewardedAdService,
                );
                expect(result, PaywallResult.cancelled);
                expect(iapService.isPro, isFalse);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Watch Ad with no ad ready → no-ad dialog, not silent',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await showPaywallSheet(
                  context,
                  iapService: iapService,
                  rewardedAdService: rewardedAdService,
                );
                expect(result, PaywallResult.cancelled,
                    reason: 'No ad loaded in test → must not claim Pro was granted');
                expect(iapService.isPro, isFalse);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch Ad — Unlock 24h'));
    await tester.pumpAndSettle();

    // plan6 H2: unavailable ad → retry dialog (not a silent dead-end).
    expect(
      find.text('Không có quảng cáo lúc này. Vui lòng thử lại sau ít phút.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    // Cancel the dialog → sheet returns cancelled.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Ad not finished. Please try again.'), findsOneWidget);
  });
}
