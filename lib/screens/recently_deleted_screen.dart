import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../models/item_model.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';

/// Trash / Recently Deleted (Task 7 — P1).
///
/// Lists soft-deleted collections and items with Restore / Delete Forever.
/// Items & collections trashed longer than 30 days are purged automatically at
/// app start (StorageService.purgeTrash) and also on screen open here.
class RecentlyDeletedScreen extends StatefulWidget {
  final StorageService storageService;
  final WidgetService widgetService;

  const RecentlyDeletedScreen({
    super.key,
    required this.storageService,
    required this.widgetService,
  });

  @override
  State<RecentlyDeletedScreen> createState() => _RecentlyDeletedScreenState();
}

class _RecentlyDeletedScreenState extends State<RecentlyDeletedScreen> {
  List<Collection> _collections = [];
  List<Item> _items = [];

  @override
  void initState() {
    super.initState();
    // Purge anything past the 30-day retention window first.
    widget.storageService.purgeTrash();
    _load();
  }

  void _load() {
    setState(() {
      _collections = widget.storageService.getTrashedCollections();
      _items = widget.storageService.getTrashedItems();
    });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  Future<void> _restoreCollection(Collection collection) async {
    final collectionId = collection.id;
    await widget.storageService.restoreCollection(collectionId);
    // Widgets pointing at this collection (if any were left) can refresh.
    await widget.widgetService.updateWidgetsForCollection(collectionId);
    if (mounted) _load();
  }

  Future<void> _deleteForeverCollection(Collection collection) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Forever?'),
        content: Text(
            'Delete "${collection.name}" and its items permanently? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.storageService.permanentlyDeleteCollection(collection.id);
    if (mounted) _load();
  }

  Future<void> _restoreItem(Item item) async {
    await widget.storageService.restoreItem(item.id);
    await widget.widgetService.updateWidgetsForCollection(item.collectionId);
    if (mounted) _load();
  }

  Future<void> _deleteForeverItem(Item item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Forever?'),
        content: Text('Delete this item permanently? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.storageService.permanentlyDeleteItem(item.id);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _collections.isEmpty && _items.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Recently Deleted')),
      body: isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_sweep_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Nothing in trash',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'Deleted items stay here for 30 days,\nthen are removed automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (_collections.isNotEmpty) ...[
                  _sectionHeader('Collections'),
                  for (final collection in _collections)
                    _collectionTile(collection),
                ],
                if (_items.isNotEmpty) ...[
                  _sectionHeader('Items'),
                  for (final item in _items) _itemTile(item),
                ],
                const SizedBox(height: 16),
                Text(
                  'Items are kept for 30 days after deletion, then removed '
                  'automatically.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _collectionTile(Collection collection) {
    final trashedItems = _items
        .where((i) => i.collectionId == collection.id)
        .length;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(collection.name.isNotEmpty
              ? collection.name[0].toUpperCase()
              : '?'),
        ),
        title: Text(collection.name),
        subtitle: Text(
            'Deleted ${_timeAgo(collection.deletedAt ?? collection.createdAt)}'
            '$trashedItems trashed item${trashedItems == 1 ? '' : 's'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restore',
              color: Colors.green,
              onPressed: () => _restoreCollection(collection),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Delete forever',
              color: Colors.red,
              onPressed: () => _deleteForeverCollection(collection),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemTile(Item item) {
    final collection = widget.storageService
        .getTrashedCollections()
        .where((c) => c.id == item.collectionId)
        .firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        leading: const Icon(Icons.notes),
        title: Text(item.text, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            '${collection?.name ?? 'Deleted collection'} • '
            '${_timeAgo(item.deletedAt ?? item.createdAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restore',
              color: Colors.green,
              onPressed: () => _restoreItem(item),
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Delete forever',
              color: Colors.red,
              onPressed: () => _deleteForeverItem(item),
            ),
          ],
        ),
      ),
    );
  }
}