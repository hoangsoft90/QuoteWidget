# CLAUDE.md — Quote Widget

## Project Identity

- **Name:** Quote Widget - Your Words
- **Package:** com.quotewidget.quotewidget
- **Type:** Flutter mobile app (Android only)
- **Purpose:** Display user quotes/reminders on Home Screen widgets

## Quick Reference

| What | Where |
|------|-------|
| Entry point | `lib/main.dart` |
| Data models | `lib/models/` (Collection, Item, WidgetConfig) |
| Services | `lib/services/` (Storage, Widget, Backup, Rotation, IAP, Share) |
| UI screens | `lib/screens/` (12 screens) |
| Reusable widgets | `lib/widgets/` (3 widgets) |
| Android widget | `android/.../widget/QuoteWidgetProvider.kt` |
| Tests | `test/` (44 tests across 4 files) |
| Plan | `plan1_final_v2.md` |

## Tech Stack

- Flutter ^3.33, Dart ^3.13.1
- Hive ^2.2.3 (local DB)
- home_widget ^0.7.0 (widget bridge)
- in_app_purchase ^3.2.1 (IAP)
- Android minSdk=24

## Architecture

Service-oriented, no formal pattern (no BLoC/Riverpod). Services instantiated in main.dart, passed via constructors. setState for UI state.

## Key Files to Read First

1. `context.md` — full project context
2. `working.md` — recent tasks and status
3. `operating_rules.md` — code conventions
4. `lib/main.dart` — app initialization and routing
5. `lib/services/widget_service.dart` — widget data sync
6. `android/.../QuoteWidgetProvider.kt` — native widget logic

## Build & Test

```bash
flutter test          # 44 tests
flutter analyze       # 0 errors, 0 warnings
flutter build apk --release  # Build APK
```

## Current Status

6 rounds of code review/fix complete. Ready for device testing.
See `working.md` for full activity log.
