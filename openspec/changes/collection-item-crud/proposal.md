# Proposal: Collection & Item CRUD

## What
Implement the core UI screens for managing Collections and Items: home screen (collection list), collection detail screen (item list with CRUD, bulk add, reorder), and the necessary navigation.

## Why
This is the primary content management interface. Users need to create collections, add/edit/delete items, bulk-add content, and reorder items before they can use widgets.

## Scope
- Home screen: list all collections, create new collection, delete collection with confirmation dialog
- Collection detail screen: list items, add/edit/delete items, bulk add (paste multiple lines), drag-to-reorder
- Confirmation dialog for collection deletion showing item count
- Navigation between screens
- Empty states for collections and items

## Non-goals
- Widget configuration (covered in widget-customization change)
- Backup/restore UI (covered in backup-restore change)
- Onboarding flow (covered in onboarding change)

## Success Criteria
- Can create a collection and see it in the list
- Can add items to a collection, edit them, delete them
- Can bulk-add items by pasting multiple lines of text
- Can reorder items via drag and drop
- Deleting a collection shows confirmation with item count
- Empty states display correctly
