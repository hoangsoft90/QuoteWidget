# Phase 1 — spec: reconcile 2-way mapping integrity

## Delta

`StorageService.reconcileWidgetConfigs()` no longer skips the integrity scan
when `hiveConfigs.length == nativeIds.length`. Whenever the native provider is
available, the full 2-way scan runs:

- A Hive `WidgetConfig` with no `wcfg_*` mapping (`getAppWidgetIdForConfig`
  returns null) is deleted (unbound/phantom).
- A Hive `WidgetConfig` mapped to an `appWidgetId` not present in the native
  set is deleted AND its `wcfg_*` mapping removed (both directions).
- A native `appWidgetId` whose `wcfg_*_configId` points at a config missing
  from Hive has its stale mapping removed.
- A native `appWidgetId` with no mapping is left alone ("Tap to set up").

## Rules

- `_reconciling` guard still prevents re-entrant runs.
- Provider returns null (MethodChannel unavailable) → abort, never destroy data.
- Runs on startup + resume (existing call sites unchanged).
- Unit tests must cover: count-equal-but-mapping-broken cleanup, unbound
  config deletion, stale-mapping cleanup, unconfigured-widget preservation.