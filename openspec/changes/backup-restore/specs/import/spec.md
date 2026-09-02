# Spec: Import Backup

## Input
- JSON file selected via file_picker
- User chooses import mode: Append or Overwrite

## Append Mode
- Keep all existing data
- Add new collections, items, widgetConfigs from backup
- Skip any item with ID that already exists in app (no overwrite, no duplicate)
- Skip any collection with ID that already exists
- Skip any widgetConfig with ID that already exists
- Log skipped items for user feedback

## Overwrite Mode
- Create safety snapshot of current data first
- Delete ALL existing collections, items, widgetConfigs
- Import all data from backup file
- If import fails mid-operation: rollback to safety snapshot
- Show success message with counts: "Imported X collections, Y items, Z widgets"

## Validation (Before Import)
- Parse JSON → if fails: "Invalid JSON file"
- Check `backupFormat` field → if missing/wrong: "Invalid backup file format"
- Check `schemaVersion` field → if missing/unsupported: "Unsupported backup version"
- Check file size → if > 20MB: "File too large (max 20MB)"
- Check required fields in each object → if missing: "Missing required field: [field name]"

## Deduplication
- Within backup file: if duplicate IDs exist, keep only first occurrence
- Cross-reference: in Append mode, skip items with existing IDs

## Reference Validation
- Check each item's collectionId exists in the backup file's collections
- If collectionId not found in backup: skip that item, log warning
- In Append mode: also check against existing collections in app

## Error Handling
- Show specific error message for each validation failure
- Never crash on invalid input
- Provide "Choose Another File" button after error
- Log errors for debugging (but not sensitive data)

## UI
- "Import Backup" button on backup screen
- File picker dialog
- Mode selection dialog (Append/Overwrite) after file selected
- Progress indicator during import
- Summary of what was imported/skipped
