import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/backup_service.dart';
import '../services/interstitial_ad_service.dart';
import '../services/snapshot_manager.dart';
import '../services/storage_service.dart';

class BackupScreen extends StatefulWidget {
  final BackupService backupService;
  final SnapshotManager snapshotManager;
  final StorageService storageService;
  final InterstitialAdController interstitialAdController;

  const BackupScreen({
    super.key,
    required this.backupService,
    required this.snapshotManager,
    required this.storageService,
    required this.interstitialAdController,
  });

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  List<SnapshotInfo> _snapshots = [];

  @override
  void initState() {
    super.initState();
    _loadSnapshots();
  }

  Future<void> _loadSnapshots() async {
    final snapshots = await widget.snapshotManager.listSnapshots();
    setState(() {
      _snapshots = snapshots;
    });
  }

  Future<void> _exportBackup() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final filePath = await widget.backupService.exportBackup();
      await widget.backupService.shareBackup(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        return;
      }

      // Show mode selection dialog
      final mode = await _showImportModeDialog();
      if (mode == null) {
        return;
      }

      setState(() {
        _isImporting = true;
      });

      try {
        final importResult = await widget.backupService.importBackup(
          filePath: filePath,
          overwrite: mode == 'overwrite',
        );

        if (importResult.success && mode == 'overwrite' && mounted) {
          // Overwrite restore replaces all data — a destructive action that
          // may trigger an interstitial (frequency-gated).
          widget.interstitialAdController.onDestructiveAction();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult.message),
              backgroundColor: importResult.success ? Colors.green : Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: $e')),
          );
        }
      } finally {
        setState(() {
          _isImporting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<String?> _showImportModeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How would you like to import?'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Append'),
              subtitle: const Text('Add new items, skip duplicates'),
              onTap: () => Navigator.of(context).pop('append'),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Overwrite'),
              subtitle: const Text('Replace all data (safety snapshot created)'),
              onTap: () => Navigator.of(context).pop('overwrite'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreFromSnapshot(SnapshotInfo snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from Snapshot'),
        content: Text(
          'Restore data from ${snapshot.timestamp.toString().substring(0, 19)}? '
          'Current data will be replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.snapshotManager.restoreFromSnapshot(snapshot.path, widget.storageService);
        // Destructive action (replaces current data) — may trigger an
        // interstitial (frequency-gated).
        widget.interstitialAdController.onDestructiveAction();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Snapshot restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadSnapshots();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Restore failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Export Section
          _buildSection(
            title: 'Export Backup',
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportBackup,
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_isExporting ? 'Exporting...' : 'Export Backup'),
            ),
          ),

          const Divider(height: 32),

          // Import Section
          _buildSection(
            title: 'Import Backup',
            child: ElevatedButton.icon(
              onPressed: _isImporting ? null : _importBackup,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isImporting ? 'Importing...' : 'Import Backup'),
            ),
          ),

          // plan4 §6: restore semantics — WidgetConfig (Hive UUID) and
          // appWidgetId (Android) are different ID spaces, so a restore never
          // auto-re-attaches the physical Home Screen widgets.
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Restore khôi phục Collections và cài đặt Widget. '
              'Widget đã có trên Home Screen có thể cần cấu hình lại thủ công.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),

          const Divider(height: 32),

          // Snapshots Section
          _buildSection(
            title: 'Safety Snapshots',
            child: _snapshots.isEmpty
                ? const Text('No snapshots available')
                : Column(
                    children: _snapshots.map((snapshot) {
                      return ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(
                          snapshot.timestamp.toString().substring(0, 19),
                        ),
                        subtitle: Text(snapshot.formattedSize),
                        trailing: IconButton(
                          icon: const Icon(Icons.restore),
                          onPressed: () => _restoreFromSnapshot(snapshot),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
