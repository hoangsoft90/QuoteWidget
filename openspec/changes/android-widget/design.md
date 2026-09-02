# Design: Android Native Widget

## Technology
- **RemoteViews XML** for widget layouts (not Jetpack Glance)
- **home_widget** Flutter package for Flutter ↔ Android bridge
- **BroadcastReceiver** for tap handling
- **SharedPreferences** for per-widget state persistence

## Widget Architecture
```
Flutter App
  ↓ (home_widget plugin)
Android SharedPreferences
  ↓
BroadcastReceiver (tap handler)
  ↓
WidgetProvider (reads state, builds RemoteViews)
  ↓
AppWidgetManager (displays widget)
```

## File Structure
```
android/app/src/main/
├── kotlin/.../widget/
│   ├── QuoteWidgetProvider.kt      # AppWidgetProvider subclass
│   ├── WidgetReceiver.kt           # BroadcastReceiver for taps
│   └── WidgetData.kt               # Helper for reading/writing widget state
├── res/
│   ├── layout/
│   │   ├── widget_small.xml        # Small widget layout
│   │   └── widget_medium.xml       # Medium widget layout
│   └── xml/
│       └── widget_provider_info.xml # Widget metadata
```

## Key Design Decisions
1. **home_widget as bridge**: Flutter writes data to SharedPreferences, Android reads it. This avoids complex Flutter ↔ native method channels.
2. **Per-widget state**: Each widget instance gets its own SharedPreferences keys (prefixed with widget ID). This ensures independent operation.
3. **No periodic updates**: Widget updates are triggered by app events (data change, tap), not by system timer. This saves battery.
4. **Manual RemoteViews building**: Full control over layout and update logic, no abstraction overhead.

## Data Flow for Tap
```
1. User taps widget
2.系统 sends PendingIntent to WidgetReceiver
3. WidgetReceiver reads: currentIndex, collectionId, rotationMode
4. WidgetReceiver loads items from SharedPreferences (synced by Flutter)
5. WidgetReceiver calculates next index
6. WidgetReceiver writes new currentIndex
7. WidgetReceiver builds RemoteViews with new text
8. WidgetReceiver calls AppWidgetManager.updateAppWidget()
```

## Data Flow for App Update
```
1. User adds/edits/deletes item in Flutter app
2. StorageService updates Hive
3. WidgetService syncs data to SharedPreferences via home_widget
4. WidgetService triggers widget update via HomeWidget.updateWidget()
5. WidgetProvider.onUpdate() rebuilds RemoteViews
```
