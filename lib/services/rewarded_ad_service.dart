import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'iap_service.dart';

/// Rewarded-ad service — the PRIMARY monetization path.
///
/// A rewarded ad is loaded when the app starts ([loadRewardedAd]) and
/// [showRewardedAd] plays it. When the user watches it to the end, the reward
/// callback fires and we call [IapService.unlockProFor24h].
///
/// Ad unit ID: use a real AdMob rewarded unit in production. The value below
/// is Google's official **test** unit, which always serves a test ad.
class RewardedAdService {
  static const String _rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

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
    if (_isLoading || _rewardedAd != null) return;

    _isLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
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
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        if (!completer.isCompleted) completer.complete(rewardGranted);
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
        // User watched the ad to the end → grant the 24h unlock.
        rewardGranted = true;
        iapService.unlockProFor24h();
      },
    );

    // Wait until the ad is dismissed (or a timeout as a safety net).
    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () => rewardGranted,
    );
  }

  /// Dispose the current ad (call on app teardown if needed).
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}