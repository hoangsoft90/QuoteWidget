# Spec: Data Models

## Collection Model
- `id`: UUID string (auto-generated)
- `name`: String (required)
- `createdAt`: DateTime (auto-generated)
- NO `itemIds[]` field — relationship goes from Item → Collection
- Hive TypeAdapter with typeId = 0

## Item Model
- `id`: UUID string (auto-generated)
- `collectionId`: String (required, references Collection.id)
- `text`: String (required)
- `order`: int (for ordering within collection)
- `createdAt`: DateTime (auto-generated)
- NO `pinned` field in MVP
- Hive TypeAdapter with typeId = 1

## WidgetConfig Model
- `id`: String (auto-generated)
- `collectionId`: String (required, references Collection.id)
- `currentIndex`: int (defaults to 0, per-widget instance)
- `rotationMode`: enum { sequential, random }
- `appearance`: AppearanceConfig object
  - `theme`: String (light/dark/custom)
  - `fontSize`: double
  - `textColor`: int (Color value)
  - `background`: int (Color value)
  - `alignment`: enum { left, center, right }
- `sizeCategory`: enum { small, medium }
- Hive TypeAdapter with typeId = 2

## AppearanceConfig
- Embedded value object within WidgetConfig
- Hive TypeAdapter with typeId = 3

## Enums
- RotationMode: sequential, random
- SizeCategory: small, medium
- TextAlignment: left, center, right
