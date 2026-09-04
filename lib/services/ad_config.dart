import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// AdMob configuration.
///
/// Ads: banner on the Home screen bottom + rare interstitial after
/// destructive actions (delete-forever, overwrite restore);
/// rewarded ads unlock Pro for 24h (widget limit only — ads stay on).
///
/// The REAL AdMob app ID lives in AndroidManifest.xml (required there for the
/// SDK to initialize) — this file only swaps ad UNIT ids.
class AdConfig {
  AdConfig._();

  /// Master switch — ads are ON by default (user decision 2026-09-03). Ship
  /// an ad-free build with `--dart-define=ENABLE_ADS=false`.
  static const bool enabled =
      bool.fromEnvironment('ENABLE_ADS', defaultValue: true);

  /// Test-ads mode — ON by default (user decision 2026-09-03): every ad unit
  /// resolves to Google's official sample/test ID so ads always fill during
  /// development and the AdMob account is never flagged/limited by the
  /// anti-fraud systems while testing. Flip to real ads with
  /// `--dart-define=TEST_ADS=false` once the units are live in the console.
  static const bool testAds =
      bool.fromEnvironment('TEST_ADS', defaultValue: true);

  /// Real (production) ad unit IDs — registered for com.quotewidget.quotewidget.
  static const String _androidBanner = 'ca-app-pub-6917313063209470/1409128007';
  static const String _androidInterstitial =
      'ca-app-pub-6917313063209470/1569899782';
  /// TODO: register a real rewarded ad unit in the AdMob console and replace
  /// this ID BEFORE disabling TEST_ADS for production — rewarded is the
  /// primary unlock path and must serve real ads once real ads are on.
  static const String _androidRewarded =
      'ca-app-pub-3940256099942544/5224354917';

  /// Google's official sample/test ad unit IDs (always fill, never limited).
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  /// Non-personalized ads request extra — keeps tracking minimal, consistent
  /// with the app's privacy positioning (no EEA consent prompt needed).
  static const Map<String, String> nonPersonalizedExtras = {'npa': '1'};

  /// Minimum time between two interstitial shows — AdMob discourages
  /// back-to-back interstitials (rate limiting / poor UX).
  static const Duration interstitialCooldown = Duration(minutes: 5);

  /// AdMob is unsupported on web and widget tests must never hit platform
  /// channels (they throw MissingPluginException).
  static bool get supported =>
      enabled && !kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST');

  static String get bannerUnitId => testAds ? _testBanner : _androidBanner;
  static String get interstitialUnitId =>
      testAds ? _testInterstitial : _androidInterstitial;
  static String get rewardedUnitId => testAds ? _testRewarded : _androidRewarded;
}