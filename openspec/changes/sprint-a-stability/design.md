# Design: Sprint A — Widget Registry / Free-limit Stability

## State ownership (from plan4_final §1)

| State | Source of truth | Role |
|---|---|---|
| Business data (theme, rotation, appearance) | Hive `WidgetConfig` | App logic / UI |
| Physical existence + Free-limit count | Native `configured_widget_ids` | **Only gate for free-limit** |
| Runtime mapping | `wcfg_<appWidgetId>_configId` ↔ `wcfg_<configId>_appWidgetId` | Hive ↔ Android widget instance |
| Render cache | `widget_<id>_*` | Native draws RemoteViews |

## A1 — Free-limit gate reads native count

**Kotlin (`MainActivity.kt`):** add a MethodChannel handler on the existing engine channel
setup — new channel `quotewidget/widgets` with method `getConfiguredWidgetCount` returning
`getConfiguredWidgetIds(context).size`. Reuse the provider's own parsing logic (the
`configured_widget_ids` string lives in FlutterSharedPreferences, written by
`saveConfiguredWidgetId` / `onDeleted`).

**Flutter (`WidgetDataBridge` or a small `WidgetCountBridge`):** expose
`getConfiguredWidgetCount()` that invokes the channel. Returns `null` on any platform
error (MissingPluginException in tests, non-Android) so callers can fall back.

**`StorageService.createWidgetConfig()`:** change the gate from
`!_isProActive && _widgetConfigsBox.isNotEmpty` to:

```
isPro? allow
else:
  nativeCount = await bridge.getConfiguredWidgetCount()   // null → fallback
  effective = nativeCount ?? _widgetConfigsBox.length      // fallback = Hive
  if (effective >= FREE_WIDGET_LIMIT) throw WidgetLimitReachedException
```

Keep the throw semantics identical (WidgetSetupScreen already catches and shows the unlock
dialog). The gate remains a *pre-check* — the native `onUpdate()` gate stays authoritative
for widgets already on screen.

**Injectable for tests:** StorageService takes an optional `Future<int?> Function()`
`widgetCountProvider`. Production wires it to the bridge; tests inject a fake so
A1 behavior is verified without platform channels.

## A2 — Hybrid reconciliation on open/resume

New `StorageService.reconcileWidgetConfigs()`:

1. Read native configured IDs (new channel method `getConfiguredWidgetIds` returning
   `List<int>`) — or via the injected provider returning `List<int>`.
2. Compare `_widgetConfigsBox.length` with native count.
3. Equal → fast path, nothing to do.
4. Mismatch → full scan:
   - For each Hive `WidgetConfig`, look up its mapped `appWidgetId` via
     `WidgetDataBridge.getAppWidgetIdForConfig(config.id)`.
   - If mapped id is non-null and NOT in the native set → orphaned → delete the Hive
     config **and** `WidgetDataBridge.removeWidgetMapping(appWidgetId)` (clean both
     directions).
   - Reverse: native ids that have no Hive config AND no mapping → unconfigured widgets,
     leave alone (they are the "Tap to set up" state).

Trigger points: `main()` after `storageService.init()` + in
`_QuoteWidgetAppState.didChangeAppLifecycleState` on `resumed` (already has a hook there
for widget taps). Guard with a re-entrancy flag (reconciliation already running → skip).

## A3 — `onDeleted()` wcfg cleanup in Kotlin

In `QuoteWidgetProvider.kt::onDeleted()`, inside the existing per-id loop, additionally:

- Read `flPrefs.getString("flutter.wcfg_${appWidgetId}_configId")` (Dart writes via
  `SharedPreferences` → keys stored with the `flutter.` prefix).
- If found → remove `wcfg_<appWidgetId>_configId` and `wcfg_<configId>_appWidgetId`
  (both with and without the `flutter.` prefix, matching the existing double-write
  convention), same `.apply()` chain as the existing cleanup.

No Dart round-trip needed — Kotlin reads the same FlutterSharedPreferences file directly
(`getFlutterPrefs()` already exists).

## A4 — PREFS_VERSION skeleton

`QuoteWidgetProvider.kt` companion: `const PREFS_VERSION = 1`, `const KEY_PREFS_VERSION`.
`onUpdate()` calls `migratePreferencesIfNeeded(context)` at the top:

```
stored = flPrefs.getInt(KEY_PREFS_VERSION, 0)  // 0 = never set (pre-version era)
if stored >= PREFS_VERSION return
// future migrations run here, keyed by stored version
flPrefs.edit().putInt(KEY_PREFS_VERSION, PREFS_VERSION).apply()
```

Stored in FlutterSharedPreferences (supplementary file — matches `is_pro` convention).
No schema change today, so the migration body is empty.

## A5 — Deep-link Upgrade Prompt → paywall sheet

**Kotlin `showUpgradePrompt()`:** add `launchIntent.putExtra("route", "paywall")`
(alongside the existing appWidgetId extra) before creating the PendingIntent.

**`MainActivity.kt`:** in `configureFlutterEngine` (cold start) read
`intent.getStringExtra("route")`; in `onNewIntent` (warm start) read the same from the new
intent. When `route == "paywall"`, write `pending_route=paywall` to
**both** HomeWidgetPreferences (raw) and FlutterSharedPreferences (`flutter.pending_route`)
so Flutter's `SharedPreferences.getInstance()` (which reads the FlutterSharedPreferences
file with the `flutter.` prefix) can reliably pick it up — this mirrors exactly how
`tapped_widget_id` flows, using the file Flutter actually reads.

**Flutter (`main.dart`):** at startup read `pending_route`; if `paywall`, clear it and pass
`showPaywallOnStart: true` to the app. `_QuoteWidgetAppState.didChangeAppLifecycleState`
on resume also checks + clears `pending_route` (warm start). Opening the sheet: reuse the
existing `WidgetSetupScreen._showUnlockDialog` UX by extracting the paywall bottom sheet
into `lib/widgets/paywall_sheet.dart` (`showPaywallSheet(context, iapService,
rewardedAdService)`) — Watch Ad (24h) / Buy Pro (forever) / Cancel. WidgetSetupScreen
switches to it so there is one paywall UI.

## §6 — UX notes

- `backup_screen.dart`: add a text under the Import section: *"Restore khôi phục
  Collections và cài đặt Widget. Widget đã có trên Home Screen có thể cần cấu hình lại
  thủ công."*
- `QuoteWidgetProvider.kt`: `displayTextColor` — drop `collectionId == null ||` (the
  variable is a non-null `String`), keep `isRemoved`.

## Test plan

- A1 unit: fake provider returns 1 → Free 2nd widget blocked even when Hive box empty;
  returns null → falls back to Hive; Pro bypasses.
- A2 unit: orphaned config (mapped id not in native set) deleted + mapping removed;
  fast path no-op when counts match; reverse no-op.
- A5 unit: paywall sheet opens from `showPaywallOnStart`; pending_route cleared.
- Existing 75 tests unchanged → must stay green.