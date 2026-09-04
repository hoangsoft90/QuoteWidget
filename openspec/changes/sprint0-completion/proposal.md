# Proposal: Sprint 0 Completion — Graceful Pro-expiry + Quick Share Undo

## What
plan5_final.md Sprint 0 = Sprint A (already merged, commit `54f5c7d`) + 2 additions
from the plan5 review round (§1.6 Graceful Pro-expiry, §1.7 Quick Share Undo).
This change implements those 2 remaining code tasks. Device testing (§1.8) stays
a manual gate — it cannot run in this environment.

## Why
- **§1.6 Graceful Pro-expiry:** today `QuoteWidgetProvider.updateAppWidget()` renders
  a configured widget's content unconditionally. When the 24h rewarded-ad pass
  expires, a 2nd configured widget either keeps showing stale content (silent
  free-ride) or, on re-render, has no defined state — the plan requires a clear
  "24h Pass Expired — Tap to renew" prompt that deep-links to the paywall so the
  user can re-unlock in one tap.
- **§1.7 Quick Share Undo:** the share flow saves directly into Hive (by design —
  no staging area) but the confirmation is a passive Toast. If a share lands in
  the wrong collection or was accidental, the only recovery is manual deletion.
  The plan requires an Undo/Change action on the confirmation that expires after
  ~10–15s. Bonus: the multi-collection share path calls `showDialog` with the
  app-level context (above MaterialApp's Navigator) — a latent crash whenever a
  user with >1 collection shares content; fixing it is in-scope because the share
  flow is being touched anyway.

## Scope
- §1.6: Kotlin only — `isExpiredLocked()` + shared `showLockedPrompt()` in
  `QuoteWidgetProvider.kt`. The oldest (smallest appWidgetId) configured widget
  stays usable as the Free slot; extras beyond `FREE_WIDGET_LIMIT` show
  "24h Pass Expired\nTap to renew" with `route=paywall` (existing A-5 deep link).
- §1.7: Flutter — `ShareService.saveToCollection` returns the created `Item`
  (null on failure); `_handlePendingShare` shows a 10s SnackBar with an **Undo**
  action (soft-delete → Trash + widget refresh); `showDialog` for the picker uses
  the navigator-key context (fixes the latent crash).

## Non-goals
- Sprint 1/2/3 (plan5 §2–§4) — hard-gated behind device testing (§1.8).
- Changing the share staging flow (still saves directly to Hive).
- Changing the free-limit policy, prefs files, or the rewarded-ad model.

## Success Criteria
- After the 24h pass expires, a 2nd configured widget re-renders as
  "24h Pass Expired — Tap to renew" (tap → paywall sheet), while the first
  configured widget keeps working. Re-unlocking restores both.
- Sharing text saves as before, and the confirmation offers Undo for ~10s;
  Undo removes the just-saved item and refreshes affected widgets.
- Multi-collection share no longer risks the app-level-context dialog crash.
- All existing tests pass; new tests cover §1.7 (ShareService return + widget
  flow). `flutter analyze` exit 0; CI debug + release builds green.