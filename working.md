# Working Log — Quote Widget

## Current Status

**Phase:** Sprint-next (prompt_sprint_next.md) P0→P0.5→P1 complete — Tasks 1-7 done
**Next:** CI build verify on GH Actions (2026-09-03 changes) + real-device test
**Blocker:** None — 71/71 tests pass, analyze clean

### [2026-09-03] Release-prep batch (ads thật + SDK36 + cleartext + icon + Sentry + nav)
- **AdMob production setup:** real App ID in manifest
  (`ca-app-pub-6917313063209470~9587990603`), real banner
  (`…/1409128007`) + interstitial (`…/1569899782`) unit IDs in new
  `lib/services/ad_config.dart` with dart-define flags `ENABLE_ADS` (default
  true) + `TEST_ADS` (default TRUE — test/sample units, tránh AdMob limit khi
  test). Banner trên Home (free tier) + interstitial sau destructive actions
  (delete-forever, overwrite restore) — `InterstitialAdController`
  (frequency 5 + 5-min cooldown, `shouldShowInterstitial` pure fn).
  google_mobile_ads ^5.3.1 → ^9.0.0.
- **targetSdk 36 + SDK setup:** compileSdk=36/targetSdk=36 pinned explicit
  (Play yêu cầu API 36 từ 31/8/2026); AGP 8.9.1 + Gradle 8.11.1 + Kotlin
  1.9.22 (AGP 9 built-in Kotlin incompatible với sentry_flutter language
  version 1.6 → revert). NDK 28.2.13676358 + platforms 34/35/36 installed
  local; ~/.gradle relocated to /opt (full disk).
- **Cleartext HTTP:** `res/xml/network_security_config.xml`
  (base-config cleartextTrafficPermitted=true) + manifest attribute — http
  hoạt động trong release APK (app có INTERNET cho ads).
- **App icon:** adaptive (gradient bg + format_quote foreground vector,
  mipmap-anydpi-v26) + legacy PNGs regenerate (PIL).
- **Sentry:** `sentry_flutter ^8.14.2`, init đầu main.dart + manifest
  `io.sentry.dsn` (native crashes).
- **Safe area:** banner thêm bottom inset (MediaQuery.paddingOf.bottom) —
  không bị Android 3-button nav bar che (edge-to-edge targetSdk 36).
- **Nav review:** BackupScreen chưa có entry point (dead end) → thêm tile
  "Backup & Restore" trong Settings; fix deep-link edge case: WidgetSetupScreen
  cold-start root → `canPop()==false` → pushReplacement Home (trước đó pop
  root → black screen).
- **CI:** workflow Flutter 3.32.4 → 3.47.1, thêm `flutter analyze` + build
  release APK step (2 artifacts). KHÔNG build local — chỉ GH Actions.
- Tests: +6 `test/interstitial_ad_test.dart` (65 → 71).

## Recent Activity

### [2026-09-03] Sprint-next Tasks 1-7 (prompt_sprint_next.md)
- **Task 1 (P0)** — Monetization pivot → rewarded-ad unlock 24h:
  - `IapService` Pro time-bound: `DateTime? proUnlockedUntil`, `isPro` = now < expiry;
    mua vĩnh viễn (IAP "Remove Ads Forever") → `DateTime(9999)`; `unlockProFor24h()`.
  - New `RewardedAdService` (google_mobile_ads): load-on-start + `showRewardedAd()`
    → reward → unlock 24h.
  - `StorageService.setProStatusProvider(() => iapService.isPro)` — widget limit
    re-evaluates live → auto re-lock after 24h expiry (tests).
  - Kotlin `isProActive()` reads `is_pro_expires_at` epoch → self-lock offline.
  - Upsell dialog (Watch Ad 24h / Remove Ads Forever) at widget-setup block point.
  - Manifest: +INTERNET, +ACCESS_NETWORK_STATE, AdMob App ID (test id).
- **Task 2 (P0)** — Share no longer launches app: ShareReceiverActivity writes to the
  CORRECT prefs file (`FlutterSharedPreferences`/`flutter.pending_share_text` — old code
  used `share_prefs`+plain key, so shares never reached Flutter), translucent theme,
  finish() only. Native Toast confirm via `quotewidget/toast` MethodChannel.
- **Task 3 (P0)** — privacy.html rewritten (offline-first + Google Ads disclosure),
  settings URL → `https://hoangsoft90.github.io/QuoteWidget/privacy.html`
  (Pages must be enabled on repo).
- **Task 4 (P0)** — Settings Pro row shows 24h countdown / Free→watch-ad / Remove Ads
  Forever purchase; Restore Purchases kept.
- **Task 5 (P0.5)** — Onboarding use-case picker (Vocabulary/Motivation/Work/Gym/
  Personal) → 1 sample collection + live widget preview → AddWidgetGuideScreen.
- **Task 6 (P0.5/P1)** — 6 curated themes (`WidgetTheme` + `kCuratedThemes`) rendered
  natively on both widget layouts via `widget_bg_*.xml` gradient drawables + Kotlin
  `themeDrawableFor()`; in-app preview mirrors gradient.
- **Task 7 (P1)** — Trash/Recently Deleted: `isDeleted`/`deletedAt` on Collection+Item
  (backward-compatible Hive adapters), soft delete, restore, delete-forever,
  `RecentlyDeletedScreen`, 30-day `purgeTrash` at app start.

## Test Status

```
65/65 tests pass (0 errors, 0 warnings on flutter analyze)
├── widget_limit_test.dart: 11
├── storage_service_test.dart: 26 (incl. 2 time-bound limit re-lock)
├── rotation_service_test.dart: 11
├── iap_service_test.dart: 6 (time-bound Pro, 24h unlock/expiry, persistence)
├── curated_themes_test.dart: 4 (theme ↔ native drawable parity)
├── trash_test.dart: 9 (soft-delete/restore/purge)
└── widget_test.dart: 1
```

## Known Issues / TODO

- [ ] CI build of new commit on GH Actions (run 33708833890) — Kotlin compile gate
- [ ] Device test: rewarded ad flow, background share (no app flash), theme render
- [ ] Enable GitHub Pages on repo so privacy URL resolves
- [ ] Replace AdMob test App ID + rewarded unit id with real production ids
- [ ] Configure IAP product `com.quotewidget.pro` in Play Console / App Store
- [ ] Device: Samsung / Xiaomi OEM add-widget flows (plan B3)

## Files Modified (Sprint-next)

~30 files: iap/rewarded_ad/widget_data_bridge/widget/storage/toast/sample_data services,
widget_theme model, collection+item models (+trash flags), main.dart, onboarding/
use_case_selection/recently_deleted/settings/widget_config/widget_setup/home screens,
widget_preview, ShareReceiverActivity+MainActivity Kotlin, QuoteWidgetProvider,
widget layouts + 6 gradient drawables, AndroidManifest, privacy.html, pubspec,
tests (3 new files + 2 new storage tests).
