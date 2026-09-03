import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

/// Pure decision — no platform channels, fully unit-testable.
///
/// An interstitial may show only when the destructive-action counter hits the
/// frequency milestone AND the cooldown since the last show has elapsed.
bool shouldShowInterstitial({
  required int actionCount,
  required int frequency,
  required DateTime now,
  required DateTime? lastShownAt,
  required Duration cooldown,
}) {
  if (actionCount <= 0 || frequency <= 0) return false;
  if (actionCount % frequency != 0) return false;
  final last = lastShownAt;
  if (last == null) return true;
  return now.difference(last) >= cooldown;
}

/// Owns the interstitial lifecycle. Ads are opportunistic: the ad is preloaded
/// in the background after each destructive action so one is already ready at
/// every [frequency]-th action. Any load or show failure is silently ignored —
/// ads must never block the user's flow.
class InterstitialAdController {
  /// Show one interstitial per this many destructive actions (rare by design).
  static const int frequency = 5;

  InterstitialAd? _ad;
  bool _loading = false;
  bool _pendingShow = false;
  DateTime? _lastShownAt;
  int _actionCount = 0;

  /// Call after each successful destructive action (delete-forever,
  /// overwrite restore).
  void onDestructiveAction() {
    if (!AdConfig.supported) return;
    _actionCount++;
    if (shouldShowInterstitial(
      actionCount: _actionCount,
      frequency: frequency,
      now: DateTime.now(),
      lastShownAt: _lastShownAt,
      cooldown: AdConfig.interstitialCooldown,
    )) {
      _showReadyAd();
    } else if (_ad == null && !_loading) {
      // Preload now so the next milestone has an ad ready to show.
      _load();
    }
  }

  void _showReadyAd() {
    final ad = _ad;
    _ad = null;
    if (ad == null) {
      // Not loaded yet (slow network / no fill) — show as soon as it lands.
      _pendingShow = true;
      if (!_loading) _load();
      return;
    }
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (a) => a.dispose(),
      onAdFailedToShowFullScreenContent: (a, _) => a.dispose(),
    );
    _lastShownAt = DateTime.now();
    ad.show();
  }

  void _load() {
    if (_loading) return;
    _loading = true;
    try {
      InterstitialAd.load(
        adUnitId: AdConfig.interstitialUnitId,
        request: AdRequest(extras: AdConfig.nonPersonalizedExtras),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _loading = false;
            _ad = ad;
            if (_pendingShow) {
              _pendingShow = false;
              _showReadyAd();
            }
          },
          onAdFailedToLoad: (_) => _loading = false,
        ),
      );
    } catch (_) {
      // No fill, offline, or a platform hiccup — never surface to the user.
      _loading = false;
    }
  }

  /// Dispose the loaded ad (call on app teardown if needed).
  void dispose() {
    _ad?.dispose();
    _ad = null;
  }
}