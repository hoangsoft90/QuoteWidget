# Proposal: Pro unlock reliability (plan3_final Fix A/B/C)

## What
Make the three Pro-unlock paths (rewarded-ad 24h, IAP Remove Ads Forever, Restore)
atomic and visible: a grant is only reported as success after it has been persisted,
the native widget is pushed to refresh whenever the Pro state changes, and IAP
grant/completion handling is async-safe.

## Why
`plan3_final.md` (`.plan/plan3_final.md`) verified three open defects in the current
source:

1. **Fix A (HIGH)** — `lib/services/rewarded_ad_service.dart:94` calls
   `iapService.unlockProFor24h()` inside the reward callback **without `await`** and
   reports the grant before persistence finishes. If the app is killed right after the
   ad closes, the user watched a full ad but stays locked.
2. **Fix B (MEDIUM)** — `IapService._persist()` writes `is_pro`/`is_pro_expires_at`
   via `saveWidgetData` but never calls `HomeWidget.updateWidget`, so unlocking from
   Settings (watch-ad / buy / restore) leaves an existing 2nd-widget "Upgrade to Pro"
   placeholder stale until some unrelated update.
3. **Fix C (LOW-MEDIUM)** — `IapService._onPurchaseUpdate` fires `_persist()` and
   `completePurchase` without awaiting or error tolerance; and the widget-limit dialog's
   "Remove Ads Forever" branch does not auto-retry the widget setup once Pro is granted.

## Scope
- Rewarded-ad grant outcome gated on successful 24h unlock persistence.
- `HomeWidget.updateWidget` push after any Pro state persist (Kotlin re-evaluates
  limit/placeholder via existing `onUpdate` logic — no Kotlin change needed).
- Async-safe purchase grant + completion order in `IapService`.
- Auto-retry widget setup after "Remove Ads Forever" completes in
  `widget_setup_screen.dart`.
- Unit tests for the reward outcome gate (fake IapService) and for the widget push
  (mocked `home_widget` channel).

## Non-goals
- No new monetization features (photo background, custom fonts, iOS widget, cloud sync).
- No new/changed SharedPreferences files or keys — Pro state keeps flowing through
  `IapService._persist()` (HomeWidgetPreferences via `saveWidgetData`; supplementary
  `is_pro`/`is_pro_expires_at` mirror keys).
- No Android/Kotlin or version-matrix changes (AGP 8.11.1 / Gradle 8.14.3 / Kotlin
  2.2.20 / targetSdk 36 stay pinned).
- No local APK builds — verification via GH Actions only.

## Success Criteria
- Reward success is only reported after `unlockProFor24h()` persistence completes;
  a persistence failure reports `false` (no fake grant).
- Unlocking (any path) triggers `HomeWidget.updateWidget`, so a stale native
  "Upgrade to Pro" placeholder refreshes without user action.
- `_onPurchaseUpdate` awaits persist before completing the purchase and tolerates
  errors without breaking the purchase stream.
- `flutter analyze`: 0 errors, 0 warnings (exit code checked). `flutter test`: all
  tests pass (baseline 71 + new ones).
- CI (GitHub Actions, debug + release) green.
