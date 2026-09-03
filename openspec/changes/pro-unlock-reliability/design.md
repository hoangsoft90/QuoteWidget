# Design: Pro unlock reliability

## Current flow (verified at HEAD 9672108)

```
Reward earned (onUserEarnedReward)
   └─ rewardGranted = true
   └─ iapService.unlockProFor24h();   // NOT awaited → race (Fix A)
Ad dismissed
   └─ completer.complete(rewardGranted)  // true even if persist unfinished
```

`IapService._persist()` writes:
1. default Flutter prefs: `iap_pro_purchased` (bool), `iap_pro_expires_at` (int),
   mirror keys `is_pro` / `is_pro_expires_at` (String) — for the widget bridge;
2. `HomeWidget.saveWidgetData('is_pro' | 'is_pro_expires_at', …)` — native reads these
   from HomeWidgetPreferences;
3. **(Fix B)** — must also `HomeWidget.updateWidget` so Kotlin `onUpdate` re-renders.

No Kotlin change: `QuoteWidgetProvider.onUpdate` already re-reads `is_pro` + expiry on
every update and swaps the "Upgrade to Pro" placeholder for the normal render when Pro
becomes active.

## Fix A — atomic reward grant

- Keep plugin-callback wiring thin: `onUserEarnedReward` only sets `rewardGranted`;
  the grant (unlock + persist) is awaited inside the dismissal path before the
  completer reports success.
- Extract an instance method `resolveRewardOutcome(bool rewarded)` that performs
  `await iapService.unlockProFor24h()` under try/catch and returns `rewarded &&
  persistOk`. It is directly unit-testable with a fake `IapService` subclass (no
  platform ad instance required).
- `onAdDismissedFullScreenContent` and the 120s timeout net both route through it, so a
  dismissed ad never reports `true` unless the 24h unlock is on disk.
- `onAdFailedToShowFullScreenContent` keeps reporting `false` (nothing was granted).

## Fix B — widget push on Pro change

- Append to `IapService._persist()` (inside the existing best-effort try/catch block):
  `await HomeWidget.updateWidget(name: 'QuoteWidgetProvider', androidName: 'QuoteWidgetProvider')`.
- Covered by all persist call sites automatically: `unlockProFor24h`, purchase grant,
  legacy migration in `init()` (no-op safe when no widget exists).
- Test: mock the `home_widget` MethodChannel in a test, call `unlockProFor24h()`, assert
  an `updateWidget` invocation happened after the `saveWidgetData` writes.

## Fix C — async-safe IAP grant + buy-path auto retry

- `_onPurchaseUpdate` becomes async: grant memory state → `await _persist()` (errors
  tolerated, memory already granted) → `await completePurchase` only when pending
  (errors tolerated). Purchase stream callback accepts a `Future<void>` function.
- `widget_setup_screen._showUnlockDialog` 'buy' branch: after `buyPro()`, if
  `iapService.isPro` (grant already applied via stream), show a success snackbar and
  call `_save()` again — same auto-retry the 'ad' branch already has.

## Testability notes

- `RewardedAd` cannot be constructed in pure unit tests (plugin `instanceManager`
  requires the platform channel) → the outcome gate is a small seam; the plugin
  callback wiring is left thin and is exercised on-device/CI.
- `home_widget` exposes no platform instance to swap → use
  `TestDefaultBinaryMessengerBinding` `setMockMethodCallHandler` on channel
  `home_widget`.
