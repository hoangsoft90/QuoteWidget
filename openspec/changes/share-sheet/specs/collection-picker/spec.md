# Spec: Collection Picker

## Purpose
Allow user to choose which collection to save shared text to.

## Trigger
- When shared text is received
- If multiple collections exist: show picker
- If single collection: auto-select it
- If no collections: show "Create a collection first" message

## Layout
- Modal dialog or bottom sheet
- Title: "Save to which collection?"
- List of collections with names
- Each item tappable to select
- "Create New Collection" option at bottom

## Behavior
- Tap collection: save item to that collection, dismiss picker
- Tap "Create New Collection": navigate to create collection screen, then save
- Tap outside dialog: cancel share, don't save
- Back button: cancel share, don't save

## Auto-Select Logic
- If only 1 collection exists: skip picker, save directly
- If 0 collections: show message, offer to create one
- If 2+ collections: show picker

## Accessibility
- Large touch targets for collection items
- Clear visual feedback on selection
- Announce selection to screen readers
