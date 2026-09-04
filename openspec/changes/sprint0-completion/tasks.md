# Tasks: Sprint 0 Completion — Graceful Pro-expiry + Quick Share Undo

## §1.6 — Graceful Pro-expiry on widget (Kotlin)
- [x] `isExpiredLocked(context, appWidgetId)`: `!isProActive && configured count > FREE_WIDGET_LIMIT && widget is configured && widget != oldest id` — QuoteWidgetProvider.kt `isExpiredLocked()`
- [x] `updateAppWidget()` renders "24h Pass Expired\nTap to renew" (route=paywall) for locked widgets instead of content — QuoteWidgetProvider.kt updateAppWidget() top guard
- [x] Refactor `showUpgradePrompt()` → shared `showLockedPrompt(message)`; onUpdate keeps its "Upgrade to Pro" text — QuoteWidgetProvider.kt

## §1.7 — Quick Share Undo (Flutter)
- [x] `ShareService.saveToCollection` returns created `Item?` (null on failure) — share_service.dart
- [x] `_handlePendingShare`: 10s SnackBar "Saved to X" with **Undo** action → soft-delete item + `updateWidgetsForCollection` — main.dart + lib/widgets/share_undo_snackbar.dart (extracted helper)
- [x] Multi-collection `showDialog` uses navigator-key context (fixes app-level-context crash above MaterialApp) — main.dart

## Tests
- [x] `test/share_service_test.dart`: 4 tests — saveToCollection returns Item / appends order / delete-to-Trash (Undo path) / processShareText — PASS
- [x] `test/quick_share_undo_test.dart`: 3 widget tests — "Saved to X" + Undo shown / tapping Undo fires onUndo + "Share removed" / 10s expiry contract — PASS

## Verify
- [x] `flutter analyze` exit 0 — "No issues found!"
- [x] `flutter test` all pass — **91/91** (84 baseline + 4 share_service + 3 quick_share_undo)
- [x] Commit + push → CI debug + release green — run **33857086225** (commit `7eed09c`) completed success
- [ ] Device-test checklist (§1.8) — **manual gate, cannot run in this env**