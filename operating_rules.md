# Operating Rules — Quote Widget

## Code Style

- Flutter SDK ^3.33, Dart ^3.13.1
- `flutter analyze` must pass with 0 errors, 0 warnings before any commit
- Info-level hints (use_build_context_synchronously, prefer_is_empty) are acceptable
- No external state management library — use setState for simplicity
- No formal DI framework — services instantiated in main.dart, passed via constructors

## Testing

- Unit tests for services: `test/rotation_service_test.dart`, `test/storage_service_test.dart`
- Widget limit tests: `test/widget_limit_test.dart`
- All tests must pass before any commit
- Run: `flutter test` (all 44 tests)

## Git

- Branch: master
- No commits yet (project in development)
- Commit convention: not yet established

## Build

- `flutter build apk --release` for APK
- Android only (no iOS targets in scope for MVP)
- minSdk=24, targetSdk=latest Flutter default

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

- Do not add INTERNET permission (offline-first by design)
- Do not use `share_handler` package (unmaintained, custom bridge is sufficient)
- Do not auto-configure Pro widgets (all widgets start with "Tap to set up")
- Do not use `PreferenceManager.getDefaultSharedPreferences()` in Kotlin (wrong file)
