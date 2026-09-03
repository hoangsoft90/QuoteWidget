import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../services/iap_service.dart';
import '../services/rewarded_ad_service.dart';
import 'collection_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final WidgetService widgetService;
  final IapService iapService;
  final RewardedAdService rewardedAdService;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.widgetService,
    required this.iapService,
    required this.rewardedAdService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Collection> _collections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  void _loadCollections() {
    setState(() {
      _collections = widget.storageService.getAllCollections();
      _isLoading = false;
    });
  }

  void _showCreateCollectionDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Collection name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              _createCollection(value.trim());
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
              if (nameController.text.trim().isNotEmpty) {
                _createCollection(nameController.text.trim());
                Navigator.of(context).pop();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCollection(String name) async {
    await widget.storageService.createCollection(name);
    _loadCollections();
  }

  void _showDeleteConfirmation(Collection collection) {
    final itemCount = widget.storageService.getItemCountForCollection(collection.id);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Delete "${collection.name}"? This will also remove $itemCount item${itemCount == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteCollection(collection.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCollection(String id) async {
    await widget.widgetService.markCollectionRemoved(id);
    await widget.storageService.deleteCollection(id);
    _loadCollections();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Words'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    iapService: widget.iapService,
                    rewardedAdService: widget.rewardedAdService,
                    storageService: widget.storageService,
                    widgetService: widget.widgetService,
                  ),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _collections.isEmpty
              ? _buildEmptyState()
              : _buildCollectionList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateCollectionDialog,
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
            Icons.collections_bookmark_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Create your first collection',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _collections.length,
      itemBuilder: (context, index) {
        final collection = _collections[index];
        final itemCount = widget.storageService.getItemCountForCollection(collection.id);

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                collection.name.isNotEmpty ? collection.name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              collection.name,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text('$itemCount item${itemCount == 1 ? '' : 's'}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmation(collection);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CollectionDetailScreen(
                    collection: collection,
                    storageService: widget.storageService,
                    widgetService: widget.widgetService,
                  ),
                ),
              ).then((_) => _loadCollections());
            },
          ),
        );
      },
    );
  }
}
