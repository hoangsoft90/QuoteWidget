import 'package:flutter/material.dart';
import '../models/collection_model.dart';
import '../services/storage_service.dart';

class BulkAddScreen extends StatefulWidget {
  final Collection collection;
  final StorageService storageService;

  const BulkAddScreen({
    super.key,
    required this.collection,
    required this.storageService,
  });

  @override
  State<BulkAddScreen> createState() => _BulkAddScreenState();
}

class _BulkAddScreenState extends State<BulkAddScreen> {
  final TextEditingController _textController = TextEditingController();
  List<String> _previewItems = [];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final text = _textController.text;
    final lines = text.split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    setState(() {
      _previewItems = lines;
    });
  }

  void _confirmBulkAdd() {
    if (_previewItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No items to add')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Bulk Add'),
        content: Text('Add ${_previewItems.length} item${_previewItems.length == 1 ? '' : 's'} to "${widget.collection.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _performBulkAdd();
              Navigator.of(context).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _performBulkAdd() async {
    await widget.storageService.bulkAddItems(
      collectionId: widget.collection.id,
      texts: _previewItems,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_previewItems.length} item${_previewItems.length == 1 ? '' : 's'} added'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Add'),
        actions: [
          TextButton(
            onPressed: _previewItems.isNotEmpty ? _confirmBulkAdd : null,
            child: const Text('Add All'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter one item per line:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Item 1\nItem 2\nItem 3',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
                onChanged: (_) => _updatePreview(),
              ),
            ),
            const SizedBox(height: 16),
            if (_previewItems.isNotEmpty) ...[
              Text(
                'Preview (${_previewItems.length} item${_previewItems.length == 1 ? '' : 's'}):',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _previewItems.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${index + 1}. ${_previewItems[index]}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
