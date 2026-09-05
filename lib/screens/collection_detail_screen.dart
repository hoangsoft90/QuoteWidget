import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../models/item_model.dart';
import '../models/widget_config_model.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import 'bulk_add_screen.dart';

class CollectionDetailScreen extends StatefulWidget {
  final Collection collection;
  final StorageService storageService;
  final WidgetService widgetService;

  const CollectionDetailScreen({
    super.key,
    required this.collection,
    required this.storageService,
    required this.widgetService,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  List<Item> _items = [];
  WidgetConfig? _activeWidgetConfig;
  bool _isLoading = true;

  /// Phase 2A — Favorites filter: false = All items, true = Favorites only.
  bool _favoritesOnly = false;

  /// Phase 2A — realtime search (features_final §1.4 Search). Empty = no filter.
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadItems() {
    setState(() {
      final base = _favoritesOnly
          ? widget.storageService.getFavoriteItemsForCollection(widget.collection.id)
          : widget.storageService.getItemsForCollection(widget.collection.id);
      // In-memory realtime search (case-insensitive substring on text).
      final query = _searchQuery.trim().toLowerCase();
      _items = query.isEmpty
          ? base
          : base.where((i) => i.text.toLowerCase().contains(query)).toList();
      // Get the first active widget config for this collection (for progress display)
      // If multiple widgets exist for this collection, we show progress of the first one.
      _activeWidgetConfig = widget.storageService.getAllWidgetConfigs()
          .where((c) => c.collectionId == widget.collection.id)
          .firstOrNull;
      _isLoading = false;
    });
  }

  void _setFavoritesOnly(bool value) {
    setState(() {
      _favoritesOnly = value;
    });
    _loadItems();
  }

  void _showAddItemDialog() {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter text',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _addItem(value.trim());
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                _addItem(textController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(Item item) {
    final textController = TextEditingController(text: item.text);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter text',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _updateItem(item.id, value.trim());
              Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                _updateItem(item.id, textController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteItemConfirmation(Item item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${item.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteItem(item.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(String text) async {
    final nextOrder = _items.isEmpty
        ? 0
        : _items.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;

    await widget.storageService.createItem(
      collectionId: widget.collection.id,
      text: text,
      order: nextOrder,
    );
    _loadItems();
    _syncWidget();
  }

  Future<void> _updateItem(String id, String text) async {
    await widget.storageService.updateItem(id, text);
    _loadItems();
    _syncWidget();
  }

  Future<void> _deleteItem(String id) async {
    await widget.storageService.deleteItem(id);
    _loadItems();
    _syncWidget();
  }

  void _syncWidget() {
    widget.widgetService.updateWidgetsForCollection(widget.collection.id);
  }

  void _navigateToBulkAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BulkAddScreen(
          collection: widget.collection,
          storageService: widget.storageService,
        ),
      ),
    ).then((_) {
      _loadItems();
      _syncWidget();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.collection.name),
        actions: [
          // Phase 2A — realtime search toggle (in-memory, no new deps).
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close search',
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchActive = false;
                  _searchQuery = '';
                });
                _loadItems();
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () => setState(() => _searchActive = true),
            ),
          // Phase 2A — Favorites filter toggle (All / Favorites-only).
          IconButton(
            icon: Icon(
              _favoritesOnly ? Icons.star : Icons.star_border,
              color: _favoritesOnly
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: _favoritesOnly ? 'Show all items' : 'Show favorites only',
            onPressed: () => _setFavoritesOnly(!_favoritesOnly),
          ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _activeWidgetConfig != null && _items.isNotEmpty
                        ? '${_activeWidgetConfig!.currentIndex.clamp(0, _items.length - 1) + 1}/${_items.length}'
                        : '${_items.length} item${_items.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_to_photos),
            onPressed: _navigateToBulkAdd,
            tooltip: 'Bulk Add',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searchActive) _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? _buildEmptyState()
                    : _buildItemList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search items…',
          prefixIcon: const Icon(Icons.search),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
          _loadItems();
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearch = _searchQuery.trim().isNotEmpty;
    final isFavoritesFilter = !isSearch &&
        _favoritesOnly &&
        widget.storageService.getItemsForCollection(widget.collection.id).isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearch
                ? Icons.search_off
                : (isFavoritesFilter ? Icons.star_border : Icons.note_add_outlined),
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            isSearch
                ? 'No items match your search.'
                : (isFavoritesFilter
                    ? 'No favorites yet.'
                    : 'Add some content to this collection.'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearch
                ? 'Try a different keyword'
                : (isFavoritesFilter
                    ? 'Tap the star on an item to add it here'
                    : 'Tap + to add your first item'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _items.length,
      onReorderItem: (int fromIndex, int toIndex) {
        // onReorderItem already adjusts newIndex for the removed item — no
        // manual correction needed (unlike the deprecated onReorder).
        final item = _items.removeAt(fromIndex);
        _items.insert(toIndex, item);

        // Update order values
        final itemIds = _items.map((e) => e.id).toList();
        widget.storageService.reorderItems(widget.collection.id, itemIds);

        setState(() {});
      },
      itemBuilder: (context, index) {
        final item = _items[index];

        return Card(
          key: ValueKey(item.id),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: const Icon(Icons.drag_handle),
            title: Text(
              item.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Phase 2A — Favorites: tap the star to toggle.
                IconButton(
                  icon: Icon(
                    item.favorite ? Icons.star : Icons.star_border,
                    color: item.favorite
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  tooltip: item.favorite ? 'Remove from favorites' : 'Add to favorites',
                  onPressed: () async {
                    await widget.storageService.toggleItemFavorite(item.id);
                    _loadItems();
                    _syncWidget();
                  },
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditItemDialog(item);
                    } else if (value == 'delete') {
                      _showDeleteItemConfirmation(item);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            onTap: () => _showEditItemDialog(item),
          ),
        );
      },
    );
  }
}
