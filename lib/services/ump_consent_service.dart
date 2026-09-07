import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP consent flow (A2) — thin wrapper over the google_mobile_ads UMP API.
///
/// Google-required flow, run on EVERY app start (before the Mobile Ads SDK
/// initializes):
/// 1. `requestConsentInfoUpdate()` — refresh consent state from the server.
/// 2. `ConsentForm.loadAndShowConsentFormIfRequired()` — show the form when
///    Google requires one for this user/region.
/// 3. `canRequestAds()` — the single gate for loading/showing ANY ad
///    (banner, interstitial, rewarded).
///
/// Onboarding gating (user decision): on the very first launch the form is
/// NOT shown during onboarding — `main()` calls [ensureConsentResolved] with
/// `showFormIfRequired: false` while onboarding is incomplete, and
/// `HomeScreen` calls it again (form allowed) after onboarding.
///
/// Privacy Options: `SettingsScreen` shows an entry point only when Google
/// requires one ([isPrivacyOptionsRequired]), calling [showPrivacyOptions].
class UmpConsentService {
  UmpConsentService._();

  static final UmpConsentService instance = UmpConsentService._();

  /// Cached result of the latest [canRequestAds] query. Defaults to `true`
  /// so pure unit tests (which never run the consent flow) keep passing;
  /// on device `main()` always awaits [ensureConsentResolved] before any UI
  /// exists, which sets this to the real value.
  bool _canRequestAds = true;

  /// Whether ads may be requested/showed in this session (A2 gate).
  bool get canShowAds => _canRequestAds;

  /// Refresh consent state and, when allowed, show the required form.
  ///
  /// Safe to call multiple times; every call refreshes the cached
  /// [canShowAds] value. All UMP failures degrade to "no ads" — ads must
  /// never show with unknown consent state on a real device.
  Future<void> ensureConsentResolved({bool showFormIfRequired = true}) async {
    final info = ConsentInformation.instance;

    final updated = Completer<void>();
    try {
      info.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        updated.complete,
        (_) => updated.complete(), // failure still resolves; gate below fails closed
      );
    } catch (_) {
      _canRequestAds = false;
      return;
    }
    await updated.future.timeout(const Duration(seconds: 15), onTimeout: () {});

    if (showFormIfRequired) {
      try {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      } catch (_) {
        // Form load/show failure — consent state unchanged; gate re-reads it.
      }
    }

    try {
      _canRequestAds = await info.canRequestAds();
    } catch (_) {
      _canRequestAds = false;
    }
  }

  /// Whether Google requires a Privacy Options entry point for this user.
  Future<bool> isPrivacyOptionsRequired() async {
    try {
      final status = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Show the Privacy Options form (user can update/withdraw consent).
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {
      // No form available — nothing to show.
    }
  }
}
