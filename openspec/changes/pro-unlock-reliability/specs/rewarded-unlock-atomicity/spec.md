# Spec: Rewarded unlock atomicity

## Grant reporting
- `RewardedAdService.showRewardedAd()` returns `true` only when the user watched the ad
  to the end AND the 24h Pro unlock has been persisted successfully.
- A persistence failure (exception from `IapService.unlockProFor24h()`) reports
  `false` — the caller must not be told Pro was granted when it was not saved.
- If the ad was not watched to completion, no unlock attempt is made and the result is
  `false`.

## Callback wiring
- `onUserEarnedReward` only records that a reward was earned; it does not fire the grant.
- The grant is awaited in the ad-dismissed path before the result is completed.
- `onAdFailedToShowFullScreenContent` reports `false` without attempting a grant.
- The 120s safety timeout routes through the same persisted-grant logic when a reward
  was earned (never reports `true` without a persisted unlock).

## Testability
- The outcome decision ("rewarded AND persisted") lives in a seam that is unit-testable
  with a fake `IapService` — no platform ad instance required.
