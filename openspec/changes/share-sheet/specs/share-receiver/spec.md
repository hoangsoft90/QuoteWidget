# Spec: Share Receiver

## Android Intent Filter
- Register for `ACTION_SEND` with `text/plain` MIME type
- Handle share intents from other apps
- Extract shared text from intent extras

## Share Processing
- **Plain text**: extract text directly, save as new item
- **URL only**: detect URL pattern, open app for manual input
- **Empty/invalid**: show error message, don't save

## Data Flow
```
1. User shares text from another app
2. Android routes to QuoteWidgetActivity
3. ShareHandler extracts text from intent
4. If plain text: show collection picker (or auto-select if single collection)
5. Create new item with shared text
6. Show success toast: "Added to [collection name]"
7. Optionally open app to collection detail screen
```

## URL Detection
- Check if shared text matches URL pattern (http/https)
- If URL only (no other text): open app, show message "URL received. Add a note about this link?"
- If text contains URL: extract text, save as item (ignore URL)

## Error Handling
- Invalid intent: show "Could not process shared content"
- Empty text: show "No text content to save"
- Collection not found: show "Collection not found. Please select another."
- Save failed: show "Failed to save. Please try again."

## UI Feedback
- Toast notification on successful save
- Brief animation or haptic feedback
- Optional: open app to show where content was saved
