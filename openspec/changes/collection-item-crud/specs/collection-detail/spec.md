# Spec: Collection Detail Screen

## Layout
- AppBar with collection name (editable), back button
- Body: ListView of items sorted by order
- Each item card: text preview (truncated), edit/delete buttons
- Floating action button: add single item
- Bulk add button in AppBar or as secondary action

## Item CRUD
- Add: tap FAB → dialog with text field → create item with next order value
- Edit: tap item → dialog with text field pre-filled → update item
- Delete: swipe left or tap delete icon → confirm → delete item
- Reorder: long press + drag to reorder (update order values)

## Empty State
- When collection has no items: show "Add some content to this collection." with add button

## Bulk Add
- Tap "Bulk Add" → new screen or dialog with multi-line text field
- Each line becomes one item
- Trim whitespace, skip empty lines
- Show preview of items to be added before confirming
- Create all items with sequential order values

## Navigation
- Back → Home screen
- Item count shown in AppBar subtitle
