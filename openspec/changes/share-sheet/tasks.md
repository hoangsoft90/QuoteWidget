# Tasks: Share Sheet Quick Add

## Task 1: Set Up Share Receiver
- Add share_handler package to pubspec.yaml
- Configure Android intent filter in AndroidManifest.xml
- Register ShareReceiverActivity
- Test share intent reception on Android emulator

## Task 2: Create Share Service
- Create `lib/services/share_service.dart`
- Implement `handleShareIntent()` method
- Extract text from share data
- Detect URL-only shares
- Validate shared content

## Task 3: Create Collection Picker Dialog
- Create `lib/screens/collection_picker_dialog.dart`
- Implement modal dialog with collection list
- Implement "Create New Collection" option
- Implement selection callback
- Handle cancel/back actions

## Task 4: Implement Share Flow
- In main.dart: check for share data on launch
- If share data exists: process via ShareService
- Show CollectionPickerDialog if multiple collections
- Auto-select if single collection
- Show error if no collections

## Task 5: Save Shared Content
- Create new item with shared text
- Set collectionId from picker selection
- Set order to next available value
- Show success toast notification
- Optionally navigate to collection detail

## Task 6: Handle Edge Cases
- Invalid/empty share data → error message
- URL-only share → open app with message
- Collection not found → error message
- Save failure → error message with retry

## Task 7: Test Share Integration
- Test share from Chrome/browser
- Test share from Twitter/Reddit (if available)
- Test URL-only share
- Test empty share data
- Test with multiple collections
- Test with single collection (auto-select)
- Test with no collections (create prompt)
