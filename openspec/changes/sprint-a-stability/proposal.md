# Proposal: Sprint A — Widget Registry / Free-limit Stability

## What
Sprint A (Stability) from plan4_final.md: make the widget free-limit gate and the
Hive↔Android widget registry consistent and reliable before any UI work (Sprint B).

## Why
Two independent free-limit gates read from two different sources with no sync:
- `StorageService.createWidgetConfig()` gates purely on `_widgetConfigsBox.isNotEmpty` (Hive).
- `QuoteWidgetProvider.onUpdate()` gates on native `configured_widget_ids` (a set Kotlin
  manages itself).

Because they can diverge, a Free user can hit a **dead-end trap**: delete a collection
that Widget A is attached to → Hive config is removed (box empty) → Flutter lets the user
configure Widget B and says "success" — but native `configured_widget_ids` still contains
A (it was never removed from the Home Screen), so `onUpdate()` shows "Upgrade to Pro"
on B **forever**. This is worse than a bypass: the user followed the UI, saw success, and
the widget never works (1-star "app is a scam" reviews).

Additional stability gaps verified in code:
- `wcfg_*` mapping keys are never cleaned when a widget is physically removed
  (`onDeleted()` only clears `widget_<id>_*` + `configured_widget_ids`).
- No `PREFS_VERSION`/migration hook exists, so the first key-format change will corrupt
  installed user data with no recovery path.
- `showUpgradePrompt()` opens MainActivity with no route — users hitting the Pro wall on
  the widget cannot reach the paywall sheet.

## Scope
- A1: Free-limit gate uses the **native** `configured_widget_ids` count (via a new
  MethodChannel `getConfiguredWidgetCount()`), with Hive as fallback when the channel is
  unavailable (tests, non-Android), instead of trusting the Hive box alone.
- A2: Hybrid reconciliation on app open/resume: compare Hive `WidgetConfig` count with the
  native count; on mismatch, do a full scan and remove orphaned `WidgetConfig` rows (Hive
  has a config but native no longer has the mapped `appWidgetId`), and vice versa.
- A3: `QuoteWidgetProvider.onDeleted()` cleans `wcfg_<appWidgetId>_configId` /
  `wcfg_<configId>_appWidgetId` (both directions) in Kotlin directly — no Dart round-trip.
- A4: `PREFS_VERSION` + `migratePreferences()` skeleton in `QuoteWidgetProvider.kt`,
  checked once per update cycle.
- A5: `showUpgradePrompt()` adds `route=paywall` extra; Flutter reads it on cold start and
  on resume and opens the existing paywall bottom sheet (Watch Ad 24h / Buy Pro / Cancel).
- §6: Backup screen restore-semantics text; remove dead `collectionId == null` condition
  in `QuoteWidgetProvider.kt` (the variable is a non-null `String`).

## Non-goals
- Sprint B (Widget Gallery, Quick Editor, Search, Favorites) — gated behind device tests.
- Sprint C (Daily Item, WorkManager rotation, Duplicate Collection, Export) — later.
- Sprint D (Share as Image) — later.
- Changing the free-limit policy itself (still 1 widget on Free).
- Changing which prefs files are used (HomeWidgetPreferences vs FlutterSharedPreferences
  rules stay as documented).

## Success Criteria
- A Free user who deletes the collection of their only configured widget is **blocked**
  from configuring a 2nd widget (no more dead-end "configured but shows Upgrade" state).
- A Pro user (24h or permanent) can still add unlimited widgets.
- Removing a widget from the Home Screen clears its `wcfg_*` mapping in both directions.
- App start/resume reconciles Hive ↔ native and removes orphaned configs.
- Tapping "Upgrade to Pro" on a native widget opens the app's paywall bottom sheet.
- All 75 existing tests still pass; new unit tests cover A1/A2/A5.
- `flutter analyze` exit 0; CI debug + release builds green.