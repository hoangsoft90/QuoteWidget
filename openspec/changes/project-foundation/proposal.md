# Proposal: Project Foundation

## What
Set up the Flutter project "Quote Widget – Your Words" with the complete data model layer (Collection, Item, WidgetConfig), Hive local storage service, and the main app entry point. This is the foundation that all other features build upon.

## Why
Every feature in the app depends on the data models and storage layer being in place first. Without this, no screens, widgets, or services can be implemented.

## Scope
- Initialize Flutter project with proper Android configuration (minSdk 24, no INTERNET permission)
- Define platform-neutral data models: Collection, Item, WidgetConfig (with TypeAdapters for Hive)
- Implement StorageService with Hive for CRUD operations and cascade-delete logic
- Set up main.dart with Hive initialization and HomeWidget registration
- Create sample data for onboarding
- Define rotation logic service (Sequential/Random)

## Non-goals
- UI screens (covered in collection-item-crud change)
- Android native widget rendering (covered in android-widget change)
- Backup/restore (covered in backup-restore change)
- Onboarding UI (covered in onboarding change)

## Success Criteria
- App compiles and runs on Android emulator
- Can create/read/update/delete Collections and Items via StorageService
- Can create/read/update WidgetConfigs
- Cascade-delete works: deleting a Collection removes all its Items
- Rotation logic produces correct next index for Sequential and Random modes
