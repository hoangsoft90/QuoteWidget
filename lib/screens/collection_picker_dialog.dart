import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../services/storage_service.dart';

class CollectionPickerDialog extends StatefulWidget {
  final StorageService storageService;
  final Function(Collection) onSelected;

  const CollectionPickerDialog({
    super.key,
    required this.storageService,
    required this.onSelected,
  });

  @override
  State<CollectionPickerDialog> createState() => _CollectionPickerDialogState();
}

class _CollectionPickerDialogState extends State<CollectionPickerDialog> {
  List<Collection> _collections = [];

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  void _loadCollections() {
    setState(() {
      _collections = widget.storageService.getAllCollections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save to which collection?'),
      content: _collections.isEmpty
          ? const Text('No collections yet. Create one first.')
          : SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _collections.length + 1,
                itemBuilder: (context, index) {
                  if (index == _collections.length) {
                    // Create new collection option
                    return ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: const Text('Create New Collection'),
                      onTap: () async {
                        Navigator.of(context).pop();
                        final name = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            final controller = TextEditingController();
                            return AlertDialog(
                              title: const Text('New Collection'),
                              content: TextField(
                                controller: controller,
                                autofocus: true,
                                decoration: const InputDecoration(
                                  hintText: 'Collection name',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (controller.text.trim().isNotEmpty) {
                                      Navigator.of(ctx).pop(controller.text.trim());
                                    }
                                  },
                                  child: const Text('Create'),
                                ),
                              ],
                            );
                          },
                        );
                        if (name != null && name.isNotEmpty) {
                          final collection = await widget.storageService.createCollection(name);
                          widget.onSelected(collection);
                        }
                      },
                    );
                  }

                  final collection = _collections[index];
                  final itemCount = widget.storageService.getItemCountForCollection(collection.id);

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        collection.name[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(collection.name),
                    subtitle: Text('$itemCount item${itemCount == 1 ? '' : 's'}'),
                    onTap: () {
                      widget.onSelected(collection);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
