# Working Log — Quote Widget

## Current Status

**Phase:** plan5_final Sprint 0 code-complete — 91/91 tests pass
**Next:** CI verify (push mới nhất) → **device test Sprint 0 §1.8** (bắt buộc, gated trước Sprint 1)
**Blocker:** Device test cần máy thật (không chạy được trong env này) — Sprint 1/2/3 chờ gate

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

### [2026-09-03] plan3_final — Pro unlock reliability (A/B/C)
- **Fix A (HIGH)** — reward grant race: `RewardedAdService` now reports success
  only AFTER `unlockProFor24h()` persistence completes. New `resolveRewardOutcome`
  seam awaited in dismiss + timeout paths; failed-to-show → false. Test:
  `test/rewarded_ad_service_test.dart` (3 tests, fake IapService).
- **Fix B (MEDIUM)** — `IapService._persist()` now calls `HomeWidget.updateWidget`
  after the `is_pro`/`is_pro_expires_at` writes → widget placeholder refresh
  ngay khi Pro đổi từ Settings/buy/restore. Channel-mock test asserts order.
- **Fix C (LOW-MEDIUM)** — `_onPurchaseUpdate` async-safe: persist trước
  `completePurchase`; widget-limit dialog 'buy' branch tự retry `_save()` khi
  `isPro` đã active.
- Tests: 71 → 75 (rewarded x3, widget-push x1, khôi phục Permanent-Pro test bị
  rớt giữa chừng). CI run **33768066875** green (analyze + test + debug + release).
- Openspec: `openspec/changes/pro-unlock-reliability/` (proposal/design/tasks/specs).

## Recent Activity

### [2026-09-04] plan5_final — Sprint 0 completion (§1.6 + §1.7)
- Sprint A (plan4) items §1.1–§1.5 đã merge từ commit `54f5c7d` (CI run 33832808067 green) —
  plan5_final §0 premise "chưa thực thi" là STALE, chỉ còn 2 bổ sung §1.6/§1.7 + gate device test.
- **§1.6 Graceful Pro-expiry (Kotlin):** `QuoteWidgetProvider` thêm `isExpiredLocked()`
  (pass hết hạn + số widget cấu hình > free limit + không phải widget cũ nhất → lock) +
  `showLockedPrompt(message)` dùng chung (refactor từ `showUpgradePrompt`). Widget thứ 2
  render "24h Pass Expired\nTap to renew" thay vì giữ content âm thầm / biến mất; tap →
  route=paywall deep link (A-5) → paywall sheet. Widget cũ nhất (free slot) vẫn chạy.
  Check nằm trong `updateAppWidget()` → MỌI render path tôn trọng lock.
- **§1.7 Quick Share Undo (Flutter):** `ShareService.saveToCollection` trả `Item?`
  (Undo target chính xác); `_handlePendingShare` show SnackBar "Saved to X" 10s + action
  **Undo** → soft-delete item (Trash, recoverable) + refresh widget của collection.
  Extract `lib/widgets/share_undo_snackbar.dart` (testable không cần Hive trong
  testWidgets/FakeAsync). Fix kèm: `showDialog` multi-collection dùng navigator-key
  context (trước dùng app-level context ở TRÊN MaterialApp → crash tiềm ẩn khi
  user >1 collection share).
- Tests: 84 → **93** (4 share_service_test + 3 quick_share_undo_test + 2 widget_service_test
  startup-push). analyze exit 0. (Review bổ sung: `syncProStatus` giờ push
  `HomeWidget.updateWidget` sau khi ghi is_pro — `updatePeriodMillis=0` nên không có
  system refresh; nếu không push, widget hết hạn khi app đóng sẽ render content cũ
  mãi tới khi tap/reboot. Push lúc app mở → lock tự áp dụng.)
- Openspec: `openspec/changes/sprint0-completion/`.
- CI run **33857086225** (commit `7eed09c`) green — analyze + tests + debug/release APK
  (Kotlin §1.6 compile gate). Device test §1.8 = manual gate → Sprint 1/2/3 (plan5 §2–§4) chưa mở.


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
91/91 tests pass (0 errors, 0 warnings on flutter analyze)
├── widget_limit_test.dart: 11
├── storage_service_test.dart: 29 (incl. A1/A2 native-count + reconciliation)
├── rotation_service_test.dart: 11
├── iap_service_test.dart: 7
├── curated_themes_test.dart: 4
├── trash_test.dart: 9
├── interstitial_ad_test.dart: 6
├── rewarded_ad_service_test.dart: 3
├── paywall_sheet_test.dart: 4
├── share_service_test.dart: 4 (plan5 §1.7 Undo target)
├── quick_share_undo_test.dart: 3 (plan5 §1.7 snackbar UI)
└── widget_test.dart: 1
```

### [2026-09-04] plan4_final — Sprint A: Widget Registry / Free-limit Stability
- **A1 Free-limit gate:** `createWidgetConfig()` giờ đọc NATIVE `configured_widget_ids`
  qua MethodChannel `quotewidget/widgets` (`getConfiguredWidgetCount`/`getConfiguredWidgetIds`
  trong MainActivity), fallback Hive khi channel unavailable — fix **dead-end trap**: xoá
  collection của widget duy nhất (Hive rỗng) trước đây cho phép cấu hình widget 2 →
  native chặn "Upgrade to Pro" vĩnh viễn. `WidgetDataBridge.getNativeConfiguredWidget*`.
- **A2 Hybrid reconciliation:** `StorageService.reconcileWidgetConfigs()` — so Hive count
  vs native count, lệch → quét full xoá orphaned WidgetConfig + wcfg_* mapping cả 2
  chiều. Chạy lúc app start + resume.
- **A3 onDeleted() cleanup:** `QuoteWidgetProvider.onDeleted()` xoá luôn
  `wcfg_<appWidgetId>_configId` / `wcfg_<configId>_appWidgetId` (Kotlin, không qua Dart).
- **A4 PREFS_VERSION:** `PREFS_VERSION`=1 + `migratePreferencesIfNeeded()` gọi đầu
  `onUpdate()` — hook migration cho OTA đầu tiên đổi key format.
- **A5 Paywall deep link:** `showUpgradePrompt()` thêm `route=paywall` → MainActivity
  persist `pending_route` (cả 2 file prefs) → Flutter đọc lúc start/resume → mở
  `lib/widgets/paywall_sheet.dart` (Watch Ad 24h / Buy Pro / Cancel) — WidgetSetupScreen
  dùng chung sheet này (bỏ dialog cũ trùng logic).
- **§6:** text restore-semantics (VI) trong Backup screen + dọn điều kiện chết
  `collectionId == null` trong `displayTextColor` (Kotlin).
- Tests: **85/85** (75 baseline + 3 A1 + 3 A2 + 4 A5 mới). analyze exit 0.
- CI run: (chờ push) — xem tasks.md sprint-a-stability.

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
