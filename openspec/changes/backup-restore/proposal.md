# Proposal: Backup & Restore

## What
Implement JSON-based backup and restore functionality with two modes: Append (add new data without overwriting existing) and Overwrite (replace all data). Include safety snapshots before destructive operations and comprehensive error handling.

## Why
Data safety is critical for user trust. Users need to back up their collections and restore them on new devices or after data loss. The safety snapshot mechanism prevents accidental data loss during overwrite operations.

## Scope
- Export all data to JSON file (collections, items, widgetConfigs)
- Import JSON file with Append mode (skip duplicate IDs)
- Import JSON file with Overwrite mode (replace all data)
- Safety snapshot before overwrite and collection deletion
- Rollback mechanism if restore fails mid-operation
- Comprehensive error handling for invalid JSON, missing fields, file too large
- Share exported file via share_plus

## Non-goals
- Encrypted backup (P1 Pro feature)
- Merge by Collection (not in v1)
- Cloud backup/sync (P2 feature)
- CSV/TXT import (P1 feature)

## Success Criteria
- Can export all data to valid JSON file
- Can import JSON file in Append mode without duplicating existing items
- Can import JSON file in Overwrite mode with safety snapshot
- Safety snapshot can restore data if overwrite fails
- Invalid JSON shows clear error message, no crash
- Missing required fields shows specific error message
- File too large (>20MB) is rejected with message
- Duplicate IDs within backup file are deduplicated
- Invalid collectionId references are skipped gracefully
