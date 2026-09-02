# Design: Collection & Item CRUD

## Screen Architecture
- **HomeScreen**: StatefulWidget, uses StorageService to load collections
- **CollectionDetailScreen**: StatefulWidget, receives collectionId, loads items
- **BulkAddScreen**: StatefulWidget, receives collectionId, handles text input

## State Management
- Use StatefulWidget with setState for simplicity (no need for Provider/Riverpod at MVP)
- Services injected via constructor or service locator
- Each screen manages its own loading/error states

## UI Components
- **CollectionCard**: ListTile with name, item count, created date
- **ItemCard**: ListTile with text preview, edit/delete actions
- **BulkAddPreview**: ListView of items to be created
- **ConfirmDialog**: AlertDialog for delete confirmation

## Navigation
- Named routes or Navigator.push with arguments
- CollectionDetailScreen receives collectionId as argument
- BulkAddScreen receives collectionId as argument

## Reorder Implementation
- Use Flutter's ReorderableListView
- On reorder callback: update order values in StorageService
- Persist order changes immediately

## Empty States
- HomeScreen empty: centered message + FAB prompt
- CollectionDetail empty: centered message + add button
- Both use consistent styling (icon + text + action)
