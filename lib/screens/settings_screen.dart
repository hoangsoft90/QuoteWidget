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
  bool _isWatchingAd = false;

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
          // Pro Status — Watch ad to unlock Pro for 24h
          ListTile(
            leading: Icon(
              isPro ? Icons.star : Icons.star_border,
              color: isPro ? Colors.amber : null,
            ),
            title: Text(
              isPro
                  ? (widget.iapService.proUnlockedUntil!.year >= 9999
                      ? 'Pro (Lifetime)'
                      : 'Pro unlocked — ${hoursLeft}h left')
                  : 'Free (1 Widget)',
            ),
            subtitle: Text(
              isPro
                  ? 'Unlimited widgets — ads still active'
                  : 'Watch a short ad to unlock Pro for 24h.',
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

          const Divider(),

          // Recently Deleted (Trash)
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
