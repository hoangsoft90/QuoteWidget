import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_config.dart';
import '../services/iap_service.dart';

/// Anchored adaptive banner pinned to the bottom of the Home screen
/// (free tier only; Pro removes ads). Renders nothing on web, in widget
/// tests, while Pro, or while the ad is still loading — the layout never
/// reserves space for ads.
///
/// Adds the system bottom inset below the banner so the ad is never hidden
/// behind the Android 3-button navigation bar (edge-to-edge, targetSdk 36).
class BannerAdView extends StatefulWidget {
  final IapService iapService;

  const BannerAdView({super.key, required this.iapService});

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _banner;
  AdSize? _size;
  bool _loaded = false;
  bool _loadStarted = false;

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  void _disposeBanner() {
    _banner?.dispose();
    _banner = null;
    _loaded = false;
  }

  Future<void> _load() async {
    final width = MediaQuery.sizeOf(context).width.floor();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSizeWithOrientation(
      Orientation.portrait,
      width,
    );
    if (size == null || !mounted) return;
    _size = size;
    final banner = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: AdRequest(extras: AdConfig.nonPersonalizedExtras),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _banner = null;
        },
      ),
    );
    _banner = banner;
    await banner.load();
  }

  @override
  Widget build(BuildContext context) {
    // Pro purchase (or unsupported platform / tests) hides the banner.
    if (!AdConfig.supported || widget.iapService.isPro) {
      if (_banner != null) _disposeBanner();
      return const SizedBox.shrink();
    }
    // Kick off the load on first build (MediaQuery is safe to read here).
    if (!_loadStarted) {
      _loadStarted = true;
      _load();
    }
    final banner = _banner;
    if (banner == null || !_loaded) return const SizedBox.shrink();
    final size = _size;
    if (size == null) return const SizedBox.shrink();

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            width: size.width.toDouble(),
            height: size.height.toDouble(),
            child: AdWidget(ad: banner),
          ),
        ),
        // Keep the banner clear of the Android 3-button navigation bar
        // (edge-to-edge on targetSdk 36) — 0 on gesture-nav devices.
        SizedBox(height: bottomInset),
      ],
    );
  }
}