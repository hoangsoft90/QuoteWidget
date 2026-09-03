# Project Context — Quote Widget

## Overview

**Quote Widget** is a Flutter mobile app that displays user-selected quotes/reminders on Android Home Screen widgets. Users create collections of text items, configure widgets to show them, and cycle through items by tapping the widget.

**Core value proposition:** Personal content on your Home Screen — quotes, affirmations, notes, reminders — offline-first, no cloud, no data collection.

## Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| Framework | Flutter | SDK ^3.33 |
| Language | Dart | ^3.13.1 |
| Local DB | Hive | ^2.2.3 |
| Widget Bridge | home_widget | ^0.7.0 |
| State Management | None (setState) | — |
| Routing | Navigator 1.0 (imperative) | — |
| IAP | in_app_purchase | ^3.2.1 |
| Sharing | share_plus | ^10.1.4 |
| Platform | Android only (no iOS) | minSdk 24, targetSdk latest |

## App Identity

- **Package:** `com.quotewidget.quotewidget`
- **App name:** "Quote Widget - Your Words"
- **Version:** 1.0.0+1

## Architecture

**Pattern:** Service-oriented (no formal pattern like BLoC/Riverpod).

```
lib/
├── main.dart                    # Entry point, service init, routing
├── models/                      # Hive data models
│   ├── collection_model.dart    # Collection (id, name, createdAt)
│   ├── item_model.dart          # Item (id, collectionId, text, order, createdAt)
│   ├── widget_config_model.dart # WidgetConfig + AppearanceConfig + enums
│   └── backup_data.dart         # BackupData wrapper for export/import
├── services/                    # Business logic
│   ├── storage_service.dart     # Hive CRUD for all models
│   ├── widget_service.dart      # Sync data to SharedPreferences for Kotlin
│   ├── widget_data_bridge.dart  # SharedPreferences bridge + mapping
│   ├── rotation_service.dart    # Sequential/random item cycling
│   ├── backup_service.dart      # JSON export/import (Append/Overwrite)
│   ├── snapshot_manager.dart    # Safety snapshots before destructive ops
│   ├── sample_data_service.dart # Onboarding sample data
│   ├── share_service.dart       # Handle share intents
│   └── iap_service.dart         # In-app purchase (Restore only)
├── screens/                     # UI screens
│   ├── home_screen.dart         # Collection list + FAB
│   ├── collection_detail_screen.dart # Items in collection + progress
│   ├── bulk_add_screen.dart     # Add multiple items at once
│   ├── widget_config_screen.dart # Customize widget appearance (dead code)
│   ├── widget_setup_screen.dart # First-time widget setup (deep link target)
│   ├── onboarding_screen.dart   # Welcome screen
│   ├── onboarding_create_collection_screen.dart # Step 1
│   ├── onboarding_add_item_screen.dart # Step 2
│   ├── add_widget_guide_screen.dart # Step 3 (Android widget guide)
│   ├── backup_screen.dart       # Backup/Restore UI
│   ├── settings_screen.dart     # Settings + Restore Purchases
│   └── collection_picker_dialog.dart # Dialog to pick a collection
├── widgets/                     # Reusable widgets
│   ├── onboarding_progress.dart # 3-step progress indicator
│   ├── widget_preview.dart      # Widget preview in config screen
│   └── quote_card.dart          # Quote display card
└── android/                     # Native Android code
    └── app/src/main/kotlin/com/quotewidget/quotewidget/
        ├── MainActivity.kt      # FlutterActivity + onNewIntent()
        └── widget/
            └── QuoteWidgetProvider.kt # AppWidgetProvider (330 lines)
```

## Data Flow

```
User creates Collection + Items (Flutter UI)
    ↓
StorageService (Hive) — persists to local boxes
    ↓
WidgetService.syncWidgetData() — writes to SharedPreferences via HomeWidget.saveWidgetData()
    ↓
HomeWidget.updateWidget() — triggers Kotlin onUpdate()
    ↓
QuoteWidgetProvider.kt — reads SharedPreferences, builds RemoteViews
    ↓
Android Home Screen — displays widget
```

## SharedPreferences Files (Critical)

| File | Written by | Read by | Contains |
|------|-----------|---------|----------|
| `HomeWidgetPreferences` | Flutter (HomeWidget.saveWidgetData) | Kotlin (getPrefs) | Widget data: collectionId, text, currentIndex, totalItems, etc. |
| `FlutterSharedPreferences` | Kotlin (saveConfiguredWidgetId, onDeleted) | Kotlin (getFlutterPrefs) | Supplementary: configured_widget_ids, is_pro |
| Default SharedPreferences | — | — | NOT USED (was a bug, now fixed) |

## Key Business Rules

- Free tier: unlimited items + 1 widget
- Pro tier: unlimited widgets (24h rewarded-ad unlock + one-time IAP "Remove Ads Forever")
- INTERNET permission present (google_mobile_ads — rewarded/banner/interstitial);
  cleartext http allowed via res/xml/network_security_config.xml (some http links)
- No data collection, no cloud sync; ads serve non-personalized (npa=1)
- Safety snapshot before destructive operations (cascade-delete, overwrite restore)
