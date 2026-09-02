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

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _items = widget.storageService.getItemsForCollection(widget.collection.id);
      // Get the first active widget config for this collection (for progress display)
      // If multiple widgets exist for this collection, we show progress of the first one.
      _activeWidgetConfig = widget.storageService.getAllWidgetConfigs()
          .where((c) => c.collectionId == widget.collection.id)
          .firstOrNull;
      _isLoading = false;
    });
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _buildEmptyState()
              : _buildItemList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Add some content to this collection.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first item',
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
      onReorder: (int fromIndex, int toIndex) {
        if (fromIndex < toIndex) {
          toIndex -= 1;
        }

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
            trailing: PopupMenuButton<String>(
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
            onTap: () => _showEditItemDialog(item),
          ),
        );
      },
    );
  }
}
