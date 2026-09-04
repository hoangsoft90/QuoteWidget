# Tasks: Sprint A — Widget Registry / Free-limit Stability

## A1 — Free-limit gate reads native count ✅
- [x] Kotlin: `MainActivity` MethodChannel `quotewidget/widgets` → `getConfiguredWidgetCount` (+ `getConfiguredWidgetIds`) — MainActivity.kt lines 43-58
- [x] Flutter: bridge `getNativeConfiguredWidgetCount()` / `getNativeConfiguredWidgetIds()` (null on error) — widget_data_bridge.dart
- [x] `StorageService.createWidgetConfig()` gate: native count (fallback Hive) — storage_service.dart `_effectiveWidgetCount()`
- [x] Injectable `widgetCountProvider` + `widgetIdsProvider` for tests — storage_service.dart
- [x] Unit tests: 3× A1 in storage_service_test.dart (native=1 blocks empty Hive; null fallback; Pro bypass) — PASS

## A2 — Hybrid reconciliation ✅
- [x] Kotlin: channel method `getConfiguredWidgetIds` (List<int>) — MainActivity.kt
- [x] `StorageService.reconcileWidgetConfigs()`: fast path + full scan cleanup — storage_service.dart
- [x] Wire: app start (`main()`) + resume (`didChangeAppLifecycleState`) — main.dart
- [x] Unit tests: 3× A2 (orphan removed; fast-path no-op; reverse no-op) — PASS

## A3 — `onDeleted()` wcfg cleanup (Kotlin) ✅
- [x] Clean `wcfg_<appWidgetId>_configId` + `wcfg_<configId>_appWidgetId` both prefix variants — QuoteWidgetProvider.kt onDeleted()

## A4 — PREFS_VERSION skeleton (Kotlin) ✅
- [x] `PREFS_VERSION`=1 + `KEY_PREFS_VERSION` + `migratePreferencesIfNeeded()` called in `onUpdate()` — QuoteWidgetProvider.kt

## A5 — Deep-link Upgrade Prompt → paywall ✅
- [x] Kotlin: `showUpgradePrompt()` adds `route=paywall` + NEW_TASK/CLEAR_TOP — QuoteWidgetProvider.kt
- [x] Kotlin: MainActivity cold-start (configureFlutterEngine) + onNewIntent write `pending_route` to BOTH prefs files — MainActivity.kt
- [x] Flutter: startup + resume read/clear `pending_route` → `showPaywallOnStart` → `_openPaywall()` — main.dart (navigatorKey)
- [x] Extract `lib/widgets/paywall_sheet.dart`; WidgetSetupScreen `_showUnlockDialog` reuses it
- [x] Widget tests: 4× paywall_sheet_test.dart (opens 3 options; Cancel; ad-unavailable; buy-unavailable) — PASS

## §6 — UX notes ✅
- [x] Backup screen restore-semantics text (VI) — backup_screen.dart
- [x] `displayTextColor` dead `collectionId == null` condition removed — QuoteWidgetProvider.kt

## Verify
- [x] `flutter analyze` exit 0 — "No issues found!" (exit 0)
- [x] `flutter test` all pass — **85/85** (75 baseline + 3 A1 + 3 A2 + 4 A5)
- [ ] Commit + push → CI debug + release green
- [ ] Device-test checklist delivered (Sprint A §2.6) — **gated: needs physical device, cannot run in this env**