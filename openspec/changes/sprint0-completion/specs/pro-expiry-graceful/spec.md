# Spec: Graceful Pro-expiry on widget

## Behavior

When a widget instance is re-rendered by `QuoteWidgetProvider` (onUpdate, options
changed, app-initiated update, tap), it shows the state below:

| Condition | Display |
|---|---|
| Pro active (24h within window / permanent) | Normal content |
| Free, configured widgets ≤ `FREE_WIDGET_LIMIT` (1) | Normal content |
| Free, configured widgets > 1 AND this widget is the oldest (smallest appWidgetId) | Normal content — stays the Free slot |
| Free, configured widgets > 1 AND this widget is NOT the oldest | `24h Pass Expired\nTap to renew` (gray prompt, no progress), tap → `route=paywall` deep link → paywall bottom sheet |
| Unconfigured + Free limit reached | `Upgrade to Pro\nto add more widgets` (unchanged A-5 prompt) |

## Rules

- Lock decision re-evaluates on every render — re-unlocking (rewarded ad) restores
  content without any app restart.
- The expired prompt reuses the existing `route=paywall` deep-link machinery
  (MainActivity persists `pending_route`; Flutter opens the paywall sheet) — no
  new channels.
- Tap-to-cycle (`WIDGET_TAP`) is unreachable on a locked widget because its click
  intent is the paywall activity, not the tap broadcast.

## Keys / files

No new prefs keys. Reads `is_pro`, `is_pro_expires_at`, `configured_widget_ids`
from the existing HomeWidgetPreferences/FlutterSharedPreferences convention.