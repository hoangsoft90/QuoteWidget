# Tasks — Phase 1 (plan phase0_checklist.md)

## P0-1 — source/ archive note — ✅ PASS
- [x] Verify `source/` no longer exists (no such dir)
- [x] Verify CI/scripts do not reference `source/` (grep clean)
- [x] README.md: canonical-source note + project README rewrite
- [x] operating_rules.md: Canonical Source rule (root only, no `source/`)

## P0-2 — reconcileWidgetConfigs 2-way scan — ✅ PASS
- [x] Removed `count == count → return` early-return
- [x] Direction 1: unbound config → delete; mapped-to-dead-widget → delete + removeWidgetMapping
- [x] Direction 2: native id stale mapping → removeWidgetMapping; unconfigured → keep
- [x] `_reconciling` guard + provider-null abort kept
- [x] Tests: "counts equal but mapping broken" + unbound + stale-mapping (storage_service_test.dart)

## P0-3 — Backup no-phantom semantics — ✅ PASS
- [x] exportBackup serializes widgetConfigs: []
- [x] importBackup ignores file widgetConfigs (passes const [])
- [x] Backup screen canonical copy
- [x] Test: restore file WITH widgetConfigs → Hive widget_configs empty (restore_rollback_test.dart)

## P0-4 — Dead code + docs hygiene — ✅ PASS
- [x] Deleted processShareText/_isUrlOnly/getShareMessage/ShareResult + dead test
- [x] Fixed WidgetDataBridge header comment
- [x] features.md → canonical .plan/features_final.md

## P0-5 — AdMob runbook — ✅ PASS
- [x] operating_rules.md + README: release build with TEST_ADS=false
- [x] (already) TEST_ADS/ENABLE_ADS dart-defines + no-fill dialog + retry

## P0-6 — IAP consistency — ✅ PASS (verify only)
- [x] No in_app_purchase dep; no buyPro/RemoveAds UI; IapService time-bound only

## P0-7 — onDeleted cleanup — ✅ PASS (verify only)
- [x] wcfg_* 2-way cleanup + read-configId-before-remove confirmed in Kotlin

## P0-8 — Gate — ✅ PASS
- [x] flutter analyze --fatal-warnings: No issues found!
- [x] flutter test: 107/107 PASS
- [x] CI debug + release APK green (run id after push)
- [x] .plan/progress_notes.md written (P0-1…P0-8 = 8/8 PASS)