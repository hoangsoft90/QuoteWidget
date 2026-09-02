# Spec: Rotation Service

## Responsibilities
- Calculate the next item index based on rotation mode
- Handle edge cases: empty collections, single item, collection removed

## Sequential Mode
- Given currentIndex and totalItems, return (currentIndex + 1) % totalItems
- Wraps around: last item → first item
- Preserves currentIndex across app restarts (stored in WidgetConfig)

## Random Mode (MVP)
- Given currentIndex and totalItems, return a random index that is NOT currentIndex
- If totalItems <= 1, return 0 (only one item, no choice)
- Does not guarantee shuffled-array behavior in MVP (that's P1)

## Edge Cases
- Empty collection (totalItems == 0): return -1 (caller should show empty state)
- Single item (totalItems == 1): return 0 (same item, no change)
- Collection removed: return -1 (caller should show "Collection removed" state)
- CurrentItem deleted: caller should find next valid index, not rotation service

## API
- `getNextIndex(currentIndex: int, totalItems: int, mode: RotationMode) -> int`
  - Returns -1 for empty/invalid state
