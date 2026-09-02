# Spec: Export Backup

## Output Format
- JSON file with schema version and metadata
- File extension: `.json`
- Default filename: `quotewidget-backup-YYYY-MM-DD.json`

## JSON Schema
```json
{
  "backupFormat": "quote-widget-backup",
  "schemaVersion": 1,
  "appVersion": "1.0.0",
  "createdAt": "ISO-8601 timestamp",
  "platform": "android",
  "collections": [...],
  "items": [...],
  "widgetConfigs": [...]
}
```

## Export Process
1. Read all Collections from Hive
2. Read all Items from Hive
3. Read all WidgetConfigs from Hive
4. Build JSON structure with metadata
5. Write to temporary file
6. Share file via share_plus (or save to downloads)

## Validation
- Ensure all required fields are present
- Ensure timestamps are valid ISO-8601
- Ensure IDs are valid UUIDs
- Log warning if any data inconsistencies found (but still export)

## UI
- "Export Backup" button on backup screen
- Show progress indicator during export
- Show success message with file location
- Offer to share file immediately after export
