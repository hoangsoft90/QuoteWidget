import 'dart:async';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_config.dart';
import 'iap_service.dart';

/// Rewarded-ad service — the PRIMARY monetization path.
///
/// A rewarded ad is loaded when the app starts ([loadRewardedAd]) and
/// [showRewardedAd] plays it. When the user watches it to the end, the 24h
/// Pro unlock is persisted via [IapService.unlockProFor24h] and the grant is
/// only reported as success AFTER that persistence completes
/// ([resolveRewardOutcome]) — a completed ad must never leave the user
/// locked because the app was killed mid-write (plan3 Fix A).
///
/// The unit ID comes from [AdConfig] — test units by default (TEST_ADS=true),
/// real units once TEST_ADS is flipped off for production.
class RewardedAdService {
  final IapService iapService;

  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// Whether an ad is currently loaded and ready to show.
  bool get isAdReady => _rewardedAd != null;

  RewardedAdService(this.iapService);

  /// Initialize the Mobile Ads SDK (call once at app startup).
  static Future<void> initMobileAds() async {
    await MobileAds.instance.initialize();
  }

  /// Load a rewarded ad. Call on app open; re-call after each show.
  Future<void> loadRewardedAd() async {
    // Skip in tests / when ads are disabled — never hit platform channels.
    if (!AdConfig.supported || _isLoading || _rewardedAd != null) return;

    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: AdConfig.rewardedUnitId,
        request: AdRequest(extras: AdConfig.nonPersonalizedExtras),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isLoading = false;
          },
          onAdFailedToLoad: (error) {
            _rewardedAd = null;
            _isLoading = false;
          },
        ),
      );
    } catch (_) {
      _isLoading = false;
    }
  }

  /// Show the loaded rewarded ad.
  ///
  /// Returns `true` if the user watched the ad to completion and the reward
  /// was granted (i.e. Pro was unlocked for 24h), `false` otherwise
  /// (no ad loaded, ad dismissed early, load error).
  Future<bool> showRewardedAd() async {
    var ad = _rewardedAd;
    if (ad == null) {
      // No ad ready — try to load once, then give up for this tap.
      await loadRewardedAd();
      ad = _rewardedAd;
      if (ad == null) return false;
    }

    final completer = Completer<bool>();
    var rewardGranted = false;
    final currentAd = ad;

    currentAd.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _rewardedAd = null;
        // Await the persisted 24h unlock BEFORE reporting success so a
        // completed ad never returns true while the grant is still in memory.
        final outcome = await resolveRewardOutcome(rewardGranted);
        if (!completer.isCompleted) completer.complete(outcome);
        // Reload a fresh ad for the next request.
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(false);
        loadRewardedAd();
      },
    );

    currentAd.show(
      onUserEarnedReward: (ad, reward) {
        // User watched the ad to the end — the unlock itself is granted in
        // [resolveRewardOutcome] once the ad closes (persistence is awaited).
        rewardGranted = true;
      },
    );

    // Wait until the ad is dismissed (or a timeout as a safety net).
    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () async {
        // Dismissal never arrived (plugin hiccup). If a reward was earned,
        // still persist the grant so the user is not penalized; otherwise the
        // outcome is false. Never reports true without a persisted unlock.
        return resolveRewardOutcome(rewardGranted);
      },
    );
  }

  /// Resolve the final outcome of a rewarded-ad session (plan3 Fix A).
  ///
  /// Returns `true` only when the ad was watched to the end AND the 24h Pro
  /// unlock has been fully persisted by [IapService.unlockProFor24h]. Any
  /// persistence failure degrades the outcome to `false` — the caller must
  /// never be told Pro was granted when it was not saved. Exposed as a small
  /// test seam (fake [IapService]) since [RewardedAd] cannot be constructed
  /// in pure unit tests.
  @visibleForTesting
  Future<bool> resolveRewardOutcome(bool rewarded) async {
    if (!rewarded) return false;
    try {
      await iapService.unlockProFor24h();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Dispose the current ad (call on app teardown if needed).
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}