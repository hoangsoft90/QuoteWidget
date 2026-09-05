# Operating Rules — Quote Widget

## Canonical Source (Phase 1 P0-1)

- Repo ROOT (`lib/`, `android/`, `test/`) is the ONLY source of truth.
- The legacy `source/` tree was removed — do NOT recreate it, and never
  develop in any `_archive_legacy_*` folder.
- Canonical feature spec: `.plan/features_final.md` (wins over `features.md`).
- No cloud, iOS, AI, photo background, custom font upload, notification,
  Saved Presets in V1.

## Code Style

- Flutter SDK ^3.33, Dart ^3.13.1
- `flutter analyze` must pass with 0 errors, 0 warnings before any commit
- Info-level hints (use_build_context_synchronously, prefer_is_empty) are acceptable
- No external state management library — use setState for simplicity
- No formal DI framework — services instantiated in main.dart, passed via constructors

## Testing

- All tests must pass before any commit (`flutter test`)
- Baseline: 105 tests (storage, rotation, trash, iap, ads, share, backup
  rollback, widget limit, curated themes, paywall, quick-share undo)
- Backup semantics (Phase 1 P0-3): restore NEVER re-inserts WidgetConfigs
  from a backup file — collections + items only; physical widgets must be
  set up again after restore

## Git

- Branch: main (pushed to origin; CI builds on push)
- Conventional commits: `feat|fix|docs|refactor(scope): summary`
- Commit only after: `flutter analyze` 0 issues + full test suite PASS

## Build

- NEVER build APKs locally — builds run on GitHub Actions only
  (`.github/workflows/build-debug-apk.yml`: analyze --fatal-warnings, test,
  debug APK, release APK smoke compile)
- Android only (no iOS targets in scope for MVP)
- minSdk=24, targetSdk=36 (Google Play API-36 requirement from 2026-08-31)

## Release runbook (Phase 1 P0-5)

- Production build (real ads, real rewarded ID):
  `flutter build appbundle --release --dart-define=TEST_ADS=false`
- Dev / test builds keep the default `TEST_ADS=true` (sample ad units — never
  risk AdMob account limits during development).
- `ENABLE_ADS=false` ships an ad-free build (master switch).
- No-fill UX: rewarded fail → "No ad available. Try again." dialog + retry
  (never silent fail); interstitial cooldown 5 min; non-personalized requests.

## SharedPreferences Convention

- Widget data → `HomeWidgetPreferences` (via `HomeWidget.saveWidgetData()`)
- Supplementary data (is_pro, configured_widget_ids) → `FlutterSharedPreferences` (via `SharedPreferences.getInstance()`)
- NEVER use default SharedPreferences file (caused a critical bug)
- Kotlin reads both files via helper methods: `getString()`, `getInt()`, `getBoolean()`

## Widget Data Flow

- Flutter writes widget data via `HomeWidget.saveWidgetData()`
- Kotlin reads via `getPrefs()` (HomeWidgetPreferences) + helper methods
- `HomeWidget.updateWidget()` triggers Kotlin `onUpdate()`
- Widget tap sends broadcast `com.quotewidget.WIDGET_TAP` → `handleTap()`
- Unconfigured widget tap opens app via `PendingIntent.getActivity()`

## Deep Link Convention

- `tapped_widget_id` in SharedPreferences = widget that was tapped (written by Kotlin)
- `tapped_collection_id` in SharedPreferences = collection to open (for empty collection)
- Both cleared by Flutter after navigation
- Warm-start handled by `WidgetsBindingObserver.didChangeAppLifecycleState`
- Cold-start handled by `main()` reading SharedPreferences before `runApp()`

## Ponytail Mode

- Default: FULL (minimize code, avoid over-engineering)
- Disabled for: widget SharedPreferences bridge, PendingIntent logic, IAP, data validation
- The app prioritizes simplicity over abstraction — no BLoC, no Riverpod, no formal architecture patterns

## Do NOT

- Do NOT use bare `// ignore: unused_local_variable` or `// ignore: unused_element` —
  an unused local usually means logic is dead (plan6 C1: a broken reconciliation
  was silenced this way). Either delete the dead code, or keep the ignore WITH a
  comment directly above explaining exactly why (e.g. API-compat placeholder). If
  unsure, ask the user instead of suppressing.
- Do not REMOVE INTERNET permission (required by google_mobile_ads — ads are
  the primary monetization path; app data itself stays offline-first)
- Do not disable TEST_ADS for normal dev builds (real units → AdMob can limit
  the account; flip with --dart-define=TEST_ADS=false only for release testing)
- Do not build APKs locally — builds run on GitHub Actions only
- Do not use `share_handler` package (unmaintained, custom bridge is sufficient)
- Do not auto-configure Pro widgets (all widgets start with "Tap to set up")
- Do not use `PreferenceManager.getDefaultSharedPreferences()` in Kotlin (wrong file)
