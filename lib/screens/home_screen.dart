import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../services/backup_service.dart';
import '../services/sample_data_service.dart';
import '../services/snapshot_manager.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../services/iap_service.dart';
import '../services/interstitial_ad_service.dart';
import '../services/rewarded_ad_service.dart';
import '../widgets/banner_ad_view.dart';
import 'collection_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;
  final WidgetService widgetService;
  final IapService iapService;
  final RewardedAdService rewardedAdService;
  final InterstitialAdController interstitialAdController;
  final BackupService backupService;
  final SnapshotManager snapshotManager;

  const HomeScreen({
    super.key,
    required this.storageService,
    required this.widgetService,
    required this.iapService,
    required this.rewardedAdService,
    required this.interstitialAdController,
    required this.backupService,
    required this.snapshotManager,
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

  /// Phase 2A — Templates + Empty-state (features_final §1.4): when Home has
  /// zero collections, offer the 5 starter packs (reuses SampleDataService)
  /// or "Start empty" (plain new collection).
  Future<void> _createFromTemplate(SampleUseCase useCase) async {
    try {
      final collections =
          await SampleDataService(widget.storageService)
              .createSampleCollections(useCase);
      if (!mounted) return;
      final created = collections.isNotEmpty ? collections.first : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created != null
                ? 'Created "${created.name}"'
                : 'Template created',
          ),
        ),
      );
      _loadCollections();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Template failed: $e')),
      );
    }
  }

  /// Phase 2A — Duplicate Collection: copies collection + items with fresh
  /// ids, name `name (Copy)`. No widget configs are copied (a duplicated
  /// widget would need a physical widget that doesn't exist).
  Future<void> _duplicateCollection(String id) async {
    try {
      final copy = await widget.storageService.duplicateCollection(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated as "${copy.name}"')),
      );
      _loadCollections();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicate failed: $e')),
      );
    }
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
                    backupService: widget.backupService,
                    snapshotManager: widget.snapshotManager,
                    interstitialAdController: widget.interstitialAdController,
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
      // Banner ad pinned below the body — the Scaffold lifts the FAB above
      // it automatically so the [+] button never overlaps the ad.
      bottomNavigationBar: const BannerAdView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateCollectionDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    // Phase 2A — Templates: CTA starter packs (reuse onboarding sample data)
    // or start empty with the FAB (+).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Start with a template',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a pack — you can edit everything later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: SampleUseCase.values.map((useCase) {
                return ActionChip(
                  avatar: Icon(_iconFor(useCase), size: 18),
                  label: Text(useCase.title),
                  onPressed: () => _createFromTemplate(useCase),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _showCreateCollectionDialog,
              icon: const Icon(Icons.create_new_folder_outlined),
              label: const Text('Start empty'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(SampleUseCase useCase) {
    switch (useCase) {
      case SampleUseCase.vocabulary:
        return Icons.translate;
      case SampleUseCase.motivation:
        return Icons.auto_awesome;
      case SampleUseCase.workFocus:
        return Icons.work_outline;
      case SampleUseCase.gym:
        return Icons.fitness_center;
      case SampleUseCase.personalQuotes:
        return Icons.edit_note;
    }
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
                if (value == 'duplicate') {
                  _duplicateCollection(collection.id);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(collection);
                }
              },
              itemBuilder: (context) => [
                // Phase 2A — Duplicate Collection (features_final §1.4).
                const PopupMenuItem(
                  value: 'duplicate',
                  child: Text('Duplicate'),
                ),
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
