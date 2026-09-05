# Startup reconciliation fix (C1)

## Requirements

- On app start, after services init and before/around `runApp`, scan the native
  configured-widget ids from `configured_widget_ids` SharedPreferences.
- For each native id, resolve its Hive config UUID via
  `WidgetDataBridge.getConfigIdForWidget(appWidgetId)` (key `wcfg_<id>_configId`).
- If a mapping exists BUT the referenced config is no longer in
  `storageService.getAllWidgetConfigs()` → orphan mapping → call
  `WidgetDataBridge.removeWidgetMapping(appWidgetId)` (cleans both directions).
- Widgets with no mapping at all are unconfigured widgets — left alone (the
  native "Tap to set up" state), NOT cleaned.
- The scan must be non-blocking (`Future.microtask`) and must never throw on
  malformed data.
- No `// ignore:` comments for unused locals — dead code must be deleted, not
  silenced.

## Test

- Seed prefs: `configured_widget_ids = "42"`, `wcfg_42_configId = <uuid>`,
  where `<uuid>` is NOT in the Hive widget_configs box.
- Run the reconciliation → mapping `wcfg_42_configId` and
  `wcfg_<uuid>_appWidgetId` are removed; no exception.
- A mapped-and-existing config → mapping preserved.