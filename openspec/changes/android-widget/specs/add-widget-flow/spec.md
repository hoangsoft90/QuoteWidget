# Spec: Add Widget Flow

## Primary Path: requestPinAppWidget
- Check `AppWidgetManager.isRequestPinAppWidgetSupported()`
- If supported: call `requestPinAppWidget()` → system shows "Add to Home Screen?" dialog
- User confirms → widget added automatically
- This works on Pixel/stock Android, some Samsung devices

## Fallback: OEM-Specific Guide
- If requestPinAppWidget not supported: show guided instructions
- Detect device manufacturer using `device_info_plus` or Build.MANUFACTURER
- Show appropriate instructions with illustrations:

### Pixel/Stock Android
- "Long press on home screen → Widgets → Find Your Words → Drag to home screen"

### Samsung One UI
- "Long press on home screen → Widgets → Find Your Words → Add"

### Xiaomi MIUI
- "Long press on home screen → Add widgets → Find Your Words → Tap to add"

### Generic (other OEMs)
- "Long press on home screen → Widgets → Find Your Words"

## UX Goal
- First widget added within 60 seconds of first app open
- Guide screen should be simple, visual, and scannable
- Include "I've added the widget" button to proceed to main app

## Implementation
- Create `AddWidgetGuideScreen` with device-specific instructions
- Use `device_info_plus` to detect manufacturer
- Include images/illustrations for each OEM guide
- Provide "Open Widget Picker" button where possible (deep link to widget picker)
