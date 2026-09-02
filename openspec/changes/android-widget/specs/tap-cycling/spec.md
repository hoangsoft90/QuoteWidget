# Spec: Tap Cycling

## Behavior
- Tap widget → calculate next index based on rotation mode
- Update currentIndex in SharedPreferences
- Refresh widget RemoteViews with new item text
- Do NOT open app on tap (Android only)

## Sequential Mode
- nextIndex = (currentIndex + 1) % totalItems
- Wraps around from last to first

## Random Mode (MVP)
- Pick random index from 0 to totalItems-1
- Exclude currentIndex (don't show same item twice in a row)
- If totalItems <= 1, stay at index 0

## Widget Update Flow
1. Tap detected by BroadcastReceiver
2. Read currentIndex, collectionId, rotationMode from SharedPreferences
3. Load items from Hive for this collection
4. Calculate next index using RotationService logic
5. Write new currentIndex to SharedPreferences
6. Build RemoteViews with new item text
7. Update widget via AppWidgetManager

## Edge Cases
- Empty collection → show empty state, no index change
- Collection deleted → show "Collection removed" state
- Current item deleted → find next valid index (don't crash)
- Widget force-stopped → recreated by system, reads state from SharedPreferences
