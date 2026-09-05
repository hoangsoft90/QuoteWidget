# Tasks — plan6-bugfix

## C1 — Fix startup reconciliation (CRITICAL) ✅

- [x] Remove `// ignore: unused_local_variable` + broken int-vs-UUID comparison in `main.dart`
- [x] Rewrite: for each native `appWidgetId`, resolve its config UUID via
      `WidgetDataBridge.getConfigIdForWidget()`; if a mapping exists but the
      config is no longer in Hive → orphan → `WidgetDataBridge.removeWidgetMapping()`
- [x] Wrap in `Future.microtask()` (non-blocking before/after runApp)
- [x] Test: stale `wcfg_<id>_configId` mapping whose config was deleted →
      orphan cleaned, no throw — 4 tests trong storage_service_test.dart

## C4 — Real rewarded ad unit ID (CRITICAL) ✅

- [x] Replace `_androidRewarded` in `lib/services/ad_config.dart` with
      `ca-app-pub-6917313063209470/7613467914`
- [x] Keep `_testRewarded` = sample ID; confirm the two differ
- [ ] Report: logcat verification of TEST_ADS=false is a Device QA gate item #10

## C5 — Dead code + CI guard (CRITICAL) ✅

- [x] Delete `lib/screens/widget_config_screen.dart` + `lib/widgets/widget_preview.dart`
      (cả 2 dead, chỉ reference nhau)
- [x] `flutter analyze` clean after deletion (no broken imports)
- [x] Add `flutter analyze --fatal-warnings` to `.github/workflows/build-debug-apk.yml`
- [x] Add rule to `operating_rules.md`: no bare `// ignore: unused_local_variable` /
      `unused_element` — must carry an explanation comment above, or ask user

## H2 — Rewarded no-fill handling (HIGH) ✅

- [x] `RewardedAdService`: `RewardedAdResult` enum — granted / dismissed /
      unavailable (load fail / no-fill / show error / timeout)
- [x] Paywall sheet + settings: khi unavailable → dialog
      "Không có quảng cáo lúc này. Vui lòng thử lại sau ít phút." + Retry (loop)
- [x] No free-fallback unlock added (explicitly deferred)
- [x] Tests: rewarded_ad_service (no-ad → unavailable) + paywall_sheet (dialog)

## H5 — Share target dialog (HIGH) ✅

- [x] Native check: ShareReceiverActivity only writes prefs + finish (verified — no Hive write)
- [x] `main.dart`: on `pending_share_text` → dialog `share_target_dialog.dart`
      "Lưu vào [collection mặc định/gần nhất]" / "Đổi collection" / "Huỷ"
      instead of auto-save
- [x] No 5s auto-save timer
- [x] Widget test — 5 tests (default save / change / cancel / barrier dismiss / content)

## H6 — Restore rollback test (HIGH) ✅

- [x] Test: restore fails mid-way (FailingRestoreStorage throws after partial
      write) → whole Hive DB returns to pre-restore state
- [x] Assert snapshot contains OLD data → created BEFORE clearAll
- [x] Verify no partial mix (old collections intact, no NEW data survives)
- [x] 2 integration tests (test/restore_rollback_test.dart, PathProviderPlatform fake)

## Docs ✅

- [x] `features.md` / `checklist.md`: rewarded-only 24h là chiến lược chính thức;
      banner stays for rewarded Pro; IAP removed is intentional (not leftover)
- [x] Verify no hardcoded Pro=true in lib/ (H4) — clean (chỉ legacy migration
      `DateTime(9999)` khi đọc `iap_pro_purchased` cũ)

## Verify ✅

- [x] `flutter analyze --fatal-warnings` exit 0 — No issues found
- [x] `flutter test` — **105/105 pass** (93 baseline + 4 C1 + 1 H2 + 5 H5 + 2 H6)
- [ ] CI green after push (debug + release APK)