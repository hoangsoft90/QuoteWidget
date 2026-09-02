# Design: Project Foundation

## Architecture
- Flutter app with clean separation: Models → Services → Screens → Widgets
- Platform-neutral data models (no Flutter/Android dependencies in model layer)
- Hive for local storage (fast, no native setup needed, good for simple models)
- home_widget plugin for Flutter ↔ Android widget bridge

## Project Structure
```
lib/
├── main.dart
├── models/
│   ├── collection_model.dart
│   ├── item_model.dart
│   ├── widget_config_model.dart
│   └── appearance_config.dart
├── services/
│   ├── storage_service.dart
│   └── rotation_service.dart
├── screens/ (added in later changes)
├── widgets/ (added in later changes)
└── android/ (native widget code, added in android-widget change)
```

## Technology Choices
- **Hive** over SQLite: simpler API, no SQL needed, TypeAdapters are straightforward, good performance for small datasets
- **UUID** for IDs: ensures uniqueness across backup/restore operations
- **home_widget** package: official Flutter community package for home screen widget communication

## Data Flow
```
User Action → Screen → Service → Hive Box → Model (TypeAdapter serialize/deserialize)
                                              ↓
Widget Bridge ← home_widget ← Service ← Hive Box
```

## Key Design Decisions
1. **Cascade-delete in StorageService**: When a Collection is deleted, the service automatically deletes all Items and WidgetConfigs referencing it. This prevents orphaned data and broken widget states.
2. **currentIndex per WidgetConfig**: Each widget instance tracks its own position independently. Tap on widget A doesn't affect widget B.
3. **Rotation as pure function**: getNextIndex is a pure function with no side effects, making it easy to test and reason about.
4. **Platform-neutral models**: Models have no Android/iOS imports. Only the widget bridge layer is platform-specific.
