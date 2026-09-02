# Design: Backup & Restore

## Architecture
- **BackupService**: handles all export/import logic
- **SnapshotManager**: handles safety snapshots and rollback
- **BackupScreen**: UI for export/import/snapshot management

## File Structure
```
lib/
├── services/
│   ├── backup_service.dart      # Export/Import logic
│   └── snapshot_manager.dart    # Safety snapshot management
├── screens/
│   └── backup_screen.dart       # Backup/Restore UI
└── models/
    └── backup_data.dart         # Backup file schema model
```

## Data Flow: Export
```
1. User taps "Export Backup"
2. BackupService reads all data from Hive boxes
3. BackupService builds JSON structure with metadata
4. BackupService writes to temporary file in cache directory
5. share_plus shares the file (or saves to downloads)
6. Temporary file cleaned up after share
```

## Data Flow: Import
```
1. User taps "Import Backup"
2. file_picker opens file selection dialog
3. User selects JSON file
4. BackupService validates file (schema, size, required fields)
5. User chooses mode: Append or Overwrite
6. If Overwrite: SnapshotManager creates safety snapshot
7. BackupService processes import:
   - Append: add new items, skip duplicates
   - Overwrite: clear all data, import all from file
8. If success: show summary, clean up temporary files
9. If failure: rollback to snapshot (if Overwrite), show error
```

## Safety Snapshot Flow
```
1. Before destructive operation:
   - Read all data from Hive
   - Write to JSON file in documents directory
   - Delete oldest snapshot if > 3 exist
2. After operation:
   - If success: retain snapshot for 7 days
   - If failure: keep snapshot for manual rollback
3. Rollback:
   - Read snapshot file
   - Clear all Hive boxes
   - Import data from snapshot
   - Show success message
```

## Error Handling Strategy
- **Validation errors**: specific message, no crash, allow retry
- **IO errors**: message about file access, suggest checking permissions
- **Parse errors**: message about invalid JSON, suggest checking file
- **Partial import errors**: automatic rollback if available, manual rollback option
- **All errors**: log for debugging, never expose sensitive data in messages

## Key Design Decisions
1. **JSON format**: human-readable, easy to debug, widely compatible
2. **Safety snapshots**: automatic before destructive operations, max 3 retained
3. **Append mode**: idempotent (running same import twice doesn't duplicate)
4. **File size limit**: 20MB prevents accidental import of huge files
5. **No cloud**: all operations local, no network needed, privacy-first
