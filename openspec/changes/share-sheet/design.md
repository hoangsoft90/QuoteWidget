# Design: Share Sheet Quick Add

## Architecture
- **ShareHandler**: processes incoming share intents
- **CollectionPickerDialog**: UI for selecting target collection
- **ShareReceiverActivity**: Android activity to receive shares

## File Structure
```
android/app/src/main/
├── kotlin/.../share/
│   ├── ShareReceiverActivity.kt   # Receives share intents
│   └── ShareHandler.kt            # Processes shared text
├── AndroidManifest.xml            # Intent filter registration

lib/
├── services/
│   └── share_service.dart         # Flutter side share handling
├── screens/
│   └── collection_picker_dialog.dart  # Collection selection UI
└── main.dart                      # Share intent handling
```

## Data Flow
```
1. User shares text from Reddit/Twitter
2. Android → ShareReceiverActivity
3. ShareReceiverActivity extracts text
4. ShareReceiverActivity launches Flutter app with share data
5. Flutter main.dart receives share data
6. ShareService processes text:
   a. If plain text: show CollectionPickerDialog
   b. If URL only: open app with message
   c. If invalid: show error
7. User selects collection (or auto-selected)
8. StorageService creates new item
9. Show success toast
```

## Android Configuration
- Intent filter in AndroidManifest.xml:
  ```xml
  <intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
  </intent-filter>
  ```
- ShareReceiverActivity registered as launcher activity for shares

## Flutter Integration
- Use method channel or home_widget for share data passing
- Or use share_handler package (simpler, recommended)
- Handle share data in main.dart or dedicated share handler

## Key Design Decisions
1. **share_handler package**: recommended for Flutter share handling, simpler than manual method channels
2. **Collection picker as dialog**: lightweight, doesn't require full screen navigation
3. **Auto-select single collection**: reduces friction for users with one collection
4. **URL detection**: simple regex pattern, no complex parsing
5. **Toast feedback**: non-intrusive, quick confirmation
