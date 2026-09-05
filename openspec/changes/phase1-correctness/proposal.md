# Phase 1 — Production Correctness

## Why

The app is ~86/100 on the production-readiness audit (plan7). Before any new
feature (Favorites/Search/Shuffle/Daily) ships, three P1 correctness holes must
close (per `.plan/phase0_checklist.md`):

1. `reconcileWidgetConfigs()` skips its integrity scan when Hive count == native
   count — a broken/absent mapping survives silently ("count bằng nhau nhưng
   mapping gãy").
2. Backup export serializes active WidgetConfigs and import re-inserts them,
   creating phantom Hive configs with no physical widget (blocks the Free
   limit / shows stale content).
3. Dead code: `processShareText()` + `ShareResult` have no call site; the
   `WidgetDataBridge` header comment names a non-existent prefs file.

`source/` legacy tree is already gone (verified). IAP is already Rewarded-only
(verified). Native `onDeleted` already cleans `wcfg_*` both ways (verified).

## Out of scope (Phase 1)

Favorites, Search, Shuffle Bag, Daily rotation, Auto-rotate, Tap action, 4×2,
templates — all gated behind Phase 1 PASS (plan gate).

## Design

### 1. `reconcileWidgetConfigs()` — always scan (P0-2)

Remove the `hiveConfigs.length == nativeIds.length` early-return. When the
native provider is available, always run the full 2-way scan:

- For each Hive config: resolve `appWidgetId = getAppWidgetIdForConfig(id)`.
  - `appWidgetId == null` → unbound/phantom config → delete.
  - `appWidgetId != null && !nativeIds.contains(appWidgetId)` → physical widget
    gone → delete config + `removeWidgetMapping(appWidgetId)`.
- For each nativeId: `configId = getConfigIdForWidget(nativeId)`.
  - `configId != null && config not in Hive` → stale mapping → `removeWidgetMapping`.
  - `configId == null` → unconfigured widget → keep ("Tap to set up").

Keep the `_reconciling` guard. Keep `cleanupOrphanWidgetMappings` (prefs-based
fallback used by the main.dart microtask when the MethodChannel is down).

Tests updated: the old "fast path: counts match → no cleanup" test becomes
"counts equal BUT mapping broken → cleanup runs" (plan-mandated case) + new
cases for unbound config deletion and stale-mapping cleanup inside reconcile.

### 2. Backup semantics — no phantom WidgetConfigs (P0-3)

- `exportBackup()`: serialize `widgetConfigs: const []` (keep schema field,
  empty) — active configs never leave the device.
- `importBackup()`: accept files with or without `widgetConfigs`, but pass
  `const []` to `restoreFromBackup`/`appendFromBackup` — file configs are
  ignored (V1: physical widgets are NOT part of backup).
- `StorageService.restoreFromBackup/appendFromBackup` keep the param — the
  SnapshotManager rollback path legitimately restores real (bound) configs.
  Overwrite import therefore clears `_widgetConfigsBox` (via `clearAll`) and
  does NOT repopulate it → no phantoms.
- Backup screen copy → canonical: "Backup restores your collections and items.
  Home Screen widgets need to be set up again."
- Test: restore a file that CONTAINS widgetConfigs → Hive `widget_configs` is
  empty; collections/items restored correctly.

### 3. Dead code + docs hygiene (P0-4)

- Delete `processShareText()`, `_isUrlOnly()`, `getShareMessage()`,
  `ShareResult` + the dead test that exercises them (share flow uses
  `saveToCollection` directly — the only live path).
- Fix `WidgetDataBridge` header comment: the bridge writes
  `FlutterSharedPreferences` (via `SharedPreferences.getInstance()`); display
  data flows through `HomeWidget.saveWidgetData` → `HomeWidgetPreferences`.
- `features.md`: point to `.plan/features_final.md` as the canonical spec.

### 4. AdMob release runbook (P0-5)

Document the production build command (`--dart-define=TEST_ADS=false`) in
`operating_rules.md`. Flags + no-fill dialog already exist (plan6 H2).

## Verification

- `flutter analyze` exit 0 (CI runs `--fatal-warnings`)
- `flutter test` all pass (105 baseline + new P0-2/P0-3 cases − 1 dead test)
- Debug/release APK compile via GH Actions (project rule: no local builds)