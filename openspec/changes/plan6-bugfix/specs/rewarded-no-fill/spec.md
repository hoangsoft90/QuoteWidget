# Rewarded ad no-fill handling (H2)

## Requirements

- `RewardedAdService` exposes load-failure state so UI can distinguish
  "ad finished but user dismissed" from "no ad available" (load error,
  no-fill, show error, timeout).
- Paywall sheet and Settings "Watch Ad" flow: when no ad is available →
  show dialog: "Không có quảng cáo lúc này. Vui lòng thử lại sau ít phút."
  with a **Retry** button (retries the flow) and a dismiss action.
- No silent hang, no dead-end: user always gets a clear outcome.
- NO free-fallback unlock (1x/day) added in this change — explicitly deferred
  until real ad data exists.

## Behavior matrix

| Ad outcome | UI |
|---|---|
| watched to end + persisted | Pro unlocked (existing snackbar) |
| dismissed early | existing "Ad not finished" snackbar |
| load failed / no-fill / show error / timeout | no-ad dialog + Retry |