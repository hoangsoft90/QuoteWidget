# Spec: Widget Provider

## Widget Provider Info XML
- minWidth/minHeight for small (2x1 cells) and medium (4x1 cells)
- resizeMode: none (fixed sizes only, no free resize)
- previewLayout: reference to preview image
- updatePeriodMillis: 0 (manual updates only, not periodic)

## RemoteViews Layouts
- **Small widget**: Single text view, centered, no author line
- **Medium widget**: Text view + optional author/attribution line below
- Both layouts use RemoteViews-compatible views only (TextView, LinearLayout, etc.)

## Widget Update Mechanism
- On data change in app: call HomeWidget.saveWidgetData() → trigger widget update
- On tap: BroadcastReceiver receives intent → calculate next index → update widget data → update RemoteViews
- Widget reads currentIndex from SharedPreferences (via home_widget plugin)

## States
- **Normal**: displays item text (and optional author for medium size)
- **Empty collection**: "Add some content to this collection."
- **Collection removed**: "Collection removed" + "Tap to choose another collection"
- **No collection assigned**: "Tap to set up this widget"

## Persistence
- currentIndex stored per widget instance in SharedPreferences
- Key format: `widget_<widgetId>_currentIndex`
- collectionId stored per widget instance: `widget_<widgetId>_collectionId`
