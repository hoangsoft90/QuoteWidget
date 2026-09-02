# Spec: Storage Service

## Responsibilities
- Initialize Hive with all registered TypeAdapters
- Provide CRUD operations for Collection, Item, and WidgetConfig
- Handle cascade-delete: deleting a Collection deletes all Items with that collectionId
- Handle cascade-delete: deleting a Collection deletes all WidgetConfigs with that collectionId
- Provide query methods: get all items for a collection, get widget config by id

## API Surface

### Collections
- `createCollection(name: String) -> Collection`
- `getAllCollections() -> List<Collection>`
- `getCollection(id: String) -> Collection?`
- `updateCollection(id: String, name: String) -> void`
- `deleteCollection(id: String) -> void` (cascade: deletes items + widgetConfigs)

### Items
- `createItem(collectionId: String, text: String, order: int) -> Item`
- `getItemsForCollection(collectionId: String) -> List<Item>` (sorted by order)
- `getAllItems() -> List<Item>`
- `getItem(id: String) -> Item?`
- `updateItem(id: String, text: String) -> void`
- `deleteItem(id: String) -> void`
- `reorderItems(collectionId: String, itemIds: List<String>) -> void`
- `bulkAddItems(collectionId: String, texts: List<String>) -> List<Item>`

### WidgetConfigs
- `createWidgetConfig(collectionId: String, sizeCategory: SizeCategory) -> WidgetConfig`
- `getAllWidgetConfigs() -> List<WidgetConfig>`
- `getWidgetConfig(id: String) -> WidgetConfig?`
- `updateWidgetConfig(config: WidgetConfig) -> void`
- `deleteWidgetConfig(id: String) -> void`

### Lifecycle
- `init() -> void` (register adapters, open boxes)
- `close() -> void`
