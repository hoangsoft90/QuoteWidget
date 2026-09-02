# Proposal: Android Native Widget

## What
Implement the Android home screen widget using RemoteViews XML. This includes the widget provider, tap-to-cycle behavior, multiple widget sizes (small/medium), and the add-widget flow with OEM-specific fallbacks.

## Why
The widget is the core value proposition of the app. Users create content specifically to display it on their home screen. Without a working widget, the app has no purpose.

## Scope
- Android widget provider (RemoteViews XML)
- Widget layouts for small and medium sizes
- Tap-to-cycle behavior (Sequential and Random modes)
- Per-widget currentIndex persistence via home_widget
- Add Widget flow: requestPinAppWidget() + OEM-specific fallback guide
- Widget update mechanism (app changes → widget refresh)
- Empty state and "collection removed" state for widget

## Non-goals
- Widget customization UI (covered in widget-customization change)
- iOS WidgetKit (covered in later priority)
- Daily Reset via WorkManager (P1 feature)

## Success Criteria
- Widget renders correct text on home screen
- Tap changes to next item without opening app
- Widget survives force-stop and device reboot
- Multiple widget instances work independently
- Empty collection shows "Add some content" message
- Deleted collection shows "Collection removed" with CTA
- Add Widget flow works on Pixel/Samsung/Xiaomi
- Widget updates when data changes in app
