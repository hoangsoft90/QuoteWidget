# Tasks: Android Native Widget

## Task 1: Set Up Android Widget Infrastructure
- Create widget provider info XML (minWidth, minHeight, resizeMode, preview)
- Create small widget layout XML (RemoteViews-compatible)
- Create medium widget layout XML (RemoteViews-compatible)
- Register widget provider in AndroidManifest.xml
- Add necessary Android permissions (no INTERNET)

## Task 2: Implement WidgetProvider
- Create `QuoteWidgetProvider.kt` extending AppWidgetProvider
- Implement `onUpdate()` to build and display RemoteViews
- Implement `onReceive()` to handle tap actions
- Read widget state from SharedPreferences
- Build RemoteViews with correct text and styling

## Task 3: Implement Tap Cycling
- Create `WidgetReceiver.kt` BroadcastReceiver
- Handle tap Intent: read currentIndex, collectionId, rotationMode
- Calculate next index using rotation logic
- Update SharedPreferences with new currentIndex
- Rebuild RemoteViews and update widget

## Task 4: Implement Widget State Management
- Create `WidgetData.kt` helper class
- Implement read/write for widget state (currentIndex, collectionId, rotationMode)
- Handle widget instance isolation (different keys per widget ID)
- Implement empty state and "collection removed" state

## Task 5: Create WidgetService (Flutter Side)
- Create `lib/services/widget_service.dart`
- Implement data sync from Hive to SharedPreferences via home_widget
- Implement `updateWidget()` to trigger widget refresh
- Implement `addWidget()` to call requestPinAppWidget
- Handle widget configuration updates

## Task 6: Implement Add Widget Flow
- Create `lib/screens/add_widget_guide_screen.dart`
- Detect device manufacturer using device_info_plus
- Show OEM-specific instructions with illustrations
- Implement "I've added the widget" button
- Implement deep link to widget picker where possible

## Task 7: Handle Widget States
- Implement empty collection state: "Add some content to this collection."
- Implement collection removed state: "Collection removed" + CTA
- Implement no collection assigned state: "Tap to set up this widget"
- Ensure widget updates when data changes in app

## Task 8: Test Widget Behavior
- Test tap cycling on Android emulator
- Test multiple widget instances (independent currentIndex)
- Test widget survival after force-stop
- Test widget survival after reboot
- Test widget update when data changes
- Test empty and error states
