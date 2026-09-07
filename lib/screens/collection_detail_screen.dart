import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/collection_model.dart';
import '../models/item_model.dart';
import '../models/widget_config_model.dart';
import '../services/backup_service.dart';
import '../services/snapshot_manager.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import 'bulk_add_screen.dart';
import 'share_quote_card_screen.dart';

/// A5a: the full reorder flow — persists the new order in Hive AND
/// immediately re-syncs every widget bound to this collection (before the
/// fix, the widget kept the old pool until an unrelated action re-synced it).
/// Top-level so it can be tested without pumping the widget tree.
Future<List<Item>> reorderAndSyncItems({
  required StorageService storageService,
  required WidgetService widgetService,
  required String collectionId,
  required List<Item> items,
  required int fromIndex,
  required int toIndex,
}) async {
  final item = items.removeAt(fromIndex);
  items.insert(toIndex, item);

  final itemIds = items.map((e) => e.id).toList();
  await storageService.reorderItems(collectionId, itemIds);
  await widgetService.updateWidgetsForCollection(collectionId);
  return items;
}

class CollectionDetailScreen extends StatefulWidget {
  final Collection collection;
  final StorageService storageService;
  final WidgetService widgetService;
  final SnapshotManager? snapshotManager;

  const CollectionDetailScreen({
    super.key,
    required this.collection,
    required this.storageService,
    required this.widgetService,
    this.snapshotManager,
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
    final authorController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            // B1: optional author — empty is fine.
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                hintText: 'Author (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                _addItem(textController.text.trim(),
                    author: authorController.text.trim());
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
    final authorController = TextEditingController(text: item.author);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter text',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            // B1: optional author — empty clears it.
            TextField(
              controller: authorController,
              decoration: const InputDecoration(
                hintText: 'Author (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                _updateItem(item.id, textController.text.trim(),
                    author: authorController.text.trim());
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

  Future<void> _addItem(String text, {String? author}) async {
    final nextOrder = _items.isEmpty
        ? 0
        : _items.map((e) => e.order).reduce((a, b) => a > b ? a : b) + 1;

    await widget.storageService.createItem(
      collectionId: widget.collection.id,
      text: text,
      order: nextOrder,
      author: author,
    );
    _loadItems();
    _syncWidget();
  }

  Future<void> _updateItem(String id, String text, {String? author}) async {
    await widget.storageService.updateItem(id, text, author: author);
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

  /// A5a: reorder handler — delegates to [reorderAndSyncItems] so the full
  /// flow (Hive order write + immediate widget re-sync) is testable without
  /// pumping the widget tree.
  Future<void> handleReorder(int fromIndex, int toIndex) async {
    final reordered = await reorderAndSyncItems(
      storageService: widget.storageService,
      widgetService: widget.widgetService,
      collectionId: widget.collection.id,
      items: _items,
      fromIndex: fromIndex,
      toIndex: toIndex,
    );
    if (mounted) setState(() => _items = reordered);
  }

  /// B2: shared BackupService handle for this screen's export/import.
  BackupService get _backupService => BackupService(
      widget.storageService, widget.snapshotManager ?? SnapshotManager());

  /// B2: export THIS collection + its items as a shareable .json file.
  Future<void> _exportCollection() async {
    try {
      final path = await _backupService.exportCollection(widget.collection.id);
      await _backupService.shareBackup(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Collection exported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  /// B2: import items from a collection-export file — either a NEW collection
  /// or appended into THIS one. One confirm step before anything is written.
  Future<void> _importCollection() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final filePath = picked?.files.single.path;
      if (filePath == null) return;

      final preview = await BackupService.previewCollectionImport(filePath);
      if (!mounted) return;
      final mode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Import "${preview.collection.name}"?'),
          content: Text(
              'This file contains ${preview.items.length} item(s). Import as a new collection, or add them to "${widget.collection.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('new'),
              child: const Text('New collection'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('append'),
              child: const Text('Add here'),
            ),
          ],
        ),
      );
      if (mode == null || !mounted) return;

      final result = await _backupService.importCollection(
        filePath: filePath,
        targetCollectionId: mode == 'append' ? widget.collection.id : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success ? Colors.green : Colors.red,
        ),
      );
      if (result.success) {
        _loadItems();
        _syncWidget();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
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
          // B2: single-collection export / import.
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'export') _exportCollection();
              if (value == 'import') _importCollection();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.ios_share),
                  title: Text('Export collection'),
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Import items'),
                ),
              ),
            ],
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
        unawaited(handleReorder(fromIndex, toIndex));
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
                    } else if (value == 'shareImage') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ShareQuoteCardScreen(
                            quoteText: item.text,
                            author: item.author,
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit'),
                    ),
                    const PopupMenuItem(
                      value: 'shareImage',
                      child: Text('Share as image'),
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
