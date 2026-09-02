# Tasks: Collection & Item CRUD

## Task 1: Create Home Screen
- Create `lib/screens/home_screen.dart`
- Implement AppBar with title "Your Words"
- Implement ListView of collection cards
- Implement FAB for creating new collection
- Implement create collection dialog
- Implement delete collection with confirmation dialog
- Add empty state for no collections

## Task 2: Create Collection Detail Screen
- Create `lib/screens/collection_detail_screen.dart`
- Implement AppBar with collection name and item count
- Implement ListView of items
- Implement add item dialog
- Implement edit item dialog
- Implement delete item with confirmation
- Implement empty state for no items

## Task 3: Implement Item Reorder
- Add ReorderableListView to collection detail screen
- Implement onReorder callback
- Update item order values in StorageService
- Persist reorder immediately

## Task 4: Create Bulk Add Screen
- Create `lib/screens/bulk_add_screen.dart`
- Implement multi-line text input field
- Implement text processing (split, trim, skip empty)
- Implement preview list of items to add
- Implement confirm/cancel actions
- Create items with sequential order values

## Task 5: Set Up Navigation
- Configure routes in main.dart
- Implement Navigator.push for screen transitions
- Pass collectionId as route arguments
- Handle back navigation properly

## Task 6: Polish UI
- Add consistent theming (colors, typography)
- Add loading states for async operations
- Add error handling with user-friendly messages
- Add haptic feedback for reorder (optional)
- Test on different screen sizes
