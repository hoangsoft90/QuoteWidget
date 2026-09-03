# Spec: Pro-state widget refresh

## Widget push on Pro change
- Whenever `IapService` persists a Pro state change (24h unlock, permanent purchase,
  restore, legacy migration) it calls `HomeWidget.updateWidget` for
  `QuoteWidgetProvider` after writing `is_pro` / `is_pro_expires_at`, so Kotlin
  re-renders (placeholder → "Tap to set up") without user action.
- The widget push is best-effort: it must never break persistence when no widget host
  exists (e.g. unit tests).

## Async-safe purchase grant
- Purchase/restore grants set in-memory Pro first, then `await` persistence, then
  complete the pending purchase. Persistence or completion errors are tolerated and
  never break the purchase stream.
- Unlock flows started from a widget-limit dialog auto-retry the widget setup once Pro
  is active (both the "Watch Ad" and "Remove Ads Forever" paths).

## Persistence contract (unchanged)
- Pro state keeps flowing through the existing keys/files: `iap_pro_purchased`,
  `iap_pro_expires_at` + mirror `is_pro` / `is_pro_expires_at` in Flutter
  SharedPreferences, and HomeWidgetPreferences via `saveWidgetData`. No new
  SharedPreferences files are introduced.
