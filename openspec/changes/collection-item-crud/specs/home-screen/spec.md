# Spec: Home Screen

## Layout
- AppBar with app title "Your Words"
- Floating action button to create new collection
- ListView of collection cards
- Each card shows: collection name, item count, created date
- Tap card → navigate to collection detail screen
- Long press or swipe to delete collection

## States
- Empty: show message "Create your first collection" with illustration
- Loading: show skeleton or progress indicator
- Normal: show list of collections sorted by creation date (newest first)

## Create Collection
- Tap FAB → show dialog with text field for collection name
- Validate: name must not be empty
- On confirm: create collection, dismiss dialog, scroll to new collection

## Delete Collection
- Swipe left or long press → show confirmation dialog
- Dialog text: "Delete [collection name]? This will also remove [N] items."
- Confirm → cascade delete collection + items + widgetConfigs
- Auto-create safety snapshot before delete (reuse backup mechanism)

## Navigation
- Home → Collection Detail (push)
- Home → Onboarding (if first launch, handled in onboarding change)
