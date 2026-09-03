import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/backup_service.dart';
import '../services/iap_service.dart';
import '../services/interstitial_ad_service.dart';
import '../services/rewarded_ad_service.dart';
import '../services/snapshot_manager.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import 'backup_screen.dart';
import 'recently_deleted_screen.dart';

class SettingsScreen extends StatefulWidget {
  final IapService iapService;
  final RewardedAdService rewardedAdService;
  final StorageService storageService;
  final WidgetService widgetService;
  final BackupService backupService;
  final SnapshotManager snapshotManager;
  final InterstitialAdController interstitialAdController;

  const SettingsScreen({
    super.key,
    required this.iapService,
    required this.rewardedAdService,
    required this.storageService,
    required this.widgetService,
    required this.backupService,
    required this.snapshotManager,
    required this.interstitialAdController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRestoring = false;
  bool _isWatchingAd = false;

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);
    try {
      final restored = await widget.iapService.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restored
                ? 'Pro features restored successfully'
                : 'No previous purchases found'),
            backgroundColor: restored ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _watchAdToUnlock() async {
    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);
    try {
      final rewarded = await widget.rewardedAdService.showRewardedAd();
      if (mounted) {
        setState(() {}); // Refresh Pro status row
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rewarded
                ? 'Pro unlocked for 24 hours!'
                : 'Ad not finished. Please try again.'),
            backgroundColor: rewarded ? Colors.green : Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
  }

  Future<void> _buyForever() async {
    final started = await widget.iapService.buyPro();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(started
              ? 'Opening store… complete the purchase to remove ads forever.'
              : 'Purchase unavailable right now.'),
        ),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    // Hosted on GitHub Pages of the QuoteWidget repo — static, versioned in git.
    final url = Uri.parse(
        'https://hoangsoft90.github.io/QuoteWidget/privacy.html');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = widget.iapService.isPro;
    final hoursLeft = widget.iapService.hoursRemaining;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Pro Status (time-bound model — Task 4)
          ListTile(
            leading: Icon(
              isPro ? Icons.star : Icons.star_border,
              color: isPro ? Colors.amber : null,
            ),
            title: Text(
              isPro
                  ? (widget.iapService.proUnlockedUntil!.year >= 9999
                      ? 'Pro (Remove Ads Forever)'
                      : 'Pro unlocked — ${hoursLeft}h left')
                  : 'Free (1 Widget)',
            ),
            subtitle: Text(
              isPro
                  ? 'All features unlocked'
                  : 'Watch a short ad to unlock Pro for 24h, or remove ads forever.',
            ),
            trailing: _isWatchingAd
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: isPro ? null : _watchAdToUnlock,
          ),

          // Remove Ads Forever (secondary IAP path)
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Remove Ads Forever'),
            subtitle: const Text('One-time purchase — no ads, Pro forever'),
            onTap: _buyForever,
          ),

          const Divider(),

          // Recently Deleted (Trash — Task 7)
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Recently Deleted'),
            subtitle: const Text('Restore or permanently delete trashed content'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecentlyDeletedScreen(
                    storageService: widget.storageService,
                    widgetService: widget.widgetService,
                    interstitialAdController: widget.interstitialAdController,
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // Backup & Restore (export/import + safety snapshots)
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Export, import, and safety snapshots'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BackupScreen(
                    backupService: widget.backupService,
                    snapshotManager: widget.snapshotManager,
                    storageService: widget.storageService,
                    interstitialAdController: widget.interstitialAdController,
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // Restore Purchases (required for Store review)
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Purchases'),
            subtitle: const Text('Restore Pro features from a previous purchase'),
            trailing: _isRestoring
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isRestoring ? null : _restorePurchases,
          ),

          const Divider(),

          // Privacy Policy (required for Google Play)
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How we handle your data'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: _openPrivacyPolicy,
          ),

          const Divider(),

          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Quote Widget – Your Words v1.0.0'),
          ),
        ],
      ),
    );
  }
}