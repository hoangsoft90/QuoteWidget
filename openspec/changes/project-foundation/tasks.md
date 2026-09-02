# Tasks: Project Foundation

## Task 1: Initialize Flutter Project
- Create Flutter project with `flutter create`
- Configure Android: set minSdk to 24, remove INTERNET permission
- Add dependencies to pubspec.yaml: hive, hive_flutter, home_widget, uuid, path_provider
- Run `flutter pub get`

## Task 2: Create Data Models
- Create `lib/models/collection_model.dart` with Hive TypeAdapter (typeId=0)
- Create `lib/models/item_model.dart` with Hive TypeAdapter (typeId=1)
- Create `lib/models/widget_config_model.dart` with Hive TypeAdapter (typeId=2)
- Create `lib/models/appearance_config.dart` with Hive TypeAdapter (typeId=3)
- Create enum definitions for RotationMode, SizeCategory, TextAlignment

## Task 3: Create Storage Service
- Create `lib/services/storage_service.dart`
- Implement Hive box initialization with all TypeAdapters registered
- Implement Collection CRUD (create, read, update, delete with cascade)
- Implement Item CRUD (create, read, update, delete, reorder, bulk add)
- Implement WidgetConfig CRUD
- Test cascade-delete behavior

## Task 4: Create Rotation Service
- Create `lib/services/rotation_service.dart`
- Implement `getNextIndex()` with Sequential mode
- Implement `getNextIndex()` with Random mode (exclude current)
- Handle edge cases: empty collection, single item

## Task 5: Set Up Main Entry Point
- Create `lib/main.dart`
- Initialize Hive with Flutter bindings
- Register all TypeAdapters
- Set up home_widget initialization
- Create basic MaterialApp with placeholder home screen

## Task 6: Verify Foundation
- Run `flutter analyze` to check for issues
- Write unit tests for RotationService
- Write unit tests for StorageService cascade-delete
- Verify app compiles and runs on Android emulator
