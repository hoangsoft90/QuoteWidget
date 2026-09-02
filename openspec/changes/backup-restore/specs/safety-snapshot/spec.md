# Spec: Safety Snapshot

## Purpose
Protect against data loss during destructive operations (overwrite import, collection deletion).

## Snapshot Content
- Complete copy of all Collections, Items, and WidgetConfigs
- Stored as JSON in app's documents directory
- Filename: `safety-snapshot-{timestamp}.json`
- Maximum 3 snapshots retained (oldest deleted automatically)

## When to Create Snapshot
1. Before Overwrite import (always)
2. Before Collection deletion (always)
3. NOT before Append import (non-destructive)

## Snapshot Lifecycle
- Created → stored in documents directory
- If operation succeeds: snapshot retained for 7 days, then auto-deleted
- If operation fails: snapshot available for manual rollback
- Maximum 3 snapshots: oldest deleted when new one created

## Rollback Mechanism
- If overwrite import fails mid-operation:
  1. Detect failure (exception, partial data, validation error)
  2. Delete any partially imported data
  3. Read safety snapshot
  4. Restore all data from snapshot
  5. Delete the failed import file
  6. Show message: "Import failed. Previous data restored from safety snapshot."

## Rollback UI
- "Restore from Snapshot" button on backup screen
- Shows list of available snapshots with timestamps
- Confirm before restoring: "Restore data from [timestamp]? Current data will be replaced."
- Show progress during restore
- Success message: "Data restored from snapshot [timestamp]"

## Storage Location
- App's documents directory (accessible via path_provider)
- Not visible to user in file manager (internal storage)
- Backed up by Android's automatic app backup (if enabled)
