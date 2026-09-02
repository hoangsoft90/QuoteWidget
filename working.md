# Working Log — Quote Widget

## Current Status

**Phase:** Pre-release (6 rounds of code review/fix complete)
**Next:** Build APK + real device testing (21 test cases)
**Blocker:** None — code is ready for device testing

## Recent Activity

### [2026-09-02] Round 6 — Empty Collection Fix + Warm-start Deep Link
- Fixed empty collection dead-end (PendingIntent.getActivity → CollectionDetailScreen)
- Added onNewIntent() to MainActivity for warm-start deep link
- Added WidgetsBindingObserver fallback for warm-start navigation
- Updated PendingIntent summary table (3/5 states open app)

### [2026-09-02] Round 5 — Tap-to-Configure Deep Link
- Fixed PendingIntent for unconfigured widgets (was handleTap → now getActivity)
- Created WidgetSetupScreen (collection picker for first-time setup)
- Added deep link: tapped_widget_id → SharedPreferences → Flutter routing

### [2026-09-02] Round 4 — SharedPreferences Mismatch + onDeleted
- Fixed SharedPreferences file mismatch (HomeWidgetPreferences vs FlutterSharedPreferences)
- Added onDeleted() handler to clean up configured widget IDs
- Removed Pro auto-configure (all widgets start with "Tap to set up")
- Added appWidgetId↔configId mapping table
- Fixed markCollectionRemoved appWidgetId=0 bug

### [2026-09-02] Round 3 — Widget Limit Deep Dive
- Confirmed createWidgetConfig() never called from Android system picker
- Implemented Approach A: block at Kotlin onUpdate()
- Added SharedPreferences bridge (WidgetDataBridge)
- Fixed flaky _generateId() in all 3 models (atomic counter)

### [2026-09-02] Round 2 — H-series Fixes
- H1: Progress indicator n/total (showProgress field + widget XML)
- H2: Onboarding "Add Your Own" guided flow (3 steps)
- H3: Sample content rewritten (no celebrity quotes)
- H4: Share sheet hardened (.commit() instead of .apply())
- H5: Free tier 1-widget limit enforcement

### [2026-09-02] Round 1 — C-series + M-series Fixes
- C1: totalItems not written to SharedPreferences
- C2: DropdownButtonFormField (initialValue correct for this SDK)
- C3: ShareReceiverActivity package name mismatch
- C4: Safety snapshot before cascade-delete
- C5: Restore Purchases + Privacy Policy
- M1: collection.name[0] crash, __COLLECTION_REMOVED__ sentinel, onboarding progress

## Test Status

```
44/44 tests pass (0 errors, 0 warnings)
├── widget_limit_test.dart: 11 tests (widget limit, SharedPreferences bridge)
├── storage_service_test.dart: 21 tests (CRUD, cascade-delete, backup/restore)
├── rotation_service_test.dart: 11 tests (sequential, random, edge cases)
└── widget_test.dart: 1 test (app renders)
```

## Known Issues / TODO

- [ ] Build APK and run on real device
- [ ] Run 21 device test cases (B1+B2+B3)
- [ ] Test on Samsung One UI / Xiaomi MIUI
- [ ] Firebase Test Lab for multi-OEM coverage
- [ ] Host privacy.html (GitHub Pages)
- [ ] Configure IAP product ID in store console
- [ ] Actual paywall UI (deferred to P0.5)

## Files Modified (Cumulative)

~35 files modified/created across 6 rounds of review.
