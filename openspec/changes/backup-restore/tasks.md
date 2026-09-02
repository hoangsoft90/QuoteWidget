# Tasks: Backup & Restore

## Task 1: Create Backup Data Model
- Create `lib/models/backup_data.dart`
- Define BackupData class with schema version, metadata
- Define serialization/deserialization methods
- Validate JSON schema on import

## Task 2: Implement Export Functionality
- Create `lib/services/backup_service.dart`
- Implement `exportBackup()` method
- Read all data from Hive boxes
- Build JSON structure with metadata
- Write to temporary file
- Share file via share_plus

## Task 3: Implement Import Functionality
- Implement `importBackup()` method
- Validate JSON file (schema, size, required fields)
- Implement Append mode: add new items, skip duplicates
- Implement Overwrite mode: clear all, import all from file
- Handle deduplication within backup file
- Handle invalid collectionId references

## Task 4: Implement Safety Snapshot
- Create `lib/services/snapshot_manager.dart`
- Implement `createSnapshot()` method
- Implement `restoreFromSnapshot()` method
- Implement `listSnapshots()` method
- Implement `cleanupOldSnapshots()` method
- Maximum 3 snapshots retained

## Task 5: Create Backup Screen
- Create `lib/screens/backup_screen.dart`
- Implement "Export Backup" button
- Implement "Import Backup" button
- Implement mode selection dialog (Append/Overwrite)
- Implement progress indicators
- Implement success/error messages
- Implement "Restore from Snapshot" section

## Task 6: Integrate with Collection Deletion
- Update StorageService.deleteCollection() to create safety snapshot
- Add snapshot before cascade-delete
- Update backup screen to show recent deletion snapshots

## Task 7: Error Handling
- Implement validation for all import errors
- Show specific error messages for each failure type
- Implement automatic rollback on overwrite failure
- Implement manual rollback option
- Log errors for debugging

## Task 8: Test Backup/Restore
- Test export creates valid JSON file
- Test import Append mode skips duplicates
- Test import Overwrite mode replaces all data
- Test safety snapshot creation and restore
- Test error handling for invalid files
- Test file size limit enforcement
