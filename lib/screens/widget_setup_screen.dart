import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/collection_model.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import '../services/widget_data_bridge.dart';
import 'collection_detail_screen.dart';
import 'package:home_widget/home_widget.dart';

/// Screen shown when user taps an unconfigured/empty widget on Home Screen.
/// If [collectionId] is null → shows collection picker (first-time setup).
/// If [collectionId] is provided → opens collection detail to add items.
class WidgetSetupScreen extends StatefulWidget {
  final int appWidgetId;
  final String? collectionId;
  final StorageService storageService;
  final WidgetService widgetService;

  const WidgetSetupScreen({
    super.key,
    required this.appWidgetId,
    this.collectionId,
    required this.storageService,
    required this.widgetService,
  });

  @override
  State<WidgetSetupScreen> createState() => _WidgetSetupScreenState();
}

class _WidgetSetupScreenState extends State<WidgetSetupScreen> {
  List<Collection> _collections = [];
  Collection? _selectedCollection;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _collections = widget.storageService.getAllCollections();

    // If collectionId is provided, auto-select it and save immediately
    if (widget.collectionId != null) {
      final col = widget.storageService.getCollection(widget.collectionId!);
      if (col != null) {
        _selectedCollection = col;
        // Auto-save and navigate to collection detail
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _saveAndNavigateToDetail();
        });
      }
    }
  }

  Future<void> _saveAndNavigateToDetail() async {
    if (_selectedCollection == null || _saving) return;
    setState(() => _saving = true);

    // Create WidgetConfig
    final config = await widget.storageService.createWidgetConfig(
      collectionId: _selectedCollection!.id,
    );

    // Register mapping
    await WidgetDataBridge.registerWidgetMapping(
      appWidgetId: widget.appWidgetId,
      configId: config.id,
    );

    // Sync data
    await widget.widgetService.syncWidgetData(
      config,
      appWidgetId: widget.appWidgetId,
    );

    // Trigger widget refresh
    await HomeWidget.updateWidget(
      name: 'QuoteWidgetProvider',
      androidName: 'QuoteWidgetProvider',
    );

    // Clear tapped ids
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tapped_widget_id');
    await prefs.remove('tapped_collection_id');

    if (mounted) {
      // Navigate to collection detail screen to add items
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => CollectionDetailScreen(
            collection: _selectedCollection!,
            storageService: widget.storageService,
            widgetService: widget.widgetService,
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_selectedCollection == null || _saving) return;
    setState(() => _saving = true);

    // Create WidgetConfig
    final config = await widget.storageService.createWidgetConfig(
      collectionId: _selectedCollection!.id,
    );

    // Register mapping: appWidgetId ↔ configId
    await WidgetDataBridge.registerWidgetMapping(
      appWidgetId: widget.appWidgetId,
      configId: config.id,
    );

    // Sync data to HomeWidgetPreferences so Kotlin can read it
    await widget.widgetService.syncWidgetData(
      config,
      appWidgetId: widget.appWidgetId,
    );

    // Trigger widget refresh
    await HomeWidget.updateWidget(
      name: 'QuoteWidgetProvider',
      androidName: 'QuoteWidgetProvider',
    );

    // Clear the tapped_widget_id
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tapped_widget_id');

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Widget configured!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up Widget'),
      ),
      body: _collections.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No collections yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Create a collection first, then come back to set up your widget.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _collections.length,
              itemBuilder: (context, index) {
                final col = _collections[index];
                final isSelected = _selectedCollection?.id == col.id;
                final itemCount = widget.storageService
                    .getItemCountForCollection(col.id);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        col.name.isNotEmpty ? col.name[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(col.name),
                    subtitle: Text('$itemCount items'),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      setState(() => _selectedCollection = col);
                    },
                  ),
                );
              },
            ),
      bottomNavigationBar: _collections.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _selectedCollection != null && !_saving
                      ? _save
                      : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Set Up Widget'),
                ),
              ),
            )
          : null,
    );
  }
}
