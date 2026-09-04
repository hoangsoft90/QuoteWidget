# Widget Registry Stability

## ADDED Requirements

### Native widget count via MethodChannel

- `MainActivity` exposes MethodChannel `quotewidget/widgets` with method
  `getConfiguredWidgetCount` returning the size of `configured_widget_ids` (parsed the same
  way as `QuoteWidgetProvider.getConfiguredWidgetIds`).
- The same channel exposes `getConfiguredWidgetIds` returning the parsed `List<int>` of
  configured app widget ids.

### Free-limit gate uses native count

- `StorageService.createWidgetConfig()` blocks a Free-tier 2nd widget when the **native**
  configured-widget count is at or above the Free limit (1), regardless of the Hive
  `widget_configs` box contents.
- When the native count is unavailable (platform error / tests), the gate falls back to the
  Hive box length so behavior never silently loosens.
- Pro users (permanent or within the 24h window) are not blocked.

### Hybrid reconciliation

- `StorageService.reconcileWidgetConfigs()` compares Hive `WidgetConfig` count with the
  native configured-widget count.
- If counts match → no-op (fast path).
- If they differ → full scan; a Hive `WidgetConfig` whose mapped `appWidgetId` is not in
  the native set is deleted together with its `wcfg_*` mapping (both directions).
- Reconciliation runs at app start and on app resume, guarded against re-entrancy.

### `onDeleted()` mapping cleanup

- `QuoteWidgetProvider.onDeleted()` removes `wcfg_<appWidgetId>_configId` and
  `wcfg_<configId>_appWidgetId` (both `flutter.`-prefixed and raw variants) for every
  deleted widget id, in the same `SharedPreferences` apply chain as the existing cleanup.

### PREFS_VERSION migration hook

- `QuoteWidgetProvider` defines `PREFS_VERSION` and calls `migratePreferencesIfNeeded()`
  at the top of `onUpdate()`; stored version lives in FlutterSharedPreferences; the
  migration body is a no-op today but runs once per version bump.

### Paywall deep link from native widget

- `showUpgradePrompt()` adds `route=paywall` to the launch intent.
- `MainActivity` persists `pending_route=paywall` to both HomeWidgetPreferences and
  FlutterSharedPreferences (`flutter.`-prefixed) on cold start and warm start.
- The Flutter app reads + clears `pending_route` on startup and on resume; when present it
  opens the paywall bottom sheet (Watch Ad 24h / Buy Pro / Cancel).
- `WidgetSetupScreen` reuses the same paywall sheet.