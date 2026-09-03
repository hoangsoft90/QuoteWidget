# Tasks: Pro unlock reliability

## Task 1: OpenSpec scaffolding
- [x] Create `openspec/changes/pro-unlock-reliability/` with `.openspec.yaml`,
  `proposal.md`, `design.md`, `tasks.md`, delta specs.

## Task 2: Fix A — reward grant is persisted before success is reported
- [x] `lib/services/rewarded_ad_service.dart`: instance method `resolveRewardOutcome`
  awaits `iapService.unlockProFor24h()` under try/catch; true only when rewarded AND
  persisted (lines 108–124).
- [x] Rewire: `onUserEarnedReward` sets `rewardGranted` only; dismiss + timeout paths
  complete via `await resolveRewardOutcome(...)`; failed-to-show completes `false`.
- [x] `test/rewarded_ad_service_test.dart` (new, 3 tests): fake `IapService` — no reward
  → false + unlock not called; reward + ok → true; reward + persist throws → false.
- Evidence: `flutter test test/rewarded_ad_service_test.dart` → `+3: All tests passed!`;
  baseline run of the same file pre-fix → compile error (red).

## Task 3: Fix B — push widget update when Pro state persists
- [x] `lib/services/iap_service.dart` `_persist()`: `HomeWidget.updateWidget` for
  `QuoteWidgetProvider` after the `saveWidgetData` writes, inside the best-effort block.
- [x] `test/iap_service_test.dart`: channel-mock test asserts `updateWidget` is invoked
  AFTER the `is_pro` write (order verified via recorded calls).
- Evidence: `flutter test test/iap_service_test.dart` → `+7: All tests passed!`
  (incl. restored legacy Permanent-Pro test that a mid-edit accidentally dropped —
  caught by the count check, git-diff verified).

## Task 4: Fix C — async-safe IAP grant + buy-path auto retry
- [x] `lib/services/iap_service.dart` `_onPurchaseUpdate` → async: grant memory →
  `await _persist()` (tolerated) → `await completePurchase` when pending (tolerated).
- [x] `lib/screens/widget_setup_screen.dart` `_showUnlockDialog` 'buy' branch: when
  `iapService.isPro` after `buyPro()`, success snackbar + auto `_save()` retry.
- Evidence: code lines above; full suite + widget-limit tests green.

## Task 5: Full verification (no verbal pass — run and show)
- [x] `flutter analyze` → exit 0, "No issues found!".
- [x] `flutter test` → `+75: All tests passed!` (71 baseline + 3 Fix A + 1 Fix B;
  per-file sum agrees: 4+7+6+3+11+23+9+11+1 = 75).
- [ ] Push to `main`; GH Actions run (analyze + test + debug build + release build)
  green — read real logs.
- [ ] Update `working.md` with task results + CI run id.
